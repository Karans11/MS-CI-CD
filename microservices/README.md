# Fake Banking Microservices Architecture

Intentionally vulnerable microservices architecture for CNAPP security testing and demonstration.

## Architecture Overview

The fake banking application has been split into three microservices:

```
┌─────────────────────────────────────────────────────────────────┐
│                         Internet                                 │
└──────────────────────┬──────────────────────────────────────────┘
                       │
                       │ HTTP:80
                       ▼
              ┌────────────────────┐
              │  Homepage Service  │
              │  (Port 8081)       │
              │  LoadBalancer      │
              └────────┬───────────┘
                       │
       ┌───────────────┼───────────────┐
       │               │               │
       ▼               ▼               ▼
┌──────────────┐ ┌──────────────┐ ┌──────────────┐
│   Payment    │ │     User     │ │    Azure     │
│   Service    │ │   Database   │ │    Blob      │
│ (Port 8082)  │ │   Service    │ │   Storage    │
│  ClusterIP   │ │ (Port 8083)  │ │              │
└──────┬───────┘ └──────┬───────┘ └──────────────┘
       │                │
       └────────┬───────┘
                │
                ▼
         ┌──────────────┐
         │   MySQL DB   │
         │ (Port 3306)  │
         │  ClusterIP   │
         └──────────────┘
```

## Microservices

### 1. Homepage Service
**Port**: 8081
**Type**: LoadBalancer (Public)
**Purpose**: Main entry point, orchestrates calls to other services

**Endpoints**:
- `GET /` - Homepage
- `GET /health` - Health check
- `GET /api/config` - Exposes internal configuration (INSECURE)
- `GET /api/search` - Search with XSS vulnerability
- `GET /debug` - Exposes environment variables (INSECURE)

**Vulnerabilities**:
- Hardcoded API keys in code
- Environment variables exposed via `/debug` endpoint
- XSS vulnerability in search
- No authentication on sensitive endpoints
- Privileged container (root user)
- Host network mode enabled

### 2. Payment Service
**Port**: 8082
**Type**: ClusterIP (Internal)
**Purpose**: Handles payment processing and transactions

**Endpoints**:
- `GET /api/payments/health` - Health check
- `POST /api/payments/process` - Process payment (no auth)
- `GET /api/payments/history?userId=X` - SQL injection vulnerable
- `POST /api/payments/admin/refund` - Admin refund (no auth)
- `GET /api/payments/config` - Exposes payment gateway credentials
- `POST /api/payments/update` - Mass assignment vulnerability

**Vulnerabilities**:
- SQL injection in payment history
- Hardcoded payment gateway credentials
- No authentication on admin endpoints
- Database credentials in plaintext
- Logs sensitive card data
- Privileged container
- Host network and PID namespace

### 3. User Database Service
**Port**: 8083
**Type**: ClusterIP (Internal)
**Purpose**: User data management and PII storage

**Endpoints**:
- `GET /api/users/health` - Health check
- `GET /api/users/{userId}` - Get user by ID (SQL injection)
- `GET /api/users/all` - Get all users with PII (no auth)
- `POST /api/users/create` - Create user (no validation)
- `PUT /api/users/update` - Update user (mass assignment)
- `DELETE /api/users/delete/{userId}` - Delete user (no auth)
- `GET /api/users/admin/dump` - Full database dump (CRITICAL)
- `GET /api/users/search?query=X` - Search with SQL injection
- `GET /api/users/config` - Exposes database credentials
- `POST /api/users/admin/backdoor` - Command injection backdoor

**Vulnerabilities**:
- Multiple SQL injection vulnerabilities
- Command injection in backdoor endpoint
- Exposes passwords in plaintext
- Full PII dump without authentication
- Database credentials exposed
- No input validation
- Privileged container
- Host network, PID, and IPC namespace access

### 4. MySQL Database
**Port**: 3306
**Type**: ClusterIP (Internal)
**Purpose**: Data persistence layer

**Configuration**:
- Root password: `RootPassword123!` (hardcoded)
- Default database: `users`
- Running as root

## Security Vulnerabilities Summary

### Application Level
1. **SQL Injection** - Multiple endpoints across services
2. **Command Injection** - Backdoor endpoint in user service
3. **XSS** - Search functionality in homepage service
4. **Mass Assignment** - Update endpoints without validation
5. **Hardcoded Secrets** - API keys, passwords, tokens in code
6. **No Authentication** - Admin and sensitive endpoints exposed
7. **PII Exposure** - User data accessible without auth
8. **Weak Encryption** - DES algorithm, weak keys
9. **Information Disclosure** - Error messages, stack traces, debug endpoints

### Infrastructure Level
1. **Privileged Containers** - All services run as root
2. **Host Network Access** - Containers use host network
3. **Host PID/IPC Namespace** - Shared with host
4. **No Network Policies** - All pods can communicate
5. **Secrets in Environment Variables** - Visible in pod specs
6. **No Resource Limits** - Potential for resource exhaustion
7. **Public Load Balancer** - Homepage exposed to internet without TLS
8. **No RBAC** - Kubernetes RBAC disabled

### CI/CD Level
1. **Hardcoded Credentials** - Azure credentials in pipeline YAML
2. **Skip Tests** - No validation before deployment
3. **Admin ACR Access** - Using admin credentials instead of managed identity
4. **No Image Scanning** - Vulnerable images pushed without checks
5. **Auto-approve Deployments** - No manual approval gates

## Deployment

### Prerequisites
- Azure subscription
- Azure DevOps organization
- Azure CLI with DevOps extension
- Terraform 1.1.0+
- kubectl

### Option 1: Deploy via Terraform

```bash
cd iac
terraform init
terraform apply -auto-approve
```

This will create:
- AKS cluster with all microservices
- ACR for container images
- Storage account with PII data
- Key Vault
- All Kubernetes resources

### Option 2: Deploy via Azure DevOps Pipeline

1. Create pipeline pointing to `pipelines/microservices-pipeline.yml`
2. Update variables in the pipeline YAML
3. Run the pipeline

### Option 3: Manual Deployment

```bash
# Build and push images
cd microservices/homepage-service
mvn package -DskipTests
docker build -t fakebankingregistry.azurecr.io/homepage-service:latest .
docker push fakebankingregistry.azurecr.io/homepage-service:latest

cd ../payment-service
mvn package -DskipTests
docker build -t fakebankingregistry.azurecr.io/payment-service:latest .
docker push fakebankingregistry.azurecr.io/payment-service:latest

cd ../user-database-service
mvn package -DskipTests
docker build -t fakebankingregistry.azurecr.io/user-database-service:latest .
docker push fakebankingregistry.azurecr.io/user-database-service:latest

# Deploy to Kubernetes
kubectl apply -f pipelines/k8s/microservices-deployment.yaml
```

## Accessing Services

After deployment, get service endpoints:

```bash
kubectl get svc -n fakebanking
```

**Homepage Service** (Public):
```
http://<HOMEPAGE_EXTERNAL_IP>/
http://<HOMEPAGE_EXTERNAL_IP>/api/config
http://<HOMEPAGE_EXTERNAL_IP>/debug
```

**Payment Service** (Internal - port-forward required):
```bash
kubectl port-forward -n fakebanking svc/payment-service 8082:8082
curl http://localhost:8082/api/payments/health
curl http://localhost:8082/api/payments/config
```

**User Database Service** (Internal - port-forward required):
```bash
kubectl port-forward -n fakebanking svc/user-database-service 8083:8083
curl http://localhost:8083/api/users/health
curl http://localhost:8083/api/users/all
curl http://localhost:8083/api/users/admin/dump
```

## Testing Vulnerabilities

### SQL Injection Examples

```bash
# Payment history SQL injection
curl "http://localhost:8082/api/payments/history?userId=' OR '1'='1"

# User search SQL injection
curl "http://localhost:8083/api/users/search?query=' OR 1=1--"

# User by ID SQL injection
curl "http://localhost:8083/api/users/' OR '1'='1"
```

### Command Injection Example

```bash
# Backdoor command execution
curl -X POST http://localhost:8083/api/users/admin/backdoor \
  -H "Content-Type: application/json" \
  -d '{"cmd": "ls -la"}'
```

### Exposed Secrets Examples

```bash
# Homepage config exposure
curl http://<HOMEPAGE_IP>/api/config

# Payment gateway credentials
curl http://localhost:8082/api/payments/config

# Database credentials
curl http://localhost:8083/api/users/config

# Environment variables
curl http://<HOMEPAGE_IP>/debug
```

### PII Data Exposure

```bash
# Get all users with PII
curl http://localhost:8083/api/users/all

# Complete database dump
curl http://localhost:8083/api/users/admin/dump
```

## Traffic Flow

1. **User** → Homepage Service (Port 80 via LoadBalancer)
2. **Homepage Service** → Payment Service (Port 8082 internal)
3. **Homepage Service** → User Database Service (Port 8083 internal)
4. **Payment Service** → MySQL Database (Port 3306)
5. **User Database Service** → MySQL Database (Port 3306)
6. **Homepage Service** → Azure Blob Storage (for PII data)

## Cleanup

```bash
# Delete Kubernetes resources
kubectl delete namespace fakebanking

# Or destroy all infrastructure
cd iac
terraform destroy -auto-approve

# Or delete entire resource group
az group delete --name fakebanking-rg --yes
```

## Warning

⚠️ **This is intentionally vulnerable code for security testing and education only.**

- DO NOT deploy in production
- DO NOT use on public networks without isolation
- DO NOT use real credentials or data
- Only deploy in controlled lab environments
- All vulnerabilities are intentional for CNAPP detection demos

## CNAPP Detection Targets

These microservices demonstrate vulnerabilities detectable by CNAPP solutions:

**IDE/SAST**:
- Hardcoded secrets in source code
- SQL injection patterns
- Command injection patterns
- Weak encryption algorithms

**IaC Scanning**:
- Privileged containers
- Host namespace sharing
- Missing network policies
- Hardcoded secrets in Terraform

**CI/CD**:
- Credentials in pipeline YAML
- Skipped security gates
- No image scanning
- Admin credential usage

**Runtime**:
- Privileged pod execution
- Host network access
- Exposed sensitive endpoints
- Public PII data access
- Container breakout potential
