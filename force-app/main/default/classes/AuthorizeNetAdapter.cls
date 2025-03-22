/*
 * ####################################################################################
 * # I'M STILL WORKING IN THIS TRANSACTIONS!
 * # PLEASE BE PATIENT THAT AS SOON AS POSSIBLE I'LL RELEASE THE FINAL WORKING VERSION
 * ####################################################################################
 */

public with sharing class AuthorizeNetAdapter implements commercepayments.PaymentGatewayAdapter {
    private static final String CLASS_NAME = 'AuthorizeNetAdapter';
    private static final commercepayments.SalesforceResultCodeInfo SUCCESS_SALESFORCE_RESULT_CODE_INFO = 
    		new commercepayments.SalesforceResultCodeInfo(commercepayments.SalesforceResultCode.Success);
    private static final commercepayments.SalesforceResultCodeInfo DECLINE_SALESFORCE_RESULT_CODE_INFO = 
    		new commercepayments.SalesforceResultCodeInfo(commercepayments.SalesforceResultCode.Decline);
            
    public commercepayments.GatewayResponse processRequest(commercepayments.paymentGatewayContext gatewayContext) {
        String METHOD_NAME = 'processRequest';
        system.debug(CLASS_NAME + ' ' + METHOD_NAME + ' gatewayContext ' + gatewayContext);
        commercepayments.RequestType requestType = gatewayContext.getPaymentRequestType();
        commercepayments.GatewayResponse response;
        system.debug(CLASS_NAME + ' ' + METHOD_NAME + ' requestType ' + requestType);
        try {
            if(String.valueOf(requestType) == 'Authorize') {  // AUTH ONLY
                commercepayments.AuthorizationRequest authRequest = (commercepayments.AuthorizationRequest) gatewayContext.getPaymentRequest();
                response = createAuthResponse((commercepayments.AuthorizationRequest)gatewayContext.getPaymentRequest());
            } else if (requestType == commercepayments.RequestType.Tokenize) {
                response = createTokenizeResponse((commercepayments.PaymentMethodTokenizationRequest)gatewayContext.getPaymentRequest());
            }
            return response;
        } catch(Exception e) {
            system.debug(e.getMessage());
            return new commercepayments.GatewayErrorResponse('400', e.getMessage());
        }
    }

    private String getRandomNumber(integer stringLength){
        final integer MAX = integer.valueOf(Math.pow(10,stringLength) - 1);
        return String.valueOf(Math.Round(Math.Random() * MAX)).leftPad(stringLength,'0');
    }

    public commercepayments.GatewayResponse createTokenizeResponse(commercepayments.PaymentMethodTokenizationRequest tokenizeRequest) {
        commercepayments.PaymentMethodTokenizationResponse tokenizeResponse = new commercepayments.PaymentMethodTokenizationResponse();
        tokenizeResponse.setGatewayToken(getRandomNumber(8)+getRandomNumber(8));
        tokenizeResponse.setGatewayTokenDetails(getRandomNumber(8)+getRandomNumber(8));
        tokenizeResponse.setGatewayAvsCode(getRandomNumber(8)+getRandomNumber(8));
        tokenizeResponse.setGatewayMessage(getRandomNumber(8)+getRandomNumber(8));
        tokenizeResponse.setGatewayResultCode(getRandomNumber(8)+getRandomNumber(8));
        tokenizeResponse.setGatewayResultCodeDescription(getRandomNumber(8)+getRandomNumber(8));
        tokenizeResponse.setSalesforceResultCodeInfo(SUCCESS_SALESFORCE_RESULT_CODE_INFO);
        tokenizeResponse.setGatewayToken(getRandomNumber(8)+getRandomNumber(8));
        tokenizeResponse.setGatewayDate(system.now());
        return tokenizeResponse;
    }
    
    public commercepayments.GatewayResponse createAuthResponse(commercepayments.AuthorizationRequest authRequest) {
        String METHOD_NAME = 'createAuthResponse';
        system.debug(CLASS_NAME + ' ' + METHOD_NAME + ' authRequest ' + authRequest);

        
        commercepayments.AuthorizationResponse authResponse = new commercepayments.AuthorizationResponse();
        commercepayments.PaymentMethodTokenizationResponse paymentMethodTokenizationResponse = new commercepayments.PaymentMethodTokenizationResponse();
        if(authRequest.amount!=null ){
            authResponse.setAmount(authRequest.amount);
        }else{
            throw new UtilApplicationException('Required Field Missing : Amount');
        }
    
        // Like that is working to B2C and Authorize.Net
        authResponse.setGatewayResultCode('00');
        authResponse.setGatewayResultCodeDescription('Transaction Normal');
        authResponse.setGatewayAuthCode('SF'+getRandomNumber(6));
        authResponse.setGatewayReferenceNumber(getRandomNumber(10));
        authResponse.setSalesforceResultCodeInfo(SUCCESS_SALESFORCE_RESULT_CODE_INFO);
        authResponse.setGatewayDate(system.now());
        paymentMethodTokenizationResponse.setGatewayToken(getRandomNumber(8)+getRandomNumber(8));
        authResponse.setPaymentMethodTokenizationResponse(paymentMethodTokenizationResponse);
        return authResponse;




        // // This version needs to be finished yet
        // // >>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>
        // // Setup Authorize.Net
        // B2BAuthorizeNetRequest authNetRequest = new B2BAuthorizeNetRequest();
        // HttpResponse authNetRequestResponse = authNetRequest.createAuthTransaction(authRequest);
        // system.debug(CLASS_NAME + ' ' + METHOD_NAME + ' authNetRequestResponse ' + authNetRequestResponse);
        // // Handle our Response
        // B2BAuthorizeNetResponse authNetResponse = B2BAuthorizeNetResponse.parse(authNetRequestResponse.getBody().replace('\uFEFF','').trim());
        // system.debug(CLASS_NAME + ' ' + METHOD_NAME + ' authNetResponse ' + authNetResponse);

        // // commercepayments.AuthorizationResponse authResponse = new commercepayments.AuthorizationResponse();
        // authResponse.setGatewayDate(System.now());
        // system.debug(CLASS_NAME + ' ' + METHOD_NAME + ' authRequest.amount ' + authRequest.amount);
        // authResponse.setAmount(authRequest.amount);

        // // Setup default messages.
        // system.debug(CLASS_NAME + ' ' + METHOD_NAME + ' authNetResponse.messages ' + authNetResponse.messages);
        // B2BAuthorizeNetResponse.Messages_Z messages = authNetResponse.messages;
        // B2BAuthorizeNetResponse.Message message = messages.message[0];
        // authResponse.setGatewayResultCode(messages.resultCode);
        // system.debug(CLASS_NAME + ' ' + METHOD_NAME + ' authResponse ' + authResponse);
        // system.debug(CLASS_NAME + ' ' + METHOD_NAME + ' message.text ' + message.text);
        // authResponse.setGatewayMessage(message.text);

        // B2BAuthorizeNetResponse.TransactionResponse transactionResponse = authNetResponse.transactionResponse;
        // system.debug(CLASS_NAME + ' ' + METHOD_NAME + ' transactionResponse ' + transactionResponse);
        // system.debug(CLASS_NAME + ' ' + METHOD_NAME + ' messages.resultCode ' + messages.resultCode);
        // if(messages.resultCode == 'Ok') {
            
        //     //authResponse.setAuthorizationExpirationDate(authExpDate);
        //     authResponse.setGatewayAuthCode(transactionResponse.authCode);
        //     authResponse.setGatewayAvsCode(transactionResponse.avsResultCode);            
        //     //authResponse.setGatewayReferenceDetails(gatewayReferenceDetails);
        //     authResponse.setGatewayReferenceNumber(transactionResponse.transId);
        //     authResponse.setGatewayResultCode('200');
            
        //     // commercepayments.PaymentMethodTokenizationResponse paymentMethodTokenizationResponse = new commercepayments.PaymentMethodTokenizationResponse();
        //     paymentMethodTokenizationResponse.setGatewayTokenDetails(transactionResponse.accountNumber);
        //     paymentMethodTokenizationResponse.setGatewayDate(System.now());
        //     paymentMethodTokenizationResponse.setGatewayTokenEncrypted(transactionResponse.transHashSha2);
        //     B2BAuthorizeNetResponse.Messages transMessage = transactionResponse.messages[0];
        //     paymentMethodTokenizationResponse.setGatewayResultCode(transMessage.code);
	    //     paymentMethodTokenizationResponse.setGatewayMessage(transMessage.description);
        //     authResponse.setPaymentMethodTokenizationResponse(paymentMethodTokenizationResponse);
            
        //     authResponse.setGatewayResultCodeDescription(message.text);
        //     authResponse.setSalesforceResultCodeInfo(new commercepayments.SalesforceResultCodeInfo(commercepayments.SalesforceResultCode.Success));
        //     return authResponse;
        // }
        
        // if(messages.resultCode == 'Error') {
        //     List<B2BAuthorizeNetResponse.Errors> authNetErrors = transactionResponse.errors;
        //     authResponse.setGatewayMessage(authNetErrors[0].errorText);
        //     authResponse.setGatewayResultCode(authNetErrors[0].errorCode);
        //     return new commercepayments.GatewayErrorResponse('400', authNetErrors[0].errorText);
        // }
        
        // // Handle Errors
        // authResponse.setSalesforceResultCodeInfo(new commercepayments.SalesforceResultCodeInfo(commercepayments.SalesforceResultCode.ValidationError));
        // return authResponse;
        // // <<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<
        
    }
}