FROM alpine

RUN apk add --update --no-cache ca-certificates fuse openssh-client bzip2 bash docker
RUN wget -O /tmp/restic_0.9.5_linux_amd64.bz2 https://github.com/restic/restic/releases/download/v0.9.5/restic_0.9.5_linux_amd64.bz2
RUN bzip2 -d /tmp/restic_0.9.5_linux_amd64.bz2
RUN mv /tmp/restic_0.9.5_linux_amd64 /usr/bin/restic

ADD rancher.sh /usr/bin

ENV RANCHER_CONTAINER_NAME=rancher
ENV RANCHER_VERSION=2.2.4
ENV RESTORE_SNAPSHOT=latest
KEEP_LAST="30"
KEEP_DAILY="15"
KEEP_WEEKLY="8"
KEEP_MONTHLY="2"
KEEP_WITHIN="2m"

ENTRYPOINT ["/usr/bin/rancher.sh"]
