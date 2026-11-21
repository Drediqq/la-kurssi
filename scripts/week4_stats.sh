#!/bin/bash
set -e

REMOTE_HOST="${REMOTE_HOST:-}"
REMOTE_USER="${REMOTE_USER:-}"
REMOTE_STATS_DIR="${REMOTE_STATS_DIR:-${REMOTE_USER:+/home/${REMOTE_USER}/stats}}"
REMOTE_STATS_DIR="${REMOTE_STATS_DIR:-$STATS_DIR}"
SSH_KEY="${SSH_KEY:-/root/.ssh/rsync_key}"
PRETTY_TIMESTAMP="${PRETTY_TIMESTAMP:-}"

BACKUP_DIR="${BACKUP_DIR:-}"
STATS_DIR="${STATS_DIR}"

ORIG_FILE="/var/www/html/lakurssi/index.html"
TEST_FILE="index.html"
RESTORE_TMP="/tmp/restore_verify"

mkdir -p "$STATS_DIR" "$RESTORE_TMP"
chmod 755 "$STATS_DIR"


#write function
################################################################################################
write_values() {
  local target="$1"
  local value="$2"
  local tmp="${target}.tmp.$$"
  printf '%s\n' "$value" > "$tmp"
  chmod 0644 "$tmp"
  mv "$tmp" "$target"
}
################################################################################################


# backup count
################################################################################################
if [[ -d "$BACKUP_DIR" ]]; then
  COUNT=$(find "$BACKUP_DIR" -maxdepth 1 -type f -name '*.tar.gz' | wc -l)
  write_values "$STATS_DIR/bu_count.txt" "$COUNT"
else
  write_values "$STATS_DIR/bu_count.txt" "0"
fi
################################################################################################


# restore check
################################################################################################
LATEST_ARCHIVE=$(ls -1t "$BACKUP_DIR"/*.tar.gz 2>/dev/null | head -n 1 || true)
ARCHIVE_ENTRY=$(tar -tzf "$LATEST_ARCHIVE" 2>/dev/null | grep -E '(^|/)index\.html$' | head -n 1 || true)

if [[ -z "${LATEST_ARCHIVE:-}" || ! -f "$ORIG_FILE" ]]; then
  write_values "$STATS_DIR/restore_check.txt" "MISSING"
elif [[ -z "${ARCHIVE_ENTRY:-}" ]]; then
  write_values "$STATS_DIR/restore_check.txt" "MISSING"
else
  rm -rf "${RESTORE_TMP:?}/"*
  if tar -xzf "$LATEST_ARCHIVE" -C "$RESTORE_TMP" "$ARCHIVE_ENTRY" 2>/dev/null \
     && [[ -f "$RESTORE_TMP/$ARCHIVE_ENTRY" ]] \
     && cmp -s "$ORIG_FILE" "$RESTORE_TMP/$ARCHIVE_ENTRY"; then
    write_values "$STATS_DIR/restore_check.txt" "MATCH"
  else
    write_values "$STATS_DIR/restore_check.txt" "MISMATCH"
  fi
fi
################################################################################################


# timestamp and sync
################################################################################################
if [ -n "${PRETTY_TIMESTAMP:-}" ]; then
  TMP_LASTBU="${STATS_DIR}/lastbu.txt.tmp.$$"
  printf '%s\n' "$PRETTY_TIMESTAMP" > "$TMP_LASTBU"
  chmod 0644 "$TMP_LASTBU"
  mv "$TMP_LASTBU" "${STATS_DIR}/lastbu.txt"
fi

REMOTE_STATS_DIR="${REMOTE_STATS_DIR:-$STATS_DIR}"

if [ -n "${REMOTE_HOST:-}" ] && [ -n "${REMOTE_USER:-}" ]; then
  echo "=> syncing stats to ${REMOTE_USER}@${REMOTE_HOST}:${REMOTE_STATS_DIR}/..."
  SSH_OPTS=(-o BatchMode=yes)
  if [ -n "${SSH_KEY:-}" ]; then
    SSH_OPTS+=(-i "$SSH_KEY")
  fi

  FILES_TO_SYNC=()
  for f in "${STATS_DIR}/bu_count.txt" "${STATS_DIR}/restore_check.txt" "${STATS_DIR}/lastbu.txt"; do
    [ -f "$f" ] && FILES_TO_SYNC+=("$f")
  done

  if [ "${#FILES_TO_SYNC[@]}" -gt 0 ]; then
    rsync -az -e "ssh ${SSH_OPTS[*]}" \
      "${FILES_TO_SYNC[@]}" \
      "${REMOTE_USER}@${REMOTE_HOST}:${REMOTE_STATS_DIR}/"
  fi
fi
################################################################################################