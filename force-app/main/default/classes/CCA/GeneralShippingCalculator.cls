/**
 * This code extends the CartExtension.ShippingCartCalculator base class in order to calculate shipping charges in
 * conjunction with the cart orchestrator. This class is current with the Spring '24 release and a part of the
 * Salesforce Partner Learning Camp course "B2B Commerce: Developer Essentials" and specific to these activities:
 *      1. Implement a Shipping Provider
 *      2. Configure a Cart Orchestrator
 *
 *      Main documentation source: https://developer.salesforce.com/docs/commerce/salesforce-commerce/guide/ShippingCartCalculator.html
 * 
 *-------------------------------------------------------------------------------------------------------------------------------------------
 * 
**/
public class GeneralShippingCalculator extends CartExtension.ShippingCartCalculator{
    private static final String CLASS_NAME = 'GeneralShippingCalculator';

    private static ShippingCharge__mdt shippingChargeDefault = getShippingCharge('DefaultValue');
    private static ShippingCharge__mdt shippingChargeShipping1 = getShippingCharge('Shipping1');
    private static ShippingCharge__mdt shippingChargeShipping2 = getShippingCharge('Shipping2');
    private static ShippingCharge__mdt shippingChargeAdditionalOption = getShippingCharge('FreeShipping');
    private static ShippingCharge__mdt shippingChargeAmountToFreeShipping = getShippingCharge('AmountToFreeShipping');

    private static String shippingMethodToShow = shippingChargeDefault.LabelToShow__c;

    /**
     * The  moniker for the shipping Shipping Product Placeholder represented in ProductCode. In a real implementation you'd typically have
     * one product, but multiple order delivery groups that are different. Then the price is whatever is calculated in checkout (price from
     * the product isn't a factor).
     */
    public static final String SHIPPING_PRODUCT = ! Test.isRunningTest() ? 'DefaultShipping01'  : 'DefaultShipping01Test';

    /**
     * The product for shipping represented in ProductCode.
     */
    public static final String SHIPPING_PRODUCT_CODE = SHIPPING_PRODUCT;

    /**
     * The product for shipping represented in the SKU.
     */
    public static final String SHIPPING_PRODUCT_STOCK_KEEPING_UNIT = ! Test.isRunningTest() ? 'S01'  : 'DefaultShipping01Test';

    /**
     * The product for shipping represented in the Name.
     */
    public static final String SHIPPING_PRODUCT_NAME = SHIPPING_PRODUCT;

    // TODO: Refactor this to use the BaseRestUtility or one of its children - the naming also isn't fantastic here
    private static final Integer SUCCESSFUL_HTTP_REQUEST = 200;

    public virtual override void calculate(CartExtension.CartCalculateCalculatorRequest request) {
        String METHOD_NAME = 'calculate';

        try
        {
            System.debug('## INVOCATION: GeneralShippingCalculator.calculate called.');

            CartExtension.Cart cart = request.getCart();
            System.debug(CLASS_NAME + ' ' + METHOD_NAME + ' cart ' + cart);
            String accountId = cart.getAccountId();
            System.debug(CLASS_NAME + ' ' + METHOD_NAME + ' accountId ' + accountId);

            Map<String,String> accountCodeGroup = getAccountCodeGroupById(accountId);
            System.debug(CLASS_NAME + ' ' + METHOD_NAME + ' accountCodeGroup ' + accountCodeGroup);
            
            /***
             * Clean up CartValidationOutputList based on SHIPPING. When new shipping calculator request comes, we need to clean up
             * previous CVOs as they have been previously handled by the Cart Calculate API.
             */
            CartExtension.CartValidationOutputList cartValidationOutputCollection = cart.getCartValidationOutputs();
            System.debug(CLASS_NAME + ' ' + METHOD_NAME + ' cartValidationOutputCollection ' + cartValidationOutputCollection);

            Iterator<CartExtension.CartValidationOutput> cartValidationOutputCollectionIterator = cartValidationOutputCollection.iterator();

            System.debug(CLASS_NAME + ' ' + METHOD_NAME + ' cartValidationOutputCollectionIterator ' + cartValidationOutputCollectionIterator);
            while (cartValidationOutputCollectionIterator.hasNext())
            {
                CartExtension.CartValidationOutput cvo = cartValidationOutputCollectionIterator.next();

                if (cvo.getType() == CartExtension.CartValidationOutputTypeEnum.SHIPPING) {
                    cartValidationOutputCollection.remove(cvo);
                }
            }

            // To create the Cart delivery group methods, we need to get the ID of the cart delivery group.
            CartExtension.CartDeliveryGroupList cartDeliveryGroups = cart.getCartDeliveryGroups();
            System.debug(CLASS_NAME + ' ' + METHOD_NAME + ' cartDeliveryGroups ' + cartDeliveryGroups);
            if (cartDeliveryGroups.size() == 0)
            {
                CartExtension.CartValidationOutput cvo = new CartExtension.CartValidationOutput(CartExtension.CartValidationOutputTypeEnum.SHIPPING,
                    CartExtension.CartValidationOutputLevelEnum.ERROR);
                cvo.setMessage('No Cart Delivery Groups have been defined');
                cartValidationOutputCollection.add(cvo);
            }
            else
            {
                CartExtension.CartItemList cartItems = cart.getCartItems();
                System.debug(CLASS_NAME + ' ' + METHOD_NAME + ' cartItems ' + cartItems);

                Integer numberOfUniqueItems = cartItems.size();

                System.debug(CLASS_NAME + ' ' + METHOD_NAME + ' numberOfUniqueItems ' + numberOfUniqueItems);

                // Get the Shipping Product
                List<Product2> shippingProducts = [
                    SELECT
                        Id, Name, StockKeepingUnit, ProductCode
                    FROM
                        Product2
                    WHERE
                        ProductClass != 'VariationParent'
                        AND Name = :SHIPPING_PRODUCT_NAME
                        AND StockKeepingUnit = :SHIPPING_PRODUCT_STOCK_KEEPING_UNIT
                        AND ProductCode = :SHIPPING_PRODUCT_CODE LIMIT 1
                ];

                System.debug(CLASS_NAME + ' ' + METHOD_NAME + ' shippingProducts ' + shippingProducts);

                CartExtension.CartDeliveryGroup cartDeliveryGroup = cartDeliveryGroups.get(0);
                System.debug(CLASS_NAME + ' ' + METHOD_NAME + ' cartDeliveryGroup ' + cartDeliveryGroup);
                CartExtension.CartDeliveryGroupMethodList cartDeliveryGroupMethods = cartDeliveryGroup.getCartDeliveryGroupMethods();
                System.debug(CLASS_NAME + ' ' + METHOD_NAME + ' cartDeliveryGroupMethods ' + cartDeliveryGroupMethods);
                // Clean up the CartDeliveryGroupMethods
                for (Integer j = (cartDeliveryGroupMethods.size() - 1); j >= 0; j--)
                {
                    CartExtension.CartDeliveryGroupMethod method = cartDeliveryGroupMethods.get(j);
                    cartDeliveryGroupMethods.remove(method);
                }

                cartDeliveryGroup.setSelectedCartDeliveryGroupMethod(null);

                for (Integer i = (cartDeliveryGroups.size() - 1); i >= 0; i--){

                    // To clear selected Cart Delivery Group Method
                    // if(shippingChargeAdditionalOption == null) cartDeliveryGroup.setSelectedCartDeliveryGroupMethod(null);

                    // // Get the Shipping Product
                    // List<Product2> shippingProducts = [
                    //     SELECT
                    //         Id, Name, StockKeepingUnit, ProductCode
                    //     FROM
                    //         Product2
                    //     WHERE
                    //         ProductClass != 'VariationParent'
                    //         AND Name = :SHIPPING_PRODUCT_NAME
                    //         AND StockKeepingUnit = :SHIPPING_PRODUCT_STOCK_KEEPING_UNIT
                    //         AND ProductCode = :SHIPPING_PRODUCT_CODE LIMIT 1
                    // ];

                    System.debug(CLASS_NAME + ' ' + METHOD_NAME + ' shippingProducts ' + shippingProducts);

                    if(shippingProducts.size() == 0)
                    {
                        CartExtension.CartValidationOutput cvo = new CartExtension.CartValidationOutput(CartExtension.CartValidationOutputTypeEnum.SHIPPING,
                                CartExtension.CartValidationOutputLevelEnum.ERROR );
                        cvo.setMessage('No Shipping Products have been defined');
                        cartValidationOutputCollection.add(cvo);
                    }
                    else
                    {
                        String shippingProduct = Id.valueOf(shippingProducts[0].Id);
                        // TODO: Put this into a method like getShippingOptionsAndRatesFromOrg
                        System.debug('## INVOCATION: GeneralShippingCalculator.calculate using org-based values.');
                        // 1. Defatul Shipping = 2.8% fee

                        Decimal totalProductAmout = cart.getTotalProductAmount() ;
                        System.debug(CLASS_NAME + ' ' + METHOD_NAME + ' totalProductAmout ' + totalProductAmout);


                        // checks the logic to apply the calculation value
                        Decimal shippingChargeValue = setShippingChargeValue(accountCodeGroup, totalProductAmout);
                        System.debug(CLASS_NAME + ' ' + METHOD_NAME + ' shippingChargeValue ' + shippingChargeValue);

                        Decimal shippingValue = totalProductAmout * shippingChargeValue;
                        System.debug(CLASS_NAME + ' ' + METHOD_NAME + ' shippingValue ' + shippingValue);
                        System.debug(CLASS_NAME + ' ' + METHOD_NAME + ' totalProductAmout ' + totalProductAmout);

                        if(freeShippingAmountReached(totalProductAmout)) {
                            shippingValue = 0;
                            shippingMethodToShow = shippingChargeAmountToFreeShipping.LabelToShow__c;
                        }

                        CartExtension.CartDeliveryGroupMethod cartDeliveryGroupMethod01 = new CartExtension.CartDeliveryGroupMethod(shippingMethodToShow, shippingValue , shippingProduct);
                        cartDeliveryGroupMethod01.setExternalProvider(shippingMethodToShow);
                        cartDeliveryGroupMethod01.setCarrier('DefaultShipping');
                        cartDeliveryGroupMethod01.setClassOfService('Default Shipping');
                        cartDeliveryGroupMethod01.setIsActive(true);
                        cartDeliveryGroupMethods.add(cartDeliveryGroupMethod01);
                        System.debug(CLASS_NAME + ' ' + METHOD_NAME + ' cartDeliveryGroupMethod01 fine');

                        if(shippingChargeAdditionalOption != null) {
                            CartExtension.CartDeliveryGroupMethod cartDeliveryGroupMethodAdditionalOption = new CartExtension.CartDeliveryGroupMethod(shippingChargeAdditionalOption.LabelToShow__c, shippingChargeAdditionalOption.ShippingChargeValue__c , shippingProduct);
                            cartDeliveryGroupMethod01.setExternalProvider(shippingChargeAdditionalOption.LabelToShow__c);
                            cartDeliveryGroupMethodAdditionalOption.setCarrier('AdditionalOption');
                            cartDeliveryGroupMethodAdditionalOption.setClassOfService('Additional Option');
                            cartDeliveryGroupMethodAdditionalOption.setIsActive(true);
                            cartDeliveryGroupMethods.add(cartDeliveryGroupMethodAdditionalOption);
                        }
                       
                        // // 1. Ground delivery = 10.99 fee
                        // CartExtension.CartDeliveryGroupMethod cartDeliveryGroupMethod01 = new CartExtension.CartDeliveryGroupMethod('Ground Shipping', 10.99, shippingProduct);
                        // cartDeliveryGroupMethod01.setCarrier('USPS');
                        // cartDeliveryGroupMethod01.setClassOfService('Ground Shipping');

                        // // 2. Nest Day Air delivery = 15.99 fee
                        // CartExtension.CartDeliveryGroupMethod cartDeliveryGroupMethod02 = new CartExtension.CartDeliveryGroupMethod('Next Day Air', 15.99, shippingProduct);
                        // cartDeliveryGroupMethod02.setCarrier('UPS');
                        // cartDeliveryGroupMethod02.setClassOfService('Next Day Air');
                        // cartDeliveryGroupMethods.add(cartDeliveryGroupMethod01);
                        // cartDeliveryGroupMethods.add(cartDeliveryGroupMethod02);
                    }
                }
                cartDeliveryGroup.setSelectedCartDeliveryGroupMethod(null);
            }

            System.debug('## SUCCESS: GeneralShippingCalculator.calculate');
        }
        catch (Exception e)
        {
            /***
             * For testing purposes, this example treats exceptions as user errors, which means they are
             * displayed to the buyer user. In production, you probably want exceptions to be admin-type
             * errors. In that case, throw the exception here and make sure that a notification system is
             * in place to let the admin know that the error occurred.
             */
            System.debug('## EXCEPTION THROWN: GeneralShippingCalculator.calculate: ' + e.getMessage());
        }
    }

    private static ShippingCharge__mdt getShippingCharge(String developerName){

        try {
            List<ShippingCharge__mdt> objConf = [
                SELECT 
                    Id, DeveloperName, MasterLabel, ShippingChargeValue__c, LabelToShow__c, AdditionalTitle__c, AdditionalDescription__c, ShippingType__c
                FROM ShippingCharge__mdt
                WHERE isActive__c = true
                AND   DeveloperName =: developerName
                LIMIT 1
            ];

            if (Test.isRunningTest()){
                // if ('Enviar a domicilio')

                objConf.add(
                    new ShippingCharge__mdt(
                        DeveloperName = developerName,
                        LabelToShow__c = developerName,
                        AdditionalTitle__c = developerName,
                        AdditionalDescription__c = developerName,
                        ShippingChargeValue__c = 0.04
                    )
                );
            }
    
            return objConf.size() > 0 ? objConf[0] : null;
        } catch (Exception e) {System.debug('There is no configuration for ' + developerName + '!' + e.getMessage()); return null; }

    }

    private static Map<String,String> getAccountCodeGroupById(String accountId){
        String METHOD_NAME = 'getAccountCodeGroupById';
        Map<String,String> accountCodeGroup = new Map<String,String>();
        System.debug(CLASS_NAME + ' ' + METHOD_NAME + ' accountId ' + accountId);


        for(Account rowAccount :  [
            SELECT Id, Name 
            FROM Account
            WHERE Id =: accountId
        ]){

        }

        System.debug(CLASS_NAME + ' ' + METHOD_NAME + ' accountCodeGroup ' + accountCodeGroup);

        return accountCodeGroup;
    }

    private static Decimal setShippingChargeValue(Map<String,String> accountCodeGroup, Decimal totalAmount){
        // Default case, if no conditions are met
        Decimal shippingValue = shippingChargeDefault.ShippingChargeValue__c;
        shippingMethodToShow = shippingChargeDefault.LabelToShow__c;

        // Extract values from the Map
        // idGrupo = GroupNum
        String idGrupo = accountCodeGroup.containsKey('idGrupo') ? accountCodeGroup.get('idGrupo') : '';
        // codigoPoblacion = CodPob
        String codigoPoblacion = accountCodeGroup.containsKey('codigoPoblacion') ? accountCodeGroup.get('codigoPoblacion') : '';

        // Check the conditions
        if (idGrupo == '123') {
            shippingValue = shippingChargeShipping2.ShippingChargeValue__c;
            shippingMethodToShow = shippingChargeShipping2.LabelToShow__c;
        } 
        else if (codigoPoblacion.startsWith('15') && !codigoPoblacion.contains('15106') && totalAmount <= 5000 && idGrupo != '123') {
            shippingValue = shippingChargeShipping1.ShippingChargeValue__c;
            shippingMethodToShow = shippingChargeShipping1.LabelToShow__c;
        }
        else if (codigoPoblacion.startsWith('09') && totalAmount <= 5000 && idGrupo != '123') {
            shippingValue = shippingChargeShipping1.ShippingChargeValue__c;
            shippingMethodToShow = shippingChargeShipping1.LabelToShow__c;
        }
        else if (codigoPoblacion.startsWith('19') && totalAmount <= 5000 && idGrupo != '123') {
            shippingValue = shippingChargeShipping1.ShippingChargeValue__c;
            shippingMethodToShow = shippingChargeShipping1.LabelToShow__c;
        }
        else if (codigoPoblacion.startsWith('05') && totalAmount <= 5000 && idGrupo != '123') {
            shippingValue = shippingChargeShipping1.ShippingChargeValue__c;
            shippingMethodToShow = shippingChargeShipping1.LabelToShow__c;
        }
        else if (totalAmount <= 10000 && idGrupo != '123') {
            shippingValue = shippingChargeShipping1.ShippingChargeValue__c;
            shippingMethodToShow = shippingChargeShipping1.LabelToShow__c;
        }
                
        return shippingValue;
    }

    private static Boolean freeShippingAmountReached(Decimal totalProductAmount) {
        String METHOD_NAME = 'freeShippingAmountReached';
        Boolean freeShippingAmountReached = false;

        System.debug(CLASS_NAME + ' ' + METHOD_NAME + ' totalProductAmount ' + totalProductAmount);
        System.debug(CLASS_NAME + ' ' + METHOD_NAME + ' shippingChargeAmountToFreeShipping ' + shippingChargeAmountToFreeShipping);
        if(totalProductAmount >= shippingChargeAmountToFreeShipping.ShippingChargeValue__c) {
            freeShippingAmountReached = true;
        }

        return freeShippingAmountReached;
    }
 }