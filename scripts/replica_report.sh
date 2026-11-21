#!/bin/bash
set -u

CONTAINER_NAME="mariadb_replica"
DB_USER="replica"
STATS_DIR="/var/www/html/lakurssi/week2/templates/stats"

mkdir -p "$STATS_DIR"
chmod 755 "$STATS_DIR"

write_values() {
  local target="$1"
  local value="$2"
  local tmp="${target}.tmp.$$"
  printf '%s\n' "$value" > "$tmp"
  chmod 644 "$tmp"
  mv "$tmp" "$target"
}

if ! docker inspect -f '{{.State.Running}}' "$CONTAINER_NAME" 2>/dev/null | grep -q '^true$'; then
  write_values "$STATS_DIR/repl_status.txt" "CONTAINER DOWN"
  write_values "$STATS_DIR/repl_lag.txt" "N/A"
  echo "not working"
  exit 0
fi

CLIENT="mariadb"
if ! docker exec "$CONTAINER_NAME" command -v mariadb >/dev/null 2>&1; then
  CLIENT="mysql"
fi

ROW=$(docker exec "$CONTAINER_NAME" "$CLIENT" -u"$DB_USER" -N -B -e "SHOW SLAVE STATUS\G" 2>/dev/null)

IO_RUNNING=$(printf '%s\n' "$ROW" | awk -F': ' '/Slave_IO_Running:/ {print $2}')
SQL_RUNNING=$(printf '%s\n' "$ROW" | awk -F': ' '/Slave_SQL_Running:/ {print $2}')
LAG_SEC=$(printf '%s\n' "$ROW" | awk -F': ' '/Seconds_Behind_Master:/ {print $2}')

if [[ "$IO_RUNNING" == "Yes" && "$SQL_RUNNING" == "Yes" && "${LAG_SEC:-}" != "NULL" ]]; then
  write_values "$STATS_DIR/replica_status.txt" "OK (replicating)"
  write_values "$STATS_DIR/replica_lag.txt" "${LAG_SEC:-0}s"
  echo "$STATS_DIR/replica_status.txt" "OK (replicating) $STATS_DIR/replica_lag.txt" "${LAG_SEC:-0}s"
else
  write_values "$STATS_DIR/replica_status.txt" "ERROR / STOPPED"
  write_values "$STATS_DIR/replica_lag.txt" "N/A"
  echo "$STATS_DIR/replica_status.txt" "ERROR / STOPPED $STATS_DIR/replica_lag.txt" "N/A:"
fi