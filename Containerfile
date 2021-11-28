ARG OS_RELEASE=35
ARG OS_IMAGE=fedora:$OS_RELEASE

FROM $OS_IMAGE as build

ARG OS_RELEASE
ARG OS_IMAGE
ARG HTTP_PROXY=""
ARG USER="e2guardian"

LABEL MAINTAINER riek@llunved.net

ENV LANG=en_US.UTF-8
ENV USER=$USER
USER root

RUN mkdir -p /src
WORKDIR /src

# Install dependencies in build environment
ADD ./contrib/podman-fedora/rpmreqs-rt.txt ./contrib/podman-fedora/rpmreqs-build.txt /src/

ENV http_proxy=$HTTP_PROXY

RUN rpm -ivh  https://download1.rpmfusion.org/free/fedora/rpmfusion-free-release-$OS_RELEASE.noarch.rpm \
    && rpm -ivh  https://download1.rpmfusion.org/nonfree/fedora/rpmfusion-nonfree-release-$OS_RELEASE.noarch.rpm \
    && dnf -y upgrade \
    && dnf -y install glibc-langpack-en $(cat /src/rpmreqs-rt.txt) $(cat /src/rpmreqs-build.txt) 


# Create the minimal target environment
RUN mkdir /sysimg \
    && dnf install --installroot /sysimg --releasever $OS_RELEASE --setopt install_weak_deps=false --nodocs -y coreutils-single glibc-minimal-langpack $(cat rpmreqs-rt.txt) \
    && if [ ! -z "$DEVBUILD" ] ; then dnf install  --installroot /sysimg --releasever $OS_RELEASE --setopt install_weak_deps=false --nodocs -y $(cat rpmreqs-dev.txt); fi \
    && rm -rf /sysimg/var/cache/* \
    && ls -alh /sysimg/var/cache

#Add the insteon user both in the build and rt contexts
RUN adduser -u 1010 -d /var/lib/e2guardian -r -U -G users,root,dialout -s /sbin/nologin -c "app user" $USER
RUN adduser -R /sysimg -d /var/lib/e2guardian -u 1010 -r -U -G users,root -s /sbin/nologin -c "app user" $USER

RUN mkdir -p /etc/e2guardian /var/lib/e2guardian /var/log/e2guardian

# BUILD
COPY . /src/

RUN \
    ./autogen.sh \
    && ./configure '--prefix=/usr/local' '--enable-clamd=yes' '--with-proxyuser=e2guardian' '--with-proxygroup=e2guardian' '--sysconfdir=/etc' '--localstatedir=/var' '--enable-icap=yes' '--enable-commandline=yes' '--enable-email=yes' '--enable-ntlm=yes' '--mandir=${prefix}/share/man' '--infodir=${prefix}/share/info' '--enable-pcre=yes' '--enable-sslmitm=yes' 'CPPFLAGS=-mno-sse2 -g -O2'

RUN \
    make && make install

RUN \ 
    sed -i "s|^.\{0,1\}dockermode = off$|dockermode = on|g" /etc/e2guardian/e2guardian.conf

# Copy to minimal target environment
RUN rsync -av /usr/local/ /sysimg/usr/local/ \
    && rsync -av /etc/e2guardian/ /sysimg/etc/e2guardian.default/ \
    && rsync -av /var/log/e2guardian/ /sysimg/var/log/e2guardian/ \
    && rsync -av /var/lib/e2guardian/ /sysimg/var/lib/e2guardian/ \
    && mkdir -v /sysimg/etc/e2guardian

RUN \
    echo '######## Modify openssl.cnf ########' && \
    echo -e \
        '[ ca ] \n'\
        'basicConstraints=critical,CA:TRUE \n' \
        >> /sysimg/etc/pki/tls/openssl.cnf 

ADD ./contrib/podman-fedora/entrypoint.sh \ 
    ./contrib/podman-fedora/install.sh \ 
    ./contrib/podman-fedora/upgrade.sh \
    ./contrib/podman-fedora/uninstall.sh /sysimg/sbin/ 
ADD ./contrib/podman-fedora/start.sh /sysimg/bin/ 
RUN chmod +x /sysimg/sbin/entrypoint.sh \ 
    && chmod +x /sysimg/sbin/install.sh \
    && chmod +x /sysimg/sbin/upgrade.sh \
    && chmod +x /sysimg/sbin/uninstall.sh \ 
    &&  chmod +x /sysimg/bin/start.sh


# RUNTIME
FROM scratch AS runtime
ARG USER="e2guardian"
#ARG USER="$USER"

LABEL MAINTAINER riek@llunved.net

ENV LANG=en_US.UTF-8
ENV USER=$USER

COPY --from=build /sysimg /

WORKDIR /var/lib/e2guardian

VOLUME /etc/e2guaridan
VOLUME /var/log/e2guardian
VOLUME /var/lib/e2guardian

ENV CHOWN=true
ENV CHOWN_DIRS="/etc/e2guardian /etc/e2guardian.default /var/log/e2guardian /var/lib/e2guardian"

EXPOSE 8080
ENTRYPOINT ["/sbin/entrypoint.sh"]
CMD ["/bin/start.sh"]

# FIXME LABEL RUN="podman run --rm -t -i --name \$NAME -p 8080:8080 --net=host --entrypoint /sbin/entrypoint.sh -v /var/lib/e2guardian:/var/lib/e2guardian -v /var/lib/insteon_mqtt/openzwave:/etc/openzwave -v /var/log/insteon_mqtt:/var/log/insteon_mqtt \$IMAGE /bin/start.sh"
LABEL INSTALL="podman run --rm -t -i --privileged --rm --net=host --ipc=host --pid=host -v /:/host -v /run:/run -e HOST=/host -e IMAGE=\$IMAGE -e NAME=\$NAME -e LOGDIR=/var/log -e DATADIR=/var/lib -e CONFDIR=/etc --entrypoint /bin/sh  \$IMAGE /sbin/install.sh"
LABEL UPGRADE="podman run --rm -t -i --privileged --rm --net=host --ipc=host --pid=host -v /:/host -v /run:/run -e HOST=/host -e IMAGE=\$IMAGE -e NAME=\$NAME -e LOGDIR=/var/log -e DATADIR=/var/lib -e CONFDIR=/etc --entrypoint /bin/sh  \$IMAGE /sbin/upgrade.sh"
LABEL UNINSTALL="podman run --rm -t -i --privileged --rm --net=host --ipc=host --pid=host -v /:/host -v /run:/run -e HOST=/host -e IMAGE=\$IMAGE -e NAME=\$NAME -e LOGDIR=/var/log -e DATADIR=/var/lib -e CONFDIR=/etc --entrypoint /bin/sh  \$IMAGE /sbin/uninstall.sh"


