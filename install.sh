#!/bin/bash

# exit if shit hits the fan
set -e

# get directory
REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
echo "=> repo path : $REPO_DIR"

# make script executable
echo "=> executing peasants..."
mkdir -p "$REPO_DIR/week3/stats"
chmod +x "$REPO_DIR/week3/report.sh"

# nginx
echo "=> updating enjinks..."
sudo bash -c "cat > /etc/nginx/sites-available/default" <<'EOF'
##
# You should look at the following URL's in order to grasp a solid understanding
# of Nginx configuration files in order to fully unleash the power of Nginx.
# https://www.nginx.com/resources/wiki/start/
# https://www.nginx.com/resources/wiki/start/topics/tutorials/config_pitfalls/
# https://wiki.debian.org/Nginx/DirectoryStructure
#
# In most cases, administrators will remove this file from sites-enabled/ and
# leave it as reference inside of sites-available where it will continue to be
# updated by the nginx packaging team.
#
# This file will automatically load configuration files provided by other
# applications, such as Drupal or Wordpress. These applications will be made
# available underneath a path with that package name, such as /drupal8.
#
# Please see /usr/share/doc/nginx-doc/examples/ for more detailed examples.
##

# Default server configuration
#
server {
        listen 80 default_server;
        listen [::]:80 default_server;

        root /home/ubuntu/la-kurssi;
        index index.html index.htm;

        server_name _;

        # strip trailing .html
        location ~ ^/(?<path>.*)\.html$ {
                return 301 /$path;
        }

        # reverse proxy week2
        location /week2 {
                proxy_pass http://127.0.0.1:5000;
                proxy_set_header Host $host;
                proxy_set_header X-Real-IP $remote_addr;
                proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
                proxy_set_header X-Forwarded-Proto $scheme;
        }

        # week3
        location /week3 {
                try_files $uri /week3/week3.html =404;
        }

        # stats with caching disabled
        location /week3/stats/ {
                add_header Cache-Control "no-store, no-cache, must-revalidate, proxy-revalidate, max-age=0";
                expires off;
        }

        # assets directories
        location /css/ {
                alias /home/ubuntu/la-kurssi/css/;
        }
        location /js/ {
                alias /home/ubuntu/la-kurssi/js/;
        }

        # handler for everything else
        location / {
                try_files $uri $uri/ $uri.html =404;
        }

        # pass PHP scripts to FastCGI server
        #
        #location ~ \.php$ {
        #       include snippets/fastcgi-php.conf;
        #
        #       # With php-fpm (or other unix sockets):
        #       fastcgi_pass unix:/run/php/php7.4-fpm.sock;
        #       # With php-cgi (or other tcp sockets):
        #       fastcgi_pass 127.0.0.1:9000;
        #}

        # deny access to .htaccess files, if Apache's document root
        # concurs with nginx's one
        #
        #location ~ /\.ht {
        #       deny all;
        #}
}


# Virtual Host configuration for example.com
#
# You can move that to a different file under sites-available/ and symlink that
# to sites-enabled/ to enable it.
#
#server {
#       listen 80;
#       listen [::]:80;
#
#       server_name example.com;
#
#       root /var/www/example.com;
#       index index.html;
#
#       location / {
#               try_files $uri $uri/ =404;
#       }
#}

EOF

# test nginx
sudo nginx -t
sudo systemctl restart nginx
echo "=> Nginx success"

# cron
echo "=> automating script usage..."
if [ -z "$REPO_DIR" ]; then
    echo "Error: REPO_DIR is not set." >&2
    exit 1
fi

SCRIPT_PATH="$REPO_DIR/week3/report.sh"
CRON_COMMAND="* * * * * $SCRIPT_PATH >/dev/null 2>&1"

# make temp file
TMP_CRON=$(mktemp)

# copy old cron setup to temp
crontab -l 2>/dev/null > "$TMP_CRON" || true

# check if command is setup alrady
if grep -Fq "$SCRIPT_PATH" "$TMP_CRON"; then
    echo "=> cron already ready"
else
    echo "$CRON_COMMAND" >> "$TMP_CRON"
    
    crontab "$TMP_CRON"
    echo "=> cron success"
fi

echo "=> setup complete!"