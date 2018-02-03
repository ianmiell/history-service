#!/bin/bash

set -ue

LISTEN_PORT=${1:-8456}

# Check socat is there
which socat > /dev/null 2>&1 || (echo socat should be installed && exit 1)

#socat -vvv TCP-LISTEN:${LISTEN_PORT},reuseaddr,fork OPEN:$(pwd)/history.dat,create,ignoreeof!!$(pwd)/history.dat
socat -vvv TCP-LISTEN:${LISTEN_PORT},reuseaddr,fork SYSTEM:$(pwd)/listener.sh
