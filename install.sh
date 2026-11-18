#!/bin/bash

# exit if shit hits the fan
set -e

# update and install core dependencies
####################################################################################################
echo "=> installing system dependencies..."
sudo apt-get update
sudo apt-get install -y \
    ca-certificates \
    curl \
    gnupg \
    lsb-release \
    rsync \
    nginx \
    docker-compose

# enable docker demon
sudo systemctl enable --now docker
# add user to docker group
sudo usermod -aG docker $USER

####################################################################################################

# get directory
####################################################################################################
REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
WEB_DIR=$REPO_DIR/website
SCR_DIR=$REPO_DIR/scripts
CFG_DIR=$REPO_DIR/configs
DOCKER_DIR=$REPO_DIR/docker
echo "=> repo path : $REPO_DIR"
####################################################################################################



# making directory if its missing
####################################################################################################
echo "=> executing peasants..."
mkdir -p "$WEB_DIR/week3/stats"
####################################################################################################



# make script executable
####################################################################################################
chmod +x "$SCR_DIR/report.sh"
####################################################################################################



# copy repo content
####################################################################################################
echo "=> copying web content.."
sudo mkdir -p /var/www/html/lakurssi
sudo cp -r "$WEB_DIR/"* /var/www/html/lakurssi

echo "=> copying scripts.."
sudo cp -r "$SCR_DIR/"* /usr/local/bin
####################################################################################################



# docker
####################################################################################################
sudo cp -r "$DOCKER_DIR/"* /opt/
####################################################################################################



# .env
####################################################################################################
APP_OPT_DIR="/opt/w2-app"

if [ -f "$APP_OPT_DIR/.env" ]; then
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

# ([s]ilent) password for user
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


# write env file
echo "=> writing $APP_OPT_DIR/.env..."
sudo bash -c "cat > $APP_OPT_DIR/.env" <<EOF
MYSQL_ROOT_PASSWORD=$MYSQL_ROOT_PASSWORD
MYSQL_DATABASE=$DB_NAME
MYSQL_USER=$DB_USER
MYSQL_PASSWORD=$DB_PASSWORD
DB_HOST=db
DB_PORT=3306
EOF


# permissions to env for root only
sudo chmod 600 "$APP_OPT_DIR/.env"
echo "=> .env success"
fi
####################################################################################################



# start docker containers
####################################################################################################
cd /opt/w2-app
sudo docker network create shared-network || true
sudo docker compose up -d 
echo "=> waiting for mariadb"
until sudo docker exec mariadb_prime mariadb-admin ping -h"localhost" -u"root" -p"$MYSQL_ROOT_PASSWORD" --silent 2>/dev/null; do
    echo -n "."
    sleep 5
done
echo "=> maria up"
sudo chmod +x init_db.sh
sudo bash init_db.sh
####################################################################################################



# nginx
####################################################################################################
echo "=> updating enjinks..."
sudo cp "$CFG_DIR/lakurssi.conf" /etc/nginx/sites-available/lakurssi
sudo rm -f /etc/nginx/sites-enabled/default
sudo ln -sf /etc/nginx/sites-available/lakurssi /etc/nginx/sites-enabled/
####################################################################################################

# test nginx
####################################################################################################
sudo nginx -t
sudo systemctl restart nginx
echo "=> Nginx success"
####################################################################################################

# cron
####################################################################################################
echo "=> automating scripts..."


CRON_FILE="/etc/cron.d/lakurssi-report"

# make report run as root
sudo bash -c "cat > $CRON_FILE" <<EOF
* * * * * root /usr/local/bin/report.sh >/dev/null 2>&1
EOF

# strict permissions
sudo chmod 644 "$CRON_FILE"

echo "=> cron success"
####################################################################################################

echo "=> setup complete!"