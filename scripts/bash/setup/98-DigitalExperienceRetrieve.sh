# ./scripts/bash/setup/98-DigitalExperienceRetrieve.sh CI_SANDBOX manifest/setup/package-99DigitalExperience.xml
# ./scripts/bash/setup/98-DigitalExperienceRetrieve.sh tmp20241218 manifest/setup/package-99DigitalExperience.xml


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
	error_and_exit "You need to specify the org name to retrieve the digital experience"
fi

if [ -z "$2" ]
then
	error_and_exit "You need to specify the the package name to retrieve the digital experience"
fi


retrieveOrgName=$1
packageName=$2


# But we need it in an sandbox or productive orgs
echo_attention "Retriving from $retrieveOrgName organization with the $packageName package file."
# These test classes will be added as soon as possible
# But for now, we'll just deploy it

sf project retrieve start -o $retrieveOrgName --manifest $packageName

echo ""
echo ""
echo_attention "Finishing the digital experience retrieve at $(date)"
echo ""
echo ""
