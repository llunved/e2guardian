#!/bin/bash

file_exists() {
	    local f="$1"
	        stat $f &>/dev/null
	}

if (! file_exists "/etc/e2guardian/*"); then
	        echo ### Initializeing config dir
		        cp -pRd /etc/e2guardian.default/* /etc/e2guardian/
fi

rm -rf /var/run/e2guardian.pid

exec /usr/local/sbin/e2guardian -N -c /etc/e2guardian/e2guardian.conf

