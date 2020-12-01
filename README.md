# rancher-backup-restic

This is an image to easily manage backups and restores of a single node Rancher installation via a container. I use this on RancherOS (where everything runs as a container) so the instructions below are for RancherOS, but they can easily be adapted for general use with Docker. An S3 compatible bucket as the storage for the off site backups is currently required. Backups are performed by [Restic](https://restic.net/).

## Usage (e.g. on RancherOS)

- Before biulding Docker image put any custom CAs to the root folder
- Create a couple directories for the Rancher data and the local backups

```
cd /home/rancher
mkdir -p data
mkdir -p backup
```

- Run Rancher server if not running already

```
docker run -d --name rancher --restart unless-stopped -p 80:80 -p 443:443 -v $(pwd)/data:/var/lib/rancher rancher/rancher:v2.2.4 --acme-domain your-domain.com
```

- Create a secrets file for Restic

```
cat <<EOD > .restic-settings
export RESTIC_REPOSITORY=s3:host/bucket
export RESTIC_PASSWORD=...
export AWS_ACCESS_KEY_ID=...
export AWS_SECRET_ACCESS_KEY=...
EOD
```

### Manual backup
Please note that because of the current rancher image version fetching algorithm the backup contaier must not include word *rancher* in it's name.

You can pass `RESTIC_HOST` environment variable (default *restic*). Restic will only act on the backup set from this *host* (forget, snapshots)

You can mount custom certificates (crt) to */etc/ssl/certs* by specifying mountpoints like this:
`-v $(pwd)/certs/custom_cert.crt:/etc/ssl/certs/custom_sert.crt`
```
cd /home/rancher

docker run --rm --name backup-container --env RESTIC_HOST=${HOSTNAME} -v $(pwd)/backup:/backup -v $(pwd)/.restic-settings:/.restic-settings -v /var/run/docker.sock:/var/run/docker.sock zurajm/rancher-backup-restic:latest backup
```

A backup archive will be created in `rancher/backup`. NOTE: time zone for the timestamps in the filenames is UTC.

Optional environment variables with their defaults:

```
RANCHER_CONTAINER_NAME=rancher
BACKUP_DIR=/home/rancher/backup/

For email notifications:

EMAIL_NOTIFICATIONS_ENABLED="YES"
SMTP_HOST=""
SMTP_PORT="587"
SMTP_HOSTNAME="my-domain.com"
SMTP_TLS="YES"
SMTP_USER=""
SMTP_PASSWORD=""
SENDER_EMAIL=""
DEST_EMAIL=""
EMAIL_SUBJECT="Rancher backup"
```

Optional environment variables for Restic with their defaults (see Restic documentation):

```
DELETE_OLDER_THAN_X_DAYS="3" #how many days backups will be kept on local storage, independent of Restic settings
KEEP_LAST="30"
KEEP_DAILY="15"
KEEP_WEEKLY="8"
KEEP_MONTHLY="2"
KEEP_WITHIN="2m"
```

### Scheduled backup

To schedule a backup with cron in RancherOS create a config file:

```
cat <<EOD > /var/lib/rancher/conf/backup-container.yml
user-cron:
  image: rancher/container-crontab:v0.5.0
  uts: host
  net: none
  privileged: true
  restart: always
  volumes:
  - /var/run/docker.sock:/var/run/docker.sock
  environment:
    DOCKER_API_VERSION: "1.22"
scheduled-backup:
  image: zurajm/rancher-backup-restic:latest
  command:
  - "backup"
  volumes:
  - /var/run/docker.sock:/var/run/docker.sock
  - /home/rancher/backup:/backup
  - /home/rancher/.restic-settings:/.restic-settings
  labels:
    cron.schedule: "0 4 * * *"
  environment:
    RANCHER_CONTAINER_NAME: "rancher"
    BACKUP_DIR: "/home/rancher/backup/"
    EMAIL_NOTIFICATIONS_ENABLED: "NO"
    SMTP_HOST: "..."
    SMTP_PORT: "587"
    SMTP_HOSTNAME: "my-domain.com"
    SMTP_TLS: "YES"
    SMTP_USER: "..."
    SMTP_PASSWORD: "..."
    SENDER_EMAIL: ""
    DEST_EMAIL: ""
    EMAIL_SUBJECT: "Rancher backup"
EOD
```

Then run

```
sudo ros service enable /var/lib/rancher/conf/backup-container.yml
sudo ros service up user-cron scheduled-backup
```

### Restore from local backup

Find a backup to restore

```
ls -tr /home/rancher/rancher/backup
```

Then to restore that backup pass the `LOCAL_BACKUP` environment variable with the backup filename:

```
docker run --rm --name backup-container --env LOCAL_BACKUP=<filename> -v $(pwd)/backup:/backup -v $(pwd)/.restic-settings:/.restic-settings -v /var/run/docker.sock:/var/run/docker.sock zurajm/rancher-backup-restic:latest restore-from-local-backup
```

Optional environment variables with their defaults:

```
RANCHER_CONTAINER_NAME=rancher
BACKUP_DIR=/home/rancher/backup/
```


### Restore from Restic snapshot

#### Latest snapshot

```
docker run --rm --name backup-container -v $(pwd)/backup:/backup -v $(pwd)/.restic-settings:/.restic-settings -v /var/run/docker.sock:/var/run/docker.sock zurajm/rancher-backup-restic:latest restore-from-snapshot
```

#### An older snapshot

If you wish to restore a snapshot other than the latest, first find the snapshot to restore with:

```
cd /home/rancher

docker run --rm --name backup-container -v $(pwd)/backup:/backup -v $(pwd)/.restic-settings:/.restic-settings -v /var/run/docker.sock:/var/run/docker.sock zurajm/rancher-backup-restic:latest snapshots
```

Then to restore that snapshot pass the `RESTORE_SNAPSHOT` environment variable with the snapshot id:

```
docker run --rm --name backup-container --env RESTORE_SNAPSHOT=<snapshot id> -v $(pwd)/backup:/backup -v $(pwd)/.restic-settings:/.restic-settings -v /var/run/docker.sock:/var/run/docker.sock zurajm/rancher-backup-restic:latest restore-from-snapshot
```

Optional environment variables with their defaults:

```
RANCHER_CONTAINER_NAME=rancher
BACKUP_DIR=/home/rancher/backup/
```
