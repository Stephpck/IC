@IsTest public with sharing class B2BICShippingTest {
    @testSetup
    private static void setupData() {
        B2BTestUtils testUtils = new B2BTestUtils();
        Account testAccount = new Account(Name='TestAccount');
        insert testAccount;
        WebStore testWebStore = new WebStore(Name='TestWebStore', DefaultLanguage='en_US');
        insert testWebStore;
        
        Account account = [SELECT Id FROM Account WHERE Name='TestAccount' LIMIT 1];
        WebStore webStore = [SELECT Id FROM WebStore WHERE Name='TestWebStore' LIMIT 1];

        WebCart cart = new WebCart(Name='Cart', WebStoreId=webStore.Id, AccountId=account.Id);
        insert cart;
        
        CartDeliveryGroup cartDeliveryGroup = new CartDeliveryGroup(CartId=cart.Id, Name='Default Delivery 1');
        insert cartDeliveryGroup;

        List<Product2> prods = testUtils.getProducts(1);
        Product2 prod = prods.get(0);
        insert prod;

        CartItem cartItem = new CartItem(CartId=cart.Id, Product2Id = prod.Id, Type='Product', Name='TestProduct', CartDeliveryGroupId=cartDeliveryGroup.Id);
        insert cartItem;
    }

    public static List<CartItem> getCartItemsForCart(Id cartId) {
        return [SELECT Id, Quantity, Product2Id FROM CartItem WHERE CartId = :cartId];
    }

    public static List<CartDeliveryGroup> getCartDeliveryGroupForCart(Id cartId) {
        return [SELECT Id, DeliverToCountry, DeliverToState FROM CartDeliveryGroup WHERE CartId = :cartId];
    }

    private class ShipStationCarriersMock implements HttpCalloutMock {

        public HTTPResponse respond(HTTPRequest req) {
            String fullJson = '[{"name":"Stamps.com","code":"stamps_com","accountNumber":null,"requiresFundedAccount":true,"balance":0.0,"nickname":"Free","shippingProviderId":12345,"primary":true}]';

            HTTPResponse res = new HTTPResponse();
            res.setHeader('Content-Type', 'text/json');
            res.setBody(fullJson);
            res.setStatusCode(200);
            return res;
        }
    }

    private class ShipStationRatesMock implements HttpCalloutMock {

        public HTTPResponse respond(HTTPRequest req) {
            String fullJson = '[{"serviceName":"USPS First Class Mail - Letter","serviceCode":"usps_first_class_mail","shipmentCost":0.9100,"otherCost":0.0}]';

            HTTPResponse res = new HTTPResponse();
            res.setHeader('Content-Type', 'text/json');
            res.setBody(fullJson);
            res.setStatusCode(200);
            return res;
        }
    }

    private class ShipStationWarehouseMock implements HttpCalloutMock {

        public HTTPResponse respond(HTTPRequest req) {
            String fullJson = '[{"isDefault":true,"originAddress":{"postalCode":"30318"}}]';

            HTTPResponse res = new HTTPResponse();
            res.setHeader('Content-Type', 'text/json');
            res.setBody(fullJson);
            res.setStatusCode(200);
            return res;
        }
    }

    @isTest
    private static void getFreightShippingOptions() {
        B2BICShipping icShipping = new B2BICShipping();
        sfdc_checkout.IntegrationInfo integInfo = new sfdc_checkout.IntegrationInfo();		
        WebCart webCart = [SELECT Id, AccountId FROM WebCart WHERE Name='Cart' LIMIT 1];
        integInfo.jobId = null;

        sfdc_checkout.IntegrationStatus integrationResult = icShipping.startCartProcessAsync(integInfo, webCart.Id);
        System.assertEquals(sfdc_checkout.IntegrationStatus.Status.SUCCESS, integrationResult.status);

        List<CartDeliveryGroupMethod> cartDeliveryGroupMethods = [SELECT Id, ShippingFee, Name FROM CartDeliveryGroupMethod WHERE WebCartId = :webCart.Id ORDER BY Name];
        // If no products in the cart have a ShippingMethod of 'FedEx', the Freight flow is entered
        System.assertEquals(1, cartDeliveryGroupMethods.size(), 'not the correct amount of CartDeliveryGroupMethod');
        System.assertEquals('*Freight', cartDeliveryGroupMethods.get(0).Name, 'should have freight option');
        System.assertEquals(0, cartDeliveryGroupMethods.get(0).ShippingFee, 'should have 0 fee');
    }

    @isTest
    private static void getFedExShippingOptions() {
        B2BTestUtils testUtils = new B2BTestUtils();
        B2BICShipping.carriersMock = new ShipStationCarriersMock();
        B2BICShipping.ratesMock = new ShipStationRatesMock();
        B2BICShipping.warehouseMock = new ShipStationWarehouseMock();
        B2BICShipping icShipping = new B2BICShipping();

        sfdc_checkout.IntegrationInfo integInfo = new sfdc_checkout.IntegrationInfo();		
        WebCart webCart = [SELECT Id, AccountId FROM WebCart WHERE Name='Cart' LIMIT 1];
        CartDeliveryGroup cartDeliveryGroup = [SELECT Id FROM CartDeliveryGroup WHERE CartId = :webCart.Id LIMIT 1];

        List<Product2> fedExProds = testUtils.getProducts(1);
        Product2 fedExProd = fedExProds.get(0);
        fedExProd.Shipping_Method__c = 'FedEx';
        insert fedExProd;

        CartItem fedExCartItem = new CartItem(CartId=webCart.Id, Product2Id = fedExProd.Id, Type='Product', Name='TestProduct', CartDeliveryGroupId=cartDeliveryGroup.Id);
        insert fedExCartItem;	

        integInfo.jobId = null;

        sfdc_checkout.IntegrationStatus integrationResult = icShipping.startCartProcessAsync(integInfo, webCart.Id);

        System.assertEquals(sfdc_checkout.IntegrationStatus.Status.SUCCESS, integrationResult.status);

        List<CartDeliveryGroupMethod> cartDeliveryGroupMethods = [SELECT Id, ShippingFee, Name FROM CartDeliveryGroupMethod WHERE WebCartId = :webCart.Id ORDER BY Name];
        // If any products in the cart have a ShippingMethod of 'FedEx', the ShipStation flow is entered
        System.assert(cartDeliveryGroupMethods.size() > 0, 'not the correct amount of CartDeliveryGroupMethod');
        System.assert(cartDeliveryGroupMethods.get(0).ShippingFee > 0, 'should have a fee');
        System.assertEquals(1, cartDeliveryGroupMethods.size(), 'mock service has one method');
        System.assertEquals(0.9100, cartDeliveryGroupMethods.get(0).ShippingFee, 'mock service fee should be 0.9100');
    }

    @isTest
    private static void getCalloutFailure() {
        // If no HttpCalloutMock is set, test fails due to limitations around testing and web callouts
        B2BTestUtils testUtils = new B2BTestUtils();
        B2BICShipping icShipping = new B2BICShipping();

        sfdc_checkout.IntegrationInfo integInfo = new sfdc_checkout.IntegrationInfo();		
        WebCart webCart = [SELECT Id, AccountId FROM WebCart WHERE Name='Cart' LIMIT 1];
        CartDeliveryGroup cartDeliveryGroup = [SELECT Id FROM CartDeliveryGroup WHERE CartId = :webCart.Id LIMIT 1];

        List<Product2> fedExProds = testUtils.getProducts(1);
        Product2 fedExProd = fedExProds.get(0);
        fedExProd.Shipping_Method__c = 'FedEx';
        insert fedExProd;

        CartItem fedExCartItem = new CartItem(CartId=webCart.Id, Product2Id = fedExProd.Id, Type='Product', Name='TestProduct', CartDeliveryGroupId=cartDeliveryGroup.Id);
        insert fedExCartItem;	

        integInfo.jobId = null;

        sfdc_checkout.IntegrationStatus integrationResult = icShipping.startCartProcessAsync(integInfo, webCart.Id);
        System.assertEquals(sfdc_checkout.IntegrationStatus.Status.FAILED, integrationResult.status);

        List<CartDeliveryGroupMethod> cartDeliveryGroupMethods = [SELECT Id, ShippingFee, Name FROM CartDeliveryGroupMethod WHERE WebCartId = :webCart.Id ORDER BY Name];
        // If any products in the cart have a ShippingMethod of 'FedEx', the ShipStation flow is entered
        System.assert(cartDeliveryGroupMethods.size() == 0, 'not the correct amount of CartDeliveryGroupMethod');
    }
}


