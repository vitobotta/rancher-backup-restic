# rancher-backup-restic

This is an image to easily manage backups and restores of a single node Rancher installation via a container. I use this on RancherOS (where everything runs as a container) so the instructions below are for RancherOS, but they can easily be adapted for general use with Docker. An S3 compatible bucket as the storage for the off site backups is currently required. Backups are performed by [Restic](https://restic.net/).

## Usage (e.g. on RancherOS)

- Create a couple directories for the Rancher data and the local backups

```
cd /home/rancher
mkdir -p rancher/data
mkdir -p rancher/backup
```

- Run Rancher server if not running already

```
docker run -d --name rancher --restart unless-stopped -p 80:80 -p 443:443 -v $(pwd)/rancher/data:/var/lib/rancher rancher/rancher:2.2.4 --acme-domain your-domain.com
```

- Create a secrets file for Restic

```
cat <<EOD > rancher/.restic-settings
export RESTIC_REPOSITORY=s3:host/bucket
export RESTIC_PASSWORD=...
export AWS_ACCESS_KEY_ID=...
export AWS_SECRET_ACCESS_KEY=...
EOD
```

### Manual backup

```
cd /home/rancher

docker run --rm --name rancher-backup -v $(pwd)/rancher/backup:/backup -v $(pwd)/rancher/.restic-settings:/.restic-settings -v /var/run/docker.sock:/var/run/docker.sock backup
```

A backup archive will be created in `rancher/backup`.

Optional environment variables with their defaults:

```
RANCHER_CONTAINER_NAME=rancher
RANCHER_VERSION=2.2.4
```

Optional environment variables for Restic with their defaults (see Restic documentation):

```
KEEP_LAST="30"
KEEP_DAILY="15"
KEEP_WEEKLY="8"
KEEP_MONTHLY="2"
KEEP_WITHIN="2m"
```

### Scheduled backup

To schedule a backup with cron in RancherOS create a config file:

```
cat <<EOD > /var/lib/rancher/conf/rancher-backup.yml
user-cron:
  image: rancher/container-crontab:v0.5.0
  uts: host
  net: none
  privileged: true
  restart: always
  volumes:
  - /var/run/docker.sock:/var/run/docker.sock
  environment:
    DOCKER_API_VERSION: "1.39"
rancher-backup:
  image: vitobotta/rancher-backup-restic:0.1.0
  command:
  - "backup"
  volumes:
  - /var/run/docker.sock:/var/run/docker.sock
  - /home/rancher/rancher/backup:/backup
  - /home/rancher/rancher/.restic-settings:/.restic-settings
  labels:
    cron.schedule: "0 4 * * *"
  environment:
    ENV RANCHER_CONTAINER_NAME=rancher
    ENV RANCHER_VERSION=2.2.4
EOD
```

Then reboot.


### Restore from local backup

Find a backup to restore

```
ls -tr /home/rancher/rancher/backup
```

Then to restore that backup pass the `LOCAL_BACKUP` environment variable with the backup filename:

```
docker run --rm --name rancher-backup --env LOCAL_BACKUP=<filename> -v $(pwd)/rancher/backup:/backup -v $(pwd)/rancher/.restic-settings:/.restic-settings -v /var/run/docker.sock:/var/run/docker.sock restore-from-local-backup
```


### Restore from Restic snapshot

#### Latest snapshot

```
docker run --rm --name rancher-backup -v $(pwd)/rancher/backup:/backup -v $(pwd)/rancher/.restic-settings:/.restic-settings -v /var/run/docker.sock:/var/run/docker.sock restore
```

#### An older snapshot

If you wish to restore a snapshot other than the latest, first find the snapshot to restore with:

```
cd /home/rancher

docker run --rm --name rancher-backup -v $(pwd)/rancher/backup:/backup -v $(pwd)/rancher/.restic-settings:/.restic-settings -v /var/run/docker.sock:/var/run/docker.sock snapshots
```

Then to restore that snapshot pass the `RESTORE_SNAPSHOT` environment variable with the snapshot id:

```
docker run --rm --name rancher-backup --env RESTORE_SNAPSHOT=<snapshot id> -v $(pwd)/rancher/backup:/backup -v $(pwd)/rancher/.restic-settings:/.restic-settings -v /var/run/docker.sock:/var/run/docker.sock restore-from-snapshot
```
