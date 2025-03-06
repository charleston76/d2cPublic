
Map<String, String> mapVariation = new Map<String, String>{
    'Color' => 'Color', 'Size' => 'Talla',  'Color_Size' => 'Color y Talla'
} ;
List<ProductAttributeSet> lstNewAttributeSet = new List<ProductAttributeSet>();
 
String description = 'Crea los atributos de ';

System.debug('mapVariation ' + mapVariation);

// Checks if the ProductAttributeSet is created
List<ProductAttributeSet> lstExit = [
    SELECT Id, DeveloperName, MasterLabel, Description 
    FROM ProductAttributeSet
    WHERE DeveloperName IN : mapVariation.keyset()
    AND   MasterLabel IN: mapVariation.values()
];

System.debug('Color lstExit.size()' + lstExit.size()) ;

if (lstExit.size() ==0){
    for (String fieldKey : mapVariation.keyset() ){
        lstNewAttributeSet.add(
            new ProductAttributeSet (
                    DeveloperName = fieldKey, 
                    MasterLabel = mapVariation.get(fieldKey), 
                    Description = description + mapVariation.get(fieldKey)
                )
        );
    }
    
    insert lstNewAttributeSet;

    System.debug('lstNewAttributeSet ' + lstNewAttributeSet) ;

    // Create the fields inside the attributes
    Map<String,String> mapFieldId = new Map<String,String>();
    String objectName = 'ProductAttribute';

    for (FieldDefinition objField : [
        SELECT DurableId, QualifiedApiName, Label
        FROM FieldDefinition
        WHERE EntityDefinition.QualifiedApiName =: objectName
        AND   QualifiedApiName IN ('SOLUColor__c', 'SOLUSize__c')
        ]){
            String strId = String.valueOf(objField.DurableId);
            strId = strId.replace(objectName +'.','' );
            mapFieldId.put(objField.Label , strId);
    }

    System.debug('mapFieldId' + mapFieldId) ;

    List<ProductAttributeSetItem> lstSetItem = new List<ProductAttributeSetItem>();
    String colorSizeAttId = '';

    for (ProductAttributeSet rowAttSet : lstNewAttributeSet){
        System.debug('rowAttSet' + rowAttSet) ;

        if (rowAttSet.MasterLabel !=  'Color y Talla'){
            lstSetItem.add(
                new ProductAttributeSetItem (
                    ProductAttributeSetId = rowAttSet.Id, 
                    Field = mapFieldId.get(rowAttSet.MasterLabel), 
                    Sequence = 0
                )
            );
        } else {
            colorSizeAttId = String.valueOf(rowAttSet.Id);
        }
    }

    Integer sequence = 0;
    for (String fieldKey : mapFieldId.values() ){
        System.debug('fieldKey' + fieldKey) ;
        lstSetItem.add(
            new ProductAttributeSetItem (
                ProductAttributeSetId = colorSizeAttId, 
                Field = fieldKey, 
                Sequence = sequence
            )
        );
        sequence++;
    }

    System.debug('lstSetItem ' + lstSetItem) ;
    // System.debug('lstSetItem.size() ' + lstSetItem.size()) ;
    if (lstSetItem.size() > 0 ) insert lstSetItem;
}


// // SELECT Id, Name, ProductId, VariantParentId, Sequence, SOLUColor__c, SOLUSize__c FROM ProductAttribute
// delete [
//     SELECT Id FROM ProductAttribute
// ];
// delete [
//     SELECT Id FROM Product2
// ];
// delete [
//     SELECT Id FROM ProductCategory
// ];
// delete [
//     SELECT Id FROM ProductAttributeSetItem
// ];

// delete [
//     SELECT Id FROM ProductAttributeSet
// ];

