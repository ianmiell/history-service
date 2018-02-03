#!/bin/bash

set -uex

SECRET="somesecret"

read password
# Remove whitespace from end of password (eg when using telnet)
password="${password%"${password##*[![:space:]]}"}" 
# Password failure
if [[ $password != $SECRET ]]
then
	exit 1
fi
while read input
do
	echo $input >> history.dat
done
