#!/bin/bash
set -e

BACKUP_DIR="/var/backups/lakurssi"        
ORIG_FILE="/var/www/html/lakurssi/index.html"
TEST_FILE_IN_ARCHIVE="index.html"
RESTORE_TMP="/tmp/restore_verify"
STATS_DIR="/var/www/html/lakurssi/week2/templates/stats"

mkdir -p "$RESTORE_TMP" "$STATS_DIR"
chmod 755 "$STATS_DIR"

write_values() {
  local target="$1"
  local value="$2"
  local tmp="${target}.tmp.$$"
  printf '%s\n' "$value" > "$tmp"
  chmod 644 "$tmp"
  mv "$tmp" "$target"
}

LATEST_ARCHIVE=$(ls -1t "$BACKUP_DIR"/*.tar.gz 2>/dev/null | head -n 1)

if [[ -z "${LATEST_ARCHIVE:-}" || ! -f "$ORIG_FILE" ]]; then
  write_values "$STATS_DIR/restore_check.txt" "MISSING"
  exit 0
fi

rm -rf "${RESTORE_TMP:?}/"*
if tar -xzf "$LATEST_ARCHIVE" -C "$RESTORE_TMP" "$TEST_FILE_IN_ARCHIVE" 2>/dev/null \
   && [[ -f "$RESTORE_TMP/$TEST_FILE_IN_ARCHIVE" ]] \
   && cmp -s "$ORIG_FILE" "$RESTORE_TMP/$TEST_FILE_IN_ARCHIVE"; then
  write_values "$STATS_DIR/restore_check.txt" "MATCH"
else
  write_values "$STATS_DIR/restore_check.txt" "MISMATCH"
fi