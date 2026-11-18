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
GRANT SELECT, UPDATE ON \`${MYSQL_DATABASE}\`.visits TO '${MYSQL_USER}'@'%';
FLUSH PRIVILEGES;

CREATE USER '${REPLICA_USER}'@'%' IDENTIFIED BY '${REPLICA_PASSWORD}';
GRANT REPLICATION SLAVE ON *.* TO '${REPLICA_USER}'@'%';
FLUSH PRIVILEGES;
EOF

echo "=> Creating replication user on Master..."
sudo docker compose exec -T db mariadb -u "root" -p"$MYSQL_ROOT_PASSWORD" <<EOF
CREATE USER IF NOT EXISTS '${DB_REPLICA_USER}'@'%' IDENTIFIED BY '${DB_REPLICA_PASSWORD}';
GRANT REPLICATION SLAVE ON *.* TO '${DB_REPLICA_USER}'@'%';
FLUSH PRIVILEGES;
EOF


echo "=>db init success"