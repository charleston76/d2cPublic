@IsTest
public with sharing class GeneralShippingCalculatorTest {
    private static WebCart cart;

    private static List<OrderDeliveryMethod> odms;

    static void makeData() {
        StaticResourceCalloutMock mock = new StaticResourceCalloutMock();
		mock.setStaticResource('staticCalloutMock');
		mock.setStatusCode(200);
		mock.setHeader('Content-Type', 'text/json');
		System.Test.setMock( HttpCalloutMock.class, mock );

        User u = [SELECT Id, UserRole.Name, Profile.Name FROM User WHERE Id = :UserInfo.getUserId()];
        System.runAs(u) {
            Account objAccount = GeneralTestDataFactory.createAccount();
            GeneralTestDataFactory.createBuyerAccount(objAccount.Id);

            Product2 objProd = GeneralTestDataFactory.createProduct('SKUTest','ProdTest');
            insert objProd;

            cart = GeneralTestDataFactory.createWebCart(objAccount.Id);
		    insert cart;

            CartDeliveryGroup cartDeliveryGroup = GeneralTestDataFactory.createCartDeliveryGroup(cart.Id, 'Default Delivery');
            insert cartDeliveryGroup;

            CartItem objCartItem = GeneralTestDataFactory.createdCartItem(cart.Id, cartDeliveryGroup.Id , 'cartItem', 10000, objProd);
            insert objCartItem;
        }

    }

    @IsTest
    static void testCartWithNoCartDeliveryGroup() {
        // Arrange
        makeData();
        CartExtension.Cart cart = CartExtension.CartTestUtil.getCart(cart.Id);
        CartExtension.CartDeliveryGroupList deliveryGroups = cart.getCartDeliveryGroups();
        CartExtension.CartDeliveryGroup deliveryGroup = deliveryGroups.get(0);
        deliveryGroups.remove(deliveryGroup);

        // Act
        Test.startTest();
        CartExtension.CartCalculateCalculatorRequest request = new CartExtension.CartCalculateCalculatorRequest(cart, CartExtension.OptionalBuyerActionDetails.empty());
        GeneralShippingCalculator calculator = new GeneralShippingCalculator();
        calculator.calculate(request);
        calculator = new GeneralShippingCalculator();
        calculator.calculate(request);
        Test.stopTest();

        // Assert
        CartExtension.CartValidationOutputList cartValidationOutputs = cart.getCartValidationOutputs();
        Assert.areEqual(1, cartValidationOutputs.size());
        CartExtension.CartValidationOutput cvo = cartValidationOutputs.get(0);
        Assert.areEqual(CartExtension.CartValidationOutputTypeEnum.SHIPPING, cvo.getType());
        Assert.areEqual('No Cart Delivery Groups have been defined', cvo.getMessage());
    }

    @IsTest
    static void testShippingMethodsAreCreated() {
        // Arrange
        makeData();
        // Create the default shipping product
        Product2 objShipProd = GeneralTestDataFactory.createProduct(GeneralShippingCalculator.SHIPPING_PRODUCT_CODE , GeneralShippingCalculator.SHIPPING_PRODUCT_NAME);
        insert objShipProd;

        CartExtension.Cart cart = CartExtension.CartTestUtil.getCart(cart.Id);

        // Act
        Test.startTest();
        CartExtension.CartCalculateCalculatorRequest request = new CartExtension.CartCalculateCalculatorRequest(cart, CartExtension.OptionalBuyerActionDetails.empty());
        GeneralShippingCalculator calculator = new GeneralShippingCalculator();
        calculator.calculate(request);
        calculator = new GeneralShippingCalculator();
        calculator.calculate(request);
        Test.stopTest();
        // Assert
        // Test if no CVO is created
        CartExtension.CartValidationOutputList cartValidationOutputs = cart.getCartValidationOutputs();
        Assert.areEqual(0, cartValidationOutputs.size());
    }

    @IsTest
    static void testNoShippingProduct() {
        // Arrange
        makeData();

        CartExtension.Cart cart = CartExtension.CartTestUtil.getCart(cart.Id);

        // Act
        Test.startTest();
        CartExtension.CartCalculateCalculatorRequest request = new CartExtension.CartCalculateCalculatorRequest(cart, CartExtension.OptionalBuyerActionDetails.empty());
        GeneralShippingCalculator calculator = new GeneralShippingCalculator();
        calculator.calculate(request);
        calculator = new GeneralShippingCalculator();
        calculator.calculate(request);
        Test.stopTest();
        // Assert
        // Test that one CVO is created
        CartExtension.CartValidationOutputList cartValidationOutputs = cart.getCartValidationOutputs();
        Assert.areEqual(1, cartValidationOutputs.size());
    }
}