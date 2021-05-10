#!/bin/bash


set -x

SERVICE=$IMAGE

env

# Make sure the host is mounted
if [ ! -d /host/etc -o ! -d /host/proc -o ! -d /host/var/run ]; then
	    echo "Host file system is not mounted at /host" >&2
	        exit 1
fi

# Make sure that we have required directories in the host
for CUR_DIR in /host/${LOGDIR}/${NAME} /host/${DATADIR}/${NAME} /host/${CONFDIR}/${NAME} ; do
    if [ ! -d $CUR_DIR ]; then
        mkdir -p $CUR_DIR
        chmod 775 $CUR_DIR
	chgrp -R 0 $CUR_DIR
	chmod g+r -R $CUR_DIR
    fi
done    

if [  ${IMAGE%%\/*} == "localhost" ]; then 
    PULLALLWAYS=""
else
    PULLALWAYS="--pull=always"
fi

echo chroot /host /usr/bin/podman create --name ${NAME} --net=host --label "io.containers.autoupdate=image" ${PULLALWAYS} --entrypoint /sbin/entrypoint.sh -v ${DATADIR}/${NAME}:/var/lib/e2guardian:z,rw -v ${CONFDIR}/${NAME}:/etc/e2guardian:z,rw -v ${LOGDIR}/${NAME}:/var/log/e2guardian:z,rw ${IMAGE} /bin/start.sh
chroot /host /usr/bin/podman create --name ${NAME} --net=host --label "io.containers.autoupdate=image" ${PULLALWAYS} --entrypoint /sbin/entrypoint.sh -v ${DATADIR}/${NAME}:/var/lib/e2guardian:z,rw -v ${CONFDIR}/${NAME}:/etc/e2guardian:z,rw -v ${LOGDIR}/${NAME}:/var/log/e2guardian:z,rw ${IMAGE} /bin/start.sh

chroot /host sh -c "/usr/bin/podman generate systemd --restart-policy=always -t 1 ${NAME} > /etc/systemd/system/${NAME}.service && systemctl daemon-reload && systemctl enable ${NAME}"

