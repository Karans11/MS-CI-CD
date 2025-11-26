#!/usr/bin/env python3
"""
Intentionally Vulnerable Banking API - Python Version
For CNAPP/Wiz SAST Security Testing

This script contains multiple security vulnerabilities intentionally:
- Hardcoded credentials
- SQL Injection
- Command Injection
- Path Traversal
- Insecure cryptography
- Weak random number generation
- Exposed secrets
"""

import os
import subprocess
import sqlite3
import hashlib
import random
from flask import Flask, request, jsonify

app = Flask(__name__)

# SAST Vulnerability: Hardcoded credentials
DB_PASSWORD = "SuperSecretPassword123"
AWS_ACCESS_KEY = "AKIAIOSFODNN7EXAMPLE"
AWS_SECRET_KEY = "wJalrXUtnFEMI/K7MDENG/bPxRfiCYEXAMPLEKEY"
API_KEY = "sk-fake-banking-api-key-12345"
STRIPE_SECRET = "sk_live_51fake123456789abcdefgh"
JWT_SECRET = "myJWTSecretKey123456789"
ADMIN_PASSWORD = "admin123"

# SAST Vulnerability: Weak cryptography (MD5)
def weak_hash_password(password):
    """Using MD5 for password hashing - intentionally insecure"""
    return hashlib.md5(password.encode()).hexdigest()

# SAST Vulnerability: SQL Injection
@app.route('/api/login', methods=['POST'])
def login():
    username = request.form.get('username')
    password = request.form.get('password')

    # SQL Injection vulnerability - string concatenation
    conn = sqlite3.connect('banking.db')
    cursor = conn.cursor()

    query = f"SELECT * FROM users WHERE username='{username}' AND password='{password}'"
    cursor.execute(query)

    user = cursor.fetchone()
    if user:
        return jsonify({
            'success': True,
            'userId': user[0],
            'username': user[1],
            'ssn': user[3],  # Exposing PII
            'creditCard': user[4]  # Exposing sensitive data
        })
    return jsonify({'success': False})

# SAST Vulnerability: Command Injection
@app.route('/api/ping', methods=['GET'])
def ping_server():
    host = request.args.get('host')

    # Command injection vulnerability - using shell=True with user input
    result = subprocess.run(f"ping -c 4 {host}", shell=True, capture_output=True, text=True)

    return jsonify({
        'host': host,
        'output': result.stdout,
        'error': result.stderr
    })

# SAST Vulnerability: Path Traversal
@app.route('/api/download', methods=['GET'])
def download_file():
    filename = request.args.get('filename')

    # Path traversal vulnerability - no input validation
    file_path = f"/app/files/{filename}"

    try:
        with open(file_path, 'r') as f:
            content = f.read()
        return jsonify({'filename': filename, 'content': content})
    except Exception as e:
        return jsonify({'error': str(e)})

# SAST Vulnerability: Weak random number generation
@app.route('/api/generate-token', methods=['GET'])
def generate_token():
    # Using weak random for security-sensitive operation
    token = ''.join([str(random.randint(0, 9)) for _ in range(16)])

    return jsonify({
        'token': token,
        'note': 'Weak random number generation - not cryptographically secure!'
    })

# SAST Vulnerability: Exposing secrets in API
@app.route('/api/config', methods=['GET'])
def get_config():
    return jsonify({
        'dbPassword': DB_PASSWORD,
        'awsAccessKey': AWS_ACCESS_KEY,
        'awsSecretKey': AWS_SECRET_KEY,
        'apiKey': API_KEY,
        'stripeSecret': STRIPE_SECRET,
        'jwtSecret': JWT_SECRET,
        'adminPassword': ADMIN_PASSWORD
    })

# SAST Vulnerability: Insecure deserialization
@app.route('/api/deserialize', methods=['POST'])
def deserialize_data():
    import pickle

    data = request.data

    # Insecure deserialization vulnerability
    obj = pickle.loads(data)

    return jsonify({'result': str(obj)})

# SAST Vulnerability: Hardcoded encryption key
def encrypt_data(data):
    """Insecure encryption with hardcoded key"""
    ENCRYPTION_KEY = "hardcoded-encryption-key-12345"  # SAST will flag this

    # Using weak encryption (XOR)
    encrypted = ''.join(chr(ord(c) ^ ord(ENCRYPTION_KEY[i % len(ENCRYPTION_KEY)])) for i, c in enumerate(data))
    return encrypted

# SAST Vulnerability: Exposing environment variables
@app.route('/api/env', methods=['GET'])
def get_env():
    return jsonify(dict(os.environ))

# SAST Vulnerability: SSRF (Server-Side Request Forgery)
@app.route('/api/fetch', methods=['GET'])
def fetch_url():
    import urllib.request

    url = request.args.get('url')

    # SSRF vulnerability - no URL validation
    response = urllib.request.urlopen(url)
    content = response.read()

    return jsonify({'url': url, 'content': content.decode('utf-8')})

# SAST Vulnerability: Eval injection
@app.route('/api/calculate', methods=['GET'])
def calculate():
    expression = request.args.get('expr')

    # Code injection vulnerability - using eval with user input
    try:
        result = eval(expression)
        return jsonify({'expression': expression, 'result': result})
    except Exception as e:
        return jsonify({'error': str(e)})

# SAST Vulnerability: XXE (XML External Entity)
@app.route('/api/parse-xml', methods=['POST'])
def parse_xml():
    import xml.etree.ElementTree as ET

    xml_data = request.data

    # XXE vulnerability - parsing XML without disabling external entities
    root = ET.fromstring(xml_data)

    return jsonify({'parsed': ET.tostring(root).decode()})

# SAST Vulnerability: Insecure file permissions
@app.route('/api/save-file', methods=['POST'])
def save_file():
    filename = request.form.get('filename')
    content = request.form.get('content')

    # Insecure file permissions
    with open(f"/tmp/{filename}", 'w') as f:
        f.write(content)

    os.chmod(f"/tmp/{filename}", 0o777)  # World-writable file

    return jsonify({'success': True, 'filename': filename})

# SAST Vulnerability: No authentication
@app.route('/api/admin/delete-user', methods=['DELETE'])
def delete_user():
    user_id = request.args.get('user_id')

    # No authentication required for sensitive operation
    conn = sqlite3.connect('banking.db')
    cursor = conn.cursor()

    cursor.execute(f"DELETE FROM users WHERE id={user_id}")
    conn.commit()

    return jsonify({'success': True, 'deleted': user_id})

# SAST Vulnerability: Information disclosure in error messages
@app.errorhandler(Exception)
def handle_error(error):
    import traceback

    # Exposing full stack trace to users
    return jsonify({
        'error': str(error),
        'type': type(error).__name__,
        'traceback': traceback.format_exc(),
        'locals': str(locals())
    }), 500

# SAST Vulnerability: Insecure cookie settings
@app.route('/api/set-session', methods=['POST'])
def set_session():
    from flask import make_response

    username = request.form.get('username')

    resp = make_response(jsonify({'success': True}))

    # Insecure cookie - no secure, httponly, or samesite flags
    resp.set_cookie('session', username, secure=False, httponly=False, samesite=None)

    return resp

# SAST Vulnerability: Hardcoded database connection
def get_db_connection():
    """Database connection with hardcoded credentials"""
    import pymysql

    # Hardcoded credentials in code
    connection = pymysql.connect(
        host='mysql-db',
        user='root',
        password='RootPassword123!',  # SAST will flag this
        database='users',
        charset='utf8mb4'
    )

    return connection

# SAST Vulnerability: LDAP Injection
@app.route('/api/ldap-search', methods=['GET'])
def ldap_search():
    import ldap

    username = request.args.get('username')

    # LDAP injection vulnerability
    ldap_filter = f"(uid={username})"

    # This would connect to LDAP server without input sanitization
    return jsonify({'filter': ldap_filter})

# SAST Vulnerability: Unvalidated redirect
@app.route('/api/redirect', methods=['GET'])
def redirect_url():
    from flask import redirect

    url = request.args.get('url')

    # Open redirect vulnerability
    return redirect(url)

# Additional hardcoded secrets for SAST detection
GITHUB_TOKEN = "ghp_fake1234567890abcdefghijklmnopqrst"
SLACK_WEBHOOK = "https://hooks.slack.com/services/T00000000/B00000000/XXXXXXXXXXXXXXXXXXXX"
PRIVATE_KEY = """-----BEGIN RSA PRIVATE KEY-----
MIIEpAIBAAKCAQEA1234567890FAKE_KEY_FOR_DEMO_ONLY
-----END RSA PRIVATE KEY-----"""

if __name__ == '__main__':
    # SAST Vulnerability: Debug mode enabled in production
    # SAST Vulnerability: Running on 0.0.0.0 without proper security
    app.run(host='0.0.0.0', port=5000, debug=True)
