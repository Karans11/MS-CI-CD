# Step-by-Step Deployment Guide for Azure + Wiz Integration

This guide will walk you through deploying the Fake Banking microservices demo to Azure and integrating with Wiz for security scanning.

## Prerequisites

Before starting, ensure you have:

- [ ] Azure subscription with Owner/Contributor access
- [ ] Azure CLI installed (`brew install azure-cli`)
- [ ] Terraform installed (`brew install terraform`)
- [ ] kubectl installed (`brew install kubectl`)
- [ ] jq installed (`brew install jq`)
- [ ] Docker Desktop installed and running
- [ ] Git installed
- [ ] Azure DevOps account (free tier is fine)

---

## 📋 STEP 1: Setup Azure Credentials

**What you'll do**: Create a service principal and gather Azure credentials needed for deployment.

**Run this command**:
```bash
cd /Users/karan.sarvaiya/Documents/MS-CI:CD
./setup-azure-credentials.sh
```

**What happens**:
1. Azure CLI will open a browser for login
2. You'll select your subscription
3. A service principal will be created
4. Credentials will be saved to `azure-credentials.txt`

**Expected output**:
- ✅ Subscription ID
- ✅ Tenant ID
- ✅ Client ID (App ID)
- ✅ Client Secret (Password)

**Verification**:
```bash
# Check if credentials file was created
cat azure-credentials.txt
```

**⚠️ Stop here and confirm**:
- Did the script complete successfully?
- Do you have all 4 credential values?
- Are they saved in `azure-credentials.txt`?

**Reply with "Step 1 Complete" to proceed to Step 2.**

---

## 📋 STEP 2: Configure Terraform Variables

**What you'll do**: Update Terraform configuration with your Azure credentials.

**Run this command**:
```bash
./configure-terraform.sh
```

This script will:
1. Read credentials from `azure-credentials.txt`
2. Update `iac/variables.tf` with your values
3. Update `iac/terraform.tfvars` (will be created)

**Verification**:
```bash
# View the Terraform variables
cat iac/terraform.tfvars
```

**⚠️ Stop here and confirm**:
- Did the configuration complete?
- Are your credentials in `iac/terraform.tfvars`?

**Reply with "Step 2 Complete" to proceed to Step 3.**

---

## 📋 STEP 3: Deploy Azure Infrastructure with Terraform

**What you'll do**: Deploy AKS cluster, ACR, Storage, and Key Vault to Azure.

**Run this command**:
```bash
./deploy-infrastructure.sh
```

This will:
1. Initialize Terraform
2. Create Azure resources:
   - Resource Group: `fakebanking-rg`
   - AKS Cluster: `fakebanking-aks`
   - Container Registry: `fakebankingregistry`
   - Storage Account with PII data
   - Key Vault
3. Deploy MySQL database to AKS
4. Display outputs

**Duration**: 10-15 minutes

**Verification**:
```bash
# Check Azure resources
az resource list --resource-group fakebanking-rg -o table

# Check AKS cluster
az aks list -o table

# Check ACR
az acr list -o table
```

**Expected resources**:
- ✅ AKS cluster (1 node)
- ✅ Container Registry
- ✅ Storage Account
- ✅ Key Vault
- ✅ Kubernetes namespace: fakebanking

**⚠️ Stop here and confirm**:
- Did Terraform complete successfully?
- Are all Azure resources created?
- Can you see them in Azure Portal?

**Reply with "Step 3 Complete" to proceed to Step 4.**

---

## 📋 STEP 4: Build and Push Microservices

**What you'll do**: Build Docker images for all microservices and push to ACR.

### Choose Your Build Method

You have **two options** for building and pushing images:

---

#### **Option A: ACR Cloud Build (Recommended - No Docker Required)**

**When to use:**
- ✅ You don't have Docker Desktop installed
- ✅ You want faster builds (runs in Azure cloud)
- ✅ You're on a machine without Docker support
- ✅ You want to avoid local Docker configuration issues

**Prerequisites:**
- Maven installed (already installed in previous step)
- Azure CLI logged in (already done)

**Run this command:**
```bash
./build-and-push-microservices-acr.sh
```

**What it does:**
1. Builds Maven JAR files locally (fast)
2. Uploads source code to Azure
3. Builds Docker images in Azure Container Registry (cloud)
4. Images automatically available in ACR (no push needed)

**Duration:** 8-10 minutes

---

#### **Option B: Local Docker Build (Traditional Method)**

**When to use:**
- ✅ You have Docker Desktop installed and running
- ✅ You want to test images locally before pushing
- ✅ You prefer traditional Docker workflow

**Prerequisites:**
- ✅ **Docker Desktop installed AND running**
- ✅ Maven installed
- ✅ Azure CLI logged in

**Install Docker Desktop (if needed):**
```bash
brew install --cask docker
open -a Docker  # Wait for Docker to fully start
```

**Run this command:**
```bash
./build-and-push-microservices.sh
```

**What it does:**
1. Builds Maven JAR files locally
2. Builds Docker images locally using Docker Desktop
3. Logs into ACR
4. Pushes images to ACR

**Duration:** 8-10 minutes

---

### Verification (Both Options)

After either script completes successfully:

```bash
# List images in ACR
az acr repository list --name fakebankingregistry -o table

# Show image tags
az acr repository show-tags --name fakebankingregistry --repository homepage-service -o table
az acr repository show-tags --name fakebankingregistry --repository payment-service -o table
az acr repository show-tags --name fakebankingregistry --repository user-database-service -o table
```

**Expected output:**
- ✅ homepage-service:latest
- ✅ payment-service:latest
- ✅ user-database-service:latest

**⚠️ Stop here and confirm:**
- Did all builds complete successfully?
- Are all 3 images in ACR?

**Reply with "Step 4 Complete" to proceed to Step 5.**

---

## 📋 STEP 5: Deploy Microservices to AKS

**What you'll do**: Deploy all microservices to the AKS cluster.

**Run this command**:
```bash
./deploy-microservices.sh
```

This will:
1. Get AKS credentials
2. Apply Kubernetes manifests
3. Deploy all 3 microservices + MySQL
4. Wait for pods to be ready
5. Display service endpoints

**Duration**: 3-5 minutes

**Verification**:
```bash
# Check all pods
kubectl get pods -n fakebanking

# Check all services
kubectl get svc -n fakebanking

# Check deployments
kubectl get deployments -n fakebanking
```

**Expected output**:
- ✅ 4 pods running (homepage, payment, user-db, mysql)
- ✅ 4 services created
- ✅ Homepage service has EXTERNAL-IP

**⚠️ Stop here and confirm**:
- Are all pods in "Running" state?
- Does homepage-service have an EXTERNAL-IP?

**Reply with "Step 5 Complete" to proceed to Step 6.**

---

## 📋 STEP 6: Verify Deployment and Test Endpoints

**What you'll do**: Test that all services are working and accessible.

**Run this command**:
```bash
./test-deployment.sh
```

This will:
1. Get service endpoints
2. Test homepage service
3. Test vulnerable endpoints
4. Display all accessible URLs

**Verification**:
```bash
# Get the homepage external IP
HOMEPAGE_IP=$(kubectl get svc homepage-service -n fakebanking -o jsonpath='{.status.loadBalancer.ingress[0].ip}')

# Test main endpoint
curl http://$HOMEPAGE_IP/

# Test vulnerable config endpoint
curl http://$HOMEPAGE_IP/api/config

# Test debug endpoint (exposes env vars)
curl http://$HOMEPAGE_IP/debug
```

**Expected output**:
- ✅ Homepage returns JSON response
- ✅ /api/config exposes hardcoded secrets
- ✅ /debug exposes environment variables

**⚠️ Stop here and confirm**:
- Can you access the homepage service?
- Do the vulnerable endpoints return data?

**Reply with "Step 6 Complete" to proceed to Step 7.**

---

## 📋 STEP 7: Setup Azure DevOps (Optional)

**What you'll do**: Configure Azure DevOps for CI/CD pipelines.

This step is optional but recommended for a complete demo.

**Manual steps**:
1. Go to https://dev.azure.com
2. Create new organization (if needed)
3. Create project: "FakeBanking"
4. Import repository or push code

**Run this command** (after manual setup):
```bash
./setup-azure-devops.sh
```

This will:
1. Create Azure DevOps PAT (you'll need to create this manually)
2. Configure pipelines
3. Set pipeline variables

**⚠️ Stop here and confirm**:
- Have you created Azure DevOps project?
- Is the code pushed to Azure Repos?

**Reply with "Step 7 Complete" to proceed to Step 8.**

---

## 📋 STEP 8: Integrate Wiz

**What you'll do**: Connect Wiz to your Azure subscription and AKS cluster for security scanning.

**Prerequisites**:
- Wiz account (trial or paid)
- Access to Wiz portal

**Manual steps in Wiz portal**:

1. **Connect Azure Subscription**:
   - Go to Wiz → Settings → Cloud Accounts
   - Click "Add Cloud Account" → Azure
   - Use the service principal credentials:
     ```
     Subscription ID: [from azure-credentials.txt]
     Tenant ID: [from azure-credentials.txt]
     Client ID: [from azure-credentials.txt]
     Client Secret: [from azure-credentials.txt]
     ```
   - Click "Connect"

2. **Connect AKS Cluster**:
   - Go to Wiz → Settings → Kubernetes
   - Click "Add Kubernetes Cluster"
   - Follow Wiz instructions to deploy the Wiz sensor:
     ```bash
     # Get AKS credentials first
     az aks get-credentials --resource-group fakebanking-rg --name fakebanking-aks --overwrite-existing

     # Deploy Wiz sensor (command provided by Wiz portal)
     kubectl apply -f wiz-sensor.yaml
     ```

3. **Enable Scanning**:
   - Enable Container Image Scanning
   - Enable IaC Scanning
   - Enable Runtime Scanning
   - Enable CSPM (Cloud Security Posture Management)

**Verification**:
```bash
# Check if Wiz sensor is running
kubectl get pods -n wiz-system

# In Wiz portal, verify:
# - Azure subscription is connected
# - AKS cluster is visible
# - Resources are being scanned
```

**Expected Wiz findings** (this is what you want to see):
- 🔴 Hardcoded secrets in code
- 🔴 SQL injection vulnerabilities
- 🔴 Privileged containers
- 🔴 Host network access
- 🔴 Public storage with PII
- 🔴 Missing network policies
- 🔴 Exposed sensitive endpoints
- 🔴 Weak authentication
- 🔴 Containers running as root

**⚠️ Stop here and confirm**:
- Is Wiz connected to your Azure subscription?
- Is Wiz scanning your AKS cluster?
- Are vulnerabilities showing up in Wiz portal?

**Reply with "Step 8 Complete" - DEPLOYMENT FINISHED! 🎉**

---

## 📋 STEP 9: Cleanup (When Done)

**What you'll do**: Destroy all Azure resources to avoid charges.

**Run this command**:
```bash
./cleanup-all.sh
```

This will:
1. Delete all Kubernetes resources
2. Destroy Terraform infrastructure
3. Delete resource group
4. Optionally delete service principal

**⚠️ WARNING**: This will delete everything!

**Verification**:
```bash
# Check if resource group is gone
az group list --query "[?name=='fakebanking-rg']" -o table
```

---

## Troubleshooting

### Issue: Terraform fails with authentication error
**Solution**:
```bash
# Re-run step 1 to recreate credentials
./setup-azure-credentials.sh
```

### Issue: AKS cluster creation fails
**Solution**:
```bash
# Check quota limits
az vm list-usage --location westindia -o table

# Try different region in iac/variables.tf
```

### Issue: Pods are not starting
**Solution**:
```bash
# Check pod logs
kubectl logs -n fakebanking <pod-name>

# Check events
kubectl get events -n fakebanking --sort-by='.lastTimestamp'
```

### Issue: Cannot access homepage service
**Solution**:
```bash
# Check if LoadBalancer IP is assigned
kubectl get svc homepage-service -n fakebanking

# Wait a few minutes for Azure to provision public IP
```

### Issue: ACR push fails
**Solution**:
```bash
# Login to ACR again
az acr login --name fakebankingregistry

# Check ACR admin is enabled
az acr update --name fakebankingregistry --admin-enabled true
```

---

## Architecture Summary

Once deployed, you'll have:

```
Internet
   │
   ▼
Homepage Service (LoadBalancer)
   │
   ├──► Payment Service (ClusterIP)
   │       └──► MySQL Database
   │
   ├──► User Database Service (ClusterIP)
   │       └──► MySQL Database
   │
   └──► Azure Blob Storage (Public PII data)
```

**Services**:
- Homepage: http://<EXTERNAL-IP>/
- Payment: Internal only (port 8082)
- User DB: Internal only (port 8083)
- MySQL: Internal only (port 3306)

---

## Next Steps After Deployment

1. **Explore Wiz Findings**: Review all vulnerabilities detected
2. **Test Exploits**: Try SQL injection, access exposed endpoints
3. **Demo Scenarios**: Show how CNAPP detects threats at each stage
4. **Remediation**: Use Wiz to prioritize and fix issues

---

## Support

If you encounter issues:
1. Check the troubleshooting section above
2. Review logs: `kubectl logs -n fakebanking <pod-name>`
3. Check Azure portal for resource status
4. Verify credentials in `azure-credentials.txt`

---

**Remember**: This is an intentionally vulnerable application. Only use in isolated demo environments!
