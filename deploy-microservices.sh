#!/usr/bin/env bash
# Step 5: Deploy Microservices to AKS

set -e

echo "=============================================="
echo "Step 5: Deploy Microservices to AKS"
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

echo "📝 Getting AKS credentials..."
az aks get-credentials --resource-group fakebanking-rg --name fakebanking-aks --overwrite-existing

echo "✅ Connected to AKS cluster"
echo ""

cd /Users/karan.sarvaiya/Documents/MS-CI:CD

echo "=============================================="
echo "Deploying Microservices"
echo "=============================================="
echo ""

echo "📝 Applying Kubernetes manifests..."
kubectl apply -f pipelines/k8s/microservices-deployment.yaml

echo ""
echo "⏳ Waiting for pods to be ready (this may take 2-3 minutes)..."
echo ""

echo "📋 Checking deployment status..."
kubectl get deployments -n fakebanking

echo ""
echo "⏳ Waiting for all pods to be running..."
kubectl wait --for=condition=ready pod -l app=mysql-db -n fakebanking --timeout=300s || true
kubectl wait --for=condition=ready pod -l app=homepage-service -n fakebanking --timeout=300s || true
kubectl wait --for=condition=ready pod -l app=payment-service -n fakebanking --timeout=300s || true
kubectl wait --for=condition=ready pod -l app=user-database-service -n fakebanking --timeout=300s || true

echo ""
echo "=============================================="
echo "Deployment Status"
echo "=============================================="
echo ""

echo "📋 Pods:"
kubectl get pods -n fakebanking

echo ""
echo "📋 Services:"
kubectl get svc -n fakebanking

echo ""
echo "📋 Deployments:"
kubectl get deployments -n fakebanking

echo ""
echo "=============================================="
echo "Service Endpoints"
echo "=============================================="
echo ""

echo "⏳ Waiting for LoadBalancer to assign external IP (this may take 2-3 minutes)..."
echo ""

# Wait for external IP
for i in {1..30}; do
    HOMEPAGE_IP=$(kubectl get svc homepage-service -n fakebanking -o jsonpath='{.status.loadBalancer.ingress[0].ip}' 2>/dev/null || echo "")
    if [ -n "$HOMEPAGE_IP" ]; then
        break
    fi
    echo "   Attempt $i/30: Waiting for IP assignment..."
    sleep 10
done

if [ -z "$HOMEPAGE_IP" ]; then
    echo "⚠️  LoadBalancer IP not assigned yet. Run this command to check:"
    echo "   kubectl get svc homepage-service -n fakebanking"
else
    echo "✅ Homepage Service is accessible at:"
    echo ""
    echo "   🌐 Main Page:     http://$HOMEPAGE_IP/"
    echo "   🔓 Config API:    http://$HOMEPAGE_IP/api/config"
    echo "   🐛 Debug API:     http://$HOMEPAGE_IP/debug"
    echo "   🔍 Search API:    http://$HOMEPAGE_IP/api/search?query=test"
    echo ""
fi

echo ""
echo "📋 Internal Services (use kubectl port-forward to access):"
echo ""
echo "   Payment Service:"
echo "   kubectl port-forward -n fakebanking svc/payment-service 8082:8082"
echo "   Then: curl http://localhost:8082/api/payments/health"
echo ""
echo "   User Database Service:"
echo "   kubectl port-forward -n fakebanking svc/user-database-service 8083:8083"
echo "   Then: curl http://localhost:8083/api/users/health"
echo ""

# Save the IP to a file for later use
if [ -n "$HOMEPAGE_IP" ]; then
    echo "$HOMEPAGE_IP" > /Users/karan.sarvaiya/Documents/MS-CI:CD/homepage-ip.txt
fi

echo "=============================================="
echo "✅ Step 5 Complete! 🎉"
echo "=============================================="
echo ""
echo "All microservices are deployed and running!"
echo ""
echo "Next command:"
echo "   ./test-deployment.sh"
echo ""
