#!/usr/bin/env bash
# Step 9: Cleanup All Azure Resources

set -e

echo "=============================================="
echo "⚠️  WARNING: CLEANUP ALL RESOURCES"
echo "=============================================="
echo ""
echo "This will DELETE all resources including:"
echo "   - AKS Cluster"
echo "   - Container Registry"
echo "   - Storage Account (with PII data)"
echo "   - Key Vault"
echo "   - Resource Group"
echo ""

read -p "Are you sure you want to delete everything? (yes/no): " CONFIRM

if [ "$CONFIRM" != "yes" ]; then
    echo "❌ Cleanup cancelled"
    exit 0
fi

echo ""
echo "=============================================="
echo "Cleanup Process Started"
echo "=============================================="
echo ""

CREDENTIALS_FILE="/Users/karan.sarvaiya/Documents/MS-CI:CD/azure-credentials.txt"

if [ -f "$CREDENTIALS_FILE" ]; then
    SUBSCRIPTION_ID=$(grep "^SUBSCRIPTION_ID=" "$CREDENTIALS_FILE" | cut -d'=' -f2)
    TENANT_ID=$(grep "^TENANT_ID=" "$CREDENTIALS_FILE" | cut -d'=' -f2)
    CLIENT_ID=$(grep "^CLIENT_ID=" "$CREDENTIALS_FILE" | cut -d'=' -f2)
    CLIENT_SECRET=$(grep "^CLIENT_SECRET=" "$CREDENTIALS_FILE" | cut -d'=' -f2)

    echo "📝 Logging into Azure..."
    az login --service-principal -u "$CLIENT_ID" -p "$CLIENT_SECRET" --tenant "$TENANT_ID"
    az account set --subscription "$SUBSCRIPTION_ID"
fi

echo "1️⃣  Deleting Kubernetes resources..."
kubectl delete namespace fakebanking --ignore-not-found=true || true

echo ""
echo "2️⃣  Running Terraform destroy..."
cd /Users/karan.sarvaiya/Documents/MS-CI:CD/iac
terraform destroy -auto-approve || true

echo ""
echo "3️⃣  Deleting resource group (if still exists)..."
az group delete --name fakebanking-rg --yes --no-wait || true

echo ""
echo "4️⃣  Cleaning up local files..."
rm -f /Users/karan.sarvaiya/Documents/MS-CI:CD/homepage-ip.txt
rm -f /Users/karan.sarvaiya/Documents/MS-CI:CD/iac/terraform.tfstate
rm -f /Users/karan.sarvaiya/Documents/MS-CI:CD/iac/terraform.tfstate.backup
rm -f /Users/karan.sarvaiya/Documents/MS-CI:CD/iac/tfplan
rm -rf /Users/karan.sarvaiya/Documents/MS-CI:CD/iac/.terraform

echo ""
read -p "Do you want to delete the service principal? (yes/no): " DELETE_SP

if [ "$DELETE_SP" == "yes" ] && [ -n "$CLIENT_ID" ]; then
    echo "5️⃣  Deleting service principal..."
    az ad sp delete --id "$CLIENT_ID" || true
fi

echo ""
echo "=============================================="
echo "✅ Cleanup Complete!"
echo "=============================================="
echo ""
echo "All resources have been deleted."
echo ""
echo "Note: Resource group deletion may take a few minutes to complete."
echo "      You can check status in Azure Portal."
echo ""
