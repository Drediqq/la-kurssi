#!/bin/bash

#
set -e

# where to sync 
##############################################################################################################
REMOTE_HOST=""
REMOTE_USER=""
REMOTE_BACKUP_DIR="/home/${REMOTE_USER}/backups/lakurssi"
REMOTE_STATS_DIR="/home/${REMOTE_USER}/stats"
SSH_KEY="/root/.ssh/rsync_key"
##############################################################################################################

# paths and timestamps
##############################################################################################################
TIMESTAMP=$(date +"%Y%m%d_%H%M%S")
PRETTY_TIMESTAMP=$(date '+%d.%m.%Y %H:%M')

WEB_SRC="/var/www/html/lakurssi"
STATS_DIR="/var/www/html/lakurssi/week2/templates/stats"
BACKUP_DIR="/var/backups/lakurssi/web_backup"
STAGING_BASE="/tmp/backups"
STAGING_NAME="lakurssi_${TIMESTAMP}"
DIR_NAME="${STAGING_BASE}/${STAGING_NAME}"
TAR_NAME="backup_${TIMESTAMP}.tar.gz"
##############################################################################################################

cleanup() {
    rm -rf "$DIR_NAME"
}
trap cleanup EXIT

echo "=> Backup start"

# make directories if they are missing
##############################################################################################################
mkdir -p "$BACKUP_DIR" "$DIR_NAME" "$STATS_DIR"
chmod 700 "$BACKUP_DIR"
chmod 755 "$STATS_DIR"
##############################################################################################################

# copy web content from /var/www/html/lakurssi
##############################################################################################################
if [ -d "$WEB_SRC" ]; then
    echo "=> backing up web content from $WEB_SRC..."
    cp -a "$WEB_SRC/." "$DIR_NAME/"
else
    echo "=> source directory $WEB_SRC missing, creating empty staging folder"
fi
##############################################################################################################

# make tarball (excluding stats and temps)
##############################################################################################################
echo "=> creating tar $TAR_NAME..."
tar \
    --exclude="lastbu.txt" \
    --exclude="week2/templates/stats" \
    --exclude="week2/templates/stats/*" \
    --exclude="week4/stats" \
    --exclude="week4/stats/*" \
    --exclude="*.swp" \
    -czf "${BACKUP_DIR}/${TAR_NAME}" -C "$STAGING_BASE" "$STAGING_NAME"
chmod 600 "${BACKUP_DIR}/${TAR_NAME}"
##############################################################################################################

# rsync archive if remote target is configured
##############################################################################################################
if [ -n "$REMOTE_HOST" ] && [ -n "$REMOTE_USER" ]; then
    echo "=> syncing to B -> ${REMOTE_USER}@${REMOTE_HOST}:${REMOTE_BACKUP_DIR}..."
    ssh -i "$SSH_KEY" -o BatchMode=yes "${REMOTE_USER}@${REMOTE_HOST}" \
        "mkdir -p '${REMOTE_BACKUP_DIR}' '${REMOTE_STATS_DIR}'"
    rsync -az -e "ssh -i \"$SSH_KEY\" -o BatchMode=yes" \
        "${BACKUP_DIR}/${TAR_NAME}" \
        "${REMOTE_USER}@${REMOTE_HOST}:${REMOTE_BACKUP_DIR}/"
else
    echo "=> no host setup, skipping rsync"
fi
##############################################################################################################

# remove old backups older than 7 days
##############################################################################################################
echo "=> taking out the trash..."
find "$BACKUP_DIR" -name "backup_*.tar.gz" -mtime +7 -delete
##############################################################################################################

# write timestamp to stats
##############################################################################################################
TMP_LASTBU="${STATS_DIR}/lastbu.txt.tmp.$$"
printf '%s\n' "$PRETTY_TIMESTAMP" > "$TMP_LASTBU"
chmod 0644 "$TMP_LASTBU"
mv "$TMP_LASTBU" "${STATS_DIR}/lastbu.txt"

if [ -n "$REMOTE_HOST" ] && [ -n "$REMOTE_USER" ]; then
    echo "=> syncing lastbu.txt to ${REMOTE_USER}@${REMOTE_HOST}:${REMOTE_STATS_DIR}/..."
    rsync -az -e "ssh -i \"$SSH_KEY\" -o BatchMode=yes" \
        "${STATS_DIR}/lastbu.txt" \
        "${REMOTE_USER}@${REMOTE_HOST}:${REMOTE_STATS_DIR}/"
fi
##############################################################################################################

echo "=> Backup done"