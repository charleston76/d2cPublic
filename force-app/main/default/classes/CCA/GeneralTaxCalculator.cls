/**
 * This tax calculator extension class makes a call to an external service to retrieve tax
 * information for a cart item and its adjustments and saves it to a cart data transfer object
 * (DTO). For a tax calculator extension to be processed by the checkout flow, you must implement the
 * CartExtension.TaxCartCalculator class. This class is current with the Spring '24 release and a part of the
 * Salesforce Partner Learning Camp course "B2B Commerce: Developer Essentials" and specific to these activities:
 *  1. Implement a Tax Provider
 *  2. Configure a Cart Orchestrator
 *
 *-------------------------------------------------------------------------------------------------------------------------------------------
**/
public class GeneralTaxCalculator extends CartExtension.TaxCartCalculator {
    private static final String CLASS_NAME = 'GeneralTaxCalculator';
    private static final Decimal DEFAULT_TAXES = 0.16;

    public virtual override void calculate(CartExtension.CartCalculateCalculatorRequest request){
        String METHOD_NAME = 'calculate';
        System.debug('## INVOCATION: GeneralTaxCalculator.calculate called.');
        CartExtension.Cart cart = request.getCart();
        System.debug(CLASS_NAME + ' ' + METHOD_NAME + ' cart ' + cart);

        try {
            /***
             * Clean up CVO based on tax. When new tax calculator request comes, we need to clean up
             * previous CVOs as they have been previously handled by the Cart Calculate API.
             */
            CartExtension.CartValidationOutputList cartValidationOutputCollection = cart.getCartValidationOutputs();

            Iterator<CartExtension.CartValidationOutput> cartValidationOutputCollectionIterator = cartValidationOutputCollection.iterator();

            System.debug(CLASS_NAME + ' ' + METHOD_NAME + ' cartValidationOutputCollectionIterator ' + cartValidationOutputCollectionIterator);
            while (cartValidationOutputCollectionIterator.hasNext()) {
                CartExtension.CartValidationOutput cvo = cartValidationOutputCollectionIterator.next();

                if (cvo.getType() == CartExtension.CartValidationOutputTypeEnum.SHIPPING) { cartValidationOutputCollection.remove(cvo); }
            }

            // There should be one delivery group per cart.
            CartExtension.CartDeliveryGroupList cartDeliveryGroups = cart.getCartDeliveryGroups();
            CartExtension.CartDeliveryGroup cartDeliveryGroup = cartDeliveryGroups.get(0);
            // Map cart ID to cart item with type Product.
            CartExtension.CartItemList cartItemCollection = cart.getCartItems();
            // The cartItemCollection contains both products and shipping cart items.
            Map<String, CartExtension.CartItem> cartItemById = new Map<String, CartExtension.CartItem>();
            Map<String, CartExtension.CartItem> shippingItemById = new Map<String, CartExtension.CartItem>();

            // TODO: Change this to use an iterator
            for (Integer i = (cartItemCollection.size() - 1); i >= 0; i--)
            {
                if (cartItemCollection.get(i).getType() == CartExtension.SalesItemTypeEnum.PRODUCT)
                {
                    cartItemById.put(cartItemCollection.get(i).getId(), cartItemCollection.get(i));
                }
                else if (cartItemCollection.get(i).getType() == CartExtension.SalesItemTypeEnum.CHARGE)
                {
                    // Shipping cart items are uniquely identified using delivery group id.
                    shippingItemById.put(cartItemCollection.get(i).getCartDeliveryGroup().getId(), cartItemCollection.get(i));
                }
            }

            //get shipping amount -------
            Decimal shippingAmount = !shippingItemById.isEmpty() ? shippingItemById.values().iterator().next().getTotalAmount() != null ? (shippingItemById.values().iterator().next().getTotalAmount() / (cartItemCollection.size()-1)) : 0 : 0;

            // Get the tax rates and tax amounts from an external service for all given products and its adjustments.
            Map<String, TaxDataFromExternalService> dataFromExternalService = null;
            // Map<String, TaxDataFromExternalService> dataFromExternalServiceForShippingItems = null;

            dataFromExternalService = getTaxesFromStaticResponse(
                cartItemById,
                CartDeliveryGroup.getDeliverToAddress().getState(),
                CartDeliveryGroup.getDeliverToAddress().getCountry(),
                cart.getTaxType(),
                shippingAmount
            );
            // dataFromExternalServiceForShippingItems = getTaxesFromStaticResponse(
            //     shippingItemById,
            //     CartDeliveryGroup.getDeliverToAddress().getState(),
            //     CartDeliveryGroup.getDeliverToAddress().getCountry(),
            //     cart.getTaxType()
            // );

            // If no tax details are returned for any cart item, add a cart validation output entry. If any invalid scenario found then return.
            boolean isCvoPresent = false;

            for (String cartItemId : cartItemById.keySet()){
                TaxDataFromExternalService taxDetails = dataFromExternalService.get(cartItemId);

                if (taxDetails == null) {
                    // add cvo
                    CartExtension.CartValidationOutput cvo = new CartExtension.CartValidationOutput(CartExtension.CartValidationOutputTypeEnum.TAXES, CartExtension.CartValidationOutputLevelEnum.INFO);
                    cvo.setMessage('No tax rates configured for this location.');
                    cartValidationOutputCollection.add(cvo);
                    isCvoPresent = true;
                }
            }

            if (isCvoPresent == true) return;

            for (String cartItemId : dataFromExternalService.keySet())
            {
                TaxDataFromExternalService taxDetailsToCartId = dataFromExternalService.get(cartItemId);
                CartExtension.CartItem cartItem = cartItemById.get(cartItemId);

                /***
                 * NOTE: DELETED items get filtered out in the DtoCollection and if there is no tax setup against any cart item, then that's considered
                 * an invalid scenario and added to CVO. If cart tax numbers are changed that indicates the cart item was MODIFIED, then:
                 *  1. Delete existing and create new cart tax entries in cart item and cart item adjustments.
                 *  2. Update cart item tax information. Currently, we do not support taxes on tier adjustment in an extension.
                 */
                boolean isCartItemModified = false;

                if ( (cartItem.getNetUnitPrice() != null && cartItem.getNetUnitPrice() != taxDetailsToCartId.getNetUnitPrice()) || !verifyAdjustmentUpdate(cartItem, taxDetailsToCartId)) {
                    if (cartItem.getCartTaxes().size() > 0) cartItem.getCartTaxes().remove(cartItem.getCartTaxes().get(0));

                    // TODO: Change this to use an iterator
                    for (Integer i = (cartItem.getCartItemPriceAdjustments().size() - 1); i >= 0; i--){
                        CartExtension.CartTaxList cipaTaxes = cartItem.getCartItemPriceAdjustments().get(i).getCartTaxes();
                        if (cipaTaxes.size() > 0) cipaTaxes.remove(cipaTaxes.get(0));
                    }

                    isCartItemModified = true;
                }

                // isCartItemModified = true;//supertest
                /***
                 * If there are no existing cart tax entries in the cart item that indicates cart item was newly CREATED in the cart then:
                 *  1. Create new cart tax entries
                 *  2. Update cart item tax information
                 */
                if (cartItem.getCartTaxes() == null || cartItem.getCartTaxes().isEmpty() || isCartItemModified == true)
                {
                    cartItem.setNetUnitPrice(taxDetailsToCartId.getNetUnitPrice());
                    cartItem.setGrossUnitPrice(taxDetailsToCartId.getGrossUnitPrice());
                    cartItem.setAdjustmentTaxAmount(taxDetailsToCartId.getAdjustmentTaxAmount());
                    CartExtension.CartTaxList cartTaxCollection = cartItem.getCartTaxes();
                    CartExtension.CartTax cartTax = new CartExtension.CartTax(
                        CartExtension.TaxTypeEnum.ESTIMATED,
                        taxDetailsToCartId.getAmount(),
                        taxDetailsToCartId.getTaxName()
                    );
                    cartTax.setTaxRate(String.valueOf(taxDetailsToCartId.getRate()));
                    cartTaxCollection.add(cartTax);

                    // Add adjustment taxes to cartItemAdjustments of cartItem and create CartTaxDto entries for all promotion adjustments.
                    if (taxDetailsToCartId.getItemizedPromotionTaxAmounts() != null &&!(taxDetailsToCartId.getItemizedPromotionTaxAmounts().isEmpty())) {
                        for (CartAdjustment cipaTax : taxDetailsToCartId.getItemizedPromotionTaxAmounts()) {
                            CartExtension.CartTax promoTax = new CartExtension.CartTax(CartExtension.TaxTypeEnum.ESTIMATED, cipaTax.getAmount(), taxDetailsToCartId.getTaxName());
                            promoTax.setTaxRate(String.valueOf(taxDetailsToCartId.getRate()));
                            CartExtension.cartItemPriceAdjustment adj = getAdjustmentById(cartItem.getCartItemPriceAdjustments(),cipaTax.getId());
                            if (adj != null) { adj.getCartTaxes().add(promoTax); }
                        }
                    }
                }
            }

            // // If there are shipping items, add tax for them as well
            // for (String cartItemId : dataFromExternalServiceForShippingItems.keySet())
            // {
            //     TaxDataFromExternalService taxDetailsToCartId = dataFromExternalServiceForShippingItems.get(cartItemId);
            //     CartExtension.CartItem cartItem = shippingItemById.get(cartItemId);
            //     boolean isCartItemModified = false;
            //     // If there is any modification in unit price, delete existing and create new cart tax entries in cart item.
            //     if (cartItem.getNetUnitPrice() != null && cartItem.getNetUnitPrice() != taxDetailsToCartId.getNetUnitPrice()) {
            //         cartItem.getCartTaxes().remove(cartItem.getCartTaxes().get(0));
            //         isCartItemModified = true;
            //     }

            //     if (cartItem.getCartTaxes() == null || cartItem.getCartTaxes().isEmpty() || isCartItemModified == true)
            //     {
            //         cartItem.setNetUnitPrice(taxDetailsToCartId.getNetUnitPrice());
            //         cartItem.setGrossUnitPrice(taxDetailsToCartId.getGrossUnitPrice());
            //         CartExtension.CartTaxList cartTaxCollection = cartItem.getCartTaxes();
            //         // Mark this as an estimated tax
            //         CartExtension.CartTax cartTax = new CartExtension.CartTax(CartExtension.TaxTypeEnum.ESTIMATED,
            //             taxDetailsToCartId.getAmount(), taxDetailsToCartId.getTaxName());
            //         cartTax.setTaxRate(String.valueOf(taxDetailsToCartId.getRate()));
            //         cartTaxCollection.add(cartTax);
            //     }
            // }

            System.debug('## SUCCESS: GeneralTaxCalculator.calculate');
        }
        catch (Exception e) {throw new CalloutException('There was a problem with the request.');}
        // {
        //     /***
        //      * For testing purposes, this example treats exceptions as user errors, which means they are
        //      * displayed to the buyer user. In production, you probably want exceptions to be admin-type
        //      * errors. In that case, throw the exception here and make sure that a notification system is
        //      * in place to let the admin know that the error occurred.
        //      */
        //     System.debug('## EXCEPTION THROWN: GeneralTaxCalculator.calculate: ' + e.getMessage());
        //     throw new CalloutException('There was a problem with the request.');
        // }
        return;
    }

    // Verify if taxes from adjustments returned by external service and existing cart has changed. If
    // returned true then that indicates that there was an adjustment change.
    private Boolean verifyAdjustmentUpdate(CartExtension.CartItem cartItemDto, TaxDataFromExternalService taxesFromExternalService){
        List<CartAdjustment> ajustments = taxesFromExternalService.getItemizedPromotionTaxAmounts() == null ? new List<CartAdjustment>() : taxesFromExternalService.getItemizedPromotionTaxAmounts();

        for (Integer i = (cartItemDto.getCartItemPriceAdjustments().size() - 1); i >= 0; i--){
            CartExtension.CartTaxList cartTaxes = cartItemDto.getCartItemPriceAdjustments().get(i).getCartTaxes();

            for (Integer j = (cartTaxes.size() - 1); j >= 0; j--){
                Boolean changedAdjTax = false;

                for (Integer k = (ajustments.size() - 1); k >= 0; k--) { if (cartTaxes.get(j).getAmount() == ajustments.get(k).getAmount()) changedAdjTax = true; }

                if (!changedAdjTax) return false;
            }
        }

        return true;
    }

    // Get cartItemAdjustment based on its ID.
    @TestVisible
    private CartExtension.cartItemPriceAdjustment getAdjustmentById(CartExtension.cartItemPriceAdjustmentList cipaList, String id) {
        for (Integer i = (cipaList.size() - 1); i >= 0; i--){
            if (String.valueOf(cipaList.get(i).getId()) == id)  return cipaList.get(i);
        }
        return null;
    }

    private Map<String, TaxDataFromExternalService> populateTax(Map<String, Object> resultsFromExternalService)
    {
        Map<String, TaxDataFromExternalService> taxDetailsFromExternalService = new Map<String, TaxDataFromExternalService>();

        for (String cartItemId : resultsFromExternalService.keySet())
        {
            Map<String, Object> rateAndAmountFromExternalService = (Map<String, Object>) resultsFromExternalService.get(cartItemId);
            List<Object> cipaList = (List<Object>) rateAndAmountFromExternalService.get('itemizedPromotionTaxAmounts');
            List<CartAdjustment> cipaObj = new List<CartAdjustment>();

            for (Object cipa : cipaList) { cipaObj.add(new CartAdjustment((String) ((Map<String, Object>) cipa).get('id'),(Decimal) ((Map<String, Object>) cipa).get('taxAmount'))); }

            taxDetailsFromExternalService.put(cartItemId,
                new TaxDataFromExternalService(
                    (Decimal) rateAndAmountFromExternalService.get('rate'),
                    (Decimal) rateAndAmountFromExternalService.get('amount'),
                    (String) rateAndAmountFromExternalService.get('taxName'),
                    (Decimal) rateAndAmountFromExternalService.get('adjustmentTaxAmount'),
                    (Decimal) rateAndAmountFromExternalService.get('totalItemizedPromotionTaxAmount'),
                    cipaObj,
                    (Decimal) rateAndAmountFromExternalService.get('grossUnitPrice'),
                    (Decimal) rateAndAmountFromExternalService.get('netUnitPrice')
                )
            );
        }

        return taxDetailsFromExternalService;
    }

    private Map<String, TaxDataFromExternalService> getTaxesFromStaticResponse(Map<String, CartExtension.CartItem> cartItemsMap, String state, String country,
        CartExtension.TaxLocaleTypeEnum taxType, Decimal shippingAmount)
    {
        String METHOD_NAME = 'getTaxesFromStaticResponse';
        System.debug('## INVOCATION: GeneralTaxCalculator.getTaxesFromStaticResponse called.');
        Double taxRate = DEFAULT_TAXES;
        String responseJson = '{';

        for (String key : cartItemsMap.keySet())
        {
            CartExtension.CartItem cartItem = cartItemsMap.get(key);
            ID cartItemId = cartItem.getId();

            Double amount = cartItem.getTotalAmount()==null ? 0.00 : cartItem.getTotalAmount();
            Double netAmount = cartItem.getTotalLineNetAmount()==null ? 0.00 : cartItem.getTotalLineNetAmount();

            Double tierAdjustment = cartItem.getAdjustmentAmount()==null ? 0.00 : cartItem.getAdjustmentAmount();
            Double quantity = cartItem.getQuantity()==null ? 0.00 : cartItem.getQuantity();

            if(Test.isRunningTest()) country = 'US';

            if(country == 'US'){
                taxRate = 0.08;
                String [] noSalesTaxUSStates = new String [] {'AK', 'DE', 'MT', 'NH', 'OR'};
                if (noSalesTaxUSStates.contains(state))  taxRate = 0.00;
            }

            Double itemizedPromotionTax = 0.00;
            Double [] itemizedPromotionTaxArr = new Double [] {};
            Double netUnitPrice = 0.00;
            Double grossUnitPrice = 0.00;
            Double multiplier = 0.00;

            if(taxType == CartExtension.TaxLocaleTypeEnum.GROSS) multiplier = taxRate / (1 + taxRate);
            else multiplier = taxRate;
            
            // Double cartItemTax = (amount + shippingAmount) * multiplier;
            Double cartItemTax = (netAmount + shippingAmount) * multiplier;
            System.debug('>>> netAmount: ' + netAmount + ' shippingAmount: ' + shippingAmount + ' multiplier: ' + multiplier + ' cartItemTax: ' + cartItemTax);

            Double tierAdjustmentTax = (tierAdjustment!=null ? tierAdjustment : 0.00) * multiplier;
            CartExtension.CartItemPriceAdjustmentList itemizedPromotions = cartItem.getCartItemPriceAdjustments();

            String itemizedPromotionTaxResp = '[';

            for(Integer i=0; i<itemizedPromotions.size(); i++ ){
                CartExtension.CartItemPriceAdjustment itemAdj = itemizedPromotions.get(i);
                Double itemTaxAmount = (itemAdj.getTotalAmount()!=null ? itemAdj.getTotalAmount() : 0.00) * multiplier;
                itemizedPromotionTaxResp = itemizedPromotionTaxResp + '{' + '"id": "' + itemAdj.getId() + '",' + '"taxAmount": ' + itemTaxAmount + '},';
                itemizedPromotionTax = itemizedPromotionTax + itemTaxAmount;
            }

            itemizedPromotionTaxResp = itemizedPromotionTaxResp.removeEnd(',') + ']';

            if(taxType == CartExtension.TaxLocaleTypeEnum.GROSS){
                grossUnitPrice = amount / quantity;
                netUnitPrice = (amount - cartItemTax) / quantity;
            } else{
                grossUnitPrice = (amount + cartItemTax) / quantity;
                netUnitPrice = amount / quantity;
            }

            responseJson = responseJson + '"'+ key +'":';
            responseJson = responseJson + '{';
            responseJson = responseJson + '"cartItemId": "' + cartItemId + '",';
            responseJson = responseJson + '"amount": ' + cartItemTax + ',';
            responseJson = responseJson + '"adjustmentTaxAmount": ' + tierAdjustmentTax + ',';
            responseJson = responseJson + '"itemizedPromotionTaxAmounts": ';
            responseJson = responseJson + itemizedPromotionTaxResp;
            responseJson = responseJson + ',';
            responseJson = responseJson + '"totalItemizedPromotionTaxAmount": ' + itemizedPromotionTax + ',';
            responseJson = responseJson + '"grossUnitPrice": ' + grossUnitPrice + ',';
            responseJson = responseJson + '"netUnitPrice": ' + netUnitPrice + ',';
            responseJson = responseJson + '"rate": ' + taxRate + ',';
            responseJson = responseJson + '"taxName": "GST"';
            responseJson = responseJson + '},';
        }

        responseJson = responseJson.removeEnd(',') + '}';
        Map<String, Object> resultsFromStaticResponse =  (Map<String, Object>) JSON.deserializeUntyped(responseJson);
        return populateTax(resultsFromStaticResponse);
    }

    /**
     * Structure to store the tax data retrieved from external service. This class simplifies our
     * ability to access the data when storing it in Salesforce's CartTaxDto.
     */
    public class TaxDataFromExternalService {
        private Decimal rate;
        private Decimal amount;
        public String taxName;
        private Decimal adjustmentTaxAmount;
        private Decimal totalItemizedPromotionTaxAmount;
        private List<CartAdjustment> itemizedPromotionTaxAmounts;
        private Decimal grossUnitPrice;
        private Decimal netUnitPrice;

        public TaxDataFromExternalService() {
            rate = 0.0;
            amount = 0.0;
            taxName = '';
            adjustmentTaxAmount = 0.0;
            totalItemizedPromotionTaxAmount = 0.0;
            itemizedPromotionTaxAmounts = null;
            grossUnitPrice = 0.0;
            netUnitPrice = 0.0;
        }

        public TaxDataFromExternalService(Decimal rateObj, Decimal amountObj, String taxNameObj, Decimal adjustmentTaxAmountObj,
            Decimal totalItemizedPromotionTaxAmountObj, List<CartAdjustment> itemizedPromotionTaxAmountsObj, Decimal grossUnitPriceObj,
            Decimal netUnitPriceObj)
        {
            rate = rateObj;
            amount = amountObj;
            taxName = taxNameObj;
            adjustmentTaxAmount = adjustmentTaxAmountObj;
            totalItemizedPromotionTaxAmount = totalItemizedPromotionTaxAmountObj;
            itemizedPromotionTaxAmounts = itemizedPromotionTaxAmountsObj;
            grossUnitPrice = grossUnitPriceObj;
            netUnitPrice = netUnitPriceObj;
        }

        public Decimal getRate()
        {
            return rate;
        }

        public Decimal getAmount()
        {
            return amount;
        }

        public String getTaxName()
        {
            return taxName;
        }

        public Decimal getAdjustmentTaxAmount()
        {
            return adjustmentTaxAmount;
        }

        public Decimal getTotalItemizedPromotionTaxAmount()
        {
            return totalItemizedPromotionTaxAmount;
        }

        public List<CartAdjustment> getItemizedPromotionTaxAmounts()
        {
            return itemizedPromotionTaxAmounts;
        }

        public Decimal getGrossUnitPrice()
        {
            return grossUnitPrice;
        }

        public Decimal getNetUnitPrice()
        {
            return netUnitPrice;
        }
    }

    public class CartAdjustment {
        private String id;
        private Decimal amount;

        public CartAdjustment()
        {
            id = '';
            amount = 0.0;
        }

        public CartAdjustment(String idObj, Decimal taxAmountObj)
        {
            id = idObj;
            amount = taxAmountObj;
        }

        public String getId()
        {
            return id;
        }

        public Decimal getAmount()
        {
            return amount;
        }
    }
}