#!/bin/bash
export LC_ALL=C

source /.restic-settings

case "$1" in
  "backup" )
    NOW=$(date +"%Y%m%d-%H%M%S")
    CURR_TAG=$(docker ps -f name=${RANCHER_CONTAINER_NAME} --format "{{.Image}}")
    echo CURR_TAG=${CURR_TAG}
    RANCHER_VERSION=$(echo ${CURR_TAG} | cut -f2 -d:)
    echo RANCHER_VERSION=${RANCHER_VERSION}
    ARCHIVE="/backup/rancher-data-backup-$RANCHER_VERSION-$NOW.tar.gz"
    echo ARCHIVE=${ARCHIVE}

    # Create local backup
    docker stop $RANCHER_CONTAINER_NAME
    docker create --volumes-from $RANCHER_CONTAINER_NAME --name "rancher-data-$NOW" ${CURR_TAG}
    docker run --volumes-from "rancher-data-$NOW" -v "${BACKUP_DIR}:/backup:z" --name "rancher-backup-$NOW" alpine:3.12 tar zcf $ARCHIVE /var/lib/rancher
    docker rm "rancher-data-$NOW"
    docker rm "rancher-backup-$NOW"
    docker start $RANCHER_CONTAINER_NAME

    # Delete old local backups
    find "/backup" -type f -mtime +$DELETE_OLDER_THAN_X_DAYS -exec rm {} \;

    # Off site backup with restic
    TAG="${RESTIC_TAG:-cron}"
    HOST="${RANCHER_HOST:-rancher}"
    /usr/bin/restic snapshots > /dev/null || /usr/bin/restic init
    /usr/bin/restic backup --host ${HOST} --tag ${CURR_TAG} --tag ${TAG} /backup &> /tmp/backup.log
    /usr/bin/restic forget --host ${HOST} --prune --keep-last $KEEP_LAST --keep-daily $KEEP_DAILY --keep-weekly $KEEP_WEEKLY --keep-monthly $KEEP_MONTHLY --keep-within $KEEP_WITHIN &>> /tmp/backup.log

    cat /tmp/backup.log

    if [ "$EMAIL_NOTIFICATIONS_ENABLED" == "YES" ]; then
      mkdir -p /etc/ssmtp/
      cat > /etc/ssmtp/ssmtp.conf <<EOL
mailhub=${SMTP_HOST}:${SMTP_PORT}
hostname=${SMTP_HOSTNAME}
rewriteDomain=${SMTP_HOSTNAME}
FromLineOverride=YES
AuthUser=${SMTP_USER}
AuthPass=${SMTP_PASSWORD}
UseTLS=${SMTP_TLS}
UseSTARTTLS=${SMTP_TLS}
EOL

      (echo "Subject: $EMAIL_SUBJECT"; echo "From: $SENDER_EMAIL"; echo "To: $DEST_EMAIL"; echo ""; cat /tmp/backup.log) | ssmtp $DEST_EMAIL
    fi

    ;;

  "snapshots" )
    /usr/bin/restic snapshots

    ;;

  "restore-from-snapshot" )
    SNAPSHOT="${RESTORE_SNAPSHOT:-latest}"

    /usr/bin/restic restore $SNAPSHOT --target /

    BACKUP_TO_RESTORE=`ls /backup/ -tr | tail -n1`

    docker stop $RANCHER_CONTAINER_NAME
    docker run --rm --volumes-from $RANCHER_CONTAINER_NAME -v "$BACKUP_DIR/:/backup:z" alpine:3.12 sh -c "rm /var/lib/rancher/* -rf  && tar zxvf /backup/$BACKUP_TO_RESTORE"
    docker start $RANCHER_CONTAINER_NAME

    ;;

  "restore-from-local-backup" )
    docker stop $RANCHER_CONTAINER_NAME
    docker run --rm --volumes-from $RANCHER_CONTAINER_NAME -v "$BACKUP_DIR/:/backup:z" alpine:3.12 sh -c "rm /var/lib/rancher/* -rf  && tar zxvf /backup/$LOCAL_BACKUP"
    docker start $RANCHER_CONTAINER_NAME

    ;;
esac
