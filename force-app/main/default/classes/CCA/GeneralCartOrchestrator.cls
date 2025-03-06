/**
 * This the  orchestrator that calls the inventory, pricing, promotions, shipping and tax calculators. 
 * This class must extend CartExtension.CartCalculate and be linked to the orchestrator extension point
 * (Commerce_Domain_Cart_Calculate). Key functionality:
 *
 * 1. Calculates pricing and promotions for operations: Add product to cart, remove product from cart, edit cart item quantity.
 * 2. Calculates promotions for operations: add coupon to cart, remove coupon from cart.
 * 3. Calculates pricing, promotions, inventory for start checkout operation (without shipping address available).
 * 4. Calculates pricing, promotions, inventory, shipping, post shipping and taxes for start checkout operation (with shipping
 * address available).
 * 5. Calculates shipping, post shipping and taxes for update shipping address operation.
 * 6. Calculates taxes for select delivery method operation.
**/
global class GeneralCartOrchestrator extends CartExtension.CartCalculate {
    // private static final String CLASS_NAME = 'GeneralCartOrchestrator';
    /**
     * @description All classes extending CartExtension.CartCalculate must have a default constructor defined
     */
    global GeneralCartOrchestrator() {}

    /**
     * @description Constructor used by unit tests only. See <<GeneralCartOrchestratorUnitTest>>.
     * @param apexExecutor Executor which executes various calculators. Can be used to stub calculation results or delegate calculations to actual Calculator. See <<CartCalculateExecutorMock>>.
     */
    global GeneralCartOrchestrator(final CartExtension.CartCalculateExecutorMock apexExecutor) {
        // Must call super constructor in order for provided Executor to be used for calculations
        super(apexExecutor);
    }

    // Each orchestrator must override this calculate method.
    global virtual override void calculate(CartExtension.CartCalculateOrchestratorRequest request) {
        String METHOD_NAME = 'calculate';
        CartExtension.Cart cart = request.getCart();

        // System.debug(CLASS_NAME + ' ' + METHOD_NAME + ' cart ' + cart);

        // Use BuyerActions to decide which calculators to invoke
        CartExtension.BuyerActions buyerActions = request.getBuyerActions();
        boolean runPricing = buyerActions.isCheckoutStarted() || buyerActions.isCartItemChanged();
        boolean runPromotions = buyerActions.isCheckoutStarted() || buyerActions.isCouponChanged() || buyerActions.isCartItemChanged();
        boolean runInventory = buyerActions.isCheckoutStarted();
        boolean runShipping = buyerActions.isDeliveryGroupChanged();
        boolean runPostShipping = buyerActions.isDeliveryGroupChanged() || buyerActions.isDeliveryMethodSelected();
        boolean runTaxes = buyerActions.isCheckoutStarted() || buyerActions.isDeliveryGroupChanged() || buyerActions.isDeliveryMethodSelected();

        // OptionalBuyerActionDetails can be used to optimize the various calculators that are invoked
        CartExtension.CartCalculateCalculatorRequest calculatorRequest = new CartExtension.CartCalculateCalculatorRequest(cart, request.getOptionalBuyerActionDetails());
        CartExtension.CartValidationOutputList cartValidOutList = cart.getCartValidationOutputs();

        // System.debug(CLASS_NAME + ' ' + METHOD_NAME + ' runPricing ' + runPricing);
        if (runPricing) {
            prices(calculatorRequest);

            if (hasErrorLevelCartValidationOutput(cartValidOutList, CartExtension.CartValidationOutputTypeEnum.PRICING)) return;//{
            //     System.debug(CLASS_NAME + ' ' + METHOD_NAME + ' runPricing error ');
            //     System.debug(CLASS_NAME + ' ' + METHOD_NAME + ' cartValidOutList ' + cartValidOutList);
            //     return;
            // }
        }

        if (runPromotions) {
            /* promotions(calculatorRequest);

            if (hasErrorLevelCartValidationOutput(cartValidOutList, CartExtension.CartValidationOutputTypeEnum.PROMOTIONS)) {
                return;
            } */
        }

        if (runInventory) {
            /* inventory(calculatorRequest);

            if (hasErrorLevelCartValidationOutput(cartValidOutList, CartExtension.CartValidationOutputTypeEnum.INVENTORY)) {
                return;
            } */
        }

        // System.debug(CLASS_NAME + ' ' + METHOD_NAME + ' runShipping ' + runShipping);
        if (runShipping) {
            shipping(calculatorRequest);

            if (hasErrorLevelCartValidationOutput(cartValidOutList, CartExtension.CartValidationOutputTypeEnum.SHIPPING)) return;//{
            //     System.debug(CLASS_NAME + ' ' + METHOD_NAME + ' runShipping error ');
            //     return;
            // }
        }

        // System.debug(CLASS_NAME + ' ' + METHOD_NAME + ' runPostShipping ' + runPostShipping);
        if (runPostShipping) {
            postShipping(calculatorRequest);

            if (hasErrorLevelCartValidationOutput(cartValidOutList, CartExtension.CartValidationOutputTypeEnum.SYSTEM_ERROR)) return;//{
            //     System.debug(CLASS_NAME + ' ' + METHOD_NAME + ' runPostShipping error ');
            //     return;
            // }
        }

        // System.debug(CLASS_NAME + ' ' + METHOD_NAME + ' runTaxes ' + runTaxes);
        if (runTaxes) {
            taxes(calculatorRequest);
            if (hasErrorLevelCartValidationOutput(cartValidOutList, CartExtension.CartValidationOutputTypeEnum.TAXES)) return; //{
            //     System.debug(CLASS_NAME + ' ' + METHOD_NAME + ' runTaxes error ');
            //     return;
            // }
        }
    }

    // This function evaluates whether there are errors in the CVO of a specific calculator type.
    private Boolean hasErrorLevelCartValidationOutput(CartExtension.CartValidationOutputList cartValidationOutputs,
                                                      CartExtension.CartValidationOutputTypeEnum cartValidationOutputType) {
        Iterator<CartExtension.CartValidationOutput> iterator = cartValidationOutputs.iterator();

        while (iterator.hasNext()) {
            CartExtension.CartValidationOutput cvo = iterator.next();

            Boolean cvoContainsCalculatorError = cvo.getType() == cartValidationOutputType && cvo.getLevel() == CartExtension.CartValidationOutputLevelEnum.ERROR;

            if (cvoContainsCalculatorError) return true;
        }

        return false;
    }
}