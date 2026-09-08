#!/usr/bin/env bash
set -euo pipefail

RG="mcherfiRG"
LOCATION="francecentral"
IDENTITY_NAME="github-mi-malikcherfi"
GITHUB_ORG="MalikCherfi"
GITHUB_REPO="ecf-bilan-c6-k8s-apps"
BRANCH="main"

RG_ID=$(az group show --name "mcherfiRG" --query id -o tsv)
PRINCIPAL_ID=$(az identity show --name "github-mi-malikcherfi" --resource-group "mcherfiRG" --query principalId -o tsv)

if [ -z "$PRINCIPAL_ID" ]; then
  az identity create \
    --name "$IDENTITY_NAME" \
    --resource-group "$RG" \
    --location "$LOCATION"
  PRINCIPAL_ID=$(az identity show --name "github-mi-malikcherfi" --resource-group "mcherfiRG" --query principalId -o tsv)

  az role assignment create \
  --assignee "$PRINCIPAL_ID" \
  --role "Contributor" \
  --scope "$RG_ID"
fi

CLIENT_ID=$(az identity show --name "$IDENTITY_NAME" --resource-group "$RG" --query clientId -o tsv)
SUB_ID=$(az account show --query id -o tsv)
TENANT_ID=$(az account show --query tenantId -o tsv)

# Create federated credentials for main
az identity federated-credential create \
  --name "github-${GITHUB_REPO}-${BRANCH}-main" \
  --identity-name "$IDENTITY_NAME" \
  --resource-group "$RG" \
  --issuer "https://token.actions.githubusercontent.com" \
  --subject "repo:MalikCherfi@90403152/${GITHUB_REPO}@1359948531:ref:refs/heads/main" \
  --audiences "api://AzureADTokenExchange"

# Create federated credentials for pull requests
az identity federated-credential create \
  --name "github-${GITHUB_REPO}-${BRANCH}-pull-requests" \
  --identity-name "$IDENTITY_NAME" \
  --resource-group "$RG" \
  --issuer "https://token.actions.githubusercontent.com" \
  --subject "repo:MalikCherfi@90403152/${GITHUB_REPO}@1359948531:pull_request" \
  --audiences "api://AzureADTokenExchange"

echo "AZURE_CLIENT_ID=$CLIENT_ID"
echo "AZURE_TENANT_ID=$TENANT_ID"
echo "AZURE_SUBSCRIPTION_ID=$SUB_ID"
