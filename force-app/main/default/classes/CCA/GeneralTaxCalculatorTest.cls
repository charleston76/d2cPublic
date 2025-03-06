@IsTest
public class GeneralTaxCalculatorTest {
    @IsTest
    static void calculateTaxes_Success() {
        WebCart webcart = GeneralTestDataFactory.createCartForCartCalculateClasses();
        Test.startTest();
        CartExtension.Cart cart = CartExtension.CartTestUtil.getCart(webcart.Id);
        System.debug('cart: ' + cart);
        GeneralTaxCalculator taxCalculate = new GeneralTaxCalculator();
        CartExtension.CartCalculateCalculatorRequest request = new CartExtension.CartCalculateCalculatorRequest(cart,CartExtension.OptionalBuyerActionDetails.empty());
		taxCalculate.calculate(request);
		Test.stopTest();
        Assert.isTrue(request.getCart().getCartValidationOutputs().isEmpty());
    }

    @IsTest
    static void calculateTaxes_ItemModified() {
        WebCart webcart = GeneralTestDataFactory.createCartForCartCalculateClasses();
        CartExtension.Cart cart = CartExtension.CartTestUtil.getCart(webcart.Id);
        CartExtension.CartItem cartItem = cart.getCartItems().get(0);
        cartItem.setNetUnitPrice(100.00);   
        
        Test.startTest();
        GeneralTaxCalculator taxCalculate = new GeneralTaxCalculator();
        CartExtension.CartCalculateCalculatorRequest request = new CartExtension.CartCalculateCalculatorRequest(cart, CartExtension.OptionalBuyerActionDetails.empty());
        taxCalculate.calculate(request);
        Test.stopTest();
    }
    

    @IsTest
    static void calculateTaxesCoverExternalClass() {
        GeneralTaxCalculator.TaxDataFromExternalService objCreate = new GeneralTaxCalculator.TaxDataFromExternalService();
        Integer totalItemizedPromotionTaxAmount = 0;
        Assert.isTrue(objCreate.taxName == '');
        Assert.isTrue(objCreate.getTotalItemizedPromotionTaxAmount() == totalItemizedPromotionTaxAmount);
    }

    @IsTest
    static void cartAdjustmentClass() {
        GeneralTaxCalculator.CartAdjustment objCreate = new GeneralTaxCalculator.CartAdjustment();
        String webCartId = GeneralTestDataFactory.getMockId(Schema.WebCart.SObjectType);
        Decimal getAmount = 1500;
        objCreate = new GeneralTaxCalculator.CartAdjustment(webCartId,getAmount);

        Assert.isTrue(objCreate.getId() == webCartId);
        Assert.isTrue(objCreate.getAmount() == getAmount);

    }

    @IsTest
    static void getAdjustmentByIdTest() {
        GeneralTaxCalculator objCreate = new GeneralTaxCalculator();
        WebCart webcart = GeneralTestDataFactory.createCartForCartCalculateClasses();
        Test.startTest();
        CartExtension.Cart cart = CartExtension.CartTestUtil.getCart(webcart.Id);
        GeneralTaxCalculator taxCalculate = new GeneralTaxCalculator();
        CartExtension.CartCalculateCalculatorRequest request = new CartExtension.CartCalculateCalculatorRequest(cart,CartExtension.OptionalBuyerActionDetails.empty());        
        CartExtension.Cart reqCart = request.getCart();
        CartExtension.CartItemList cartItemCollection = reqCart.getCartItems();
        CartExtension.CartItem objCartItem = cartItemCollection.get(0);
        CartExtension.CartItemPriceAdjustmentList itemizedPromotions = objCartItem.getCartItemPriceAdjustments();

        CartExtension.cartItemPriceAdjustment objReturn = objCreate.getAdjustmentById(itemizedPromotions , String.valueOf(webcart.Id));
        Test.stopTest();
        System.debug('objReturn ' + objReturn);
        Assert.isTrue(objReturn == null);
    }
 
    @IsTest
    public static void shouldRunPromotionsAndTaxesWhenBuyerAddsCoupon() {
        // Arrange Cart
        // CartExtension.Cart cart = arrangeCart();
        WebCart webcart = GeneralTestDataFactory.createCartForCartCalculateClasses();

        CartExtension.Cart cart = CartExtension.CartTestUtil.getCart(webcart.Id);
        System.debug('cart: ' + cart);
        GeneralTaxCalculator taxCalculate = new GeneralTaxCalculator();

        // Arrange BuyerActions and BuyerActionDetails as if the Buyer added a coupon
        CartExtension.BuyerActionsMock buyerActions = new CartExtension.BuyerActionsMock(cart);
        buyerActions.setCouponChanged(True);

        CartExtension.CartCalculateCalculatorRequest request = new CartExtension.CartCalculateCalculatorRequest(cart,CartExtension.OptionalBuyerActionDetails.empty());
		taxCalculate.calculate(request);
    }
    
}