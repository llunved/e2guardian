# BUILD
FROM registry.fedoraproject.org/fedora:latest as build

WORKDIR /src


# INSTALL DEPENDENCIES

RUN dnf -y install \
	adns-devel \
	autoconf \
	autogen \
	automake \
	binutils \
	gcc-c++ \
	git \
	libtool \
	make \
	openssl-devel \
	patch \
	pcre-devel \
	zlib-devel
	

# BUILD
COPY . ./

#./configure '--prefix=/usr/' '--enable-clamd=yes' '--with-proxyuser=e2guardian' '--with-proxygroup=e2guardian' '--sysconfdir=/etc' '--localstatedir=/var' '--enable-icap=yes' '--enable-commandline=yes' '--enable-email=yes' '--enable-ntlm=yes' '--mandir=${prefix}/share/man' '--infodir=${prefix}/share/info' '--enable-pcre=yes' '--enable-sslmitm=yes' 'CPPFLAGS=-mno-sse2 -g -O2'

RUN \
    ./autogen.sh \
    && ./configure '--prefix=/usr/local' '--enable-clamd=yes' '--with-proxyuser=e2guardian' '--with-proxygroup=e2guardian' '--sysconfdir=/etc' '--localstatedir=/var' '--enable-icap=yes' '--enable-commandline=yes' '--enable-email=yes' '--enable-ntlm=yes' '--mandir=${prefix}/share/man' '--infodir=${prefix}/share/info' '--enable-pcre=yes' '--enable-sslmitm=yes' 'CPPFLAGS=-mno-sse2 -g -O2'

RUN \
    make && make install

RUN \ 
    sed -i "s|^.\{0,1\}dockermode = off$|dockermode = on|g" /etc/e2guardian/e2guardian.conf

# RUNTIME
FROM registry.fedoraproject.org/fedora-minimal:latest

COPY  --from=build /usr/local /usr/local

RUN microdnf -y install openssl adns pcre && microdnf -y clean all

RUN \
    echo '######## Modify openssl.cnf ########' && \
    echo -e \
        '[ ca ] \n'\
        'basicConstraints=critical,CA:TRUE \n' \
        >> /etc/pki/tls/openssl.cnf && \
    \
    echo '######## Create e2guardian account ########' && \
    groupmod -g 1000 users && \
    useradd -u 1000 -U -d /etc/e2guardian/config -s /bin/false e2guardian && \
    usermod -G users e2guardian && \
    \
    echo '######## Clean-up ########' && \
    rm -rf /tmp/* /var/cache/dnf/*

EXPOSE 8080

ENTRYPOINT ["/sbin/tini","-vv","-g","--","/app/sbin/entrypoint.sh"]


