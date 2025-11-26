# Quick Start Guide - Fake Banking + Wiz Integration

## TL;DR - Complete Deployment in 6 Steps

```bash
cd /Users/karan.sarvaiya/Documents/MS-CI:CD

# Step 1: Setup Azure credentials
./setup-azure-credentials.sh

# Step 2: Configure Terraform
./configure-terraform.sh

# Step 3: Deploy infrastructure (10-15 min)
./deploy-infrastructure.sh

# Step 4: Build and push microservices (5-10 min)
./build-and-push-microservices.sh

# Step 5: Deploy microservices to AKS (3-5 min)
./deploy-microservices.sh

# Step 6: Test deployment
./test-deployment.sh

# Then: Connect Wiz (manual step in Wiz portal)

# Cleanup when done
./cleanup-all.sh
```

---

## What Gets Deployed

**Azure Resources:**
- Resource Group: `fakebanking-rg`
- AKS Cluster: 1 node, Free tier
- Container Registry: Basic SKU
- Storage Account: Public blob with PII
- Key Vault: No protection

**Microservices:**
- Homepage Service (Port 8081) - Public LoadBalancer
- Payment Service (Port 8082) - Internal ClusterIP
- User Database Service (Port 8083) - Internal ClusterIP
- MySQL Database (Port 3306) - Internal ClusterIP

**Total Cost:** ~$50-100/month (depends on usage)

---

## Prerequisites Checklist

```bash
# Install required tools (macOS)
brew install azure-cli
brew install terraform
brew install kubectl
brew install jq
brew install maven

# Verify installations
az --version
terraform --version
kubectl version --client
jq --version
mvn --version
docker --version
```

---

## Access URLs After Deployment

**Public Endpoints:**
```
http://<EXTERNAL-IP>/                    # Homepage
http://<EXTERNAL-IP>/api/config          # Exposed secrets
http://<EXTERNAL-IP>/debug               # Exposed env vars
http://<EXTERNAL-IP>/api/search?query=x  # XSS vulnerable
```

**Internal Endpoints (port-forward):**
```bash
# Payment Service
kubectl port-forward -n fakebanking svc/payment-service 8082:8082
curl http://localhost:8082/api/payments/config

# User Database Service
kubectl port-forward -n fakebanking svc/user-database-service 8083:8083
curl http://localhost:8083/api/users/all
curl http://localhost:8083/api/users/admin/dump
```

---

## Wiz Integration Steps

1. **Login to Wiz**: https://app.wiz.io

2. **Add Azure Subscription**:
   - Settings → Cloud Accounts → Add Cloud Account
   - Select "Azure"
   - Use credentials from `azure-credentials.txt`
   - Click "Connect"

3. **Add AKS Cluster**:
   - Settings → Kubernetes → Add Cluster
   - Follow Wiz instructions to deploy sensor
   - Run provided kubectl command

4. **Enable Scanning**:
   - Container Image Scanning
   - IaC Scanning
   - Runtime Scanning
   - CSPM

5. **Wait 5-10 minutes** for scans to complete

6. **View Findings**:
   - Go to Issues tab
   - Filter by "fakebanking" or resource group
   - Review vulnerabilities

---

## Expected Wiz Findings

**Critical Issues:**
- Hardcoded secrets in source code
- Privileged containers running as root
- Public storage with PII data
- SQL injection vulnerabilities
- Command injection backdoor
- Host network/PID/IPC access
- No RBAC enabled
- Exposed sensitive API endpoints

**High Issues:**
- Weak authentication
- Missing network policies
- Admin credentials in environment variables
- Insecure image configurations
- TLS not enforced

---

## Troubleshooting

**Problem:** `az: command not found`
```bash
brew install azure-cli
```

**Problem:** Terraform fails with auth error
```bash
# Re-run step 1
./setup-azure-credentials.sh
```

**Problem:** Pods not starting
```bash
kubectl get pods -n fakebanking
kubectl logs -n fakebanking <pod-name>
kubectl describe pod -n fakebanking <pod-name>
```

**Problem:** Can't access homepage service
```bash
# Check if IP is assigned
kubectl get svc homepage-service -n fakebanking

# Wait a few minutes for Azure to provision IP
# Check again after 2-3 minutes
```

**Problem:** Maven build fails
```bash
# Install Maven
brew install maven

# Verify Java is installed
java -version
```

**Problem:** Docker push fails
```bash
# Re-login to ACR
az acr login --name fakebankingregistry

# Check if Docker is running
docker ps
```

---

## Useful Commands

**Check deployment status:**
```bash
kubectl get all -n fakebanking
kubectl get pods -n fakebanking -w
kubectl get svc -n fakebanking
```

**View logs:**
```bash
kubectl logs -n fakebanking deployment/homepage-service
kubectl logs -n fakebanking deployment/payment-service
kubectl logs -n fakebanking deployment/user-database-service
```

**Access internal services:**
```bash
# Payment service
kubectl port-forward -n fakebanking svc/payment-service 8082:8082 &

# User database service
kubectl port-forward -n fakebanking svc/user-database-service 8083:8083 &

# MySQL
kubectl port-forward -n fakebanking svc/mysql-db 3306:3306 &
```

**Check Azure resources:**
```bash
az resource list -g fakebanking-rg -o table
az aks list -o table
az acr list -o table
az storage account list -o table
```

**View ACR images:**
```bash
az acr repository list --name fakebankingregistry -o table
az acr repository show-tags --name fakebankingregistry --repository homepage-service
```

---

## Demo Script for Wiz

1. **Show hardcoded secrets in code**
   - Point to `.env` files
   - Show `application.properties` files
   - Highlight hardcoded API keys in controllers

2. **Show infrastructure issues**
   - Privileged containers in Kubernetes manifests
   - Public blob storage in Terraform
   - No RBAC in AKS configuration

3. **Show runtime vulnerabilities**
   - Access `/api/config` endpoint (exposes secrets)
   - Access `/debug` endpoint (exposes env vars)
   - Demonstrate SQL injection
   - Show public PII data access

4. **Show Wiz findings**
   - Navigate through Wiz Issues
   - Show risk prioritization
   - Demonstrate remediation guidance
   - Show compliance violations

---

## Cleanup

**Full cleanup:**
```bash
./cleanup-all.sh
```

**Manual cleanup:**
```bash
# Delete namespace
kubectl delete namespace fakebanking

# Destroy Terraform
cd iac && terraform destroy

# Delete resource group
az group delete -n fakebanking-rg --yes

# Delete service principal (optional)
az ad sp delete --id <CLIENT_ID>
```

---

## Important Notes

⚠️ **This is intentionally vulnerable code!**
- Only use in isolated lab environments
- Do not use real credentials or data
- Do not expose to public internet without proper controls
- Clean up resources when done to avoid charges

💡 **Cost Management:**
- Free tier AKS: No charge for control plane
- VM costs: ~$50-70/month for 1 node
- Storage: ~$2-5/month
- ACR: ~$5/month (Basic tier)
- Total: ~$60-85/month

🔐 **Security:**
- All vulnerabilities are intentional
- Designed for CNAPP detection demos
- Perfect for Wiz integration testing
- Shows full spectrum of cloud security issues

---

## Support Files

- `DEPLOYMENT-GUIDE.md` - Detailed step-by-step guide
- `microservices/README.md` - Microservices architecture details
- `README.md` - Project overview
- `azure-credentials.txt` - Your Azure credentials (created by scripts)
- `homepage-ip.txt` - Homepage service IP (created after deployment)

---

## Next Steps After Deployment

1. ✅ Verify all services are running
2. ✅ Test vulnerable endpoints
3. ✅ Connect Wiz to Azure subscription
4. ✅ Connect Wiz to AKS cluster
5. ✅ Wait for Wiz scans to complete
6. ✅ Review findings in Wiz portal
7. ✅ Demo the vulnerabilities
8. ✅ Clean up resources when done

---

**Ready to start? Run the first command:**

```bash
cd /Users/karan.sarvaiya/Documents/MS-CI:CD
./setup-azure-credentials.sh
```
