#!/bin/bash

set -ue

# make sure we are in the right folder
cd "$(dirname ${BASH_SOURCE[0]})"

# Check we have run-one-constantly available
which run-one-constantly > /dev/null 2>&1 || (echo 'Install run-one to get the run-one-constantly command && exit 1')

run-one-constantly ./listener.sh
