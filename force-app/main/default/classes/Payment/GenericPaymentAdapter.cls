/*
 * Just to have the payment gateways created, I've created this class, 
 * and I'll use it to create the different payment gateways
 */
 public with sharing class GenericPaymentAdapter implements commercepayments.PaymentGatewayAdapter {
    private static final String CLASS_NAME = 'GenericPaymentAdapter';
    public commercepayments.GatewayResponse processRequest(commercepayments.paymentGatewayContext gatewayContext) {
        String METHOD_NAME = 'processRequest';
        system.debug(CLASS_NAME + ' ' + METHOD_NAME + ' gatewayContext ' + gatewayContext);
        commercepayments.RequestType requestType;
        commercepayments.GatewayResponse response;
        return response;
    }
}