# history-service

## Overview

Stores your history on a central server. 

All you need is a port and a host to serve from, and your bash commands will be sent to and retrieved from there.

## Setup


Key for below:

```
PORTNUMBER - port you want to run on
YOURSECRET - your secret word for entry to service
HOSTNAME   - hostname you run the service on
```

- Put password for the service in 'secret' file (on one line)

- Run: `chmod 400 secret` to make the file (relatively) secure

- Test it:

Run, replacing YOURSECRET with your secret above.

```
./history-server.sh PORTNUMBER &
printf 'YOURSECRET\ntest\n' | nc localhost 8546
printf 'YOURSECRET\n\n' | nc localhost 8546
kill %1
```

Change port in `listener.sh` if you want, but remember to change below too.

- Add `/path/to/history-service/server.sh` to cronjob to run as a service - run-one takes care of duplicates

```
* * * * * /path/to/history-service/server.sh
```

- Add this to your ~/.bashrc file, replacing YOURSECRET with the secret in the
`secret` file and HOSTNAME with the host the service is running on.

```
# history service
function history_service_send_last_command() { LAST=$(HISTTIMEFORMAT='' builtin history 1 | cut -c 8-); printf 'YOURSECRET\n'"${LAST}"'\n' | nc HOSTNAME PORTNUMBER; }
if [[ ${PROMPT_COMMAND} = '' ]]
then
	PROMPT_COMMAND="history_service_send_last_command"
else
	PROMPT_COMMAND="${PROMPT_COMMAND};history_service_send_last_command"
fi
alias history="printf 'YOURSECRET\n\n' | nc HOSTNAME PORTNUMBER'
```

The security level of this is sufficent to stop casual users from abusing your
file system or getting access (assuming your secret is strong enough and kept
safe), but is not enough to stop a determined attacker from doing damage.
Use at your own risk.

## Requirements

Requires:

- bash v4+

Check your version with:

```
echo ${BASH_VERSION[0]}
```

If you are on a Mac, you may want to `brew install bash` to get a later version.

- socat

http://www.dest-unreach.org/socat/

Available on most package managers
