# FakeBanking Application - Vulnerabilities Guide

## Overview
This document catalogs all intentional security vulnerabilities built into the FakeBanking application for CNAPP/Wiz security testing and demonstration purposes.

**⚠️ WARNING: This application is intentionally vulnerable. DO NOT use with real data or deploy in production environments.**

---

## Application Access

- **Homepage URL**: http://4.187.181.146/
- **Test Users**:
  - Username: `admin` / Password: `admin123` (Balance: $50,000)
  - Username: `john.doe` / Password: `password123` (Balance: $12,500.75)
  - Username: `jane.smith` / Password: `jane2024` (Balance: $8,750.50)

---

## SAST (Static Application Security Testing) Vulnerabilities

### 1. Hardcoded Credentials & Secrets

**Location**: Multiple files

**Java (HomepageController.java)**:
```java
private static final String INTERNAL_API_KEY = "sk-fake-banking-internal-key-12345";
private static final String DB_PASSWORD = "SuperSecretPassword123";
private static final String AWS_ACCESS_KEY = "AKIAIOSFODNN7EXAMPLE";
private static final String AWS_SECRET_KEY = "wJalrXUtnFEMI/K7MDENG/bPxRfiCYEXAMPLEKEY";
private static final String STRIPE_SECRET = "sk_live_51fake123456789abcdefgh";
private static final String JWT_SECRET = "myJWTSecretKey123456789";
```

**Python (vulnerable-api.py)**:
```python
DB_PASSWORD = "SuperSecretPassword123"
AWS_ACCESS_KEY = "AKIAIOSFODNN7EXAMPLE"
AWS_SECRET_KEY = "wJalrXUtnFEMI/K7MDENG/bPxRfiCYEXAMPLEKEY"
API_KEY = "sk-fake-banking-api-key-12345"
STRIPE_SECRET = "sk_live_51fake123456789abcdefgh"
JWT_SECRET = "myJWTSecretKey123456789"
GITHUB_TOKEN = "ghp_fake1234567890abcdefghijklmnopqrst"
```

**Dockerfiles**: All three microservices
```dockerfile
ENV DB_PASSWORD="SuperSecretPassword123"
ENV INTERNAL_API_KEY="sk-fake-banking-internal-key-12345"
ENV PAYMENT_GATEWAY_SECRET="sk_test_fake_secret_87654321"
```

**Kubernetes Deployment**:
```yaml
env:
  - name: ADMIN_PASSWORD
    value: "admin123"
  - name: ADMIN_TOKEN
    value: "admin-token-12345"
```

**Wiz Detection**: Secret scanning, hardcoded credentials detection

---

### 2. SQL Injection Vulnerabilities

**Location**: `HomepageController.java` - Multiple endpoints

**Login Endpoint** (Lines 65-106):
```java
String query = "SELECT * FROM users WHERE username='" + username + "' AND password='" + password + "'";
stmt.executeQuery(query);
```

**Registration Endpoint** (Lines 109-150):
```java
String insertQuery = "INSERT INTO users (...) VALUES ('"
    + userId + "', '" + username + "', '" + password + "', ...)";
stmt.executeUpdate(insertQuery);
```

**Search Endpoint** (Lines 223-250):
```java
String sqlQuery = "SELECT username, email FROM users WHERE username LIKE '%" + query + "%'";
```

**Python API**:
```python
query = f"SELECT * FROM users WHERE username='{username}' AND password='{password}'"
cursor.execute(query)
```

**Test Payload**: `admin'--` or `' OR '1'='1`

**Wiz Detection**: SQL injection pattern detection, unsafe query concatenation

---

### 3. Command Injection Vulnerabilities

**Location**: `HomepageController.java` (Lines 152-177)

```java
@GetMapping("/api/execute")
public ResponseEntity<Map<String, Object>> executeCommand(@RequestParam String cmd) {
    Process process = Runtime.getRuntime().exec(cmd);
    // Returns command output
}
```

**Python API**:
```python
result = subprocess.run(f"ping -c 4 {host}", shell=True, capture_output=True)
```

**Test URL**: `/api/execute?cmd=whoami` or `/api/execute?cmd=ls -la`

**Wiz Detection**: Command injection, dangerous API usage (Runtime.exec, subprocess with shell=True)

---

### 4. Path Traversal Vulnerabilities

**Location**: `HomepageController.java` (Lines 179-205)

```java
@GetMapping("/api/readfile")
public ResponseEntity<Map<String, Object>> readFile(@RequestParam String filename) {
    File file = new File(filename);  // No input validation
    BufferedReader reader = new BufferedReader(new java.io.FileReader(file));
}
```

**Python API**:
```python
file_path = f"/app/files/{filename}"  # Path traversal possible
with open(file_path, 'r') as f:
    content = f.read()
```

**Test URL**: `/api/readfile?filename=/etc/passwd` or `../../../etc/hosts`

**Wiz Detection**: Path traversal patterns, unsafe file operations

---

### 5. Exposed Secrets API Endpoints

**Location**: `HomepageController.java` (Lines 207-220)

```java
@GetMapping("/api/config")
public ResponseEntity<Map<String, String>> getConfig() {
    config.put("dbPassword", DB_PASSWORD);
    config.put("awsAccessKey", AWS_ACCESS_KEY);
    config.put("awsSecretKey", AWS_SECRET_KEY);
    // ... exposing all secrets
}
```

**Test URL**:
- `/api/config` - View all secrets
- `/debug` - View environment variables and system properties

**Wiz Detection**: Sensitive data exposure, information disclosure

---

### 6. Cross-Site Scripting (XSS)

**Location**: `HomepageController.java` (Lines 223-250)

```java
// No output encoding - XSS vulnerability
results.append("<p>User: " + rs.getString("username") + " - " + rs.getString("email") + "</p>");
```

**Test URL**: `/api/search?query=<script>alert('XSS')</script>`

**Wiz Detection**: XSS vulnerability, unsafe HTML rendering

---

### 7. Weak Cryptography

**Python API**:
```python
def weak_hash_password(password):
    return hashlib.md5(password.encode()).hexdigest()  # MD5 is cryptographically broken
```

**Wiz Detection**: Weak cryptographic algorithms (MD5), insecure random number generation

---

### 8. Insecure Deserialization

**Python API**:
```python
obj = pickle.loads(data)  # Insecure deserialization
```

**Wiz Detection**: Dangerous deserialization methods

---

### 9. Code Injection (eval/exec)

**Python API**:
```python
result = eval(expression)  # Code injection via eval
```

**Wiz Detection**: Dangerous function usage (eval, exec)

---

### 10. XML External Entity (XXE)

**Python API**:
```python
root = ET.fromstring(xml_data)  # XXE vulnerability
```

**Wiz Detection**: XXE vulnerability, unsafe XML parsing

---

## DAST (Dynamic Application Security Testing) Vulnerabilities

### 1. No Authentication Required

**Endpoints**:
- `/api/account/{userId}` - Access any user's account data without authentication
- `/api/admin/delete-user` - Delete users without authentication

**Test**: `curl http://4.187.181.146/api/account/USER10001`

---

### 2. PII Data Exposure

**Location**: Database and API responses

**Exposed Data**:
- Social Security Numbers (SSN)
- Credit Card Numbers
- CVV codes
- Account numbers
- Routing numbers
- Plaintext passwords

**Test**: Login and view dashboard - all PII displayed

---

### 3. Insecure Direct Object Reference (IDOR)

**Test**: Change userId in URL to access other users' data
```
/dashboard.html?userId=USER10001
/dashboard.html?userId=USER10002
```

---

### 4. Missing HTTPS/TLS

**Issue**: All data transmitted over HTTP (not HTTPS)
- Credentials sent in plaintext
- PII transmitted unencrypted

---

### 5. Stack Trace Exposure

**Location**: Error responses expose full stack traces

```java
response.put("stackTrace", e.getStackTrace());
```

---

## Infrastructure/Container Vulnerabilities

### 1. Privileged Containers

**Location**: `microservices-deployment.yaml`

```yaml
securityContext:
  privileged: true
  allowPrivilegeEscalation: true
  runAsUser: 0  # Running as root
  capabilities:
    add:
      - NET_ADMIN
      - SYS_ADMIN
```

**Wiz Detection**: Privileged container detection, running as root

---

### 2. Host Network/PID/IPC Access

```yaml
hostNetwork: true
hostPID: true
hostIPC: true
```

**Wiz Detection**: Host namespace sharing vulnerabilities

---

### 3. World-Writable Directories

**Dockerfile**:
```dockerfile
RUN mkdir -p /app && chmod -R 777 /app
```

**Wiz Detection**: Insecure file permissions

---

### 4. Exposed Database Ports

**MySQL running with**:
- Root password: `RootPassword123!`
- Accessible from all pods in cluster
- No network policies restricting access

---

### 5. Service Account Token Auto-Mount

```yaml
automountServiceAccountToken: true
```

**Wiz Detection**: Service account token exposure risk

---

## Database Vulnerabilities

### 1. Plaintext Password Storage

**Location**: `init-db.sql`, `users` table

```sql
CREATE TABLE users (
    username VARCHAR(100),
    password VARCHAR(255) NOT NULL,  -- Plaintext!
    ...
);
```

---

### 2. Unencrypted PII Storage

**Tables with PII**:
- `users`: SSN, credit cards, CVV, date of birth
- `accounts`: account numbers, routing numbers
- `admin_users`: API keys, passwords

---

### 3. No Access Controls

- No row-level security
- No column-level encryption
- No audit logging

---

## Testing Instructions

### Test Login and Registration

1. **Open**: http://4.187.181.146/
2. **Register**: Click "Register" and create account with fake PII
3. **Login**: Use test credentials above
4. **View Dashboard**: See all exposed PII including SSN, credit card, password

### Test SQL Injection

1. **Login with**: Username: `admin'--` Password: `anything`
2. **Or search**: `/api/search?query=' OR '1'='1`

### Test Command Injection

1. **Execute**: `/api/execute?cmd=whoami`
2. **Or**: `/api/execute?cmd=cat /etc/passwd`

### Test Path Traversal

1. **Read file**: `/api/readfile?filename=/etc/hosts`
2. **Or**: `/api/readfile?filename=../../../etc/passwd`

### Test Exposed Secrets

1. **View secrets**: `/api/config`
2. **View environment**: `/debug`

### Test IDOR

1. **Login as admin** (USER10001)
2. **Change URL**: `/dashboard.html?userId=USER10002`
3. **View other user's data** without authentication

---

## Wiz Scanning Expected Findings

### Critical Issues
- Hardcoded secrets (AWS keys, API keys, passwords)
- SQL injection vulnerabilities
- Command injection vulnerabilities
- Privileged containers running as root
- PII data stored in plaintext
- Missing encryption in transit (no HTTPS)

### High Issues
- Path traversal vulnerabilities
- XSS vulnerabilities
- Weak cryptography (MD5 hashing)
- Host namespace access
- Exposed database with weak credentials
- Insecure deserialization

### Medium Issues
- Information disclosure endpoints
- Missing authentication
- Stack trace exposure
- World-writable file permissions
- Service account token auto-mount

### Low Issues
- Debug mode enabled
- Deprecated base images
- Missing security headers

---

## Remediation Guide (For Learning)

**DO NOT implement these in this test environment - this is intentionally vulnerable!**

1. **Remove hardcoded secrets** → Use Azure Key Vault or Kubernetes Secrets
2. **Fix SQL injection** → Use parameterized queries/prepared statements
3. **Fix command injection** → Validate input, use safer APIs
4. **Add authentication** → Implement OAuth2/JWT with proper validation
5. **Encrypt PII** → Use database encryption, Azure Storage encryption
6. **Use HTTPS** → Add TLS certificates, redirect HTTP to HTTPS
7. **Non-privileged containers** → Run as non-root user, drop capabilities
8. **Hash passwords** → Use bcrypt/argon2 with salt
9. **Input validation** → Validate and sanitize all user input
10. **Security headers** → Add CSP, X-Frame-Options, HSTS headers

---

## Contact & Support

For questions about this vulnerable application or Wiz integration:
- **Purpose**: CNAPP/Wiz security testing and demo
- **Environment**: Azure AKS cluster in Central India region
- **Status**: Intentionally vulnerable - for testing only

**⚠️ REMINDER: DO NOT USE WITH REAL DATA**
