#!/bin/bash

# exit if shit hits the fan
set -e




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
sudo cp -r "$WEB_DIR/"* /var/www/html/

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
    echo "=>.env exists, skipping cred setup"
else
# input env values
echo "############################"
echo "=>#####     env conf     #####"
echo "############################"

# db name
read -p "mysql database name: " DB_NAME
DB_NAME=${DB_NAME:-my_database}

# db user
read -p "mysql User: " DB_USER
DB_USER=${DB_USER:-my_user}

# ([s]ilent) password for user
read -sp "mysql password: " DB_PASSWORD
echo ""
while [ -z "$DB_PASSWORD" ]; do
    echo "empty password, no can do."
    read -sp "mysql password: " DB_PASSWORD
    echo ""
done

# [s]ilent password for root
read -sp "mysql root password: " MYSQL_ROOT_PASSWORD
echo ""
while [ -z "$MYSQL_ROOT_PASSWORD" ]; do
    echo ".. idiot"
    read -sp "mysql root password: " MYSQL_ROOT_PASSWORD
    echo ""
done


# write env file
echo "=> Writing configuration to $APP_OPT_DIR/.env..."
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
sudo docker compose up -d 
####################################################################################################



# nginx
####################################################################################################
echo "=> updating enjinks..."
sudo cp "$CFG_DIR/lakurssi.conf" /etc/nginx/sites-available/lakurssi
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
echo "=> automating script usage..."
if [ -z "$REPO_DIR" ]; then
    echo "REPO_DIR not set." >&2
    exit 1
fi

SCRIPT_PATH="/usr/local/bin"
CRON_COMMAND="* * * * * $SCRIPT_PATH/report.sh >/dev/null 2>&1"

# make temp file
TMP_CRON=$(mktemp)

# copy old cron setup to temp
crontab -l 2>/dev/null > "$TMP_CRON" || true


# check if command is setup alrady
if grep -Fq "$CRON_COMMAND" "$TMP_CRON"; then
    echo "=> cron already ready"
else
    echo "$CRON_COMMAND" >> "$TMP_CRON"
    crontab "$TMP_CRON"
    echo "=> cron success"
fi
####################################################################################################

echo "=> setup complete!"