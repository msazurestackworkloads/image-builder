#!/bin/bash -e

docker run \
-v $(pwd):/wd \
-w /wd \
-e AZURE_CLIENT_ID="${AZURE_CLIENT_ID}" \
-e AZURE_CLIENT_SECRET="${AZURE_CLIENT_SECRET}" \
-e AZURE_TENANT_ID="${AZURE_TENANT_ID}" \
-e AZURE_SUBSCRIPTION_ID="${AZURE_SUBSCRIPTION_ID}" \
"quay.io/deis/go-dev:v1.27.0" make build-azure-vhd-ubuntu-1804 |& tee packer/azure/packer1804.out

# Getting OS VHD URL
# ------------------
az login --service-principal -u ${AZURE_CLIENT_ID} -p ${AZURE_CLIENT_SECRET} --tenant ${AZURE_TENANT_ID}
az account set -s ${AZURE_SUBSCRIPTION_ID}

OS_DISK_URI=$(cat packer/azure/packer1804.out | grep "OSDiskUri:" | cut -d " " -f 2)
echo ${OS_DISK_URI} | tee packer/azure/vhd-url-1804.out

RESOURCE_GROUP_NAME="$(cat packer/azure/packer1804.out | grep "resource group name:" | cut -d " " -f 4)"
STORAGE_ACCOUNT_NAME=$(cat packer/azure/packer1804.out | grep "storage name:" | cut -d " " -f 3)
ACCOUNT_KEY=$(az storage account keys list -g ${RESOURCE_GROUP_NAME} --subscription ${AZURE_SUBSCRIPTION_ID} --account-name ${STORAGE_ACCOUNT_NAME} --query '[0].value')
START=$(date +"%Y-%m-%dT00:00Z" -d "-1 day")
EXPIRY=$(date +"%Y-%m-%dT00:00Z" -d "+1 year")

az storage container generate-sas --name system --permissions lr --account-name ${STORAGE_ACCOUNT_NAME} --account-key ${ACCOUNT_KEY} --start ${START} --expiry ${EXPIRY} | tr -d '\"' | tee -a packer/azure/vhd-url-1804.out
