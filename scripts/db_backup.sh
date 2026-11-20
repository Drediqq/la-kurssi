#!/bin/bash

# exit if shit hits the fan
set -e

ENV_L="/opt/master/.env"

# env vars
##############################################################################################################
if [ -f "$ENV_L" ]; then
    set -a
    source "$ENV_L"
    set +a
else
    echo "!= .env missing"
    exit 1
fi
##############################################################################################################

# timestamp filename
##############################################################################################################
TIMESTAMP=$(date +"%Y%m%d_%H%M%S")
BACKUP_FILE="dbbackup_${MYSQL_DATABASE}_${TIMESTAMP}.sql"
BACKUP_DIR="/var/backups/db_backup/"
mkdir -p "$BACKUP_DIR"

echo "=> backing up db: $MYSQL_DATABASE..."
##############################################################################################################

# dump the base
##############################################################################################################
docker exec mariadb_prime \
    mariadb-dump --single-transaction --quick -u root -p"$MYSQL_ROOT_PASSWORD" "$MYSQL_DATABASE" > "$BACKUP_DIR/$BACKUP_FILE"

echo "=> dump done"
##############################################################################################################

# remove old trash
##############################################################################################################
echo "=> removing too old backups..."
find "$BACKUP_DIR" -maxdepth 1 -name "dbbackup_${MYSQL_DATABASE}_*.sql" -mtime +7 -exec rm {} \;
##############################################################################################################

echo "=> db bu complete!"

