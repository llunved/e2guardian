#! /bin/bash


file_exists() {
    local f="$1"
    stat $f &>/dev/null
}

groupmod -o -g $PGID e2guardian
usermod -o -u $PUID e2guardian

if (! file_exists "/etc/e2guardian/*"); then
	echo ### Initializeing config dir
	cp -pRd /etc/e2guardian.default/* /etc/e2guardian/
fi

rm -rf /var/run/e2guardian.pid

chown -R e2guardian:e2guardian /etc/e2guardian /var/log/e2guardian

e2guardian -N -c /etc/e2guardian/e2guardian.conf

