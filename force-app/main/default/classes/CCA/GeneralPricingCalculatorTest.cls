@IsTest
public with sharing class GeneralPricingCalculatorTest {
    public static Map<Id, String> mapProductIdToSku = new Map<Id, String>();

    @IsTest
	static void processPriceStaticPricingSuccess() {
		Product2 objProd1 = GeneralTestDataFactory.createProduct('test'+GeneralTestDataFactory.generateRandomString(5), 'Test1');
        insert objProd1;
		Product2 objProd2 = GeneralTestDataFactory.createProduct('test'+GeneralTestDataFactory.generateRandomString(5), 'Test1');
        insert objProd2;
		Product2 objProd3 = GeneralTestDataFactory.createProduct('test'+GeneralTestDataFactory.generateRandomString(5), 'Test1');
        insert objProd3;

		String productId = objProd1.Id;
		String productIdWithCustomCD = objProd2.Id;
		String cachedProductId = objProd3.Id;
		Account objAcc = GeneralTestDataFactory.createAccount();
		Id accountId = objAcc.Id;

        GeneralTestDataFactory.createStandarPriceBook(new List<Id> {objProd1.id, objProd2.id});		
		final Decimal cachedListPrice = null;
		final Decimal cachedUnitPrice = null;

		CommerceStorePricing.PricingRequest pricingRequest = new CommerceStorePricing.PricingRequest();
		CommerceStorePricing.PricingRequestItem pricingRequestItem = new CommerceStorePricing.PricingRequestItem(productId);
		CommerceStorePricing.PricingRequestItem customCdPricingRequestItem = new CommerceStorePricing.PricingRequestItem(productIdWithCustomCD);
		CommerceStorePricing.PricingRequestItem cachedPricingRequestItem = new CommerceStorePricing.PricingRequestItem(cachedProductId);
		pricingRequest.addPricingRequestItem(pricingRequestItem);
		pricingRequest.addPricingRequestItem(customCdPricingRequestItem);
		pricingRequest.addPricingRequestItem(cachedPricingRequestItem);
		pricingRequest.setEffectiveAccountId(accountId);

		GeneralPricingCalculator pricingService = new GeneralPricingCalculator();
		Test.startTest();
		CommerceStorePricing.PricingResponse response = pricingService.processPrice(pricingRequest);
		Test.stopTest();
		CommerceStorePricing.PricingResponseItemCollection responseItems = response.getPricingResponseItems();
		Assert.areEqual(cachedListPrice,responseItems.get(2).getListPrice());
		Assert.areEqual(cachedUnitPrice,responseItems.get(2).getNegotiatedPrice());
	}

	@IsTest
	static void processPrice_Callout_Success() {

		Product2 objProd1 = GeneralTestDataFactory.createProduct('test'+GeneralTestDataFactory.generateRandomString(5), 'Test1');
        insert objProd1;
		Product2 objProd2 = GeneralTestDataFactory.createProduct('test'+GeneralTestDataFactory.generateRandomString(5), 'Test1');
        insert objProd2;

		Id productId = objProd1.Id;
		Id productIdWithError = objProd2.Id;
		Account objAcc = GeneralTestDataFactory.createAccount();
		Id accountId = objAcc.Id;

		GeneralTestDataFactory.createStandarPriceBook(new List<Id> {objProd1.id, objProd2.id});

		mapProductIdToSku.put(productId,'103865');
		mapProductIdToSku.put(productIdWithError, '190004');

		CommerceStorePricing.PricingRequest pricingRequest = new CommerceStorePricing.PricingRequest();
		CommerceStorePricing.PricingRequestItem pricingRequestItem = new CommerceStorePricing.PricingRequestItem(productId);
		CommerceStorePricing.PricingRequestItem errorPricingRequestItem = new CommerceStorePricing.PricingRequestItem(productIdWithError);
		pricingRequest.addPricingRequestItem(pricingRequestItem);
		pricingRequest.addPricingRequestItem(errorPricingRequestItem);
		pricingRequest.setEffectiveAccountId(accountId);

		StaticResourceCalloutMock mock = new StaticResourceCalloutMock();
		mock.setStaticResource('staticCalloutMockPricing');
		mock.setStatusCode(200);
		mock.setHeader('Content-Type', 'text/json');
		System.Test.setMock( HttpCalloutMock.class, mock );

		GeneralPricingCalculator pricingService = new GeneralPricingCalculator();
		Test.startTest();
		CommerceStorePricing.PricingResponse response = pricingService.processPrice(pricingRequest);
		Test.stopTest();
		CommerceStorePricing.PricingResponseItemCollection responseItems = response.getPricingResponseItems();
		// Assert.areEqual(990585,responseItems.get(0).getListPrice());
		// Assert.areEqual(960867,responseItems.get(0).getNegotiatedPrice());
		Assert.areEqual(1020,responseItems.get(1).getListPrice());
		// Assert.areEqual(1020,responseItems.get(1).getNegotiatedPrice());

	}

	@IsTest
	static void processTransactionalPrice_Callout_Success() {
		// Id productId = GeneralTestDataFactory.getMockId(Schema.Product2.SObjectType);
		// Id productIdWithError = GeneralTestDataFactory.getMockId(Schema.Product2.SObjectType);

		Product2 objProd1 = GeneralTestDataFactory.createProduct('test'+GeneralTestDataFactory.generateRandomString(5), 'Test1');
        insert objProd1;
		Product2 objProd2 = GeneralTestDataFactory.createProduct('test'+GeneralTestDataFactory.generateRandomString(5), 'Test1');
        insert objProd2;

        GeneralTestDataFactory.createStandarPriceBook(new List<Id> {objProd1.id, objProd2.id});

        Id productId = objProd1.Id;
        Id productIdWithError = objProd2.Id;

		mapProductIdToSku.put(objProd1.Id,objProd1.ProductCode);
		mapProductIdToSku.put(productIdWithError, objProd2.ProductCode);

		CommerceStorePricing.TransactionalPricingRequest pricingRequest = new CommerceStorePricing.TransactionalPricingRequest();
		CommerceStorePricing.TransactionalPricingRequestItem pricingRequestItem = new CommerceStorePricing.TransactionalPricingRequestItem(null, productId, 10);
		CommerceStorePricing.TransactionalPricingRequestItem errorPricingRequestItem = new CommerceStorePricing.TransactionalPricingRequestItem(null, productIdWithError, 5);
		pricingRequest.addTxnPricingRequestItem(pricingRequestItem);
		pricingRequest.addTxnPricingRequestItem(errorPricingRequestItem);

		StaticResourceCalloutMock mock = new StaticResourceCalloutMock();
		mock.setStaticResource('staticCalloutMockPricing');
		mock.setStatusCode(200);
		mock.setHeader('Content-Type', 'text/json');
		System.Test.setMock( HttpCalloutMock.class, mock );

		GeneralPricingCalculator pricingService = new GeneralPricingCalculator();
		Test.startTest();
		CommerceStorePricing.TransactionalPricingResponse response = pricingService.processTransactionalPrice(pricingRequest);
		Test.stopTest();
		CommerceStorePricing.TxnPricingResponseItemCollection responseItems = response.getTxnPricingResponseItems();
		Assert.areEqual(1020,responseItems.get(0).getListPrice());
	}
}