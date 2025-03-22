// Find the relation ship between the product and images
// and creates the media type thing
// This script just can be ran after the image importation, ensuring the relationship between the sku and the image title
// That is following the LWR
// https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_connectapi_output_managed_content_delivery_document.htm
String communityName = 'YOUR_COMMUNITY_NAME_HERE';
// 0 Simple code image, 1 Lista and Detail images
Integer intImageCodeDefinition = INT_IMAGE_CODE_DEFINITION;
// 0 Will work with the code, 1 Will work with the generic image
Integer intSwitchOption = INT_SWITCH_OPTION;

String channelId  = String.valueOf([
    SELECT Id from ManagedContentChannel
    WHERE Name=: communityName + ' Channel'
    LIMIT 1
]?.Id);

String communityId = String.valueOf([
    SELECT Id from Network 
    WHERE Name=: communityName
    LIMIT 1
]?.Id);

String webStoreId = String.valueOf([
    SELECT Id from WebStore 
    WHERE Name=: communityName
    LIMIT 1
]?.Id);


System.debug('community ' + communityName + ' - ' + communityId + ' webStoreId ' + webStoreId);
System.debug('channelId ' + channelId);
System.debug('intImageCodeDefinition ' + intImageCodeDefinition);
System.debug('intSwitchOption ' + intSwitchOption);



String contentType = '';
String language = 'en_US';
Integer pageSize = 200;
Integer pageNumber = 0;

String workspaceName = communityName + ' Workspace';
String productDetailImage = 'productDetailImage';
String productListImage = 'productListImage';
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

List<String> buyerGroupIds = new List<String>();
List<String> entitlementPolicyIds = new List<String>();
List<String> entitlementProductIds = new List<String>();
List<ProductMedia> newProductMedia = new List<ProductMedia>();
Integer countMatchesFound = 0;
Integer countNotFound = 0;

for (ElectronicMediaGroup rowGroup : [
    SELECT Id , DeveloperName FROM ElectronicMediaGroup
    WHERE DeveloperName IN : new List<String>{productDetailImage,productListImage,categoryTileImage}
    ORDER BY DeveloperName]){
    mpaMediaGroupId.put(rowGroup.DeveloperName, rowGroup.Id);
}

System.debug('mpaMediaGroupId ' + mpaMediaGroupId);
System.debug('community ' + communityName + ' - ' + communityId + ' webStoreId ' + webStoreId);
System.debug('channelId ' + channelId);


for (WebStoreBuyerGroup rowContent : [
    SELECT BuyerGroupId FROM WebStoreBuyerGroup
    WHERE WebStoreId =: webStoreId
    LIMIT :pageSize
]){
    buyerGroupIds.add(rowContent.BuyerGroupId);
}

System.debug('buyerGroupIds ' + buyerGroupIds);

for (CommerceEntitlementBuyerGroup rowEntitlement : [
    SELECT PolicyId FROM CommerceEntitlementBuyerGroup
    WHERE BuyerGroupId IN :buyerGroupIds
    LIMIT :pageSize
]){
    entitlementPolicyIds.add(rowEntitlement.PolicyId);
}

System.debug('entitlementPolicyIds ' + entitlementPolicyIds);

String workspaceId = String.valueOf([
    SELECT Id, Name FROM ManagedContentSpace
    WHERE Name =:workspaceName 
]?.Id);

System.debug('workspace ' + workspaceName + ' - ' + workspaceId);
Set<String> existingProductMedia = new Set<String>();
for (ProductMedia objRow : [
    SELECT Product.StockKeepingUnit FROM ProductMedia
]){
    existingProductMedia.add(objRow.Product.StockKeepingUnit);
}



    // LIMIT :pageSize
for (ManagedContent rowContent : [
    SELECT Id, Name
    FROM ManagedContent 
    WHERE AuthoredManagedContentSpaceId =:workspaceId
    ORDER BY Name
]){

    Integer indexDetail = 0;
    String codProd = '';
    // Check if is a list image
    Integer indexList = rowContent.Name.lastIndexOf(searchList);
    if (indexList >=0){
        // system.debug('indexList ' + indexList);
        codProd = rowContent.Name.mid(0,indexList);
    } else {
        indexDetail = rowContent.Name.lastIndexOf(searchDetail);
        // system.debug('indexDetail ' + indexDetail);
        codProd = rowContent.Name.mid(0,indexDetail);
    }

    if (! existingProductMedia.contains(codProd)) {
        managedContentIds.add(rowContent.Id);
    }   
}

// SELECT Id, Name, ContentKey, ExternalId FROM ManagedContent
// SELECT ProductId, Product.StockKeepingUnit FROM ProductMedia


String genericImageName = 'GenericImage';
for (String contentKeyOrId : managedContentIds){
    // Call the API
    // ConnectApi.ManagedContentDeliveryDocument objContDelivery = ConnectApi.Managedcontentdelivery.getManagedContentForChannel(channelId, contentKeyOrId, showAbsoluteUrl);
    try{
        // system.debug('channelId ' + channelId + ' contentKeyOrId ' + contentKeyOrId);

        ConnectApi.ManagedContentDeliveryDocument objContDelivery = ConnectApi.Managedcontentdelivery.getManagedContentForChannel(channelId, contentKeyOrId, language, showAbsoluteUrl, referenceDepth, expandReferences, referencesAsList);
        // System.debug('objContDelivery.contentBody ' + objContDelivery.contentBody );
        // System.debug('objContDelivery.contentKey ' + objContDelivery.contentKey );
        // System.debug('objContDelivery.managedContentId ' + objContDelivery.managedContentId );
        // System.debug('objContDelivery.title ' + objContDelivery.title );
        // System.debug('objContDelivery.urlName ' + objContDelivery.urlName );
        Integer indexDetail = 0;
        String codProd = '';
        // 0 Simple code image, 1 Lista and Detail images
        if (intImageCodeDefinition==0){
            codProd = objContDelivery.title;
        } else if (intImageCodeDefinition==1){
            // Check if is a list image
            Integer indexList = objContDelivery.title.lastIndexOf(searchList);
            if (indexList >=0){
                // system.debug('indexList ' + indexList);
                codProd = objContDelivery.title.mid(0,indexList);
            } else {
                indexDetail = objContDelivery.title.lastIndexOf(searchDetail);
                // system.debug('indexDetail ' + indexDetail);
                codProd = objContDelivery.title.mid(0,indexDetail);
            }
        }
        // System.debug('codProd ' + codProd );

        Map<String,String> thisContent = new Map<String,String>();
        // 0 Will work with the code, 1 Will work with the generic image
        if (intSwitchOption ==0){
            // Check if the map already have this code            
            if (mapContentItem.containsKey(codProd)){
                thisContent = mapContentItem.get(codProd);
                mapContentItem.remove(codProd);
            }
        } else if (intSwitchOption ==1){
            // Check if that is the generic key
            if (mapContentItem.containsKey(genericImageName)){
                thisContent = mapContentItem.get(genericImageName);
                mapContentItem.remove(genericImageName);
            }
        }

        thisContent.put(objContDelivery.title, objContDelivery.managedContentId);
        // System.debug('contentKeyOrId ' + contentKeyOrId);
        // System.debug('thisContent ' + thisContent);

        // 0 Will work with the code, 1 Will work with the generic image
        if (intSwitchOption ==0){
            mapContentItem.put(codProd, thisContent);
        } else if (intSwitchOption ==1){
            mapContentItem.put(genericImageName, thisContent);
        }

    }catch(Exception objEx){
        System.debug('objContDelivery error LineNumber: ' + objEx.getLineNumber() + ' Message: ' + objEx.getMessage());
    }
}

System.debug('mapContentItem ' + mapContentItem );

// Check the products that are in the right entitlement policies
for (CommerceEntitlementProduct objRow : [
    SELECT ProductId FROM CommerceEntitlementProduct
    WHERE PolicyId IN : entitlementPolicyIds
    AND   ProductId NOT IN (SELECT ProductId FROM ProductMedia)
    LIMIT :pageSize]){
    entitlementProductIds.add(objRow.ProductId);
}

System.debug('entitlementProductIds ' + entitlementProductIds );

// Create a map to related the images by the StockKeepingUnit and the title
for (Product2 objRow : [
    SELECT StockKeepingUnit, Id, Name, ProductCode, IsActive, Type 
    FROM Product2 
    WHERE StockKeepingUnit != NULL
    AND   Id IN : entitlementProductIds
    AND   IsActive = true
    AND   Id NOT IN (SELECT ProductId FROM ProductMedia)
    LIMIT :pageSize]){
    mapProduct.put(objRow.StockKeepingUnit, objRow);
}

System.debug('mapProduct ' + mapProduct );

// Verify the products and try to findout the images in the map
for (String stockKeepingUnit : mapProduct.keySet()){
    // if (mapContentItem.containsKey(stockKeepingUnit)){
    // System.debug('genericImageName ' + genericImageName);
    // System.debug('mapContentItem.containsKey(genericImageName) ' + mapContentItem.containsKey(genericImageName));


    String codeCheckContent = '';
    // 0 Will work with the code, 1 Will work with the generic image
    if (intSwitchOption ==0){
        codeCheckContent = stockKeepingUnit;
    } else if (intSwitchOption ==1){
        codeCheckContent = genericImageName;
    }

    if (mapContentItem.containsKey(codeCheckContent)){
        // Map<String,String> thisContent = mapContentItem.get(stockKeepingUnit);
        Map<String,String> thisContent = mapContentItem.get(codeCheckContent);
        // system.debug('thisContent ' + thisContent) ;

        // System.debug('thisContent ' + thisContent);
        for (String imageTitle : thisContent.keySet()){
            // Integer indexList = imageTitle.lastIndexOf(searchList);
            // if (indexList >=0){
            //     // System.debug('List ' + imageTitle );
            //     // add the product product list image
            //     newProductMedia.add(
            //         new ProductMedia(
            //             ProductId = mapProduct.get(stockKeepingUnit).Id,
            //             ElectronicMediaId = thisContent.get(imageTitle),
            //             ElectronicMediaGroupId = mpaMediaGroupId.get(productDetailImage)
            //         )
            //     );
            // } else {
            //     // System.debug('Detail ' + imageTitle );
            //     newProductMedia.add(
            //         new ProductMedia(
            //             ProductId = mapProduct.get(stockKeepingUnit).Id,
            //             ElectronicMediaId = thisContent.get(imageTitle),
            //             ElectronicMediaGroupId = mpaMediaGroupId.get(productListImage)
            //         )
            //     );
            // }
            if (imageTitle == codeCheckContent){
                // system.debug('imageTitle ' + imageTitle) ;
                // Add the product product list image
                newProductMedia.add(
                    new ProductMedia(
                        ProductId = mapProduct.get(stockKeepingUnit).Id,
                        ElectronicMediaId = thisContent.get(imageTitle),
                        ElectronicMediaGroupId = mpaMediaGroupId.get(productDetailImage)
                    )
                );
            
                // Add the product product detail image
                newProductMedia.add(
                    new ProductMedia(
                        ProductId = mapProduct.get(stockKeepingUnit).Id,
                        ElectronicMediaId = thisContent.get(imageTitle),
                        ElectronicMediaGroupId = mpaMediaGroupId.get(productListImage)
                    )
                );            
            }
        }

        countMatchesFound++;
    } else{
        countNotFound++;
        // System.debug('does not contain stockKeepingUnit ' + stockKeepingUnit);
    }
}

// System.debug('countMatchesFound ' + countMatchesFound );
// System.debug('countNotFound ' + countNotFound );
// System.debug('newProductMedia.size() ' + newProductMedia.size() );
if (newProductMedia.size() > 0) insert newProductMedia;

System.debug('newProductMedia.size() ' + newProductMedia.size() );

// Map<String,ProductCategory> mapCategory = new Map<String,ProductCategory>();
// List<ProductCategoryMedia> newProductCategoryMedia = new List<ProductCategoryMedia>();

// // Create a map to related the images by the category names
// for (ProductCategory rowCat : [
//     SELECT Id, Name FROM ProductCategory 
//     WHERE ParentCategoryId = NULL 
//     AND   IsNavigational = TRUE ]){
//     mapCategory.put(rowCat.Name, rowCat);
// }

// // Verify the categorues and try to findout the images in the map
// for (String categoryName : mapCategory.keySet()){
//     if (mapContentItem.containsKey(categoryName)){
//         newProductCategoryMedia.add(
//             new ProductCategoryMedia(
//                 ProductCategoryId = mapCategory.get(categoryName).Id,
//                 ElectronicMediaId = mapContentItem.get(categoryName),
//                 ElectronicMediaGroupId = mpaMediaGroupId.get(categoryTileImage)
//             )
//         );
//     }
// }

// System.debug('newProductCategoryMedia.size() ' + newProductCategoryMedia.size() );
// // if (newProductCategoryMedia.size() > 0) insert newProductCategoryMedia;

// // // SELECT Id, Name, ElectronicMediaId, ProductCategoryId, ElectronicMediaGroupId FROM ProductCategoryMedia
