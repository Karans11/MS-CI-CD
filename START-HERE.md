# 🚀 START HERE - Fake Banking + Wiz Demo Setup

## Welcome! 👋

This guide will walk you through deploying a complete microservices architecture to Azure and integrating it with Wiz for security scanning.

---

## 📂 What's in This Repository?

```
MS-CI:CD/
├── 📄 START-HERE.md              ← You are here!
├── 📄 QUICK-START.md             ← Fast deployment reference
├── 📄 DEPLOYMENT-GUIDE.md        ← Detailed step-by-step guide
├── 📄 README.md                  ← Project overview
│
├── 🔧 Setup Scripts:
│   ├── setup-azure-credentials.sh     ← Step 1: Create Azure SP
│   ├── configure-terraform.sh         ← Step 2: Configure Terraform
│   ├── deploy-infrastructure.sh       ← Step 3: Deploy AKS/ACR
│   ├── build-and-push-microservices.sh ← Step 4: Build images
│   ├── deploy-microservices.sh        ← Step 5: Deploy to AKS
│   ├── test-deployment.sh             ← Step 6: Test endpoints
│   └── cleanup-all.sh                 ← Step 9: Cleanup
│
├── 📁 microservices/
│   ├── homepage-service/          ← Public-facing service
│   ├── payment-service/           ← Payment processing
│   ├── user-database-service/     ← User data management
│   └── README.md                  ← Microservices docs
│
├── 📁 iac/                        ← Terraform infrastructure
│   ├── main.tf
│   ├── variables.tf
│   └── outputs.tf
│
├── 📁 pipelines/                  ← CI/CD pipelines
│   ├── microservices-pipeline.yml
│   └── k8s/
│       └── microservices-deployment.yaml
│
└── 📁 app/                        ← Original monolith app
```

---

## ⚡ Quick Start (5 Commands)

**Prerequisites:** Azure account + Azure CLI installed

```bash
cd /Users/karan.sarvaiya/Documents/MS-CI:CD

# Step 1: Create Azure credentials (~2 min)
./setup-azure-credentials.sh

# Step 2: Configure Terraform (~30 sec)
./configure-terraform.sh

# Step 3: Deploy infrastructure (~15 min)
./deploy-infrastructure.sh

# Step 4: Build & push microservices (~10 min)
./build-and-push-microservices.sh

# Step 5: Deploy to AKS (~5 min)
./deploy-microservices.sh

# Step 6: Test everything (~2 min)
./test-deployment.sh

# Done! Now integrate with Wiz
```

**Total Time:** ~35 minutes

---

## 📋 Pre-Deployment Checklist

Before you start, make sure you have:

### Required Tools (Install with Homebrew)
```bash
# Check if installed
az --version          # Azure CLI
terraform --version   # Terraform
kubectl version       # Kubernetes CLI
docker --version      # Docker
mvn --version        # Maven
jq --version         # JSON processor

# Install missing tools
brew install azure-cli terraform kubectl maven jq
```

### Azure Requirements
- [ ] Azure subscription (trial or paid)
- [ ] Owner or Contributor role on subscription
- [ ] Quota for AKS (1 Standard_D2_v2 VM)
- [ ] No conflicting resource names in region

### Local Requirements
- [ ] Docker Desktop installed and running
- [ ] 10 GB free disk space
- [ ] Stable internet connection

---

## 🎯 Choose Your Path

### Path A: Quick Demo (Recommended)
**For:** First-time setup, quick Wiz demo
**Time:** ~35 minutes
**Steps:** Follow the 6 commands above
**Guide:** See [QUICK-START.md](QUICK-START.md)

### Path B: Detailed Walkthrough
**For:** Understanding each component, troubleshooting
**Time:** ~45-60 minutes
**Steps:** Follow detailed instructions
**Guide:** See [DEPLOYMENT-GUIDE.md](DEPLOYMENT-GUIDE.md)

### Path C: Manual Deployment
**For:** Custom configurations, learning
**Time:** ~1-2 hours
**Steps:** Manual Terraform + kubectl
**Guide:** See [microservices/README.md](microservices/README.md)

---

## 🚀 Let's Start! (Path A - Quick Demo)

### STEP 1: Setup Azure Credentials

Open your terminal and run:

```bash
cd /Users/karan.sarvaiya/Documents/MS-CI:CD
./setup-azure-credentials.sh
```

**What happens:**
1. Browser opens for Azure login
2. You select your subscription
3. Service principal is created
4. Credentials saved to `azure-credentials.txt`

**Expected output:**
```
============================================
✅ Step 1 Complete!
============================================

Subscription ID: xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx
Tenant ID:       xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx
Client ID:       xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx
Client Secret:   ********
```

**⚠️ STOP HERE**

Once Step 1 completes successfully, **reply in chat with "Step 1 Complete"** and I'll guide you to Step 2.

---

## 📚 Documentation Map

| File | Purpose | When to Use |
|------|---------|-------------|
| **START-HERE.md** | Main entry point | You are here! |
| **QUICK-START.md** | Fast reference | Quick deployment |
| **DEPLOYMENT-GUIDE.md** | Detailed walkthrough | First time, troubleshooting |
| **README.md** | Project overview | Understanding the demo |
| **microservices/README.md** | Architecture details | Deep dive into services |

---

## 🎓 What You'll Learn

By completing this deployment, you'll:

1. ✅ Deploy a multi-tier microservices app to Azure AKS
2. ✅ Set up Azure Container Registry (ACR)
3. ✅ Configure Terraform for Azure infrastructure
4. ✅ Build and push Docker images
5. ✅ Deploy Kubernetes manifests
6. ✅ Integrate cloud security with Wiz
7. ✅ Identify 20+ security vulnerabilities
8. ✅ Demonstrate CNAPP capabilities

---

## 🔒 What Gets Deployed?

**Infrastructure:**
- Azure Kubernetes Service (AKS) - 1 node cluster
- Azure Container Registry (ACR) - For Docker images
- Azure Storage - With intentionally public PII data
- Azure Key Vault - With weak configuration
- Resource Group - Contains all resources

**Microservices:**
- **Homepage Service** (Public) - Main entry point
- **Payment Service** (Internal) - Payment processing
- **User Database Service** (Internal) - User data
- **MySQL Database** (Internal) - Data persistence

**Intentional Vulnerabilities:**
- 🔴 Hardcoded secrets in code
- 🔴 SQL injection vulnerabilities
- 🔴 Command injection backdoor
- 🔴 Privileged containers (root)
- 🔴 Public PII data access
- 🔴 Exposed API endpoints
- 🔴 No authentication
- 🔴 Host network access
- 🔴 RBAC disabled

---

## 💰 Cost Estimate

**Azure Resources:**
- AKS Control Plane: Free (Free tier)
- VM Node (1x Standard_D2_v2): ~$70/month
- ACR Basic: ~$5/month
- Storage: ~$2/month
- Key Vault: ~$1/month

**Total:** ~$80/month (when running 24/7)

**Cost Savings:**
- Stop AKS cluster when not in use
- Delete resources after demo
- Use for 1 day: ~$3

---

## ⚠️ Important Warnings

🚨 **Security Notice:**
This application is **INTENTIONALLY VULNERABLE** for security training.

- ❌ DO NOT use in production
- ❌ DO NOT use real credentials
- ❌ DO NOT expose to public without controls
- ✅ DO use in isolated lab environments only
- ✅ DO clean up resources after demo
- ✅ DO use for Wiz/CNAPP demonstrations

---

## 🆘 Troubleshooting

**Issue:** Script fails with "command not found"
```bash
# Install missing tools
brew install azure-cli terraform kubectl maven jq
```

**Issue:** Azure login fails
```bash
# Clear cached credentials
az logout
az login
```

**Issue:** Terraform errors
```bash
# Re-run configuration
./configure-terraform.sh
```

**Issue:** Docker errors
```bash
# Make sure Docker Desktop is running
open -a Docker
```

**Need Help?**
- Check [DEPLOYMENT-GUIDE.md](DEPLOYMENT-GUIDE.md) - Troubleshooting section
- Check [QUICK-START.md](QUICK-START.md) - Common issues
- Review logs: `kubectl logs -n fakebanking <pod-name>`

---

## ✅ Success Criteria

You'll know the deployment is successful when:

1. ✅ All 6 scripts run without errors
2. ✅ You can access homepage service via browser
3. ✅ All pods show "Running" status
4. ✅ Vulnerable endpoints return data
5. ✅ Wiz detects 20+ security issues

---

## 🎯 After Deployment

Once everything is deployed:

1. **Test the vulnerable endpoints** (Step 6 script does this)
2. **Connect Wiz to your Azure subscription**
3. **Deploy Wiz sensor to AKS cluster**
4. **Wait 5-10 minutes for Wiz scans**
5. **Review findings in Wiz portal**
6. **Demo the vulnerabilities**
7. **Clean up resources** (./cleanup-all.sh)

---

## 📞 Ready to Start?

**Run this command now:**

```bash
cd /Users/karan.sarvaiya/Documents/MS-CI:CD
./setup-azure-credentials.sh
```

**Then reply in chat with "Step 1 Complete"** and we'll proceed together! 🚀

---

## 📖 Additional Resources

- **Architecture Diagram:** See microservices/README.md
- **Vulnerability List:** See DEPLOYMENT-GUIDE.md
- **Wiz Integration:** See DEPLOYMENT-GUIDE.md Step 8
- **Cleanup Guide:** See DEPLOYMENT-GUIDE.md Step 9

---

**Let's get started! Run the first script and let me know when it completes.** ✨
