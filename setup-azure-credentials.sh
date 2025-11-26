#!/usr/bin/env bash
# Step 1: Setup Azure Credentials
# This script will help you create a service principal and gather necessary credentials

set -e

echo "=============================================="
echo "Step 1: Azure Credentials Setup"
echo "=============================================="
echo ""

# Check if Azure CLI is installed
if ! command -v az &> /dev/null; then
    echo "❌ Azure CLI is not installed. Please install it first:"
    echo "   brew install azure-cli"
    exit 1
fi

echo "✅ Azure CLI is installed"
echo ""

# Login to Azure
echo "📝 Logging into Azure..."
echo "   A browser window will open for authentication"
az login

echo ""
echo "=============================================="
echo "Available Subscriptions:"
echo "=============================================="
az account list --output table

echo ""
read -p "Enter your Subscription ID (from the list above): " SUBSCRIPTION_ID

# Set the subscription
az account set --subscription "$SUBSCRIPTION_ID"

echo ""
echo "✅ Subscription set to: $SUBSCRIPTION_ID"

# Get Tenant ID
TENANT_ID=$(az account show --query tenantId -o tsv)
echo "✅ Tenant ID: $TENANT_ID"

echo ""
echo "=============================================="
echo "Creating Service Principal"
echo "=============================================="
echo ""

# Create service principal
echo "📝 Creating service principal with Contributor role..."
SP_OUTPUT=$(az ad sp create-for-rbac \
  --name "FakeBanking-CNAPP-Demo-SP" \
  --role Contributor \
  --scopes /subscriptions/$SUBSCRIPTION_ID \
  --output json)

# Extract values
CLIENT_ID=$(echo $SP_OUTPUT | jq -r '.appId')
CLIENT_SECRET=$(echo $SP_OUTPUT | jq -r '.password')

echo ""
echo "✅ Service Principal created successfully!"
echo ""

# Create credentials file
CREDENTIALS_FILE="/Users/karan.sarvaiya/Documents/MS-CI:CD/azure-credentials.txt"

cat > "$CREDENTIALS_FILE" << EOF
============================================
Azure Credentials for Fake Banking Demo
============================================
Created: $(date)

SUBSCRIPTION_ID=$SUBSCRIPTION_ID
TENANT_ID=$TENANT_ID
CLIENT_ID=$CLIENT_ID
CLIENT_SECRET=$CLIENT_SECRET

============================================
IMPORTANT: Keep these credentials secure!
============================================

Next Steps:
1. Save these credentials in a secure location
2. You will need these for:
   - Terraform deployment
   - Azure DevOps pipeline configuration
   - Deployment scripts

⚠️  DO NOT commit this file to git!
============================================
EOF

echo "✅ Credentials saved to: $CREDENTIALS_FILE"
echo ""
echo "=============================================="
echo "Summary"
echo "=============================================="
echo "Subscription ID: $SUBSCRIPTION_ID"
echo "Tenant ID:       $TENANT_ID"
echo "Client ID:       $CLIENT_ID"
echo "Client Secret:   $CLIENT_SECRET"
echo ""
echo "=============================================="
echo "✅ Step 1 Complete!"
echo "=============================================="
echo ""
echo "📋 Your credentials have been saved to:"
echo "   $CREDENTIALS_FILE"
echo ""
echo "🔐 IMPORTANT: Keep these credentials secure!"
echo ""
echo "✅ You can now proceed to Step 2"
echo ""
