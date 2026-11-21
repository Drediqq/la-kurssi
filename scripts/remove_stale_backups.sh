#!/bin/bash

# exit if shit hits the fan
set -e

BACKUP_DIR="/home"

find "$BACKUP_DIR" -name "backup_*.tar.gz" -mtime +1 -delete