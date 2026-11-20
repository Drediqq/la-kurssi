#!/bin/bash

# exit if shit hits the fan
set -e

# where to sync
##############################################################################################################
REMOTE_HOST=""
REMOTE_USER=""
REMOTE_BACKUP_DIR="/home/$REMOTE_USER/backups/lakurssi"
SSH_KEY="/root/.ssh/rsync_key"
##############################################################################################################

# directories
##############################################################################################################
TIMESTAMP=$(date +"%Y%m%d_%H%M%S")
BACKUP_DIR="/var/backups/lakurssi_${TIMESTAMP}_backup"
TAR_NAME="backup_$TIMESTAMP.tar.gz"
DIR_NAME="/tmp/backups/lakurssi_$TIMESTAMP"
WEB_BU_TIME="/var/www/html/lakurssi/week2/templates/stats"
##############################################################################################################

echo "=> Backup start"

# make directories if they are missing
##############################################################################################################
mkdir -p "$BACKUP_DIR"
chmod 700 "$BACKUP_DIR"
mkdir -p "$DIR_NAME"
mkdir -p "$WEB_BU_TIME"
##############################################################################################################

# copy web content
##############################################################################################################
if [ -d "$WEB_BU_TIME" ]; then
    echo "=> backing up web content..."
    cp -a "$WEB_BU_TIME/." "$DIR_NAME/"
fi
##############################################################################################################

# make tarball (excluding lastbu.txt)
##############################################################################################################
echo "=> creating tar $TAR_NAME..."
tar --exclude="lastbu.txt" -czf "$BACKUP_DIR/$TAR_NAME" -C /tmp/backups "lakurssi_$TIMESTAMP"
chmod 600 "$BACKUP_DIR/$TAR_NAME"
##############################################################################################################

# rsync
##############################################################################################################
if [ -n "$REMOTE_HOST" ]; then
    echo "=> syncing to B -> ${REMOTE_USER}@${REMOTE_HOST}:${REMOTE_BACKUP_DIR}..."
    rsync -avz -e "ssh -i \"$SSH_KEY\" -o BatchMode=yes" \
        "${BACKUP_DIR}/${TAR_NAME}" \
        "${REMOTE_USER}@${REMOTE_HOST}:${REMOTE_BACKUP_DIR}/"
else
    echo "=> no host setup, skipping rsync"
fi
##############################################################################################################

# remove temp files and +week old backups
##############################################################################################################
echo "=> taking out the trash..."
rm -rf "$DIR_NAME"
find "$BACKUP_DIR" -name "backup_*.tar.gz" -mtime +7 -delete
##############################################################################################################

# write timestamp to web directory after backup completes
echo "last backup : $TIMESTAMP" > "$WEB_BU_TIME/lastbu.txt"