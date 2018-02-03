#!/bin/bash

set -ue

# make sure we are in the right folder
cd "$(dirname ${BASH_SOURCE[0]})"

# Check we have run-one-constantly available
which run-one > /dev/null 2>&1 || (echo 'Install run-one && exit 1')

while true
do
	run-one ./listener.sh
done
