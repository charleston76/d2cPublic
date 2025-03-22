@isTest
public with sharing class GenericPaymentAdapterTest {
    @isTest static void shouldGetTestCoverage(){
        commercepayments.paymentGatewayContext gatewayContext;
        Test.startTest();
        GenericPaymentAdapter adapter = new GenericPaymentAdapter();
        adapter.processRequest(gatewayContext);
        Test.stopTest();
    }
}