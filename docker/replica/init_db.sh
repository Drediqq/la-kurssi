#!/bin/bash

# exit if shit hits the fan
set -e

# load envs
if [ -f .env ]; then
    set -a
    source .env
    set +a
else
    echo "!= no env"
    exit 1
fi

# defaults
DB_HOST=${DB_HOST:-localhost}
DB_PORT=${DB_PORT:-3306}
MYSQL_DATABASE=${MYSQL_DATABASE:-db}
MYSQL_USER=${MYSQL_USER:-user}
REPLICA_USER=${DB_REPLICA_USER:-replicauser}
REPLICA_PASSWORD=${DB_REPLICA_PASSWORD:-verystrongpassword}
PEER_IP=${PEER_DB_HOST:-}

echo "initing db '$MYSQL_DATABASE' on $DB_HOST"

# spit variables to mysql
sudo docker compose exec -T db mariadb -u "root" -p"$MYSQL_ROOT_PASSWORD" <<EOF
CREATE DATABASE IF NOT EXISTS \`${MYSQL_DATABASE}\`;
USE \`${MYSQL_DATABASE}\`;

CREATE TABLE IF NOT EXISTS visits (
    id INT AUTO_INCREMENT PRIMARY KEY,
    count INTEGER NOT NULL
);

INSERT INTO visits (count)
SELECT 0
WHERE NOT EXISTS (SELECT 1 FROM visits);

CREATE USER IF NOT EXISTS '${MYSQL_USER}'@'%' IDENTIFIED BY '${MYSQL_PASSWORD}';
GRANT SELECT, UPDATE  ON \`${MYSQL_DATABASE}\`.visits TO '${MYSQL_USER}'@'%';
GRANT SLAVE MONITOR ON *.* TO '${MYSQL_USER}'@'%';
GRANT SELECT ON \`${PEER_DB_NAME}\`.* TO '${MYSQL_USER}'@'%';
FLUSH PRIVILEGES;
EOF

# replicate slave setup
if [ -n "$PEER_IP" ]; then
    echo "=> Replica to Master at $PEER_IP..."
    sudo docker compose exec -T db mariadb -u "root" -p"$MYSQL_ROOT_PASSWORD" <<EOF
STOP SLAVE;
CHANGE MASTER TO
  MASTER_HOST='$PEER_IP',
  MASTER_USER='${MYSQL_USER}',
  MASTER_PASSWORD='${MYSQL_PASSWORD}',
  MASTER_USE_GTID=slave_pos;
START SLAVE;
EOF
    echo "=> Replication ready <- $PEER_IP!"
else
    echo "!= PEER_DB_HOST empty, skipping CHANGE MASTER"
fi

echo "=> db init success"