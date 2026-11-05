from flask import Flask, render_template
import os
import mariadb

app = Flask(__name__)

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
        print(f"Database error: {e}")
        count = -1
    
    # Sends count to html <- definitely not sending vampires
    return render_template('week2.html', count=count)

if __name__ == '__main__':
    init_db()
    app.run(host='127.0.0.1', port=5000)