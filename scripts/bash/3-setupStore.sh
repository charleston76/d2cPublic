#!/bin/bash
# Use this command followed by a store name.
#
# Before running this script make sure that you completed all the previous steps in the setup
# (run convert-examples-to-sfdx.sh, execute sfdx force:source:push -f, create store)
#
# This script will:
# - register the Apex classes needed for checkout integrations and map them to your store
# - associate the clone of the checkout flow to the checkout component in your store
# - add the Customer Community Plus Profile clone to the list of members for the store
# - import Products and necessary related store data in order to get you started
# - create a Buyer User and attach a Buyer Profile to it
# - create a Buyer Account and add it to the relevant Buyer Group
# - add Contact Point Addresses for Shipping and Billing to your new buyer Account
# - activate the store
# - publish your store so that the changes are reflected

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
	exit_error_message "You need to specify the scratch org name to create it."
fi

if [ -z "$2" ]
then
	exit_error_message "You need to specify the the store name to create it."
fi

echo_attention "Starting the d2cStore set up and  buyer user creation at $(date)"
echo ""
echo ""

rm -rf experience-bundle-package
mkdir experience-bundle-package
#############################
#    Retrieve Store Info    #
#############################

scratchOrgName=$1
storename=$2


communityNetworkName=$storename
# If the name of the store starts with a digit, the CustomSite name will have a prepended X.
communitySiteName="$(echo $storename | sed -E 's/(^[0-9])/X\1/g')"
# The ExperienceBundle name is similar to the CustomSite name, but has a 1 appended.
communityExperienceBundleName="$communitySiteName"1

# Replace the names of the components that will be retrieved.
##sed -E "s/YourCommunitySiteNameHere/$communitySiteName/g;s/YourCommunityExperienceBundleNameHere/$communityExperienceBundleName/g;s/YourCommunityNetworkNameHere/$communityNetworkName/g" quickstart-config/package-retrieve-template.xml > package-retrieve.xml
sed -E "s/YourCommunitySiteNameHere/$communitySiteName/g;s/YourCommunityExperienceBundleNameHere/$communityExperienceBundleName/g;s/YourCommunityNetworkNameHere/$communityNetworkName/g" manifest/scratch/package-retrieve-template.xml > package-retrieve.xml

echo "Using this to retrieve your store info:"
cat package-retrieve.xml

echo "Retrieving the store metadata and extracting it from the zip file."
# project retrieve start
sf project retrieve start --target-metadata-dir experience-bundle-package --manifest package-retrieve.xml

unzip -d experience-bundle-package experience-bundle-package/unpackaged.zip

#############################
#       Update Store        #
#############################

# storeId=`sf data query -q "SELECT Id FROM WebStore WHERE Name='$storename' LIMIT 1" -r csv |tail -n +2`
createNewQuery "SELECT Id FROM WebStore WHERE Name='$storename' LIMIT 1"
storeId=`sf data query --file query.txt -r csv |tail -n +2`

# Register Apex classes needed for checkout integrations and map them to the store
echo "1. Setting up your integrations."
./scripts/bash/setup/97-DomainExtension.sh $scratchOrgName $storename

echo "You can view the results of the mapping in the Store Integrations page at /lightning/page/storeDetail?lightning__webStoreId=$storeId&storeDetail__selectedTab=store_integrations"

echo "2. Updating members list and activating community."
networkMetaFile="experience-bundle-package/unpackaged/networks/$communityNetworkName".network
tmpfile=$(mktemp)
sed "s/<networkMemberGroups>/<networkMemberGroups><profile>Shopper Profile<\/profile>/g;s/<status>.*/<status>Live<\/status>/g" $networkMetaFile > $tmpfile

mv -f $tmpfile $networkMetaFile

# Import Products and related data
# Get new Buyer Group Name
echo "3. Importing products and the other things"
buyergroupName=$(bash ./scripts/bash/5-importProductSample.sh $storename | tail -n 1)
echo_attention "Buyer group name $buyergroupName"

# If notnot working with scratch orgs, comment the code below
# Assign a role to the admin user, else update user will error out
echo "5. Mapping Admin User to Role."
# First of all, checks if that is not already created there...
# newRoleID=`sf data query --query \ "SELECT Id FROM UserRole WHERE Name = 'AdminRoleScriptCreation'" -r csv |tail -n +2`
createNewQuery "SELECT Id FROM UserRole WHERE Name = 'AdminRoleScriptCreation'"
newRoleID=`sf data query --file query.txt -r csv |tail -n +2`


if [ -z "$newRoleID" ]
then
	# ceoID=`sf data query --query \ "SELECT Id FROM UserRole WHERE Name = 'CEO'" -r csv |tail -n +2`
	createNewQuery "SELECT Id FROM UserRole WHERE Name = 'CEO'"
	ceoID=`sf data query --file query.txt -r csv |tail -n +2`

	# sfdx force:data:record:create -s UserRole -v "ParentRoleId='$ceoID' Name='AdminRoleScriptCreation' DeveloperName='AdminRoleScriptCreation' RollupDescription='AdminRoleScriptCreation' "
	objectName="UserRole"
	attributes="\"attributes\": { \"type\": \"$objectName\", \"referenceId\": \"${objectName}Ref1\"},"
	fieldValues="\"ParentRoleId\":\"$ceoID\", \"Name\":\"AdminRoleScriptCreation\", \"DeveloperName\":\"AdminRoleScriptCreation\", \"RollupDescription\":\"AdminRoleScriptCreation\""
	createJsonFile "$attributes $fieldValues"
	sf data import tree --files Data.json

	# after creating, just wait a little to get the id back
	# newRoleID=`sf data query --query \ "SELECT Id FROM UserRole WHERE Name = 'AdminRoleScriptCreation'" -r csv |tail -n +2`
	createNewQuery "SELECT Id FROM UserRole WHERE Name = 'AdminRoleScriptCreation'"
	newRoleID=`sf data query --file query.txt -r csv |tail -n +2`

	echo_attention "Admin user roleID ID created now $newRoleID"
else
	echo "Admin user roleID ID alreadt created $newRoleID"
fi


# after creating, just wait a little to get the id back
# userName=`sfdx force:user:display | grep "Username" | sed 's/Username//g;s/^[[:space:]]*//g'`
userName=`sfdx force:user:display | grep "Username" | sed 's/^.*Username *│ *//;s/ *│.*$//'`

trimName=`echo $userName | sed 's/ *$//g'`
userName=$trimName
# userId=`sf data query --query \ "SELECT Id FROM User WHERE username = '$userName'" -r csv |tail -n +2`
createNewQuery "SELECT Id FROM User WHERE username = '$userName'"
userId=`sf data query --file query.txt -r csv |tail -n +2`


echo_attention "Logged in username $userName ID $userId"
# after creating, just wait a little to get the id back
# sfdx force:data:record:update -s User -w "Id='$userId' username='$userName'" -v "UserRoleId='$newRoleID'" 
# Since we have a bash issue running on windows system, I have separeted the update
sf data update record --sobject User --record-id $userId --values "username='$userName'"
sf data update record --sobject User --record-id $userId --values "UserRoleId='$newRoleID'"

echo "Setup Guest Browsing."
# storeType=`sf data query --query \ "SELECT Type FROM WebStore WHERE Name = '${communityNetworkName}'" -r csv |tail -n +2`
createNewQuery "SELECT Type FROM WebStore WHERE Name = '${communityNetworkName}'"
storeType=`sf data query --file query.txt -r csv |tail -n +2`

echo "Store Type is $storeType"
# Originally it just was doing to b2c... but...
# # Update Guest Profile with required CRUD and FLS
# if [ "$storeType" = "B2C" ]
# then
	sh ./scripts/bash/4-b2bGuestBrowsing.sh "$communityNetworkName" "$buyergroupName"
# fi	
#############################
#   Deploy Updated Store    #
#############################

echo "Creating the package to deploy."
cd experience-bundle-package/unpackaged/
# Before creating the package to deploy, let deactivate some options that are not going fine
# # This option update the field, but even comming with false, the error persis
# echo_attention "Deactivating some Network object options for storeId $networkId"
# sfdx force:data:record:update -s Network -w "Id='$networkId' " -v "OptionsApexCDNCachingEnabled=false" 


# echo "Removing some options from the networks/$storename.network file"
# sed -i '' -e '/<meta>/,/<\/meta>/d' my-file.xml
# Since it is suposed to work in the api 56.0, this commands are not needed anymore
# sed -i -e "s/<enableApexCDNCaching>true<\/enableApexCDNCaching>//g" networks/$storename.network
# sed -i -e "s/<enableImageOptimizationCDN>true<\/enableImageOptimizationCDN>//g" networks/$storename.network
# sed -i -e "s/<enableImageOptimizationCDN>false<\/enableImageOptimizationCDN>//g" networks/$storename.network

cp -f ../../manifest/scratch/package-deploy-template.xml package.xml
zip -r -X ../"$communityExperienceBundleName"ToDeploy.zip *
# zip -r -X ../AccDesaToDeploy.zip *
cd ../..

# Uncomment the line below if you'd like to pause the script in order to save the zip file to deploy
echo_attention "Wait a little and, press <Enter> to resume... Just to avoind the UNABLE_TO_LOCK_ROW error..."
echo_attention "Starting now: $(date)... It is ideal await at least 5 minutes..."
read -p "Waiting"

echo "Deploy the new zip including the flow, ignoring warnings, then clean-up."
# sfdx force:mdapi:deploy -g -f experience-bundle-package/"$communityExperienceBundleName"ToDeploy.zip --wait -1 --verbose --singlepackage
sf project deploy start --metadata-dir experience-bundle-package/"$communityExperienceBundleName"ToDeploy.zip --single-package --wait 60 --verbose 

# sfdx force:mdapi:deploy -g -f experience-bundle-package/storeFront1ToDeploy.zip --wait -1 --verbose --singlepackage

echo "Removing the package xml files used for retrieving and deploying metadata at this step."
rm package-retrieve.xml

#############################################################################
# This plugin is not available anymore, since the repository was archived
# echo "Creating search index."
# sfdx 1commerce:search:start -n "$communityNetworkName"
#############################################################################

# Not layouts at this point...
# echo_attention "Doing the layouts update"
sf project deploy start --ignore-conflicts --manifest manifest/scratch/package-03layouts.xml

# # Clean the path after running
rm -rf Deploy
rm -rf experience-bundle-package

removeTempFiles

echo_attention "Running the apex file to create the variation attribute set"
sf org assign permset --name GeneralInternalUserGroup --target-org $scratchOrgName

sf apex run --file scripts/apex/setup/01ProductAttributeSet.apex

# No digital experience deployent for now

echo_attention "Please pay attention here before to continue!!!"
echo_attention "--------------------------------------------------------------------------"
echo "Before executing the next commands, please open your scratch org, do the CMS file importation"
echo "using the productMedia.zip that we have under the script/json folder (check the instruction"
echo "in readme file under the CMS configuration section) and refresh the CMS UI to confirm if"
echo "everything is already there."
echo_attention "Just after that, press <Enter> to resume..."
echo_attention "--------------------------------------------------------------------------"
read -p "Waiting"

echo_attention "Ok, let's continue!!!"
./scripts/bash/setup/99-DigitalExperienceDeploy.sh $scratchOrgName manifest/setup/package-99DigitalExperience.xml

echo "Publishing the community."
sf community publish --name "$communityNetworkName"
sleep 10


echo ""
echo ""
echo_attention "Finishing the d2cStore set up and  buyer user creation at $(date)"
