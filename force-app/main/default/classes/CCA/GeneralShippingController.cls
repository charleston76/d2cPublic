public with sharing class GeneralShippingController {

    @AuraEnabled
    public static ShippingCharge__mdt getShippingChargebyDeveloperName(String developerName) {
        return GeneralShippingHelper.getInstance().getShippingChargebyDeveloperName(developerName);
    }
}