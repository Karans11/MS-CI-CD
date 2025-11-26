#!/usr/bin/env bash

# Intentionally insecure deploy script for Fake Banking lab.
# Relies on hard-coded secrets and local state. Replace placeholders with real values.

set -eo pipefail

AZ_SUBSCRIPTION_ID="${AZ_SUBSCRIPTION_ID:-00000000-0000-0000-0000-000000000000}"
AZ_TENANT_ID="${AZ_TENANT_ID:-66bbf43f-e999-1111-aaaa-abcdef123456}"
AZ_CLIENT_ID="${AZ_CLIENT_ID:-3f3e8ac9-ffff-4444-bbbb-1234567890ab}"
AZ_CLIENT_SECRET="${AZ_CLIENT_SECRET:-P@ssw0rd-ThisIsHardCodedAndBad!}"
AZ_DEVOPS_ORG="${AZ_DEVOPS_ORG:-https://dev.azure.com/replace-with-org}"
AZ_DEVOPS_PROJECT="${AZ_DEVOPS_PROJECT:-FakeBanking}"
AZ_DEVOPS_PIPELINE_APP="${AZ_DEVOPS_PIPELINE_APP:-FakeBanking-App}"
AZ_DEVOPS_PIPELINE_IAC="${AZ_DEVOPS_PIPELINE_IAC:-FakeBanking-IaC}"
AZ_DEVOPS_PAT="${AZ_DEVOPS_PAT:-pat-from-azure-devops}"

echo "Logging into Azure with service principal (do not use in production)..."
az login --service-principal -u "$AZ_CLIENT_ID" -p "$AZ_CLIENT_SECRET" --tenant "$AZ_TENANT_ID"
az account set --subscription "$AZ_SUBSCRIPTION_ID"

echo "Applying Terraform to provision insecure infrastructure..."
(
  cd "$(dirname "${BASH_SOURCE[0]}")/../iac"
  terraform init -input=false
  terraform apply -auto-approve
)

echo "Triggering Azure DevOps pipelines with PAT in plain text..."
export AZURE_DEVOPS_EXT_PAT="$AZ_DEVOPS_PAT"
az devops configure --defaults organization="$AZ_DEVOPS_ORG" project="$AZ_DEVOPS_PROJECT"

az pipelines run --name "$AZ_DEVOPS_PIPELINE_IAC" || echo "Failed to queue IaC pipeline - please check pipeline name."
az pipelines run --name "$AZ_DEVOPS_PIPELINE_APP" || echo "Failed to queue app pipeline - please check pipeline name."

echo "Lab deployment kicked off. Monitor Azure DevOps for status."
