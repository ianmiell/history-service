# history-service

## Setup

- Put password in 'secret' file for

- Run: 'chmod 400 secret' to make file relatively secure

- Test it: run `./server.sh` and `telnet` to host on port 8456 (change port in
listener.sh if you want). Input password, then some text, then `CTRL-]` and `q` to
exit telnet.

- Add `/path/to/server.sh` to cronjob to run as a service - run-one takes care of duplicates

```
* * * * * /path/to/server.sh || true
```

- Add this to your ~/.bashrc file, replacing YOURSECRET with the secret in the `secret` file and HOSTNAME with the host the service is running on.

```
        # history service                                                                                                              
        if [[ ${PROMPT_COMMAND} = '' ]]                                                                                                
        then                                                                                                                           
            PROMPT_COMMAND="printf 'YOURSECRET\n'"!!"'\n' | /dev/tcp/HOSTNAME/8456"
		else
			PROMPT_COMMAND="${PROMPT_COMMAND} && printf 'YOURSECRET\n'"!!"'\n' | /dev/tcp/HOSTNAME/8456"
		fi
```

The security level of this is sufficent to stop casual users from abusing your
file system or getting access (assuming your secret is strong enough and kept
safe), but is not enough to stop a determined attacker from doing damage.
Use at your own risk.

## Requirements

Requires: bash v4+

Check your version with:

```
echo ${BASH_VERSION[0]}
```

