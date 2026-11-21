#!/bin/bash
set -u

USER_NAME="${USER_NAME:-je}"
CONTAINER_NAME="mariadb_replica"
DB_USER="${DB_USER:-replica}"
DB_PASS="${DB_PASS:-}"
ENV_FILE="/opt/replica/.env"
STATS_DIR="/var/www/html/lakurssi/week2/templates/stats"

mkdir -p "$STATS_DIR"
chmod 755 "$STATS_DIR"
# read env
if [ -f "$ENV_FILE" ]; then
  set -a
  . "$ENV_FILE"
  set +a
  DB_USER="${MYSQL_USER:-$DB_USER}"
  DB_PASS="${MYSQL_PASSWORD:-$DB_PASS}"
fi

write_values() {
  local target="$1"
  local value="$2"
  local tmp="${target}.tmp.$$"
  printf '%s\n' "$value" > "$tmp"
  chmod 0644 "$tmp"
  mv "$tmp" "$target"
}

if ! docker inspect -f '{{.State.Running}}' "$CONTAINER_NAME" 2>/dev/null | grep -q '^true$'; then
  write_values "$STATS_DIR/replica_status.txt" "CONTAINER DOWN"
  write_values "$STATS_DIR/replica_lag.txt" "N/A"
  echo "not working"
  exit 0
fi
# get slave status
ROW=$(docker exec -e MYSQL_PWD="$DB_PASS" "$CONTAINER_NAME" mariadb -u"$DB_USER" -e "SHOW SLAVE STATUS\G" 2>&1 || true)

IO_RUNNING=$(printf '%s\n' "$ROW" | awk -F': ' '/^[[:space:]]*Slave_IO_Running:/ {gsub(/\r/, "", $2); gsub(/^[[:space:]]+|[[:space:]]+$/, "", $2); print $2}')
SQL_RUNNING=$(printf '%s\n' "$ROW" | awk -F': ' '/^[[:space:]]*Slave_SQL_Running:/ {gsub(/\r/, "", $2); gsub(/^[[:space:]]+|[[:space:]]+$/, "", $2); print $2}')
LAG_SEC=$(printf '%s\n' "$ROW" | awk -F': ' '/^[[:space:]]*Seconds_Behind_Master:/ {gsub(/\r/, "", $2); gsub(/^[[:space:]]+|[[:space:]]+$/, "", $2); print $2}')

#write to files
if [[ "$IO_RUNNING" == "Yes" && "$SQL_RUNNING" == "Yes" && "${LAG_SEC:-}" != "NULL" ]]; then
  write_values "$STATS_DIR/replica_status.txt" "OK (replicating)"
  write_values "$STATS_DIR/replica_lag.txt" "${LAG_SEC:-0}s"
  echo "$STATS_DIR/replica_status.txt" "OK (replicating) $STATS_DIR/replica_lag.txt" "${LAG_SEC:-0}s"
else
  write_values "$STATS_DIR/replica_status.txt" "ERROR / STOPPED"
  write_values "$STATS_DIR/replica_lag.txt" "N/A"
  echo "$STATS_DIR/replica_status.txt" "ERROR / STOPPED $STATS_DIR/replica_lag.txt" "N/A:"
fi
#copy stats to proper folder
if [ -d "/home/$USER_NAME/stats" ]; then
  cp -a "/home/$USER_NAME/stats/." "$STATS_DIR/"
fi