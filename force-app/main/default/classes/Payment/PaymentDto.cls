public without sharing class PaymentDto {
    private static String CLASS_NAME = 'PaymentDto';

    @AuraEnabled
    public string redirectUrl = '';
    
    @AuraEnabled
    public string externalReference = '';

    @AuraEnabled
    public string cartId = '';

    public PaymentDto(){}
    public PaymentDto(string redirectUrl, String externalReference, string cartId){
        this.redirectUrl = redirectUrl;
        this.externalReference = externalReference;
        this.cartId = cartId;
    }
}