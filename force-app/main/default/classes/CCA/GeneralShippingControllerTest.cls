@isTest
public with sharing class GeneralShippingControllerTest {
    private static List<ShippingCharge__mdt> getMockShippingCharge(String developerName) {
        List<ShippingCharge__mdt> mockShippingCharges = new List<ShippingCharge__mdt>();

        mockShippingCharges.add(new ShippingCharge__mdt(
            DeveloperName = developerName,
            LabelToShow__c = 'Shipping Charge Test',
            AdditionalTitle__c = 'Shipping Charge Title',
            AdditionalDescription__c = 'Shipping Charge Description',
            isActive__c = true
        ));

        return mockShippingCharges;
    }

    @isTest
    static void getShippingChargebyDeveloperNameTest() {
        // Setup mock data
        List<ShippingCharge__mdt> mockShippingCharges = getMockShippingCharge('DefaultValue');

        Test.startTest();
        ShippingCharge__mdt actualShippingCharge = GeneralShippingController.getShippingChargebyDeveloperName('DefaultValue');
        Test.stopTest();
    }
}