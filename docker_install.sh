#!/bin/bash

# exit if shit hits the fan
set -e

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DOCKER_DIR=$REPO_DIR/docker

read -p "?= install master or slave? [M/s]: " -r INSTALL_MASTER
INSTALL_MASTER=${INSTALL_MASTER:-M}

if [[ "$INSTALL_MASTER" =~ ^[Mm]$ ]]; then
    ROLE="master"
    CONTAINER_NAME="mariadb_prime"
else
    ROLE="replica"
    CONTAINER_NAME="mariadb_replica"
fi

echo "=> chose $ROLE"

# docker
####################################################################################################
sudo mkdir -p /opt/$ROLE
sudo cp -r "$DOCKER_DIR/$ROLE" /opt/
####################################################################################################

# .env
####################################################################################################
APP_DIR="/opt/$ROLE"

if [ -f "$APP_DIR/.env" ]; then
    echo "!= .env exists, skipping cred setup"
else

# input env values
echo "############################"
echo "#####     env conf     #####"
echo "############################"

# db name
read -p "?= mysql database name: " DB_NAME
DB_NAME=${DB_NAME:-my_database}

# db user
read -p "?= mysql user: " DB_USER
DB_USER=${DB_USER:-my_user}

# [s]ilent password for user
read -sp "?= mysql password: " DB_PASSWORD
echo ""
while [ -z "$DB_PASSWORD" ]; do
    echo "!= empty password, no can do."
    read -sp "?= mysql password: " DB_PASSWORD
    echo ""
done

# [s]ilent password for root
read -sp "?= mysql root password: " MYSQL_ROOT_PASSWORD
echo ""
while [ -z "$MYSQL_ROOT_PASSWORD" ]; do
    echo "!= .. idiot"
    read -sp "?= mysql root password: " MYSQL_ROOT_PASSWORD
    echo ""
done

read -p "?= replica user: " DB_REPLICA_USER
DB_REPLICA_USER=${DB_REPLICA_USER:-replica_user}

read -sp "?= replica password: " DB_REPLICA_PASSWORD
echo ""
while [ -z "$DB_REPLICA_PASSWORD" ]; do
    echo "!= no password, unacceptable."
    read -sp "?= replica password: " DB_REPLICA_PASSWORD
    echo ""
done

if [ $ROLE = 'replica' ]; then
    read -p "?= replication database IP: " PEER_DB_HOST
    PEER_DB_HOST=${PEER_DB_HOST:-}

    read -p "?= replica database name: " PEER_DB_NAME
    PEER_DB_NAME=${PEER_DB_NAME:-}
else
    PEER_DB_HOST=""
    PEER_DB_NAME=""
fi

# write env file
echo "=> writing $APP_DIR/.env..."
sudo bash -c "cat > $APP_DIR/.env" <<EOF
MYSQL_ROOT_PASSWORD=$MYSQL_ROOT_PASSWORD
MYSQL_DATABASE=$DB_NAME
MYSQL_USER=$DB_USER
MYSQL_PASSWORD=$DB_PASSWORD
DB_REPLICA_USER=$DB_REPLICA_USER
DB_REPLICA_PASSWORD=$DB_REPLICA_PASSWORD
DB_HOST=db
DB_PORT=3306
PEER_DB_HOST=$PEER_DB_HOST
PEER_DB_NAME=$PEER_DB_NAME
SITE_MODE=$ROLE
EOF

# permissions to env for root only
sudo chmod 600 "$APP_DIR/.env"
echo "=> .env success"
fi
####################################################################################################

# start docker containers
####################################################################################################
cd "$APP_DIR"

if sudo docker network inspect --format '{{.Name}}' "shared-network" >/dev/null 2>&1; then
    echo "=! shared-network already exists, skipping creation"
else
    sudo docker network create shared-network
fi

sudo docker compose up -d 
####################################################################################################

# init db
####################################################################################################
echo "=> waiting for mariadb ($CONTAINER_NAME)..."
until sudo docker exec "$CONTAINER_NAME" mariadb-admin ping -h"localhost" -u"root" -p"$MYSQL_ROOT_PASSWORD" --silent 2>/dev/null; do
    echo -n "."
    sleep 3
done
echo "=> maria up"

if [ -f "init_db.sh" ]; then
    sudo chmod +x init_db.sh
    sudo bash init_db.sh
fi
####################################################################################################

echo "=> docker setup done for $ROLE"