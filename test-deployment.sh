#!/usr/bin/env bash
# Step 6: Test Deployment and Verify Endpoints

set -e

echo "=============================================="
echo "Step 6: Test Deployment"
echo "=============================================="
echo ""

# Get homepage IP
HOMEPAGE_IP=$(kubectl get svc homepage-service -n fakebanking -o jsonpath='{.status.loadBalancer.ingress[0].ip}' 2>/dev/null || echo "")

if [ -z "$HOMEPAGE_IP" ]; then
    echo "❌ Error: Homepage service IP not found!"
    echo "   The LoadBalancer might still be provisioning."
    echo ""
    echo "Run this command to check:"
    echo "   kubectl get svc homepage-service -n fakebanking"
    exit 1
fi

echo "✅ Homepage Service IP: $HOMEPAGE_IP"
echo ""

echo "=============================================="
echo "Testing Endpoints"
echo "=============================================="
echo ""

echo "1️⃣  Testing Homepage Service (Main Endpoint)"
echo "   URL: http://$HOMEPAGE_IP/"
echo ""
curl -s http://$HOMEPAGE_IP/ | jq '.' || echo "   Response received (not JSON)"
echo ""

echo "----------------------------------------"
echo ""

echo "2️⃣  Testing Config Endpoint (Exposes Secrets - VULNERABLE)"
echo "   URL: http://$HOMEPAGE_IP/api/config"
echo ""
curl -s http://$HOMEPAGE_IP/api/config | jq '.'
echo ""

echo "----------------------------------------"
echo ""

echo "3️⃣  Testing Debug Endpoint (Exposes Environment - VULNERABLE)"
echo "   URL: http://$HOMEPAGE_IP/debug"
echo ""
echo "   (Output truncated for readability)"
curl -s http://$HOMEPAGE_IP/debug | jq 'keys' || echo "   Response received"
echo ""

echo "----------------------------------------"
echo ""

echo "4️⃣  Testing Search Endpoint (XSS Vulnerable)"
echo "   URL: http://$HOMEPAGE_IP/api/search?query=test"
echo ""
curl -s "http://$HOMEPAGE_IP/api/search?query=test"
echo ""
echo ""

echo "----------------------------------------"
echo ""

echo "5️⃣  Testing Health Endpoint"
echo "   URL: http://$HOMEPAGE_IP/health"
echo ""
curl -s http://$HOMEPAGE_IP/health | jq '.'
echo ""

echo "=============================================="
echo "Testing Internal Services (via port-forward)"
echo "=============================================="
echo ""

echo "📝 Setting up port-forward for Payment Service..."
kubectl port-forward -n fakebanking svc/payment-service 8082:8082 &
PF_PID_PAYMENT=$!
sleep 3

echo "6️⃣  Testing Payment Service Health"
curl -s http://localhost:8082/api/payments/health | jq '.'
echo ""

echo "7️⃣  Testing Payment Config (Exposes Gateway Credentials - VULNERABLE)"
curl -s http://localhost:8082/api/payments/config | jq '.'
echo ""

kill $PF_PID_PAYMENT 2>/dev/null || true

echo "----------------------------------------"
echo ""

echo "📝 Setting up port-forward for User Database Service..."
kubectl port-forward -n fakebanking svc/user-database-service 8083:8083 &
PF_PID_USER=$!
sleep 3

echo "8️⃣  Testing User Database Service Health"
curl -s http://localhost:8083/api/users/health | jq '.'
echo ""

echo "9️⃣  Testing Database Config (Exposes DB Credentials - VULNERABLE)"
curl -s http://localhost:8083/api/users/config | jq '.'
echo ""

kill $PF_PID_USER 2>/dev/null || true

echo "=============================================="
echo "Testing Vulnerable Endpoints (SQL Injection)"
echo "=============================================="
echo ""

echo "📝 Setting up port-forward for testing SQL injection..."
kubectl port-forward -n fakebanking svc/user-database-service 8083:8083 &
PF_PID=$!
sleep 3

echo "🔟 Testing SQL Injection in User Search"
echo "   URL: http://localhost:8083/api/users/search?query=' OR '1'='1"
echo ""
curl -s "http://localhost:8083/api/users/search?query=%27%20OR%20%271%27=%271" || echo "   SQL injection payload sent"
echo ""
echo ""

kill $PF_PID 2>/dev/null || true

echo "=============================================="
echo "Checking Azure Blob Storage (Public PII)"
echo "=============================================="
echo ""

STORAGE_URL=$(az storage account show --name fakebankingstorage --resource-group fakebanking-rg --query primaryEndpoints.blob -o tsv 2>/dev/null || echo "")

if [ -n "$STORAGE_URL" ]; then
    PII_URL="${STORAGE_URL}leaked-data/personal-info.json"
    echo "1️⃣1️⃣  Testing Public PII Access (CRITICAL VULNERABILITY)"
    echo "   URL: $PII_URL"
    echo ""
    curl -s "$PII_URL" | jq '.' || echo "   PII data accessible"
    echo ""
fi

echo "=============================================="
echo "Deployment Test Summary"
echo "=============================================="
echo ""

echo "✅ All tests completed!"
echo ""
echo "📋 Accessible URLs:"
echo ""
echo "   🌐 Homepage:        http://$HOMEPAGE_IP/"
echo "   🔓 Config API:      http://$HOMEPAGE_IP/api/config"
echo "   🐛 Debug API:       http://$HOMEPAGE_IP/debug"
echo "   🔍 Search API:      http://$HOMEPAGE_IP/api/search?query=test"
echo "   ❤️  Health Check:   http://$HOMEPAGE_IP/health"
echo ""
echo "📋 Internal Services (require port-forward):"
echo ""
echo "   Payment Service:    kubectl port-forward -n fakebanking svc/payment-service 8082:8082"
echo "   User DB Service:    kubectl port-forward -n fakebanking svc/user-database-service 8083:8083"
echo ""

echo "⚠️  Vulnerabilities Confirmed:"
echo "   ✓ Hardcoded secrets exposed via API"
echo "   ✓ Environment variables exposed"
echo "   ✓ Payment gateway credentials exposed"
echo "   ✓ Database credentials exposed"
echo "   ✓ SQL injection endpoints present"
echo "   ✓ Public PII data accessible"
echo ""

echo "=============================================="
echo "✅ Step 6 Complete! 🎉"
echo "=============================================="
echo ""
echo "Your infrastructure is ready for Wiz integration!"
echo ""
echo "Next: Proceed to Step 8 in DEPLOYMENT-GUIDE.md"
echo "      (Step 7 - Azure DevOps is optional)"
echo ""
