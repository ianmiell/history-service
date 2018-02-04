#!/bin/bash

set -uex

# make sure we are in the right folder
cd "$(dirname ${BASH_SOURCE[0]})"

if ! [ -a secret ]
then
	echo 'Create secret file with your password, and run "chmod 400 secret"'
	exit 1
fi
if [[ $(expr $(stat -c %a secret 2> /dev/null || stat -f%A secret 2> /dev/null || echo stat failed) % 100) != '0' ]]
then
	echo 'Run "chmod 400 secret" - file should only be readable by you'
	exit 1
fi

LISTEN_PORT=${1}
LOGFILE=${2:-history-server.log}

# Check socat is there
which socat > /dev/null 2>&1 || (echo socat should be installed && exit 1)

cat > writer.sh <<- 'END'
	#!/bin/bash
	set -eu
	read password
	# Remove whitespace from end of password (eg when using telnet)
	password="${password%"${password##*[![:space:]]}"}"
	SECRET="$(cat secret)"
	if [[ ${password} != ${SECRET} ]]
	then
		echo 'Password failure'
		echo "Password failure: ${password} ${SECRET}" >> history-server.log
		exit 1
	fi
	touch history.dat
	while read input
	do
		echo $input >> history-server.log
		if [[ $input = '' ]]
		then
			cat history.dat
		fi
		echo $input >> history.dat
	done
END
chmod +x writer.sh

RUN_ONE='run-one'
if [[ $(uname -s) = 'Darwin' ]]
then
	RUN_ONE='./run-one'
	cat > run-one <<- 'END'
		#!/bin/sh -e
		PROG="run-one"
		if [ $# -eq 0 ]; then
			echo "ERROR: no arguments specified" 1>&2
			exit 1
		fi
		USER=$(id -un)
		for i in "${HOME}" "/dev/shm/${PROG}_${USER}"*; do
			if [ -w "$i" ] && [ -O "$i" ]; then
				DIR="$i"
				break
			fi
		done
		if [ -w "${DIR}" ] && [ -O "${DIR}" ]; then
			DIR="${DIR}/.cache/${PROG}"
		else
			DIR=$(mktemp -d "/dev/shm/${PROG}_${USER}_XXXXXXXX")
			DIR="${DIR}/.cache/${PROG}"
		fi
		mkdir -p "$DIR"
		CMD="$@"
		CMDHASH=$(echo "$CMD" | md5sum | awk '{print $1}')
		FLAG="$DIR/$CMDHASH"
		base="$(basename $0)"
		case "$base" in
			run-one)
				if [[ $(uname) == 'Darwin' ]]
				then
					flock -n "$FLAG" "$@"
				else
					flock -xn "$FLAG" "$@"
				fi
			;;
			run-this-one)
				ps="$CMD"
				for p in $(pgrep -u "$USER" -f "^$ps$" || true); do
					kill $p
					while ps $p >/dev/null 2>&1; do
						kill $p
						sleep 1
					done
				done
				pid=$(lsof "$FLAG" 2>/dev/null | awk '{print $2}' | grep "^[0-9]") || true
				[ -z "$pid" ] || kill $pid
				sleep 0.5
				if [[ $(uname) == 'Darwin' ]]
				then
					flock -n "$FLAG" "$@"
				else
					flock -xn "$FLAG" "$@"
				fi
			;;
			keep-one-running|run-one-constantly|run-one-until-success|run-one-until-failure)
				backoff=0
				retries=0
				while true; do
					set +e
					if [[ $(uname) == 'Darwin' ]]
					then
						flock -n "$FLAG" "$@"
					else
						flock -xn "$FLAG" "$@"
					fi
					if [ "$?" = 0 ]; then
						[ "$base" = "run-one-until-success" ] && exit $?
						backoff=0
						backoff=0
					else
						[ "$base" = "run-one-until-failure" ] && exit $?
						retries=$((retries + 1))
						backoff=$((retries / 10))
						logger -t "${base}[$$]" "last run failed; sleeping [$backoff] seconds before next run"
					fi
					[ $backoff -gt 60 ] && backoff=60
					sleep $backoff
				done
			;;
		esac
	END
	chmod +x run-one
fi

which ${RUN_ONE} || (echo run-one should be installed && exit 1)

${RUN_ONE} socat -vvv TCP-LISTEN:${LISTEN_PORT},reuseaddr,fork SYSTEM:"$(pwd)/writer.sh"

SOCATPID="$!"

function cleanup() {
	kill ${SOCATPID} >/dev/null 2>&1 || return > /dev/null 2>&1
	echo Pausing before final kill >> ${LOGFILE}
	sleep 10
	if ps -p ${SOCATPID} > /dev/null 2>&1
	then
		kill -9 ${SOCATPID}
	fi
}

trap cleanup EXIT INT TERM

wait
