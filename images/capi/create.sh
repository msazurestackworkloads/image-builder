# Required variables:
# - AZURE_TENANT_ID - tenant ID
# - AZURE_CLIENT_ID - Service principal ID
# - AZURE_CLIENT_SECRET - Service principal secret
# - AZURE_SUBSCRIPTION_ID - Subscription ID used by the pipeline
# - KUBERNETES_VERSION - version of Kubernetes to build the image with, e.g. `1.16.2`
# 1.18.2

#Write configuration files
# KUBERNETES_RELEASE=$(echo ${KUBERNETES_VERSION} | cut -d "." -f -2)
# sed -i "s/.*kubernetes_series.*/  \"kubernetes_series\": \"v${KUBERNETES_RELEASE}\",/g" packer/config/kubernetes.json
# sed -i "s/.*kubernetes_semver.*/  \"kubernetes_semver\": \"v${KUBERNETES_VERSION}\",/g" packer/config/kubernetes.json
# if [[ "${KUBERNETES_VERSION:-}" == "1.16.11" || "${KUBERNETES_VERSION:-}" == "1.17.7" || "${KUBERNETES_VERSION:-}" == "1.18.4" ]]; then
# sed -i "s/.*kubernetes_rpm_version.*/  \"kubernetes_rpm_version\": \"${KUBERNETES_VERSION}-1\",/g" packer/config/kubernetes.json
# sed -i "s/.*kubernetes_deb_version.*/  \"kubernetes_deb_version\": \"${KUBERNETES_VERSION}-01\",/g" packer/config/kubernetes.json
# else
# sed -i "s/.*kubernetes_rpm_version.*/  \"kubernetes_rpm_version\": \"${KUBERNETES_VERSION}-0\",/g" packer/config/kubernetes.json
# sed -i "s/.*kubernetes_deb_version.*/  \"kubernetes_deb_version\": \"${KUBERNETES_VERSION}-00\",/g" packer/config/kubernetes.json
# fi
# cat packer/config/kubernetes.json

#Building VHD
OUTPUT_LOG_FILE=.vscode/packer1804.out
OUTPUT_URL_FILE=.vscode/vhd-url-1804.out
make build-azure-vhd-ubuntu-1804 |& tee ${OUTPUT_LOG_FILE}

#Getting OS VHD URL
#directory: images/capi/packer/azure
#condition: eq(variables.CLEANUP, 'False')
RESOURCE_GROUP_NAME="$(cat ${OUTPUT_LOG_FILE} | grep "resource group name:" | cut -d " " -f 4)"
STORAGE_ACCOUNT_NAME=$(cat ${OUTPUT_LOG_FILE} | grep "storage name:" | cut -d " " -f 3)
OS_DISK_URI=$(cat ${OUTPUT_LOG_FILE} | grep "OSDiskUri:" | cut -d " " -f 2)
echo ${OS_DISK_URI} | tee ${OUTPUT_URL_FILE}
az login --service-principal -u $AZURE_CLIENT_ID -p $AZURE_CLIENT_SECRET --tenant ${AZURE_TENANT_ID}
az account set -s ${AZURE_SUBSCRIPTION_ID}
ACCOUNT_KEY=$(az storage account keys list -g ${RESOURCE_GROUP_NAME} --subscription ${AZURE_SUBSCRIPTION_ID} --account-name ${STORAGE_ACCOUNT_NAME} --query '[0].value')
start_date=$(date +"%Y-%m-%dT00:00Z" -d "-1 day")
expiry_date=$(date +"%Y-%m-%dT00:00Z" -d "+1 year")
az storage container generate-sas --name system --permissions lr --account-name ${STORAGE_ACCOUNT_NAME} --account-key ${ACCOUNT_KEY} --start $start_date --expiry $expiry_date | tr -d '\"' | tee -a ${OUTPUT_URL_FILE}

#cleanup - chown all files in work directory 
chown -R $USER:$USER .