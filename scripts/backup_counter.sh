#!/bin/bash
set -e

BACKUP_DIR="/var/backups/lakurssi/web_backup"
ORIG_FILE="/var/www/html/lakurssi/index.html"
TARGET_REL_PATH="index.html"
RESTORE_TMP="/tmp/restore_verify"
STATS_DIR="/var/www/html/lakurssi/week2/templates/stats"

mkdir -p "$RESTORE_TMP" "$STATS_DIR"
chmod 755 "$STATS_DIR"

# function to write value to file
write_values() {
  local target="$1"
  local value="$2"
  local tmp="${target}.tmp.$$"
  printf '%s\n' "$value" > "$tmp"
  chmod 0644 "$tmp"
  mv "$tmp" "$target"
}

LATEST_ARCHIVE=$(find "$BACKUP_DIR" -maxdepth 2 -type f -name '*.tar.gz' -printf '%T@ %p\n' 2>/dev/null | sort -nr | awk 'NR==1 {print $2}')

if [[ -z "${LATEST_ARCHIVE:-}" || ! -f "$ORIG_FILE" ]]; then
  write_values "$STATS_DIR/restore_check.txt" "MISSING"
  exit 0
fi

rm -rf "${RESTORE_TMP:?}/"*

ARCHIVE_ENTRY=$(tar -tzf "$LATEST_ARCHIVE" 2>/dev/null | grep -E "(^|/)${TARGET_REL_PATH}$" | head -n 1 || true)

if [[ -n "$ARCHIVE_ENTRY" ]] \
   && tar -xzf "$LATEST_ARCHIVE" -C "$RESTORE_TMP" "$ARCHIVE_ENTRY" 2>/dev/null \
   && [[ -f "$RESTORE_TMP/$ARCHIVE_ENTRY" ]] \
   && cmp -s "$ORIG_FILE" "$RESTORE_TMP/$ARCHIVE_ENTRY"; then
  write_values "$STATS_DIR/restore_check.txt" "MATCH"
else
  write_values "$STATS_DIR/restore_check.txt" "MISMATCH"
fi
EOF

sudo chmod 0755 /usr/local/bin/backup_check.sh