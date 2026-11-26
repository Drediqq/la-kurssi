import os

import mariadb
from flask import Flask, render_template, send_from_directory, abort

app = Flask(__name__)

DB_HOST = os.environ.get('DB_HOST', 'db') 
DB_NAME = os.environ.get('DB_NAME', 'testdb')
DB_USER = os.environ.get('DB_USER', 'root')
DB_PASSWORD = os.environ.get('DB_PASSWORD', '')
DB_PORT = int(os.environ.get('DB_PORT', '3306'))


REPLICA_HOST = os.environ.get('REPLICA_HOST', DB_HOST)
REPLICA_DB = os.environ.get('REPLICA_DB', 'master')
REPLICA_USER = os.environ.get('REPLICA_USER', DB_USER)
REPLICA_PASSWORD = os.environ.get('REPLICA_PASSWORD', DB_PASSWORD)
SITE_MODE = os.environ.get('SITE_MODE', 'master')


def get_db_connection():
    # Connects to db running in docker
    conn = mariadb.connect(
        host=DB_HOST,
        database=DB_NAME,
        user=DB_USER,
        password=DB_PASSWORD,
        port=DB_PORT
    )
    return conn

# connect to replica if server is set to replication
def get_replica_connection():
    if SITE_MODE == 'master':
        return get_db_connection()
    else:
        conn = mariadb.connect(
            host=REPLICA_HOST,
            database=REPLICA_DB,
            user=DB_USER,
            password=DB_PASSWORD,
            port=DB_PORT,
        )
        return conn

def init_db():
    # Makes a table if it doesn't exist
    try:
        conn = get_db_connection()
        cursor = conn.cursor()
        cursor.execute('''
            CREATE TABLE IF NOT EXISTS visits (
                id INT AUTO_INCREMENT PRIMARY KEY,
                count INTEGER NOT NULL
            )
        ''')
        cursor.execute('SELECT COUNT(*) FROM visits')
        if cursor.fetchone()[0] == 0:
            cursor.execute('INSERT INTO visits (count) VALUES (0)')
        conn.commit()
        cursor.close()
        conn.close()
    except Exception as e:
        print(f"Failed to connect maria: {e} :(")


# counter logic
@app.route('/week2/')
def index():
    count = 0
    try:
        conn = get_db_connection()
        cursor = conn.cursor()
        
        # +1 to count 
        cursor.execute('UPDATE visits SET count = count + 1 WHERE id = 1')
        conn.commit()
        
        cursor.execute('SELECT count FROM visits WHERE id = 1')
        count = cursor.fetchone()[0]
        
        cursor.close()
        conn.close()
    except Exception as e:
        print(f"db error: {e}")
        count = -1
    
    # Sends count to html <- definitely not sending vampires
    return render_template('week2.html', count=count)
    
@app.route('/week4/')
def week4_index():
    count = 0
    mode = SITE_MODE
    try:
        conn = get_replica_connection()
        cursor = conn.cursor()
        
        # read from replica
        cursor.execute('SELECT count FROM visits WHERE id = 1')
        count = cursor.fetchone()[0]
        
        cursor.close()
        conn.close()
    except Exception as e:
        print(f"replca db error {e}")
        count = -1
    
    return render_template('week4.html', count=count, mode=mode)


STATS_DIR = os.environ.get('STATS_DIR', '/var/www/html/lakurssi/week4/stats')

@app.route('/week2/templates/stats/<path:filename>')
def week4_stats(filename):
    full_path = os.path.abspath(os.path.join(STATS_DIR, filename))
    stats_root = os.path.abspath(STATS_DIR)

    # Ensure path stays strictly inside STATS_DIR and points to an existing file
    if not full_path.startswith(stats_root + os.sep) or not os.path.isfile(full_path):
        abort(404)

    resp = send_from_directory(
        stats_root,
        os.path.basename(full_path),
        mimetype='text/plain; charset=utf-8'
    )
    resp.headers['Cache-Control'] = 'no-store, no-cache, must-revalidate, max-age=0'
    return resp
with app.app_context():
    init_db()

if __name__ == '__main__':
    app.run(host='0.0.0.0', port=5000)