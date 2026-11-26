#!/usr/bin/env bash
# Ajetaan palvelimella GitHub Actionsin toimesta sen jälkeen, kun koodi on
# rsyncattu hakemistoon /opt/chatapp/app.
#   bash /opt/chatapp/app/scripts/deploy.sh <git-sha>
#
# Skripti koskee VAIN tämän sovelluksen omiin tiedostoihin ja palveluun:
#   /opt/chatapp, /etc/nginx/snippets/chatapp.conf, chatapp.service.
# Muiden viikkojen sivustoja, palveluita ja tietokantoja ei muuteta.
set -euo pipefail

REVISION="${1:-unknown}"
APP_DIR=/opt/chatapp/app
VENV=/opt/chatapp/venv
ENV_FILE=/etc/chatapp/chatapp.env
MASTER_ENV=/opt/master/.env
SOCKET=/run/chatapp/gunicorn.sock
SNIPPET=/etc/nginx/snippets/chatapp.conf
DB_CONTAINER=mariadb_prime

read_env_var() {
    local file="$1"
    local key="$2"
    local val
    val="$(sudo grep -E "^[[:space:]]*${key}[[:space:]]*=" "$file" | tail -n1 | sed -E "s/^[[:space:]]*${key}[[:space:]]*=[[:space:]]*//")"
    val="${val%$'\r'}"
    if [[ "$val" =~ ^\"(.*)\"$ ]] || [[ "$val" =~ ^\'(.*)\'$ ]]; then
        val="${BASH_REMATCH[1]}"
    fi
    printf '%s' "$val"
}

db_exec_stdin() {
    local db_name="$1"
    local root_pw="$2"
    if [ -n "$root_pw" ]; then
        sudo docker exec -i -e "MYSQL_PWD=$root_pw" "$DB_CONTAINER" \
            sh -c 'if command -v mariadb >/dev/null 2>&1; then exec mariadb -uroot "$1"; else exec mysql -uroot "$1"; fi' -- "$db_name"
    else
        sudo docker exec -i "$DB_CONTAINER" \
            sh -c 'if command -v mariadb >/dev/null 2>&1; then exec mariadb -uroot "$1"; else exec mysql -uroot "$1"; fi' -- "$db_name"
    fi
}

cd "$APP_DIR"

echo "==> Python-virtuaaliympäristö ja riippuvuudet"
[ -d "$VENV" ] || python3 -m venv "$VENV"
"$VENV/bin/pip" install --quiet --upgrade pip
"$VENV/bin/pip" install --quiet -r requirements.txt

echo "$REVISION" > REVISION

echo "==> Tietokantaskeema ($DB_CONTAINER)"
DB_NAME="$(read_env_var "$ENV_FILE" DB_NAME)"
if [ -z "$DB_NAME" ]; then
    echo "VIRHE: DB_NAME puuttuu tiedostosta $ENV_FILE." >&2
    exit 1
fi

DB_ROOT_PASSWORD="${DB_ROOT_PASSWORD:-}"
if [ -z "$DB_ROOT_PASSWORD" ] && [ -f "$MASTER_ENV" ]; then
    for candidate in MYSQL_ROOT_PASSWORD MARIADB_ROOT_PASSWORD DB_ROOT_PASSWORD ROOT_PASSWORD; do
        candidate_val="$(read_env_var "$MASTER_ENV" "$candidate")"
        if [ -n "$candidate_val" ]; then
            DB_ROOT_PASSWORD="$candidate_val"
            break
        fi
    done
fi

db_exec_stdin "$DB_NAME" "$DB_ROOT_PASSWORD" < deploy/sql/schema.sql

echo "==> Nginx-snippet (/viikko5/)"
# Snippetin pitää olla liitetty johonkin käytössä olevaan sivustoon (kertaluonteinen käsityö).
if ! sudo grep -REq '^\s*include\s+(/etc/nginx/)?snippets/chatapp\.conf\s*;' /etc/nginx/sites-enabled/; then
    cat >&2 <<'MSG'
VIRHE: Nginxin sivustoon ei ole liitetty chat-sovelluksen snippetiä.
Lisää KERRAN olemassa olevan sivuston server { } -lohkoon (esim. /etc/nginx/sites-available/default):

    include snippets/chatapp.conf;

Tarkista: sudo nginx -t && sudo systemctl reload nginx   ja aja deploy uudelleen.
MSG
    exit 1
fi

# Nginx (www-data) tarvitsee pääsyn Gunicornin sokettiin
NGINX_ACTION=reload
if ! id -nG www-data | grep -qw chatapp; then
    sudo usermod -aG chatapp www-data
    NGINX_ACTION=restart   # uusi ryhmäjäsenyys tulee varmasti voimaan uudelleenkäynnistyksessä
fi

# Asennetaan uusi snippet, mutta pidetään vanha tallessa: jos nginx -t epäonnistuu,
# palautetaan vanha, jotta Nginx ja muiden viikkojen sivut jatkavat toimintaansa.
sudo cp -p "$SNIPPET" "$SNIPPET.bak" 2>/dev/null || true
sudo install -m 644 deploy/nginx/chatapp.conf "$SNIPPET"
if ! sudo nginx -t; then
    echo "VIRHE: Nginx-konfiguraatio ei kelpaa, palautetaan edellinen snippet." >&2
    if [ -f "$SNIPPET.bak" ]; then sudo mv "$SNIPPET.bak" "$SNIPPET"; fi
    exit 1
fi
sudo rm -f "$SNIPPET.bak"
sudo systemctl "$NGINX_ACTION" nginx

echo "==> systemd-palvelu"
sudo install -m 644 deploy/systemd/chatapp.service /etc/systemd/system/chatapp.service
sudo systemctl daemon-reload
sudo systemctl enable chatapp >/dev/null
sudo systemctl restart chatapp

echo "==> Terveystarkistus soketin kautta (odotetaan versiota $REVISION)"
# Kysytään suoraan Gunicornilta. Julkisen polun /viikko5/health tarkistaa workflow'n savutesti.
for _ in $(seq 1 20); do
    if sudo curl -fsS --unix-socket "$SOCKET" http://localhost/health 2>/dev/null | grep -qx "$REVISION"; then
        echo "OK: versio $REVISION on käynnissä."
        exit 0
    fi
    sleep 2
done

echo "VIRHE: sovellus ei vastannut oikealla versiolla." >&2
sudo journalctl -u chatapp -n 50 --no-pager >&2
exit 1