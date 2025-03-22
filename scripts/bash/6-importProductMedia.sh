#!/bin/bash
# This script will:
# - amend files needed to fill out Product data
# - import Products and related data to make store functional
# ./scripts/bash/6-importProductMedia.sh d2cLightning
function executeApexRunFile() {
    apexCommand=$1
    echo "$apexCommand"
    # Clear the previous data
    echo ""  > apexRun.apex
    rm  apexRun.apex
    # Save the new data
    echo $apexCommand > apexRun.apex
    sf apex run --file apexRun.apex
}

function createNewQuery() {
    soqlQuery=$1
    echo "$soqlQuery"
    # Clear the previous data
    echo ""  > query.txt
    rm  query.txt
    # Save the new data
    echo $soqlQuery > query.txt
}

function removeTempFiles(){
    rm  query.txt
    rm  apexRun.apex
}

function exit_error_message() {
  local red_color='\033[0;31m'
  local no_color='\033[0m'
  echo -e "${red_color}$1${no_color}"
  exit 0
}

function echo_attention() {
  local green='\033[0;32m'
  local no_color='\033[0m'
  echo -e "${green}$1${no_color}"
}

if [ -z "$1" ]
then
	exit_error_message "You need to specify the the store name to import it."
fi

storename=$1
echo_attention "Checking if the store $storename already exists"
# storeId=`sf data query -q "SELECT Id FROM WebStore WHERE Name='$1' LIMIT 1" -r csv |tail -n +2`
createNewQuery "SELECT Id FROM WebStore WHERE Name='$1' LIMIT 1"
storeId=`sf data query --file query.txt -r csv |tail -n +2`


if [ -z "$storeId" ]
then
    echo_attention "This store name $storename doesn't exist"
    exit_error_message "The setup will stop."
fi

echo_attention "Store front id: $storeId found to $storename"

echo_attention "Checking if community $storename already exists"
# communityId=`sf data query -q "SELECT Id from Network WHERE Name='$1' LIMIT 1" -r csv |tail -n +2`
createNewQuery "SELECT Id from Network WHERE Name='$1' LIMIT 1"
communityId=`sf data query --file query.txt -r csv |tail -n +2`

if [ -z "$communityId" ]
then
    echo_attention "This community name $storename doesn't exist"
    exit_error_message "The setup will stop."
fi

echo_attention "community id: $communityId found to $storename"

echo_attention "Creating a folder to copy the apex script file"
rm -rf setupB2b
mkdir setupB2b


# 0 Simple code image, 1 Lista and Detail images
intImageCodeDefinition="0";
# 0 Will work with the code, 1 Will work with the generic image
intSwitchOption="0";
# Replace the names of the components that will be retrieved.
# sed -E "s/YOUR_COMMUNITY_NAME_HERE/$storename/g;s/YOUR_COMMUNITY_ID_HERE/$communityId/g;s/YOUR_WEBSTORE_ID_HERE/$storeId/g" scripts/apex/managedContentCreation.apex > setupB2b/managedContentCreation.apex
sed -E "s/INT_IMAGE_CODE_DEFINITION/$intImageCodeDefinition/g;s/INT_SWITCH_OPTION/$intSwitchOption/g;s/YOUR_COMMUNITY_NAME_HERE/$storename/g;" scripts/apex/managedContentCreation.apex > setupB2b/managedContentCreation.apex


# # Delete the product Media before starting
# deletedProductMedia=`sf apex run --file scripts/apex/deleteProducMedia.apex`

# echo_attention 'Deleted ProductMedia return'
# echo $deletedProductMedia

echo_attention "Executing the apex script file"
# returned=`sfdx force:apex:execute -f setupB2b/managedContentCreation.apex`
relatedQuantity=`sf apex run -f setupB2b/managedContentCreation.apex`

echo_attention 'Related products and images'
# echo $relatedQuantity


removeTempFiles

#############################################################################
# This plugin is not available anymore, since the repository was archived
# echo "Rebuilding the  search index."
# sfdx 1commerce:search:start -n "$storename"
#############################################################################

echo_attention "Removing the setupB2b folder"
rm -rf setupB2b

