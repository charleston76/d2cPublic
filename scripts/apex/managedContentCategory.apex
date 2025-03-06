// Find the relation ship between the product and images
// and creates the media type thing
// This script just can be ran after the image importation, ensuring the relationship between the sku and the image title
// That is following the LWR
// https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_connectapi_output_managed_content_delivery_document.htm
// String communityName = 'YOUR_COMMUNITY_NAME_HERE';
String communityName = 'd2cLightning';

String channelId  = String.valueOf([
    SELECT Id from ManagedContentChannel
    WHERE Name=: communityName + ' Channel'
    LIMIT 1
]?.Id);

System.debug('channelId ' + channelId);

Map<String, String> coffeeMap = new Map<String, String>{
    'Machines' => 'coffee-master-machines',
    'Coffee Machines' => 'coffee-machines',
    'Espresso Machines' => 'coffee-expresso-machines',
    'Advanced Espresso Machines' => 'coffee-advanced-expresso-machines',
    'Beans' => 'coffee-beans',
    'Dark' => 'coffee-dark-beans',
    'Light' => 'coffee-light-beans',
    'Medium' => 'coffee-medium-beans',
    'Coffee Accessories' => 'coffee-accessories',
    'Grinders' => 'coffee-grinders'
};

System.debug('coffeeMap ' + coffeeMap);
// Get all keys (Names to be searched)
Set<String> categoryNames = new Set<String>(coffeeMap.keySet());
System.debug('categoryNames ' + categoryNames);

Set<String> categoryValues = new Set<String>(coffeeMap.values());
System.debug('categoryValues ' + categoryValues);

String language = 'en_US';
String workspaceName = communityName + ' Workspace';
String categoryTileImage = 'tileImage';
Boolean showAbsoluteUrl = true;
Integer referenceDepth =0;
Boolean expandReferences = true;
Boolean referencesAsList = true;
String searchList = '_List';
String searchDetail = '_Detail';

List<String> managedContentIds = new List<String>();
List<String> topicNames = new List<String>();
Map<String,String> mpaMediaGroupId = new Map<String,String>();
Map<String,Product2> mapProduct = new Map<String,Product2>();
// Map<String,String> mapContentItem = new Map<String,String>();
Map<String,Map<String,String>> mapContentItem = new Map<String,Map<String,String>>();

List<ProductMedia> newProductMedia = new List<ProductMedia>();

for (ElectronicMediaGroup rowGroup : [
    SELECT Id , DeveloperName FROM ElectronicMediaGroup
    WHERE DeveloperName IN : new List<String>{categoryTileImage}
    ORDER BY DeveloperName]){
    mpaMediaGroupId.put(rowGroup.DeveloperName, rowGroup.Id);
}

System.debug('mpaMediaGroupId ' + mpaMediaGroupId);

String workspaceId = String.valueOf([
    SELECT Id, Name FROM ManagedContentSpace
    WHERE Name =:workspaceName 
]?.Id);

System.debug('workspace ' + workspaceName + ' - ' + workspaceId);

// Actually checks in the product category media
Set<String> existingProductMedia = new Set<String>();
for (ProductCategoryMedia objRow : [
    SELECT Name FROM ProductCategoryMedia
]){
    existingProductMedia.add(objRow.Name);
}

for (ManagedContent rowContent : [
    SELECT Id, Name
    FROM ManagedContent 
    WHERE AuthoredManagedContentSpaceId =:workspaceId
    AND   Name in : categoryValues
    ORDER BY Name
]){

    String mangedName = rowContent.Name;

    if (! existingProductMedia.contains(mangedName)) {
        managedContentIds.add(rowContent.Id);
    }   
}

System.debug('managedContentIds ' + managedContentIds);

for (String contentKeyOrId : managedContentIds){
    try{
        ConnectApi.ManagedContentDeliveryDocument objContDelivery = ConnectApi.Managedcontentdelivery.getManagedContentForChannel(channelId, contentKeyOrId, language, showAbsoluteUrl, referenceDepth, expandReferences, referencesAsList);
        // System.debug('objContDelivery.contentBody ' + objContDelivery.contentBody );
        // System.debug('objContDelivery.contentKey ' + objContDelivery.contentKey );
        // System.debug('objContDelivery.managedContentId ' + objContDelivery.managedContentId );
        // System.debug('objContDelivery.title ' + objContDelivery.title );
        // System.debug('objContDelivery.urlName ' + objContDelivery.urlName );
        String managedTitle = objContDelivery.title;

        Map<String,String> thisContent = new Map<String,String>();

        // Check if the map already have this code            
        if (mapContentItem.containsKey(managedTitle)){
            thisContent = mapContentItem.get(managedTitle);
            mapContentItem.remove(managedTitle);
        }
        thisContent.put(managedTitle, objContDelivery.managedContentId);
        // System.debug('contentKeyOrId ' + contentKeyOrId);
        // System.debug('thisContent ' + thisContent);

        mapContentItem.put(managedTitle, thisContent);

    }catch(Exception objEx){
        System.debug('objContDelivery error LineNumber: ' + objEx.getLineNumber() + ' Message: ' + objEx.getMessage());
    }
}

System.debug('mapContentItem ' + mapContentItem );


Map<String,ProductCategory> mapCategory = new Map<String,ProductCategory>();
List<ProductCategoryMedia> newProductCategoryMedia = new List<ProductCategoryMedia>();

// Create a map to related the images by the category names
for (ProductCategory rowCat : [
    SELECT Id, Name FROM ProductCategory 
    WHERE IsNavigational = TRUE
    AND   Name in : categoryNames ]){
    mapCategory.put(rowCat.Name, rowCat);
}

System.debug('mapCategory ' + mapCategory );

// Verify the categorues and try to findout the images in the map
for (String categoryName : mapCategory.keySet()){
    if (coffeeMap.containsKey(categoryName)){
        string keyName = coffeeMap.get(categoryName);
        // System.debug('keyName ' + keyName );

        if (mapContentItem.containsKey(keyName)){
            // System.debug('mapContentItem.get(keyName) ' + mapContentItem.get(keyName).get(keyName) );
            // System.debug('mapCategory.get(categoryName) ' + mapCategory.get(categoryName) );
            // System.debug('mpaMediaGroupId.get(categoryTileImage) ' + mpaMediaGroupId.get(categoryTileImage) );
            newProductCategoryMedia.add(
                new ProductCategoryMedia(
                    ProductCategoryId = mapCategory.get(categoryName).Id,
                    ElectronicMediaId = mapContentItem.get(keyName).get(keyName),
                    ElectronicMediaGroupId = mpaMediaGroupId.get(categoryTileImage)
                )
            );
        }    
    }
}

System.debug('newProductCategoryMedia.size() ' + newProductCategoryMedia.size() );
if (newProductCategoryMedia.size() > 0) insert newProductCategoryMedia;
