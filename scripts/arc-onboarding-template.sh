#!/usr/bin/env bash
set -euo pipefail

# Azure Arc onboarding template for the Ubuntu log-forwarding VM.
# Replace the placeholder values with your own environment values.
# Do NOT commit real tenant/subscription identifiers or authentication secrets.

subscriptionId="<AZURE_SUBSCRIPTION_ID>"
resourceGroup="SocLab"
tenantId="<AZURE_TENANT_ID>"
location="canadacentral"
authType="token"
correlationId="<CORRELATION_ID>"
cloud="AzureCloud"

# Download the current Linux Arc Connected Machine Agent installer.
LINUX_INSTALL_SCRIPT="/tmp/install_linux_azcmagent.sh"
rm -f "$LINUX_INSTALL_SCRIPT"
wget https://gbl.his.arc.azure.com/azcmagent-linux -O "$LINUX_INSTALL_SCRIPT"

# Install the Azure Connected Machine Agent.
bash "$LINUX_INSTALL_SCRIPT"
sleep 5

# Connect the Linux VM to Azure Arc.
sudo azcmagent connect \
  --resource-group "$resourceGroup" \
  --tenant-id "$tenantId" \
  --location "$location" \
  --subscription-id "$subscriptionId" \
  --cloud "$cloud" \
  --tags 'ArcSQLServerExtensionDeployment=Disabled' \
  --enable-automatic-upgrade \
  --correlation-id "$correlationId"

# Validate the Arc connection.
sudo azcmagent show
