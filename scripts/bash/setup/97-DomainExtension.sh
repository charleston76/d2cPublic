#!/bin/bash

#  ./scripts/bash/setup/97-DomainExtension.sh tmpScrach d2cLightning

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
	rm  Data.json
}

function exit_error_message() {
  local red_color='\033[0;31m'
  local no_color='\033[0m'
  echo -e "${red_color}$1${no_color}"
  exit 1
}

function error_message() {
  local red_color='\033[0;31m'
  local no_color='\033[0m'
  echo -e "${red_color}$1${no_color}"
}

function echo_attention() {
  local green='\033[0;32m'
  local no_color='\033[0m'
  echo -e "${green}$1${no_color}"
}

if [ -z "$1" ]
then
	exit_error_message "You need to specify the org name to create it."
fi

if [ -z "$2" ]
then
	exit_error_message "You need to specify the the store name to create it."
fi


scratchOrgName=$1
storename=$2

#############################
#       Update Store        #
#############################
# storeId=`sf data query -q "SELECT Id FROM WebStore WHERE Name='$storename' LIMIT 1" -r csv |tail -n +2`
createNewQuery "SELECT Id FROM WebStore WHERE Name='$storename' LIMIT 1"
storeId=`sf data query --file query.txt -r csv |tail -n +2`

# For each Apex class needed for integrations, register it and map to the store
function register_and_map_integration() {
	# $1 is Apex class name
	# $2 is DeveloperName
	# $3 is ExtensionPointName


	# ExternalServiceProviderType = Extension, always
	externalService="Extension"
	echo "Registering Apex class: $1 DeveloperName:$2 ExtensionPointName: $3 ."

	# First of all, checks if ExtensionPointName is already configured
	echo "Checking if the ExtensionPointName $3 is already configured"
	createNewQuery "SELECT Id FROM RegisteredExternalService WHERE ExtensionPointName='$3' LIMIT 1"
	local extensionPointConfigured=`sf data query --file query.txt -r csv |tail -n +2`

	if [ -z "$extensionPointConfigured" ]
	then
		echo "Not created, ok, let's continue"
	else
		error_message "ExtensionPointName $3 is already configured with the ID $extensionPointConfigured"
		return 0
	fi

	# Get the Id of the Apex class
	# local apexClassId=`sf data query -q "SELECT Id FROM ApexClass WHERE Name='$1' LIMIT 1" -r csv |tail -n +2`
	createNewQuery "SELECT Id FROM ApexClass WHERE Name='$1' LIMIT 1"
	local apexClassId=`sf data query --file query.txt -r csv |tail -n +2`

	if [ -z "$apexClassId" ]
	then
		echo "There was a problem getting the ID of the Apex class $1 for checkout integrations."
		echo "The registration and mapping for this class will be skipped!"
		echo "Make sure that you run convert-examples-to-sfdx.sh and execute sfdx force:source:push -f before setting up your store."
	else
		# Register the Apex class. If the class is already registered, a "duplicate value found" error will be displayed but the script will continue.
		# sfdx force:data:record:create -s RegisteredExternalService -v "DeveloperName=$2 ExternalServiceProviderId=$apexClassId ExternalServiceProviderType=$3 MasterLabel=$2"
		objectName="RegisteredExternalService"
		attributes="\"attributes\": { \"type\": \"$objectName\", \"referenceId\": \"${objectName}Ref1\"},"
		fieldValues="\"DeveloperName\":\"$2\", \"ExternalServiceProviderId\":\"$apexClassId\", \"ExtensionPointName\":\"$3\", \"ExternalServiceProviderType\":\"$externalService\", \"MasterLabel\":\"$2\""
		createJsonFile "$attributes $fieldValues"
		sf data import tree --files Data.json

		# Map the Apex class to the store if no other mapping exists for the same Service Provider Type
		# local storeIntegratedServiceId=`sf data query -q "SELECT Id FROM StoreIntegratedService WHERE ExternalServiceProviderType='$3' AND StoreId='$storeId' LIMIT 1" -r csv |tail -n +2`
		createNewQuery "SELECT Id FROM StoreIntegratedService WHERE ServiceProviderType='$3' AND StoreId='$storeId' LIMIT 1"
		local storeIntegratedServiceId=`sf data query --file query.txt -r csv |tail -n +2`

		if [ -z "$storeIntegratedServiceId" ]
		then
			# No mapping exists, so we will create one
			# local registeredExternalServiceId=`sf data query -q "SELECT Id FROM RegisteredExternalService WHERE ExternalServiceProviderId='$apexClassId' LIMIT 1" -r csv |tail -n +2`
			createNewQuery "SELECT Id FROM RegisteredExternalService WHERE ExternalServiceProviderId='$apexClassId' LIMIT 1"
			local registeredExternalServiceId=`sf data query --file query.txt -r csv |tail -n +2`

			# sfdx force:data:record:create -s StoreIntegratedService -v "Integration=$registeredExternalServiceId StoreId=$storeId ServiceProviderType =$3"
			objectName="StoreIntegratedService"
			attributes="\"attributes\": { \"type\": \"$objectName\", \"referenceId\": \"${objectName}Ref1\"},"
			fieldValues="\"Integration\":\"$registeredExternalServiceId\", \"StoreId\":\"$storeId\", \"ServiceProviderType\":\"$externalService\""
			createJsonFile "$attributes $fieldValues"
			sf data import tree --files Data.json

		else
			echo "There is already a mapping in this store for $3 ServiceProviderType : $storeIntegratedServiceId"
		fi
	fi
}

function shippingProductCreation {
	productSkuName="DefaultShipping01"
	productSku="S01"
	createNewQuery "SELECT Id FROM Product2 WHERE Name='$productSkuName' AND ProductClass != 'VariationParent' AND StockKeepingUnit = '$productSku'"
	shippingProductId=`sf data query --file query.txt -r csv |tail -n +2`

	if [ -z "$shippingProductId" ]
	then
		# sf data create record --sobject Pricebook2 --values "Name='$storeName Pricebook' IsActive=true Description='$storeName Pricebook created by script'"
		sf data create record --sobject Product2 --values "Name='$productSkuName' IsActive=true  StockKeepingUnit='$productSku' ProductCode='$productSkuName' Description='$productSkuName created as default shipping for $storename'"
	else
		error_message "Shipping product $productSkuName already created!"
	fi

}

function register_and_map_credit_card_payment_integration {
	local paymentGatewayProviderName=$1
	local paymentGatewayName=$2
	local apexAdapterName=""
	local namedCredentialLabel=""
	local GenericGatewayProviderName=""

	if [ "$paymentGatewayProviderName" != "AuthorizeNetAdapter" ]
	then
		apexAdapterName="GenericPaymentAdapter"
		namedCredentialLabel="Generic Named Credential"
		GenericGatewayProviderName="GenericGatewayProvider"
	else
		apexAdapterName="$paymentGatewayProviderName"
		namedCredentialLabel="Authorize.Net"
		GenericGatewayProviderName="AuthorizeNetGatewayProvider"
	fi


	# First of all, checks if the generic payment provider exists, and create it if don't
	createNewQuery "SELECT Id FROM ApexClass WHERE Name='$apexAdapterName' LIMIT 1"
	apexClassId=`sf data query --file query.txt -r csv |tail -n +2`

	# Checks if the PaymentGatewayProvider exists by the class ID
	createNewQuery "SELECT Id FROM PaymentGatewayProvider WHERE DeveloperName='$GenericGatewayProviderName' LIMIT 1"
	local paymentGatewayProviderId=`sf data query --file query.txt -r csv |tail -n +2`


	if [ -z "$paymentGatewayProviderId" ]
	then
		echo_attention "Registering $GenericGatewayProviderName gateway provider."

		echo "Creating PaymentGatewayProvider record using ApexAdapterId=$apexClassId."
		objectName="PaymentGatewayProvider"
		attributes="\"attributes\": { \"type\": \"$objectName\", \"referenceId\": \"${objectName}Ref1\"},"
		fieldValues="\"DeveloperName\":\"$GenericGatewayProviderName\", \"ApexAdapterId\":\"$apexClassId\", \"MasterLabel\":\"$GenericGatewayProviderName\", \"IdempotencySupported\":\"Yes\", \"Comments\":\"Comments\""
		createJsonFile "$attributes $fieldValues"
		sf data import tree --files Data.json

		# Checks if the PaymentGatewayProvider exists by the class ID
		createNewQuery "SELECT Id FROM PaymentGatewayProvider WHERE DeveloperName='$GenericGatewayProviderName' LIMIT 1"
		paymentGatewayProviderId=`sf data query --file query.txt -r csv |tail -n +2`		
	fi

	# Checks if the PaymentGateway exists by his name
	createNewQuery "SELECT Id FROM PaymentGateway WHERE PaymentGatewayName='$paymentGatewayName' LIMIT 1"
	paymentGatewayId=`sf data query --file query.txt -r csv |tail -n +2`

	# Creating Payment Gateway Provider
	if [ -z "$paymentGatewayId" ]
	then
		echo_attention "Registering $paymentGatewayName payment integration."

		createNewQuery "SELECT Id FROM NamedCredential WHERE MasterLabel='$namedCredentialLabel' LIMIT 1"
		namedCredentialId=`sf data query --file query.txt -r csv |tail -n +2`

		echo "Creating PaymentGateway record using MerchantCredentialId=$namedCredentialId, PaymentGatewayProviderId=$paymentGatewayProviderId."
		objectName="PaymentGateway"
		attributes="\"attributes\": { \"type\": \"$objectName\", \"referenceId\": \"${objectName}Ref1\"},"
		fieldValues="\"MerchantCredentialId\":\"$namedCredentialId\", \"PaymentGatewayName\":\"$paymentGatewayName\", \"PaymentGatewayProviderId\":\"$paymentGatewayProviderId\", \"Status\":\"ACTIVE\", \"Comments\":\"This is the payment gateway related with $paymentGatewayName\""
		createJsonFile "$attributes $fieldValues"
		sf data import tree --files Data.json
	else
		error_message "Payment Gateway Name $paymentGatewayName already created with ID $paymentGatewayId !"
	fi

	if [ "$paymentGatewayProviderName" == "AuthorizeNetAdapter" ]
	then
		# Map the Apex class to the store if no other mapping exists for the same Service Provider Type
		# The externalService is payment in this case
		local externalService="Payment"
		createNewQuery "SELECT Id FROM StoreIntegratedService WHERE ServiceProviderType='$externalService' AND StoreId='$storeId' LIMIT 1"
		local storeIntegratedServiceId=`sf data query --file query.txt -r csv |tail -n +2`

		if [ -z "$storeIntegratedServiceId" ]
		then
			# In this case, the registeredExternalServiceId is the same paymentGatewayId
			# Checks if the PaymentGateway exists by his name
			createNewQuery "SELECT Id FROM PaymentGateway WHERE PaymentGatewayName='$paymentGatewayName' LIMIT 1"
			local registeredExternalServiceId=`sf data query --file query.txt -r csv |tail -n +2`
			echo "Tegistered External Service Id $registeredExternalServiceId used as integration"

			# sfdx force:data:record:create -s StoreIntegratedService -v "Integration=$registeredExternalServiceId StoreId=$storeId ServiceProviderType =$3"
			objectName="StoreIntegratedService"
			attributes="\"attributes\": { \"type\": \"$objectName\", \"referenceId\": \"${objectName}Ref1\"},"
			fieldValues="\"Integration\":\"$registeredExternalServiceId\", \"StoreId\":\"$storeId\", \"ServiceProviderType\":\"$externalService\""
			createJsonFile "$attributes $fieldValues"
			sf data import tree --files Data.json

		else
			echo "There is already a mapping in this store for $externalService ServiceProviderType : $storeIntegratedServiceId"
		fi
	fi	
}

# Extension names:
# https://developer.salesforce.com/docs/commerce/salesforce-commerce/guide/available-extensions.html
# 1 - Extension point name: Commerce_Domain_Cart_Calculate
# 2 - Extension point name: Commerce_Domain_Inventory_CartCalculator
# 3 - Extension point name: Commerce_Domain_Pricing_Service
# 4 - Extension point name: Commerce_Domain_Promotions_CartCalculator
# 5 - Extension point name: Commerce_Domain_Shipping_CartCalculator
# 6 - Extension point name: Commerce_Domain_Tax_CartCalculator

# $1 is Apex class name
# $2 is DeveloperName
# $3 is ExtensionPointName
# Register Apex classes needed for checkout integrations and map them to the store
echo "Setting up your integrations."
echo "1. Setting up Cart Orchestrator."
register_and_map_integration "GeneralCartOrchestrator" "CartOrchestrator" "Commerce_Domain_Cart_Calculate"
echo "2. Setting up Shipping Calculator."
register_and_map_integration "GeneralShippingCalculator" "ShippingCalculator" "Commerce_Domain_Shipping_CartCalculator"
echo "3. Setting up Tax Calculator."
register_and_map_integration "GeneralTaxCalculator" "TaxCalculator" "Commerce_Domain_Tax_CartCalculator"
echo "4. Setting up Pricing Calculator."
register_and_map_integration "GeneralPricingCalculator" "PricingCalculator" "Commerce_Domain_Pricing_Service"

echo "5. Creating the shipping product."
shippingProductCreation

echo "6. Not registering the payment gateway anymore."
echo "6.a - Bank Transfer."
register_and_map_credit_card_payment_integration "BankTransferPGProvider" "BankTransferPGateway"

echo "6.b - Mercado Pago."
register_and_map_credit_card_payment_integration "MercadoPagoPGProvider" "MercadoPagoPGateway"

echo "6.c - Authorize.NEt."
register_and_map_credit_card_payment_integration "AuthorizeNetAdapter" "AuthorizeNetPGateway"

echo "7. Removing temporary files."
removeTempFiles

echo "You can view the results of the mapping in the Store Integrations page at /lightning/page/storeDetail?lightning__webStoreId=$storeId&storeDetail__selectedTab=store_integrations"

# To remove this data and try again:
# 	delete [SELECT Id, PaymentGatewayName FROM PaymentGateway]; 
# 	delete [SELECT Id, StoreId, Integration, ServiceProviderType FROM StoreIntegratedService]; 
# 	delete [SELECT Id, DeveloperName, MasterLabel, ExternalServiceProviderId, ExternalServiceProviderType FROM RegisteredExternalService]; 

echo ""
echo ""
echo_attention "Finishing store registration set up at $(date)"
