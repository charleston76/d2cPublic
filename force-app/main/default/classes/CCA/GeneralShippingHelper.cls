public with sharing class GeneralShippingHelper {
    private static final GeneralShippingHelper instance = new GeneralShippingHelper();

    private GeneralShippingHelper(){}

    public static GeneralShippingHelper getInstance(){
        return instance;
    }

    public ShippingCharge__mdt getShippingChargebyDeveloperName(String developerName) {
        List<ShippingCharge__mdt> objConf = [
            SELECT 
                Id, DeveloperName, MasterLabel, ShippingChargeValue__c, LabelToShow__c, AdditionalTitle__c, AdditionalDescription__c, ShippingType__c
            FROM ShippingCharge__mdt
            WHERE isActive__c = true
            AND   DeveloperName =: developerName
            LIMIT 1
        ];

        if (objConf.size() == 0 ) throw new AuraHandledException('There is no configuration for ' + developerName + '!');
        
        return objConf[0];
    }
}