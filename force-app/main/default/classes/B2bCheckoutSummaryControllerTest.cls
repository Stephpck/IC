@IsTest public with sharing class B2bCheckoutSummaryControllerTest {

    @IsTest
    public static void getCartSummary() {
        B2BTestUtils testUtils = new B2BTestUtils();
        Account acct = testUtils.getAccount('Store Account');
        insert acct;
        WebStore store = testUtils.getStore('Test Store');
        insert store;
        List<Product2> productList = testUtils.getProducts(3);
        insert productList;
    
        WebCart cart = new WebCart(
            Name = 'Cart',
            WebStoreId = store.Id,
            AccountId = acct.Id
        );
        insert cart;
    
        CartDeliveryGroup cartDeliveryGroup = new CartDeliveryGroup(
            CartId = cart.Id,
            Name = 'Default Delivery 1'
        );
        insert cartDeliveryGroup;
    
        List<CartItem> cartItemList = new List<CartItem>();
        // Products 
        Integer i = 1;
        for (Product2 prod : productList) {
            CartItem cartItem = new CartItem(
                CartId = cart.Id,
                Product2Id = prod.Id,
                Quantity = 100,
                Type = 'Product',
                Name = 'TestProduct ' + i,
                SKU = 'TEST' + i,
                CartDeliveryGroupId = cartDeliveryGroup.Id
            );
            cartItemList.add(cartItem);
            i++;
        }
        // Shipping
        Product2 shippingChargeProduct = new Product2(
            isActive = true,
            Name = 'Shipping Charge for this delivery method'
        );
        insert(shippingChargeProduct);
        CartItem shippingItem = new CartItem(
            CartId = cart.Id,
            Product2Id = shippingChargeProduct.Id,
            Quantity = 1,
            Type = 'Charge',
            Name = 'ChargeProduct',
            SKU = 'CHARGE',
            CartDeliveryGroupId = cartDeliveryGroup.Id
        );
        cartItemList.add(shippingItem);
        insert cartItemList;
    
        List<CartItem> cartItemsBefore = [
            SELECT
                Id,
                UnitAdjustmentAmount,
                Quantity,
                SalesPrice,
                UnitAdjustedPrice,
                TotalLineAmount,
                TotalPrice
            FROM CartItem
            WHERE CartId = :cart.Id
        ];
        for (CartItem cartItem : cartItemsBefore) {
            cartItem.SalesPrice = 5000;
            cartItem.UnitAdjustedPrice = 4500;
            cartItem.TotalLineAmount = cartItem.UnitAdjustedPrice * cartItem.Quantity;
            cartItem.TotalPrice = cartItem.UnitAdjustedPrice * cartItem.Quantity;
        }
        update cartItemsBefore;
    
        Test.startTest();
        B2BCheckoutSummaryController.CartSummaryResult result = B2BCheckoutSummaryController.getCartSummary(cart.Id);
        Test.stopTest();

        WebCart resultCart = result.cart;
        System.assertEquals(1350000, resultCart.TotalProductAmount, 'total product amount should be 1350000');
        System.assertEquals(4500, resultCart.TotalChargeAmount, 'total charge amount should be 4500');
        System.assertEquals(0, resultCart.TotalTaxAmount, 'total tax amount should be 0');
        System.assertEquals(1354500, resultCart.GrandTotalAmount, 'grand total should be 1354500');

        List<CartItem> chargeLines = result.chargeLines;
        System.assertEquals(1, chargeLines.size(), 'should be 1 charge line');

        Boolean includesFreight = result.includesFreight;
        System.assertEquals(false, includesFreight, 'should not include freight');
        Boolean includesFedEx = result.includesFedEx;
        System.assertEquals(false, includesFedEx, 'should not include fedex');
    }

    private static Id createOrderSummary(Id orderId) {
        ConnectApi.OrderSummaryInputRepresentation orderSummInput = new ConnectApi.OrderSummaryInputRepresentation();
        orderSummInput.orderId = orderId;
        orderSummInput.orderLifeCycleType = 'UNMANAGED';
        orderSummInput.name = orderId;
        orderSummInput.status = 'Created';
        try {
            ConnectApi.OrderSummaryOutputRepresentation output = ConnectApi.OrderSummaryCreation.createOrderSummary(orderSummInput);
            System.debug(output.success);
            System.debug(output.errors);
            System.debug(output.orderSummaryId);
            return output.orderSummaryId;
        } catch (ConnectApi.ConnectApiException e) {
            System.debug(e.getMessage());
            System.debug(e.getErrorCode());
            System.debug(e.getStackTraceString());
            return null;
        }
    }
    
    private static Id buildOrder() {
        B2BTestUtils utils = new B2BTestUtils();
        Account acct = utils.getAccount('Test Account');
        insert acct;
    
        ContactPointAddress address = new ContactPointAddress();
        address.Name = 'nm';
        address.Street = '1234 Test Street';
        address.City = 'Test City';
        address.State = 'PA';
        address.PostalCode = '12345';
        address.Country = 'US';
        address.ParentId = acct.Id;
        address.AddressType = 'Shipping';
        insert address;
    
        List<Product2> prodList = utils.getProducts(1);
        Product2 prod = prodList[0];
        insert prod;
    
        OrderDeliveryMethod defaultOrderDeliveryMethod = new OrderDeliveryMethod(
          Name = 'FEDEX GROUND',
          Carrier = 'FEDEX GROUND',
          isActive = true,
          ProductId = prod.Id,
          ClassOfService = 'FEDEX GROUND'
        );
        insert defaultOrderDeliveryMethod;
    
        Order order = new Order(
            AccountId = acct.Id,
            PoNumber = '12345',
            BillingStreet = '1234 Test Street',
            BillingCity = 'Test City',
            BillingPostalCode = '12345',
            EffectiveDate = Date.today(),
            Status = 'Draft',
            OrderedDate = System.now()
        );
        insert order;
    
        OrderDeliveryGroup deliveryGroup = new OrderDeliveryGroup(
            OrderId = order.Id,
            OrderDeliveryMethodId = defaultOrderDeliveryMethod.Id,
            DeliverToName = 'Name',
            DeliverToStreet = '1234 Test Street',
            DeliverToCity = 'Test City',
            DeliverToPostalCode = '12345',
            DeliverToState = 'PA',
            DeliverToCountry = 'US'
        );
        insert deliveryGroup;
    
        OrderItem item = new OrderItem(
            OrderId = order.Id,
            Product2Id = prod.Id,
            Type = 'Order Product',
            ListPrice = 100.00,
            Quantity = 5,
            TotalLineAmount = 450.00,
            OrderDeliveryGroupId = deliveryGroup.Id
        );
        insert item;

        order.Status = 'Activated';
        update order;
        return order.Id;
    }
    
    @IsTest(SeeAllData=true)
    static void orderSummary() {
        Id orderId = buildOrder();
        Id orderSummaryId = createOrderSummary(orderId);
    
        Test.startTest();
        B2BCheckoutSummaryController.OrderSummaryResult result = B2BCheckoutSummaryController.getOrderSummary(orderSummaryId);
        Test.stopTest();

        OrderSummary resultSummary = result.orderSummary;
        System.assertEquals(450, resultSummary.TotalAdjustedProductAmount, 'total product amount should be 450');
        System.assertEquals(0, resultSummary.TotalAdjustedDeliveryAmount, 'total charge amount should be 0');
        System.assertEquals(0, resultSummary.TotalAdjustedProductTaxAmount, 'total tax amount should be 0');
        System.assertEquals(450, resultSummary.GrandTotalAmount, 'grand total should be 450');

        List<OrderItemSummary> chargeLines = result.chargeLines;
        System.assertEquals(0, chargeLines.size(), 'should be no charge line');

        Boolean includesFreight = result.includesFreight;
        System.assertEquals(false, includesFreight, 'should not include freight');
        Boolean includesFedEx = result.includesFedEx;
        System.assertEquals(false, includesFedEx, 'should not include fedex');
      }

}
