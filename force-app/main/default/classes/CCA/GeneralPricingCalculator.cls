/**
 * This class is current with the Spring '24 release specific to these activities:
 * 1. Implement a Shipping Provider
 * 2. Configure a Cart Orchestrator
 *
 * This code handles the situation when the pricing behavior needs to be extended or overriden.
 * This is especially useful if you are sourcing pricing data from elsewhere such as in an ERP
 *
 * Your custom apex class must extend the commercestorepricing.PricingService abstract base class in
 * order to be processed by the pricing flow. The pricing extension point and then the integration
 * must be linked to the webstore in the Commerce app as covered in the B2B Commerce: Developer
 * Essentials course.
 * 
**/
public class GeneralPricingCalculator extends commercestorepricing.PricingService {
    private static final String CLASS_NAME = 'GeneralPricingCalculator';
    // private static Enumerations.LocalPricingSource localPricingSource = Enumerations.LocalPricingSource.CONNECTAPI;

    public override commercestorepricing.PricingResponse processPrice(commercestorepricing.PricingRequest request) {
        String METHOD_NAME = 'processPrice';
        commercestorepricing.PricingResponse objPricingResponse ;
        // get account ID from the request parameter
        String accountId = request.getEffectiveAccountId();
        System.debug(CLASS_NAME + ' - ' + METHOD_NAME + ' request ' + request );
        System.debug(CLASS_NAME + ' - ' + METHOD_NAME + ' accountId ' + accountId );

        try {
            Set<String> productIds = new Set<String>();
            // Get all products from request parameter            
            commercestorepricing.PricingRequestItemCollection requestedItems = request.getPricingRequestItems();

            // logic to map all product ids to a list called products
            for (Integer i = 0; i < requestedItems.size(); i++) {
                commercestorepricing.PricingRequestItem item = requestedItems.get(i);
                productIds.add(item.getProductId());
            }
            
            System.debug(CLASS_NAME + ' - ' + METHOD_NAME + ' productIds ' + productIds );

            // Get the SO custom price book IDs from the Customer Master 
            Set<String> customPriceBookId = getStandardPriceBookId(accountId);
            // System.debug(CLASS_NAME + ' - ' + METHOD_NAME + ' customPriceBookId ' + customPriceBookId );
            String currencyCode = 'USD';
            // String currencyCode = 'MXN';
 
            // Map<String, Decimal> mapProductPrices = getMapProductPrices(customPriceBookId, productIds);
            Map<String, DefinedPriceResult> mapProductPrices = getMapProductPrices(accountId,customPriceBookId, productIds);

            System.debug(CLASS_NAME + ' - ' + METHOD_NAME + ' mapProductPrices ' + mapProductPrices );

            // Create a response using just the first currency code
            objPricingResponse = new commercestorepricing.PricingResponse(currencyCode);

            // iterate through all productIds
            for (String productId : productIds){
                commercestorepricing.PricingResponseItem responseItem;

                if (mapProductPrices == null || mapProductPrices.get(productId) == null) {
                    // if blank set price to null
                    // PricingResponseItem(String productId, String productSellingModelId, String negotiatedPricebookEntryId, Decimal listPrice, Decimal negotiatedPrice)
                    responseItem = new commercestorepricing.PricingResponseItem(productId, null, null, null, null );
                    responseItem.setError('No prices available for this product.','Für dieses Produkt sind keine Preise verfügbar.');
                } else {
                    // if not blank then assign the account product price to the reponse item
                                                         // PricingResponseItem(productId, productSellingModelId, negotiatedPricebookEntryId, listPrice, negotiatedPrice)
                    responseItem = new commercestorepricing.PricingResponseItem(productId, null, null,mapProductPrices.get(ProductId).listPrice, mapProductPrices.get(ProductId).negotiatedPrice);
                }
                objPricingResponse.addPricingResponseItem(responseItem);
            }

        } catch (Exception objEx) { throw new AuraHandledException(CLASS_NAME + ' - ' + METHOD_NAME + ' - Error line ' + objEx.getLineNumber() + ' - Type ' + objEx.getTypeName() + ' - Message  ' + objEx.getMessage());}
        
        return objPricingResponse;
    }


    private static Set<String> getStandardPriceBookId(String accountId){
        String METHOD_NAME = 'getStandardPriceBookId';
        Set<String> standardPriceBookId = new Set<String>();

        System.debug(CLASS_NAME + ' - ' + METHOD_NAME + ' accountId ' + accountId );
        // Doesn't matter what would be the client, the price book always will be the standard one
        for (Pricebook2 rowPrice : [
            SELECT Id FROM Pricebook2
            WHERE IsActive = true 
            AND   IsStandard = true 
        ]){
            standardPriceBookId.add(String.valueOf(rowPrice.Id));
        }
        System.debug(CLASS_NAME + ' - ' + METHOD_NAME + ' standardPriceBookId ' + standardPriceBookId );
        return standardPriceBookId;
    }

    private static Map<String, DefinedPriceResult> getMapProductPrices(String accountId, Set<String> customPriceBookId, Set<String> productIds){
        String METHOD_NAME = 'getMapProductPrices';
        Map<String, DefinedPriceResult> mapProductPrices = new Map<String, DefinedPriceResult>();
        Map<String, Decimal> mapListPrice = new Map<String, Decimal>();
        Map<String, Decimal> mapNegotiatedPrice = new Map<String, Decimal>();
        Set<String> producDiscountId = new Set<String>();

        System.debug(CLASS_NAME + ' - ' + METHOD_NAME + ' customPriceBookId ' + customPriceBookId );
        System.debug(CLASS_NAME + ' - ' + METHOD_NAME + ' productIds ' + productIds );
        // To all the products, get the configured price
        for (PricebookEntry rowEntry : [
            SELECT Id, Product2Id, UnitPrice
            FROM PricebookEntry
            WHERE IsActive = true
            AND   Pricebook2Id IN : customPriceBookId
            AND   Product2Id IN : productIds
        ]){
            mapListPrice.put(rowEntry.Product2Id, rowEntry.UnitPrice);
            producDiscountId.add(rowEntry.Product2Id);
        }

        System.debug(CLASS_NAME + ' - ' + METHOD_NAME + ' mapListPrice ' + mapListPrice );

        System.debug(CLASS_NAME + ' - ' + METHOD_NAME + ' Auth.CommunitiesUtil.isGuestUser() ' + Auth.CommunitiesUtil.isGuestUser() );

        // Check the discounts just to logged users
        if(! Auth.CommunitiesUtil.isGuestUser()){
            // // For the products that were found, check the existing discount
            // ExternalRule_ApexControllerDiscount objDiscount = new ExternalRule_ApexControllerDiscount(accountId, producDiscountId);
            // System.debug(CLASS_NAME + ' - ' + METHOD_NAME + ' objDiscount ' + objDiscount );

            // for (String productId : producDiscountId){
            //     Decimal appliedDiscount = objDiscount.getDiscount(productId, 0);
            //     System.debug(CLASS_NAME + ' - ' + METHOD_NAME + ' appliedDiscount ' + appliedDiscount );
            //     //to avoid add negotiated price if applied discout is zero
            //     if(appliedDiscount > 0){
            //         Decimal reducedValue = mapListPrice.get(productId) * (appliedDiscount / 100);
            //         System.debug(CLASS_NAME + ' - ' + METHOD_NAME + ' reducedValue ' + reducedValue );
            //         Decimal negotiatedPrice = mapListPrice.get(productId) - reducedValue;
            //         System.debug(CLASS_NAME + ' - ' + METHOD_NAME + ' negotiatedPrice ' + negotiatedPrice );
            //         mapNegotiatedPrice.put(productId, negotiatedPrice);
            //     }
            // }
        }

        System.debug(CLASS_NAME + ' - ' + METHOD_NAME + ' mapNegotiatedPrice ' + mapNegotiatedPrice );

        for (String productId : mapListPrice.keySet()){
            Decimal listPrice = mapListPrice.get(productId);
            // If not hava negotiated price, is the same of the list
            // otherwise is the negotiated price
            Decimal negotiatedPrice = ! mapNegotiatedPrice.containsKey(productId) ?
                mapListPrice.get(productId) : mapNegotiatedPrice.get(productId) ; 

            mapProductPrices.put(productId, new DefinedPriceResult(productId, listPrice, negotiatedPrice));
        }

        System.debug(CLASS_NAME + ' - ' + METHOD_NAME + ' mapProductPrices ' + mapProductPrices );
        return mapProductPrices;
    }

    // https://developer.salesforce.com/docs/commerce/salesforce-commerce/guide/extension-provider-examples.html

    public override commercestorepricing.TransactionalPricingResponse processTransactionalPrice(
        commercestorepricing.TransactionalPricingRequest request2) {
        String METHOD_NAME = 'processTransactionalPrice';
        // get account ID from the request parameter
        System.debug(CLASS_NAME + ' - ' + METHOD_NAME + ' request2 ' + request2 );
        String accountId = request2.getEffectiveAccountId();
        
        System.debug(CLASS_NAME + ' - ' + METHOD_NAME + ' accountId ' + accountId );
        // get all products from request parameter
        Set<String> productIds = new Set<String>();
        Map<String, CommerceStorePricing.TransactionalPricingRequestItem> productIdToItem = new Map<String, CommerceStorePricing.TransactionalPricingRequestItem>();
        
        commercestorepricing.TxnPricingRequestItemCollection items = request2.getTxnPricingRequestItems();
        
        // logic to map all product ids to a list called products
        for (Integer i = 0; i < items.size(); i++) {
            commercestorepricing.TransactionalPricingRequestItem item = items.get(i);
            String productId = item.getProductId();
            System.debug(CLASS_NAME + ' - ' + METHOD_NAME + ' productId ' + productId );
            productIds.add(productId);
            productIdToItem.put(productId, item);
        }
        
        Set<String> customPriceBookId = getStandardPriceBookId(accountId);
       
        // store results in map 
        // Map<String, Decimal> mapOriginalProductId = getMapProductPrices(customPriceBookId, productIds);
        Map<String, DefinedPriceResult> mapOriginalProductId = getMapProductPrices(accountId, customPriceBookId, productIds);
        System.debug(CLASS_NAME + ' - ' + METHOD_NAME + ' mapOriginalProductId ' + mapOriginalProductId );

        // For a reason that I'm not sure, at the cart record, when you get on TransactionalPricingResponseItem.getProductId()  method
        // is returning with just 15 characters, making impossible map by 18 characters
        // So I'm changing here just due to that
        // Map<String, Decimal> mapProductPrices = new Map<String, Decimal>();
        Map<String, DefinedPriceResult> productIdToPriceData = new Map<String, DefinedPriceResult>();
        for (string originalId : mapOriginalProductId.keySet()){
            Id id18 = (id) originalId;
            String shortProdId = String.valueOf(id18.to15());
            System.debug(CLASS_NAME + ' - ' + METHOD_NAME + ' shortProdId ' + shortProdId );
            DefinedPriceResult updatResult = mapOriginalProductId.get(originalId);
            System.debug(CLASS_NAME + ' - ' + METHOD_NAME + ' updatResult before ' + updatResult );
            updatResult.productId = shortProdId;
            System.debug(CLASS_NAME + ' - ' + METHOD_NAME + ' updatResult after ' + updatResult );
            productIdToPriceData.put(shortProdId, updatResult);
            
        }
        System.debug(CLASS_NAME + ' - ' + METHOD_NAME + ' productIdToPriceData ' + productIdToPriceData );
        
        return buildTransactionalPricingResponse(productIdToItem, productIdToPriceData);

    }

	private static CommerceStorePricing.TransactionalPricingResponse buildTransactionalPricingResponse(Map<String, CommerceStorePricing.TransactionalPricingRequestItem> productIdToItem, Map<String, DefinedPriceResult> productIdToPriceData) {
        String METHOD_NAME = 'buildTransactionalPricingResponse';
        System.debug(CLASS_NAME + ' - ' + METHOD_NAME + ' productIdToItem ' + productIdToItem );
        System.debug(CLASS_NAME + ' - ' + METHOD_NAME + ' productIdToPriceData ' + productIdToPriceData );
		List<CommerceStorePricing.TransactionalPricingRequestItem> items = productIdToItem.values();
		CommerceStorePricing.TransactionalPricingResponse response = new CommerceStorePricing.TransactionalPricingResponse(null,null,null,null,'CLP');
		Decimal totalList = 0;
		Decimal totalUnit = 0;
		for (Integer i = 0; i < items.size(); i++) {
			String productId = items.get(i).getProductId();
            System.debug(CLASS_NAME + ' - ' + METHOD_NAME + ' productId ' + productId );
            Id id18 = (id) productId;
            String shortProdId = String.valueOf(id18.to15());
            String prodToCheckPrice = productId;
            System.debug(CLASS_NAME + ' - ' + METHOD_NAME + ' shortProdId ' + shortProdId );

            if (! productIdToPriceData.containsKey(prodToCheckPrice) && productIdToPriceData.containsKey(shortProdId)) prodToCheckPrice = shortProdId;
            System.debug(CLASS_NAME + ' - ' + METHOD_NAME + ' prodToCheckPrice ' + prodToCheckPrice );

            if (productIdToPriceData.containsKey(prodToCheckPrice)){
                DefinedPriceResult objDefinedPrice = productIdToPriceData.get(prodToCheckPrice);
                CommerceStorePricing.TransactionalPricingResponseItem responseItem;
    
                Decimal listPrice = objDefinedPrice.listPrice;
                // System.debug(CLASS_NAME + ' - ' + METHOD_NAME + ' listPrice ' + listPrice );
                Decimal unitPrice = objDefinedPrice.negotiatedPrice;
                // System.debug(CLASS_NAME + ' - ' + METHOD_NAME + ' unitPrice ' + unitPrice );
                Decimal quantity = productIdToItem.get(productId).getQuantity();
                // System.debug(CLASS_NAME + ' - ' + METHOD_NAME + ' quantity ' + quantity );
                totalUnit = totalUnit + unitPrice * quantity;
                // System.debug(CLASS_NAME + ' - ' + METHOD_NAME + ' totalUnit ' + totalUnit );
                totalList = totalList + listPrice * quantity;
                // System.debug(CLASS_NAME + ' - ' + METHOD_NAME + ' totalList ' + totalList );
                responseItem = new CommerceStorePricing.TransactionalPricingResponseItem(
                        productIdToItem.get(productId).getLineId(),
                        productId,
                        null,
                        listPrice,
                        unitPrice,
                        listPrice*quantity,
                        unitPrice*quantity,
                        0,
                        0,
                        unitPrice*quantity,
                        quantity,
                        'USD'
                );
                response.addTxnPricingResponseItem(responseItem);
            } else {
                // System.debug(CLASS_NAME + ' - ' + METHOD_NAME + ' productIdToPriceData.containsKey(productId) ' + productIdToPriceData.containsKey(productId) );
            }

		}
		response.setTotalAmount(totalUnit);
		response.setTotalListPrice(totalList);
		response.setTotalProductAmount(totalUnit);
        // System.debug(CLASS_NAME + ' - ' + METHOD_NAME + ' response ' + response );
		return response;
	}    

    public class DefinedPriceResult {
        String productId = '';
        Decimal listPrice = 0;
        Decimal negotiatedPrice = 0;

        public DefinedPriceResult(String productId, Decimal listPrice, Decimal negotiatedPrice){
            this.productId = productId;
            this.listPrice = listPrice;
            this.negotiatedPrice = negotiatedPrice;
    
        }
    }
}