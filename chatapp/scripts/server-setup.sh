#!/usr/bin/env bash
# Kertaluonteinen alustus OLEMASSA OLEVALLE cPouta-palvelimelle (palvelin A).
# Aiempien viikkojen sivut, palvelut ja tietokannat jätetään ennalleen.
#
# Aja palvelimella oletuskäyttäjänä (ubuntu):
#   bash server-setup.sh [ollama-malli]
# Esim: bash server-setup.sh qwen2.5:0.5b
# Skripti on idempotentti: sen voi ajaa uudelleen.
set -euo pipefail

MODEL="${1:-qwen2.5:0.5b}"
DEPLOY_USER="${DEPLOY_USER:-$(whoami)}"
APP_ROOT=/opt/chatapp
ENV_DIR=/etc/chatapp
ENV_FILE=$ENV_DIR/chatapp.env
SNIPPET=/etc/nginx/snippets/chatapp.conf
DB_NAME=chatapp
DB_USER=chatapp

echo "==> Tarkistetaan palvelimen resurssit"
free -h
df -h /
MEM_MB=$(awk '/MemTotal/ {print int($2/1024)}' /proc/meminfo)
if [ "$MEM_MB" -lt 3500 ]; then
    echo "HUOM: muistia on ${MEM_MB} MB. Käytä pientä mallia (esim. qwen2.5:0.5b) ja harkitse swapia."
fi

echo "==> Portit, joita palvelimella on jo käytössä (älä käytä näitä uudelleen)"
sudo ss -ltnp | awk 'NR==1 || /LISTEN/'

echo "==> Asennetaan puuttuvat paketit (olemassa olevia ei muuteta)"
sudo apt-get update -y
sudo DEBIAN_FRONTEND=noninteractive apt-get install -y \
    nginx mariadb-server python3-venv python3-pip rsync curl openssl

echo "==> MariaDB: tarkistetaan, ettei tämä ole read-only-replika"
sudo systemctl enable --now mariadb
if [ "$(sudo mysql -N -e 'SELECT @@global.read_only;')" = "1" ]; then
    echo "VIRHE: MariaDB on read-only-tilassa (replika, esim. palvelin B)." >&2
    echo "Chat-sovellus kirjoittaa tietokantaan, joten asenna se palvelimelle A." >&2
    exit 1
fi

echo "==> Palvelukäyttäjä 'chatapp' ja hakemistot"
if ! id chatapp &>/dev/null; then
    sudo useradd --system --no-create-home --shell /usr/sbin/nologin chatapp
fi
sudo mkdir -p "$APP_ROOT/app" "$ENV_DIR"
# Deploy-käyttäjä (GitHub Actions SSH:lla) omistaa koodin; palvelu lukee sitä.
sudo chown -R "$DEPLOY_USER:$DEPLOY_USER" "$APP_ROOT"
sudo chmod 755 "$APP_ROOT" "$APP_ROOT/app"

echo "==> MariaDB: oma tietokanta ja käyttäjä"
if [ ! -f "$ENV_FILE" ]; then
    DB_PASSWORD="$(openssl rand -hex 24)"
    sudo mysql <<SQL
CREATE DATABASE IF NOT EXISTS \`$DB_NAME\` CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;
CREATE USER IF NOT EXISTS '$DB_USER'@'localhost' IDENTIFIED BY '$DB_PASSWORD';
ALTER USER '$DB_USER'@'localhost' IDENTIFIED BY '$DB_PASSWORD';
GRANT SELECT, INSERT, UPDATE, DELETE, CREATE, ALTER, INDEX ON \`$DB_NAME\`.* TO '$DB_USER'@'localhost';
FLUSH PRIVILEGES;
SQL

    echo "==> Kirjoitetaan $ENV_FILE"
    sudo tee "$ENV_FILE" >/dev/null <<ENV
# Sovelluksen ympäristömuuttujat (luotu server-setup.sh:lla)
DB_HOST=127.0.0.1
DB_PORT=3306
DB_NAME=$DB_NAME
DB_USER=$DB_USER
DB_PASSWORD=$DB_PASSWORD
OLLAMA_URL=http://127.0.0.1:11434
OLLAMA_MODEL=$MODEL
HISTORY_LIMIT=10
ENV
    sudo chown root:chatapp "$ENV_FILE"
    sudo chmod 640 "$ENV_FILE"
else
    echo "    $ENV_FILE on jo olemassa – ei muuteta salasanaa."
    sudo sed -i "s|^OLLAMA_MODEL=.*|OLLAMA_MODEL=$MODEL|" "$ENV_FILE"
fi

echo "==> Ollama (kuuntelee vain osoitetta 127.0.0.1:11434)"
if ! command -v ollama &>/dev/null; then
    curl -fsSL https://ollama.com/install.sh | sh
fi
sudo systemctl enable --now ollama
for _ in $(seq 1 30); do
    curl -fsS http://127.0.0.1:11434/api/tags >/dev/null 2>&1 && break
    sleep 2
done
echo "==> Ladataan malli $MODEL (voi kestää useita minuutteja)"
ollama pull "$MODEL"

echo "==> Nginx-snippet"
sudo mkdir -p /etc/nginx/snippets
if [ ! -f "$SNIPPET" ]; then
    # Tyhjä paikkamerkki, jotta include-rivin voi lisätä heti. deploy.sh korvaa sisällön.
    echo "# chat-sovelluksen snippet – deploy.sh kirjoittaa sisällön" | sudo tee "$SNIPPET" >/dev/null
fi

if sudo grep -REq '^\s*include\s+(/etc/nginx/)?snippets/chatapp\.conf\s*;' /etc/nginx/sites-enabled/; then
    echo "    include-rivi löytyy: $(sudo grep -RlE 'snippets/chatapp\.conf' /etc/nginx/sites-enabled/)"
    INCLUDE_OK=1
else
    INCLUDE_OK=0
fi

cat <<DONE

Valmis! Seuraavaksi:
DONE

if [ "$INCLUDE_OK" = "0" ]; then
    cat <<DONE
  0. Liitä snippet olemassa olevaan sivustoon (tehdään vain kerran). Käytössä olevat sivustot:
$(ls -1 /etc/nginx/sites-enabled/ | sed 's/^/       /')
     Avaa se, jossa aiempien viikkojen sivut ovat (yleensä default), ja lisää server { } -lohkoon:
         include snippets/chatapp.conf;
     Sitten: sudo nginx -t && sudo systemctl reload nginx
DONE
fi

cat <<DONE
  1. Lisää GitHub-repon Secrets: CPOUTA_HOST, CPOUTA_USER ($DEPLOY_USER), CPOUTA_SSH_KEY, CPOUTA_KNOWN_HOSTS
  2. git push -> GitHub Actions ajaa testit ja deployaa koodin hakemistoon $APP_ROOT/app
  3. Avaa selaimessa http://<floating-ip>/viikko5/

DONE