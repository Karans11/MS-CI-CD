#!/usr/bin/env bash
# Step 2: Configure Terraform with Azure Credentials

set -e

echo "=============================================="
echo "Step 2: Configure Terraform Variables"
echo "=============================================="
echo ""

CREDENTIALS_FILE="/Users/karan.sarvaiya/Documents/MS-CI:CD/azure-credentials.txt"

if [ ! -f "$CREDENTIALS_FILE" ]; then
    echo "❌ Error: azure-credentials.txt not found!"
    echo "   Please run setup-azure-credentials.sh first (Step 1)"
    exit 1
fi

echo "📝 Reading credentials from azure-credentials.txt..."

# Extract credentials using grep and awk
SUBSCRIPTION_ID=$(grep "^SUBSCRIPTION_ID=" "$CREDENTIALS_FILE" | cut -d'=' -f2)
TENANT_ID=$(grep "^TENANT_ID=" "$CREDENTIALS_FILE" | cut -d'=' -f2)
CLIENT_ID=$(grep "^CLIENT_ID=" "$CREDENTIALS_FILE" | cut -d'=' -f2)
CLIENT_SECRET=$(grep "^CLIENT_SECRET=" "$CREDENTIALS_FILE" | cut -d'=' -f2)

# Check if credentials were extracted
if [ -z "$SUBSCRIPTION_ID" ] || [ -z "$TENANT_ID" ] || [ -z "$CLIENT_ID" ] || [ -z "$CLIENT_SECRET" ]; then
    echo "❌ Error: Could not extract credentials from azure-credentials.txt"
    echo "   Please check the file format."
    exit 1
fi

echo "✅ Credentials loaded"
echo ""
echo "   Subscription ID: $SUBSCRIPTION_ID"
echo "   Tenant ID:       $TENANT_ID"
echo "   Client ID:       $CLIENT_ID"
echo "   Client Secret:   [hidden]"
echo ""

# Create terraform.tfvars
TFVARS_FILE="/Users/karan.sarvaiya/Documents/MS-CI:CD/iac/terraform.tfvars"

echo "📝 Creating iac/terraform.tfvars..."

cat > "$TFVARS_FILE" << EOF
# Auto-generated Terraform variables
# Created: $(date)

subscription_id = "$SUBSCRIPTION_ID"
tenant_id       = "$TENANT_ID"
client_id       = "$CLIENT_ID"
client_secret   = "$CLIENT_SECRET"

# Optional: Customize these if needed
prefix      = "fakebanking"
environment = "demo"
location    = "westindia"
EOF

echo "✅ terraform.tfvars created"
echo ""

# Update pipeline files with credentials
echo "📝 Updating pipeline YAML files with your credentials..."

# Update terraform-pipeline.yml
sed -i.bak "s/azureSubscriptionId: '.*'/azureSubscriptionId: '$SUBSCRIPTION_ID'/" /Users/karan.sarvaiya/Documents/MS-CI:CD/pipelines/terraform-pipeline.yml
sed -i.bak "s/azureTenantId: '.*'/azureTenantId: '$TENANT_ID'/" /Users/karan.sarvaiya/Documents/MS-CI:CD/pipelines/terraform-pipeline.yml
sed -i.bak "s/azureAppId: '.*'/azureAppId: '$CLIENT_ID'/" /Users/karan.sarvaiya/Documents/MS-CI:CD/pipelines/terraform-pipeline.yml
sed -i.bak "s/azurePassword: '.*'/azurePassword: '$CLIENT_SECRET'/" /Users/karan.sarvaiya/Documents/MS-CI:CD/pipelines/terraform-pipeline.yml

# Update app-pipeline.yml
sed -i.bak "s/azureSubscriptionId: '.*'/azureSubscriptionId: '$SUBSCRIPTION_ID'/" /Users/karan.sarvaiya/Documents/MS-CI:CD/pipelines/app-pipeline.yml
sed -i.bak "s/azureTenantId: '.*'/azureTenantId: '$TENANT_ID'/" /Users/karan.sarvaiya/Documents/MS-CI:CD/pipelines/app-pipeline.yml
sed -i.bak "s/azureAppId: '.*'/azureAppId: '$CLIENT_ID'/" /Users/karan.sarvaiya/Documents/MS-CI:CD/pipelines/app-pipeline.yml
sed -i.bak "s/azurePassword: '.*'/azurePassword: '$CLIENT_SECRET'/" /Users/karan.sarvaiya/Documents/MS-CI:CD/pipelines/app-pipeline.yml

# Update microservices-pipeline.yml
sed -i.bak "s/azureSubscriptionId: '.*'/azureSubscriptionId: '$SUBSCRIPTION_ID'/" /Users/karan.sarvaiya/Documents/MS-CI:CD/pipelines/microservices-pipeline.yml
sed -i.bak "s/azureTenantId: '.*'/azureTenantId: '$TENANT_ID'/" /Users/karan.sarvaiya/Documents/MS-CI:CD/pipelines/microservices-pipeline.yml
sed -i.bak "s/azureAppId: '.*'/azureAppId: '$CLIENT_ID'/" /Users/karan.sarvaiya/Documents/MS-CI:CD/pipelines/microservices-pipeline.yml
sed -i.bak "s/azurePassword: '.*'/azurePassword: '$CLIENT_SECRET'/" /Users/karan.sarvaiya/Documents/MS-CI:CD/pipelines/microservices-pipeline.yml

# Clean up backup files
rm -f /Users/karan.sarvaiya/Documents/MS-CI:CD/pipelines/*.bak

echo "✅ Pipeline files updated"
echo ""

echo "=============================================="
echo "✅ Step 2 Complete!"
echo "=============================================="
echo ""
echo "📋 Configuration Summary:"
echo "   - iac/terraform.tfvars: Created with your credentials"
echo "   - Pipeline YAML files: Updated with your credentials"
echo ""
echo "✅ You can now proceed to Step 3"
echo ""
echo "Next command:"
echo "   ./deploy-infrastructure.sh"
echo ""
