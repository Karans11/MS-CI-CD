#!/usr/bin/env bash
# Step 4: Build and Push Microservices to ACR

set -e

echo "=============================================="
echo "Step 4: Build and Push Microservices"
echo "=============================================="
echo ""

CREDENTIALS_FILE="/Users/karan.sarvaiya/Documents/MS-CI:CD/azure-credentials.txt"

if [ ! -f "$CREDENTIALS_FILE" ]; then
    echo "❌ Error: azure-credentials.txt not found!"
    exit 1
fi

SUBSCRIPTION_ID=$(grep "^SUBSCRIPTION_ID=" "$CREDENTIALS_FILE" | cut -d'=' -f2)
TENANT_ID=$(grep "^TENANT_ID=" "$CREDENTIALS_FILE" | cut -d'=' -f2)
CLIENT_ID=$(grep "^CLIENT_ID=" "$CREDENTIALS_FILE" | cut -d'=' -f2)
CLIENT_SECRET=$(grep "^CLIENT_SECRET=" "$CREDENTIALS_FILE" | cut -d'=' -f2)

echo "📝 Logging into Azure..."
az login --service-principal -u "$CLIENT_ID" -p "$CLIENT_SECRET" --tenant "$TENANT_ID"
az account set --subscription "$SUBSCRIPTION_ID"

ACR_NAME="fakebankingregistry"
ACR_LOGIN_SERVER="$ACR_NAME.azurecr.io"

echo "✅ Logged into Azure"
echo ""

echo "📝 Logging into ACR: $ACR_NAME..."
az acr login --name $ACR_NAME

echo "✅ Logged into ACR"
echo ""

cd /Users/karan.sarvaiya/Documents/MS-CI:CD

echo "=============================================="
echo "Building Homepage Service"
echo "=============================================="
cd microservices/homepage-service
echo "📦 Building Maven package..."
mvn clean package -DskipTests

echo "🐳 Building Docker image..."
docker build -t $ACR_LOGIN_SERVER/homepage-service:latest .

echo "⬆️  Pushing to ACR..."
docker push $ACR_LOGIN_SERVER/homepage-service:latest

echo "✅ Homepage service pushed"
echo ""

cd /Users/karan.sarvaiya/Documents/MS-CI:CD

echo "=============================================="
echo "Building Payment Service"
echo "=============================================="
cd microservices/payment-service
echo "📦 Building Maven package..."
mvn clean package -DskipTests

echo "🐳 Building Docker image..."
docker build -t $ACR_LOGIN_SERVER/payment-service:latest .

echo "⬆️  Pushing to ACR..."
docker push $ACR_LOGIN_SERVER/payment-service:latest

echo "✅ Payment service pushed"
echo ""

cd /Users/karan.sarvaiya/Documents/MS-CI:CD

echo "=============================================="
echo "Building User Database Service"
echo "=============================================="
cd microservices/user-database-service
echo "📦 Building Maven package..."
mvn clean package -DskipTests

echo "🐳 Building Docker image..."
docker build -t $ACR_LOGIN_SERVER/user-database-service:latest .

echo "⬆️  Pushing to ACR..."
docker push $ACR_LOGIN_SERVER/user-database-service:latest

echo "✅ User database service pushed"
echo ""

cd /Users/karan.sarvaiya/Documents/MS-CI:CD

echo "=============================================="
echo "Verifying Images in ACR"
echo "=============================================="
echo ""
echo "📋 Images in ACR:"
az acr repository list --name $ACR_NAME -o table

echo ""
echo "📋 Homepage Service Tags:"
az acr repository show-tags --name $ACR_NAME --repository homepage-service -o table

echo ""
echo "📋 Payment Service Tags:"
az acr repository show-tags --name $ACR_NAME --repository payment-service -o table

echo ""
echo "📋 User Database Service Tags:"
az acr repository show-tags --name $ACR_NAME --repository user-database-service -o table

echo ""
echo "=============================================="
echo "✅ Step 4 Complete! 🎉"
echo "=============================================="
echo ""
echo "All microservices built and pushed to ACR successfully!"
echo ""
echo "Next command:"
echo "   ./deploy-microservices.sh"
echo ""
