#!/bin/bash
# filepath: c:\code_py\demo\byor106\azure-enterprise-scale-byor-106\aifactory-addons\bicep\my-aks.sh

# Exit on error
set -e

# Default parameters (customize as needed)
PROJECT_NUMBER="001"
ENV="dev"  # Options: dev, test, prod
COMMON_RG_NAME_PREFIX="rg-"
LOCATION="westeurope"
LOCATION_SUFFIX="weu"
AIFACTORY_SUFFIX_RG="-001"
COMMON_RESOURCE_SUFFIX="-001"
VNET_NAME_BASE="vnt-esmlcmn"
VNET_RESOURCE_GROUP=""
VNET_NAME_FULL=""
NETWORK_ENV=""
AKS_SUFFIX=""
OVERRIDE_SUBNET_ID=""

# Parse command line arguments
while [[ $# -gt 0 ]]; do
  case $1 in
    --project-number)
      PROJECT_NUMBER="$2"
      shift 2
      ;;
    --env)
      ENV="$2"
      shift 2
      ;;
    --rg-prefix)
      COMMON_RG_NAME_PREFIX="$2"
      shift 2
      ;;
    --location)
      LOCATION="$2"
      shift 2
      ;;
    --location-suffix)
      LOCATION_SUFFIX="$2"
      shift 2
      ;;
    --aifactory-suffix)
      AIFACTORY_SUFFIX_RG="$2"
      shift 2
      ;;
    --common-resource-suffix)
      COMMON_RESOURCE_SUFFIX="$2"
      shift 2
      ;;
    --vnet-rg)
      VNET_RESOURCE_GROUP="$2"
      shift 2
      ;;
    --vnet-name)
      VNET_NAME_FULL="$2"
      shift 2
      ;;
    --network-env)
      NETWORK_ENV="$2"
      shift 2
      ;;
    --aks-suffix)
      AKS_SUFFIX="$2"
      shift 2
      ;;
    --subnet-id)
      OVERRIDE_SUBNET_ID="$2"
      shift 2
      ;;
    --help)
      echo "Usage: $0 [options]"
      echo "Options:"
      echo "  --project-number NUMBER       Project number (default: 001)"
      echo "  --env ENV                     Environment: dev, test, or prod (default: dev)"
      echo "  --rg-prefix PREFIX            Resource group prefix (default: rg-)"
      echo "  --location LOCATION           Azure region (default: westeurope)"
      echo "  --location-suffix SUFFIX      Location suffix (default: weu)"
      echo "  --aifactory-suffix SUFFIX     AI Factory suffix (default: -001)"
      echo "  --common-resource-suffix SUF  Common resource suffix (default: -001)"
      echo "  --vnet-rg RG                  VNet resource group name"
      echo "  --vnet-name NAME              VNet full name"
      echo "  --network-env ENV             Network environment"
      echo "  --aks-suffix SUFFIX           AKS suffix (default: '')"
      echo "  --subnet-id ID                Override subnet ID"
      echo "  --help                        Display this help message"
      exit 0
      ;;
    *)
      echo "Unknown option: $1"
      exit 1
      ;;
  esac
done

# Set tags
TAGS="{\"Project\":\"ESML\",\"Environment\":\"$ENV\"}"

# Show deployment configuration
echo "=== AKS Deployment Configuration ==="
echo "Project Number:        $PROJECT_NUMBER"
echo "Environment:           $ENV"
echo "Resource Group Prefix: $COMMON_RG_NAME_PREFIX"
echo "Location:              $LOCATION"
echo "Location Suffix:       $LOCATION_SUFFIX"
echo "AI Factory Suffix:     $AIFACTORY_SUFFIX_RG"
echo "Common Resource Suffix: $COMMON_RESOURCE_SUFFIX"
echo "=================================="

# Calculate the target resource group name
PROJECT_NAME="project$PROJECT_NUMBER"
TARGET_RG="${COMMON_RG_NAME_PREFIX}esml-${PROJECT_NAME}-${LOCATION_SUFFIX}-${ENV}${AIFACTORY_SUFFIX_RG}-rg"

echo "Target Resource Group: $TARGET_RG"

# Check if the resource group exists
if ! az group show --name "$TARGET_RG" &>/dev/null; then
  echo "Creating resource group: $TARGET_RG"
  az group create --name "$TARGET_RG" --location "$LOCATION" --tags "$TAGS"
else
  echo "Resource group already exists: $TARGET_RG"
fi

# Deploy Bicep template
echo "Deploying AKS using Bicep template..."
az deployment group create \
  --resource-group "$TARGET_RG" \
  --template-file "my-aks.bicep" \
  --parameters \
    projectNumber="$PROJECT_NUMBER" \
    env="$ENV" \
    commonRGNamePrefix="$COMMON_RG_NAME_PREFIX" \
    locationSuffix="$LOCATION_SUFFIX" \
    aifactorySuffixRG="$AIFACTORY_SUFFIX_RG" \
    tags="$TAGS" \
    location="$LOCATION" \
    commonResourceSuffix="$COMMON_RESOURCE_SUFFIX" \
    vnetNameBase="$VNET_NAME_BASE" \
    vnetResourceGroup_param="$VNET_RESOURCE_GROUP" \
    vnetNameFull_param="$VNET_NAME_FULL" \
    network_env="$NETWORK_ENV" \
    aksSuffix="$AKS_SUFFIX" \
    overrideSubnetId="$OVERRIDE_SUBNET_ID"

echo "AKS deployment completed successfully!"
echo "To connect to your AKS cluster:"
echo "az aks get-credentials --resource-group $TARGET_RG --name esml${PROJECT_NUMBER}-${LOCATION_SUFFIX}-${ENV}${AKS_SUFFIX}"