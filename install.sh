#!/bin/bash

# exit if shit hits the fan
set -e


# update and install core dependencies
####################################################################################################
PACKAGES=(ca-certificates curl gnupg lsb-release rsync nginx docker-compose-v2)
MISSING_PACKAGES=()

# check which packages are installed already
for pkg in "${PACKAGES[@]}"; do
    
    if ! dpkg-query -W -f='${Status}' "$pkg" 2>/dev/null | grep -q "install ok installed"; then
        MISSING_PACKAGES+=("$pkg")
    fi
done
# if something is not installed, install them, otherwise skip installation
if [ ${#MISSING_PACKAGES[@]} -gt 0 ]; then
    echo "=> installing missing: ${MISSING_PACKAGES[*]}"
    sudo apt-get update
    sudo apt-get install -y "${MISSING_PACKAGES[@]}"
else
    echo "!= all good, skipping package install"
fi
    
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

echo "=> repo path : $REPO_DIR"
####################################################################################################



# making directory if its missing
####################################################################################################
echo "=> executing peasants..."
mkdir -p "$WEB_DIR/week3/stats"
####################################################################################################



# make sure scripts executable
####################################################################################################
chmod +x "$SCR_DIR/"*
####################################################################################################



# copy repo content
####################################################################################################
echo "=> copying web content.."
sudo mkdir -p /var/www/html/lakurssi
sudo cp -r "$WEB_DIR/"* /var/www/html/lakurssi
####################################################################################################


# script installation and automation
####################################################################################################
read -p "?= install master scripts? [Y/n]: " -r INSTALL_BACKUP_SCRIPTS
INSTALL_BACKUP_SCRIPTS=${INSTALL_BACKUP_SCRIPTS:-Y}

CRON_FILE="/etc/cron.d/lakurssi"
CRON_CONTENT=$'PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin\n'


if [[ "$INSTALL_BACKUP_SCRIPTS" =~ ^[Yy]$ ]]; then
    sudo cp \
    "$SCR_DIR/server_backup.sh" \
    "$SCR_DIR/db_backup.sh" \
    "$SCR_DIR/report.sh" \
    "$SCR_DIR/week4_stats.sh" \
    /usr/local/bin/

    CRON_CONTENT+="0 * * * * root /usr/local/bin/server_backup.sh >/dev/null 2>&1"$'\n'
    CRON_CONTENT+="0 * * * * root /usr/local/bin/db_backup.sh >/dev/null 2>&1"$'\n'
    CRON_CONTENT+="* * * * * root /usr/local/bin/week4_stats.sh >/dev/null 2>&1"$'\n'
    CRON_CONTENT+="* * * * * root /usr/local/bin/report.sh >/dev/null 2>&1"$'\n'
else
    sudo cp \
    "$SCR_DIR/report.sh" \
    "$SCR_DIR/replica_report.sh" \
    "$SCR_DIR/remove_stale_backups.sh" \
    /usr/local/bin/

    CRON_CONTENT+="* * * * * root /usr/local/bin/report.sh >/dev/null 2>&1"$'\n'
    CRON_CONTENT+="* * * * * root /usr/local/bin/replica_report.sh >/dev/null 2>&1"$'\n'
    CRON_CONTENT+="* * * * * root /usr/local/bin/remove_stale_backups.sh >/dev/null 2>&1"$'\n'
    mkdir -p $HOME/stats
    mkdir -p $HOME/backups/lakurssi
    
fi

sudo chmod +x /usr/local/bin/*
printf "%s" "$CRON_CONTENT" | sudo tee "$CRON_FILE" >/dev/null
sudo chown root:root "$CRON_FILE"
sudo chmod 0644 "$CRON_FILE"

# strict permissions
sudo chmod 644 "$CRON_FILE"

echo "=> scripts done"
####################################################################################################


# docker installation
####################################################################################################
read -p "?= install Docker containers? [Y/n]: " -r INSTALL_DOCKER
INSTALL_DOCKER=${INSTALL_DOCKER:-Y}

if [[ "$INSTALL_DOCKER" =~ ^[Yy]$ ]]; then
    sudo bash docker_install.sh
else
    echo "=> docker install skipped"
fi
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


echo "=> setup complete!"