FROM amd64/alpine:3.12

RUN apk add --update --no-cache ca-certificates fuse openssh-client bzip2 bash docker ssmtp
RUN wget -O /tmp/restic_0.10.0_linux_amd64.bz2 https://github.com/restic/restic/releases/download/v0.10.0/restic_0.10.0_linux_amd64.bz2 \
    && bzip2 -d /tmp/restic_0.10.0_linux_amd64.bz2 \
    && mv /tmp/restic_0.10.0_linux_amd64 /usr/bin/restic \
    && chmod +x /usr/bin/restic

ADD rancher.sh /usr/bin
COPY *.crt /etc/ssl/certs

ENV RANCHER_CONTAINER_NAME=rancher
ENV RESTORE_SNAPSHOT=latest
ENV BACKUP_DIR=/home/rancher/backup/
ENV DELETE_OLDER_THAN_X_DAYS="30"
ENV KEEP_LAST="30"
ENV KEEP_DAILY="15"
ENV KEEP_WEEKLY="8"
ENV KEEP_MONTHLY="2"
ENV KEEP_WITHIN="2m"
ENV EMAIL_NOTIFICATIONS_ENABLED="NO"
ENV SMTP_HOST=""
ENV SMTP_PORT="587"
ENV SMTP_HOSTNAME="my-domain.com"
ENV SMTP_TLS="YES"
ENV SSMTP_USER=""
ENV SMTP_PASSWORD=""
ENV SENDER_EMAIL=""
ENV DEST_EMAIL=""
ENV EMAIL_SUBJECT="Rancher backup"
# How many days of the local backups we will keep on BACKUP_DIR
ENV DELETE_OLDER_THAN_X_DAYS="3"

ENTRYPOINT ["/usr/bin/rancher.sh"]
