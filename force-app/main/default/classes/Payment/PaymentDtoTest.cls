@isTest
public class PaymentDtoTest {

    @isTest
    static void testDefaultConstructor() {
        PaymentDto paymentDto = new PaymentDto();
    }
    
    @isTest
    static void testParameterizedConstructor() {
        String expectedRedirectUrl = 'https://example.com';
        String expectedExternalReference = 'EXTERNAL123';
        String expectedCartId = 'CART123';

        PaymentDto paymentDto = new PaymentDto(expectedRedirectUrl, expectedExternalReference, expectedCartId);
    }
}
