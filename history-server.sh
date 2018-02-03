#!/bin/bash

set -ue

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
	# Password failure
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
		#
		#    run-one - run just one instance at a time of some command and
		#              unique set of arguments (useful for cronjobs, eg)
		#
		#    run-this-one - kill any identical command/args processes
		#                   before running this one
		#
		#    run-one-constantly - run-one, but respawn every time that one exits
		#
		#    run-one-until-success - run-one, but respawn until a successful exit
		#
		#    run-one-until-failure - run-one, but respawn until an unsuccessful exit
		#
		#    Copyright (C) 2010-2013 Dustin Kirkland <kirkland@ubuntu.com>
		#
		#    Authors:
		#        Dustin Kirkland <kirkland@ubuntu.com>
		#
		#    This program is free software: you can redistribute it and/or modify
		#    it under the terms of the GNU General Public License as published by
		#    the Free Software Foundation, either version 3 of the License.
		#
		#    This program is distributed in the hope that it will be useful,
		#    but WITHOUT ANY WARRANTY; without even the implied warranty of
		#    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
		#    GNU General Public License for more details.
		#
		#    You should have received a copy of the GNU General Public License
		#    along with this program.  If not, see <http://www.gnu.org/licenses/>.

		PROG="run-one"

		if [ $# -eq 0 ]; then
			echo "ERROR: no arguments specified" 1>&2
			exit 1
		fi

		# Cache hashes here, to keep one user from DoS'ing another
		# Test if home is writeable and owned by the current user;
		# which is not always the case -- e.g. daemon
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

		# Calculate the hash of the command and arguments
		CMD="$@"
		CMDHASH=$(echo "$CMD" | md5sum | awk '{print $1}')
		FLAG="$DIR/$CMDHASH"

		base="$(basename $0)"
		case "$base" in
			run-one)
				# Run the specified command, assuming we can flock this command string's hash
				if [[ $(uname) == 'Darwin' ]]
				then
					flock -n "$FLAG" "$@"
				else
					flock -xn "$FLAG" "$@"
				fi
			;;
			run-this-one)
				ps="$CMD"
				# Loop through matching pids
				for p in $(pgrep -u "$USER" -f "^$ps$" || true); do
					# Try to kill pid
					kill $p
					# And then block until killed
					while ps $p >/dev/null 2>&1; do
						kill $p
						sleep 1
					done
				done
				# Also try to use lsof, but it seems that flock()'s
				# are not always persistent enough, so this is purely auxilliary.
				pid=$(lsof "$FLAG" 2>/dev/null | awk '{print $2}' | grep "^[0-9]") || true
				[ -z "$pid" ] || kill $pid
				sleep 0.5
				# Run the specified command, assuming we can flock this command string's hash
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
					# Run the specified command, assuming we can flock this command string's hash
					set +e
					if [[ $(uname) == 'Darwin' ]]
					then
						flock -n "$FLAG" "$@"
					else
						flock -xn "$FLAG" "$@"
					fi
					if [ "$?" = 0 ]; then
						# If we were waiting for success, we're done
						[ "$base" = "run-one-until-success" ] && exit $?
						# Last run finished successfully, reset to minimum back-off of 1 second
						backoff=0
						backoff=0
					else
						# If we were waiting for failure, we're done
						[ "$base" = "run-one-until-failure" ] && exit $?
						# Last run failed, so slow down the retries
						retries=$((retries + 1))
						backoff=$((retries / 10))
						logger -t "${base}[$$]" "last run failed; sleeping [$backoff] seconds before next run"
					fi
					# Don't sleep more than 60 seconds
					[ $backoff -gt 60 ] && backoff=60
					sleep $backoff
				done
			;;
		esac
	END
	chmod +x run-one
fi

${RUN_ONE} socat -vvv TCP-LISTEN:${LISTEN_PORT},reuseaddr,fork SYSTEM:"$(pwd)/writer.sh" &

SOCATPID="$!"

function cleanup() {
	rm -f writer.sh run-one.sh
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
