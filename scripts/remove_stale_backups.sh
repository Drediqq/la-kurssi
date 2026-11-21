#!/bin/bash

# exit if shit hits the fan
set -e

BACKUP_DIR="/var/backups/lakurssi/web_backup"

find "$BACKUP_DIR" -name "backup_*.tar.gz" -mtime +7 -delete