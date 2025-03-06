#  ./scripts/bash/setup/99-DigitalExperienceDeploy.sh tmpWork manifest/setup/package-99DigitalExperience.xml
# ./scripts/bash/setup/99-DigitalExperienceDeploy.sh tmp20241218 manifest/setup/package-99DigitalExperience.xml
#!/bin/bash
# Use this command retrieve, deploy and publish the store front

function echo_attention() {
  local green='\033[0;32m'
  local no_color='\033[0m'
  echo -e "${green}$1${no_color}"
}

function error_and_exit() {
  local red_color='\033[0;31m'
  local no_color='\033[0m'
  echo -e "${red_color}$1${no_color}"
  exit 1
}


if [ -z "$1" ]
then
	error_and_exit "You need to specify the org name to deploy the digital experience"
fi

if [ -z "$2" ]
then
	error_and_exit "You need to specify the the package name to retrieve the digital experience"
fi

deploymentOrgName=$1
packageName=$2

sf config set target-org $deploymentOrgName

# But we need it in an sandbox or productive orgs
echo_attention "Deploying in to $deploymentOrgName organization with the $packageName package file."

# sf project deploy start --ignore-conflicts --manifest $packageName 
sf project deploy start --ignore-conflicts --manifest $packageName  --target-org $deploymentOrgName

sf community publish --name d2cLightning

echo ""
echo ""
echo_attention "Finishing the digital experience deployment at $(date)"
echo ""
echo ""
