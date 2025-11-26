#!/usr/bin/env bash
# Step 3: Deploy Azure Infrastructure with Terraform

set -e

echo "=============================================="
echo "Step 3: Deploy Azure Infrastructure"
echo "=============================================="
echo ""

CREDENTIALS_FILE="/Users/karan.sarvaiya/Documents/MS-CI:CD/azure-credentials.txt"
TFVARS_FILE="/Users/karan.sarvaiya/Documents/MS-CI:CD/iac/terraform.tfvars"

if [ ! -f "$CREDENTIALS_FILE" ]; then
    echo "❌ Error: azure-credentials.txt not found!"
    echo "   Please run Step 1 first: ./setup-azure-credentials.sh"
    exit 1
fi

if [ ! -f "$TFVARS_FILE" ]; then
    echo "❌ Error: terraform.tfvars not found!"
    echo "   Please run Step 2 first: ./configure-terraform.sh"
    exit 1
fi

# Extract credentials
SUBSCRIPTION_ID=$(grep "^SUBSCRIPTION_ID=" "$CREDENTIALS_FILE" | cut -d'=' -f2)
TENANT_ID=$(grep "^TENANT_ID=" "$CREDENTIALS_FILE" | cut -d'=' -f2)
CLIENT_ID=$(grep "^CLIENT_ID=" "$CREDENTIALS_FILE" | cut -d'=' -f2)
CLIENT_SECRET=$(grep "^CLIENT_SECRET=" "$CREDENTIALS_FILE" | cut -d'=' -f2)

echo "📝 Logging into Azure..."
az login --service-principal -u "$CLIENT_ID" -p "$CLIENT_SECRET" --tenant "$TENANT_ID"
az account set --subscription "$SUBSCRIPTION_ID"

echo "✅ Logged into Azure"
echo ""

cd /Users/karan.sarvaiya/Documents/MS-CI:CD/iac

echo "=============================================="
echo "Terraform: Initializing"
echo "=============================================="
terraform init

echo ""
echo "=============================================="
echo "Terraform: Validating"
echo "=============================================="
terraform validate

echo ""
echo "=============================================="
echo "Terraform: Planning"
echo "=============================================="
terraform plan -out=tfplan

echo ""
echo "⏳ This will create the following resources:"
echo "   - Resource Group: fakebanking-rg"
echo "   - AKS Cluster: fakebanking-aks (1 node)"
echo "   - Container Registry: fakebankingregistry"
echo "   - Storage Account: fakebankingstorage (with public PII)"
echo "   - Key Vault: fakebankingkv"
echo "   - Kubernetes resources (namespace, services)"
echo ""
echo "⏱️  Estimated time: 10-15 minutes"
echo ""

read -p "Do you want to proceed? (yes/no): " CONFIRM

if [ "$CONFIRM" != "yes" ]; then
    echo "❌ Deployment cancelled"
    exit 0
fi

echo ""
echo "=============================================="
echo "Terraform: Applying (this will take 10-15 min)"
echo "=============================================="
terraform apply tfplan

echo ""
echo "=============================================="
echo "Getting AKS Credentials"
echo "=============================================="
az aks get-credentials --resource-group fakebanking-rg --name fakebanking-aks --overwrite-existing

echo ""
echo "=============================================="
echo "Deployment Complete! 🎉"
echo "=============================================="
echo ""

echo "📋 Resources Created:"
terraform output

echo ""
echo "✅ Verifying resources..."
echo ""
az resource list --resource-group fakebanking-rg -o table

echo ""
echo "✅ Checking Kubernetes cluster..."
kubectl get nodes
kubectl get namespaces

echo ""
echo "=============================================="
echo "✅ Step 3 Complete!"
echo "=============================================="
echo ""
echo "Next command:"
echo "   ./build-and-push-microservices.sh"
echo ""
