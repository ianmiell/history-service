#!/bin/bash

set -uex


if ! [ -a secret ]
then
	echo 'Create secret file with your password, and run "chmod 400 secret"'
	exit 1
fi
if [[ $(expr $(stat -f%A secret) % 100) != '0' ]]
then
	echo 'Run "chmod 400 secret" - file should only be readable by you'
	exit 1
fi

SECRET="$(cat secret)"

read password
# Remove whitespace from end of password (eg when using telnet)
password="${password%"${password##*[![:space:]]}"}" 
# Password failure
if [[ ${password} != ${SECRET} ]]
then
	echo 'Password failure'
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
