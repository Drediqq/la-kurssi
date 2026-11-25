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
SOCKET=/run/chatapp/gunicorn.sock
SNIPPET=/etc/nginx/snippets/chatapp.conf

cd "$APP_DIR"

echo "==> Python-virtuaaliympäristö ja riippuvuudet"
[ -d "$VENV" ] || python3 -m venv "$VENV"
"$VENV/bin/pip" install --quiet --upgrade pip
"$VENV/bin/pip" install --quiet -r requirements.txt

echo "$REVISION" > REVISION

echo "==> Tietokantaskeema"
DB_NAME="$(sudo grep -E '^DB_NAME=' "$ENV_FILE" | cut -d= -f2)"
sudo mysql "$DB_NAME" < deploy/sql/schema.sql

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