#!/usr/bin/env bash

# Tear down Fake Banking lab resources. Uses same hard-coded credentials as deploy script.

set -eo pipefail

AZ_SUBSCRIPTION_ID="${AZ_SUBSCRIPTION_ID:-00000000-0000-0000-0000-000000000000}"
AZ_TENANT_ID="${AZ_TENANT_ID:-66bbf43f-e999-1111-aaaa-abcdef123456}"
AZ_CLIENT_ID="${AZ_CLIENT_ID:-3f3e8ac9-ffff-4444-bbbb-1234567890ab}"
AZ_CLIENT_SECRET="${AZ_CLIENT_SECRET:-P@ssw0rd-ThisIsHardCodedAndBad!}"

echo "Logging into Azure to destroy lab..."
az login --service-principal -u "$AZ_CLIENT_ID" -p "$AZ_CLIENT_SECRET" --tenant "$AZ_TENANT_ID"
az account set --subscription "$AZ_SUBSCRIPTION_ID"

echo "Destroying all Terraform managed resources..."
(
  cd "$(dirname "${BASH_SOURCE[0]}")/../iac"
  terraform destroy -auto-approve
)

echo "Optionally delete residual resource group manually if destroy fails."
