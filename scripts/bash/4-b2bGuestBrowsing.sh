#!/bin/sh

if [[ -z "$1" ]] || [[ -z "$2" ]]
then
	echo "You need to specify the name of the store and name of the buyer group."
	echo "Command should look like: ./enable-guest-browsing.sh <YourStoreName> <NameOfBuyerGroup>"
	exit 1
fi

function createJsonFile() {
    fieldValues="{\"records\": [ {$1} ]}" 
    echo $fieldValues
    # Clear the previous data
    echo ""  > Data.json
    rm  Data.json
    # Save the new data
    echo "$fieldValues" > Data.json
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
    rm  Data.json
}

function echo_attention() {
  local green='\033[0;32m'
  local no_color='\033[0m'
  echo -e "${green}$1${no_color}"
}

communityNetworkName=$1
# If the name of the store starts with a digit, the CustomSite name will have a prepended X.
communitySiteName="$(echo $1 | sed -E 's/(^[0-9])/X\1/g')"
# The ExperienceBundle name is similar to the CustomSite name, but has a 1 appended.
buyergroupName=$2

echo_attention "Creating guest user to $buyergroupName"

# Enable Guest Browsing for WebStore and create Guest Buyer Profile. 
createNewQuery "SELECT Id FROM WebStore WHERE Name='$communityNetworkName' LIMIT 1"
webStoreId=`sf data query --file query.txt -r csv |tail -n +2`
# Assign to Buyer Group of choice.
# sfdx force:data:record:update -s WebStore -w "Name='$communityNetworkName'" -v "OptionsGuestBrowsingEnabled='true'" 
sf data update record --sobject WebStore --record-id $webStoreId --values "OptionsGuestBrowsingEnabled='true'"

# guestBuyerProfileId=`sf data query --query \ "SELECT GuestBuyerProfileId FROM WebStore WHERE Name = '$communityNetworkName'" -r csv |tail -n +2`
createNewQuery "SELECT GuestBuyerProfileId FROM WebStore WHERE Name = '$communityNetworkName'"
guestBuyerProfileId=`sf data query --file query.txt -r csv |tail -n +2`


echo_attention "Guest Buyer Profile Id $guestBuyerProfileId"

# buyergroupID=`sf data query --query \ "SELECT Id FROM BuyerGroup WHERE Name = '$buyergroupName'" -r csv |tail -n +2`
createNewQuery "SELECT Id FROM BuyerGroup WHERE Name = '$buyergroupName'"
buyergroupID=`sf data query --file query.txt -r csv |tail -n +2`

echo_attention "Buyer Group ID $buyergroupID"

# sfdx force:data:record:create -s BuyerGroupMember -v "BuyerId='$guestBuyerProfileId' BuyerGroupId='$buyergroupID'"
objectName="BuyerGroupMember"
attributes="\"attributes\": { \"type\": \"$objectName\", \"referenceId\": \"${objectName}Ref1\"},"
fieldValues="\"BuyerId\":\"$guestBuyerProfileId\", \"BuyerGroupId\":\"$buyergroupID\""
createJsonFile "$attributes $fieldValues"
sf data import tree --files Data.json

#############################################################################
# This plugin is not available anymore, since the repository was archived
# echo "Rebuilding the  search index."
# sfdx 1commerce:search:start -n "$communityNetworkName"
#############################################################################

echo "Publishing the community."
# sfdx force:community:publish -n "$communityNetworkName"
sf community publish --name "$communityNetworkName"
sleep 10

removeTempFiles

echo
echo
echo "Done! Guest Buyer Access is setup!"
echo
echo