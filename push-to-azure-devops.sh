#!/usr/bin/env bash
# Script to push FakeBanking code to Azure DevOps

set -e

echo "========================================="
echo "Push FakeBanking Code to Azure DevOps"
echo "========================================="
echo ""

# Colors for output
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m' # No Color

# Get Azure DevOps repository URL from user
echo -e "${YELLOW}Please enter your Azure DevOps repository URL:${NC}"
echo "Example: https://[your-org]@dev.azure.com/[your-org]/FakeBanking/_git/FakeBanking"
read -p "Repository URL: " REPO_URL

if [ -z "$REPO_URL" ]; then
    echo -e "${RED}Error: Repository URL cannot be empty${NC}"
    exit 1
fi

echo ""
echo -e "${GREEN}Step 1: Initialize Git Repository${NC}"
git init

echo ""
echo -e "${GREEN}Step 2: Configure Git${NC}"
git config user.email "demo@fakebanking.com"
git config user.name "FakeBanking Demo"

echo ""
echo -e "${GREEN}Step 3: Add all files${NC}"
git add .

echo ""
echo -e "${GREEN}Step 4: Create initial commit${NC}"
git commit -m "Initial commit: FakeBanking intentionally vulnerable application

Features:
- Microservices architecture (homepage, payment, user-database)
- Kubernetes deployments on AKS
- MySQL database with test data
- 40+ intentional security vulnerabilities for Wiz CNAPP testing
- Banking UI with login/registration
- Terraform infrastructure as code

This application is intentionally vulnerable for security testing purposes.
DO NOT use with real data or deploy in production environments."

echo ""
echo -e "${GREEN}Step 5: Add remote repository${NC}"
git remote add origin "$REPO_URL"

echo ""
echo -e "${GREEN}Step 6: Push to Azure DevOps${NC}"
echo -e "${YELLOW}You may be prompted for Azure DevOps credentials...${NC}"
git push -u origin master

echo ""
echo -e "${GREEN}=========================================${NC}"
echo -e "${GREEN}✓ Code successfully pushed to Azure DevOps!${NC}"
echo -e "${GREEN}=========================================${NC}"
echo ""
echo "Next steps:"
echo "1. Go to Azure DevOps: https://dev.azure.com"
echo "2. Navigate to your FakeBanking project > Repos"
echo "3. Verify all files are present"
echo "4. Set up CI/CD pipelines (optional)"
echo ""
