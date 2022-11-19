FROM ubuntu:22.10
LABEL MAINTAINER "Uwe Dauernheim <uwe@dauernheim.net>"

# Suppress warning about UTF-8
ENV LC_CTYPE=POSIX
ENV OVFTOOL_FILENAME=VMware-ovftool-4.5.0-20459872-lin.x86_64.bundle

ADD $OVFTOOL_FILENAME /tmp/

WORKDIR /root

RUN /bin/sh /tmp/$OVFTOOL_FILENAME --console --required --eulas-agreed && \
    rm -f /tmp/$OVFTOOL_FILENAME

ENTRYPOINT ["ovftool"]