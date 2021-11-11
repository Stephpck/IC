global without sharing class B2BICShipping implements sfdc_checkout.CartShippingCharges {
    @TestVisible
    private static HttpCalloutMock carriersMock = null;

    @TestVisible
    private static HttpCalloutMock ratesMock = null;

    @TestVisible
    private static HttpCalloutMock warehouseMock = null;

    global sfdc_checkout.IntegrationStatus startCartProcessAsync(sfdc_checkout.IntegrationInfo jobInfo, Id cartId) {
        sfdc_checkout.IntegrationStatus integStatus = new sfdc_checkout.IntegrationStatus();
		
        try {
            // In the Summer '20 release there should be one delivery group per cart.
            // We need to get the ID of that delivery group in order to use it for the shipping charge.
            Id cartDeliveryGroupId = [SELECT CartDeliveryGroupId FROM CartItem WHERE CartId = :cartId WITH SECURITY_ENFORCED][0].CartDeliveryGroupId;

            // Review cart products to get weight and determine if all are freight
            Decimal productWeight = getTotalProductWeight(cartId);
            Boolean allFreight = productWeight == 0;
            
            // Get the shipping options from the external service.
            ShippingOptionsAndRatesFromExternalService[] shippingOptionsAndRatesFromExternalService = null;
            if(!allFreight) {
                shippingOptionsAndRatesFromExternalService = getShippingOptionsAndRatesFromExternalService(cartDeliveryGroupId, productWeight);
            }

            // Delete all previous CartDeliveryGroupMethods for the given cartDeliveryGroupId
            delete [SELECT Id FROM CartDeliveryGroupMethod WHERE CartDeliveryGroupId = :cartDeliveryGroupId WITH SECURITY_ENFORCED];

            // Create a CartDeliveryGroupMethod record for every shipping option returned from the external service
			// Create orderDeliveryMethods given the shipping options from the external service or fetch existing ones
            populateCartDeliveryGroupMethodWithShippingOptions(shippingOptionsAndRatesFromExternalService, cartDeliveryGroupId, cartId, allFreight);	
                   
            // If everything works well, the charge is added to the cart and our integration has been successfully completed.
            integStatus.status = sfdc_checkout.IntegrationStatus.Status.SUCCESS;

        // For testing purposes, this example treats exceptions as user errors, which means they are displayed to the buyer user.
        // In production you probably want this to be an admin-type error. In that case, throw the exception here
        // and make sure that a notification system is in place to let the admin know that the error occurred.
        // See the readme section about error handling for details about how to create that notification.
        } catch (DmlException de) {
            // Catch any exceptions thrown when trying to insert the shipping charge to the CartItems
            Integer numErrors = de.getNumDml();
            String errorMessage = 'There were ' + numErrors + ' errors when trying to insert the charge in the CartItem: ';
            for(Integer errorIdx = 0; errorIdx < numErrors; errorIdx++) {
                errorMessage += 'Field Names = ' + de.getDmlFieldNames(errorIdx);
                errorMessage += 'Message = ' + de.getDmlMessage(errorIdx);
                errorMessage += ' , ';
            }
            return integrationStatusFailedWithCartValidationOutputError(
                integStatus,
                errorMessage,
                jobInfo,
                cartId
            );
        } catch(Exception e) {
            return integrationStatusFailedWithCartValidationOutputError(
                integStatus,
                'An exception of type ' + e.getTypeName() + ' has occurred: ' + e.getMessage(),
                jobInfo,
                cartId
            );
        }
        return integStatus;
    }
    
    private ShippingOptionsAndRatesFromExternalService[] getShippingOptionsAndRatesFromExternalService (Id cartDeliveryGroupId, Decimal productWeight) {

        ShippingOptionsAndRatesFromExternalService[] shippingOptions = new List<ShippingOptionsAndRatesFromExternalService>();
		
        // To access the services below, you may need to add endpoint in Setup | Security | Remote site settings.
        final Integer SuccessfulHttpRequest = 200;
        String username = 'ffa66eee0528412e8751c32cd7b5b2b0';
		String password = 'e34658fd90e44778b2969a5f61b8dd91';
        Blob headerValue = Blob.valueOf(username + ':' + password);
        String authorizationHeader = 'Basic ' + EncodingUtil.base64Encode(headerValue);

        // Request for getting list of carriers for account
        Http http_c = new Http();
        HttpRequest request_c = new HttpRequest();   
		request_c.setEndpoint('https://ssapi.shipstation.com/carriers');
        request_c.setMethod('GET');
        request_c.setHeader('Authorization', authorizationHeader);
        
        // Request for getting rates for list of carriers on account
        Http http_r = new Http();
        HttpRequest request_r = new HttpRequest();   
		request_r.setEndpoint('https://ssapi.shipstation.com/shipments/getrates');
        request_r.setMethod('POST');
        request_r.setHeader('Authorization', authorizationHeader);
		request_r.setHeader('Content-Type', 'application/json;charset=UTF-8');

        // Request for getting warehouse location information
        Http http_w = new Http();
        HttpRequest request_w = new HttpRequest();   
        request_w.setEndpoint('https://ssapi.shipstation.com/warehouses');
        request_w.setMethod('GET');
        request_w.setHeader('Authorization', authorizationHeader);

		// Cart information for getting shipping rates
		CartDeliveryGroup cartDeliveryGroup = [SELECT DeliverToState, DeliverToCountry, DeliverToPostalCode, DeliverToCity FROM CartDeliveryGroup WHERE Id =:cartDeliveryGroupId LIMIT 1];
        
        // Get warehouse info for account
        HttpResponse response_w = null;
        if (Test.isRunningTest() && (warehouseMock!=null)) {
            response_w = warehouseMock.respond(request_w);
        } else {
            response_w = http_w.send(request_w);
        }

        String fromPostalCode = '30318'; // Zip Code of Atlanta warehouse
        List<Object> warehouses = (List<Object>) JSON.deserializeUntyped(response_w.getBody());
        for(Object obj_w : warehouses){
            Map<String, Object> warehouse = (Map<String, Object>) obj_w;
            if((Boolean) warehouse.get('isDefault')) {
                Object originAddress = warehouse.get('originAddress');
                Map<String, Object> originAddressMap = (Map<String, Object>) originAddress;
                fromPostalCode = (String) originAddressMap.get('postalCode');
            }
        }

		String toState = cartDeliveryGroup.DeliverToState;
		String toCountry = cartDeliveryGroup.DeliverToCountry != null && cartDeliveryGroup.DeliverToCountry.length() == 2 ? cartDeliveryGroup.DeliverToCountry : 'US'; // needs to be two digit
		String toPostalCode = cartDeliveryGroup.DeliverToPostalCode;
		String toCity = cartDeliveryGroup.DeliverToCity;
		String weight = productWeight.toPlainString(); // Roll up from cart items
		String weightUnit = 'pounds';
        
        // Get list of carriers for account
        HttpResponse response_c = null;
        if (Test.isRunningTest() && (carriersMock!=null)) {
            response_c = carriersMock.respond(request_c);
        } else {
            response_c = http_c.send(request_c);
        }
        // If the request is successful, parse the JSON response.
        // The response looks like this: {"name":"Stamps.com","code":"stamps_com","accountNumber":null,"requiresFundedAccount":true,"balance":0.0,"nickname":"Free","shippingProviderId":12345,"primary":true}
        if (response_c.getStatusCode() == SuccessfulHttpRequest) {
            List<Object> carriers = (List<Object>) JSON.deserializeUntyped(response_c.getBody());
            for(Object obj_c : carriers){
                Map<String, Object> carrier = (Map<String, Object>) obj_c;
                
                // For each carrier, get rates
                request_r.setBody('{"carrierCode":"' + (String) carrier.get('code') +
					'","serviceCode":null,"packageCode":null,"fromPostalCode":"' + fromPostalCode +
					'","toState":"' + toState +
					'","toCountry":"' + toCountry +
					'","toPostalCode":"' + toPostalCode +
					'","toCity":"' + toCity +
					'","weight":{"value":' + weight +
					',"units":"' + weightUnit +
					'"},"confirmation":"delivery","residential":false}');

                HttpResponse response_r = null;
                if (Test.isRunningTest() && (ratesMock!=null)) {
                    response_r = ratesMock.respond(request_r);
                } else {
                    response_r = http_r.send(request_r);
                }

                // If the request is successful, parse the JSON response.
                // The response looks like this: {"serviceName":"USPS First Class Mail - Letter","serviceCode":"usps_first_class_mail","shipmentCost":0.9100,"otherCost":0.0}
                if (response_r.getStatusCode() == SuccessfulHttpRequest) {
                    List<Object> rates = (List<Object>) JSON.deserializeUntyped(response_r.getBody());
                    for(Object obj_r : rates){
                        Map<String, Object> rate = (Map<String, Object>) obj_r;
                        
                        ShippingOptionsAndRatesFromExternalService shippingOption = new ShippingOptionsAndRatesFromExternalService(
							(String) carrier.get('name'),
							(String) carrier.get('code'),
							(String) rate.get('serviceCode'), 
							(Decimal) rate.get('shipmentCost'),
							(Decimal) rate.get('otherCost'),
							(String) rate.get('serviceName') 
						);
                        shippingOptions.add(shippingOption);
                    }
                }
                else {
                    throw new CalloutException ('There was a problem with the request. Error: ' + response_r.getStatusCode());
                }
            }
            return shippingOptions;
        }
        else {
            throw new CalloutException ('There was a problem with the request. Error: ' + response_c.getStatusCode());
        }
    }
    
    // Structure to store the shipping options retrieved from external service.
    Class ShippingOptionsAndRatesFromExternalService {
		private String name; // Delivery Method Name
		private String code;
        private String provider;
        private Decimal rate;
		private Decimal otherCost;
		private String serviceName; // Carrier Method Name
        
        /*public ShippingOptionsAndRatesFromExternalService() {
			name = '';
			code = '';
            provider = '';
            rate = 0.0;
			otherCost = 0.0;
			serviceName = '';
        }*/
        
        public ShippingOptionsAndRatesFromExternalService(String someName, String someCode, String someProvider, Decimal someRate, Decimal someOtherCost, String someServiceName) {
            name = someName;
			code = someCode;
			provider = someProvider;
            rate = someRate;
			otherCost = someOtherCost;
			serviceName = someServiceName;
        }
        
		/*
        public String getName() {
            return name;
        }
        */        
        
		/*
        public String getCode() {
			return code;
		}
        */
		
		public String getProvider() {
            return provider;
        }
        
        public Decimal getRate() {
            return rate;
        }
		
        /*
		public Decimal getOtherCost() {
			return otherCost;
		}
        */
		
		public String getServiceName() {
			return serviceName;
		}
    }
    
    // Create a CartDeliveryGroupMethod record for every shipping option returned from the external service
	// Create orderDeliveryMethods given the shipping options from the external service or fetch existing ones
    private void populateCartDeliveryGroupMethodWithShippingOptions(ShippingOptionsAndRatesFromExternalService[] shippingOptionsAndRatesFromExternalService,
                                                                  Id cartDeliveryGroupId,
                                                                  Id webCartId,
                                                                  Boolean allFreight){

        if(allFreight) {
            Id orderDeliveryMethodId = getFreightOrderDeliveryMethod();
            CartDeliveryGroupMethod cartDeliveryGroupMethod = new CartDeliveryGroupMethod(
                CartDeliveryGroupId = cartDeliveryGroupId,
                DeliveryMethodId = orderDeliveryMethodId,
                ExternalProvider = 'TBD',
                Name = '*Freight',
                ShippingFee = 0,
                WebCartId = webCartId
            );
            insert(cartDeliveryGroupMethod);
        }
        else {
            for (ShippingOptionsAndRatesFromExternalService shippingOption : shippingOptionsAndRatesFromExternalService) {
                // When inserting a new CartDeliveryGroupMethod, the following fields have to be populated:
                // CartDeliveryGroupId: Id of the delivery group of this shipping option
                // DeliveryMethodId: Id of the delivery method for this shipping option
                // In production implementation you need to query OrderDeliveryMethods based on service response)
                // ExternalProvider: Unique identifier of shipping provider
                // Name: Name of the CartDeliveryGroupMethod record
                // ShippingFee: The cost of shipping for the delivery group
                // WebCartId: Id if the cart that the delivery group belongs to
                
                Id orderDeliveryMethodId = getOrderDeliveryMethod(shippingOption);
                CartDeliveryGroupMethod cartDeliveryGroupMethod = new CartDeliveryGroupMethod(
                    CartDeliveryGroupId = cartDeliveryGroupId,
                    DeliveryMethodId = orderDeliveryMethodId,
                    ExternalProvider = shippingOption.getProvider(),
                    Name = shippingOption.getServiceName(),
                    ShippingFee = shippingOption.getRate(),
                    WebCartId = webCartId
                );
                insert(cartDeliveryGroupMethod);
            }
        }
    }
    
    private sfdc_checkout.IntegrationStatus integrationStatusFailedWithCartValidationOutputError(
        sfdc_checkout.IntegrationStatus integrationStatus, String errorMessage, sfdc_checkout.IntegrationInfo jobInfo, Id cartId) {
            integrationStatus.status = sfdc_checkout.IntegrationStatus.Status.FAILED;
            // In order for the error to be propagated to the user, we need to add a new CartValidationOutput record.
            // The following fields must be populated:
            // BackgroundOperationId: Foreign Key to the BackgroundOperation
            // CartId: Foreign key to the WebCart that this validation line is for
            // Level (required): One of the following - Info, Error, or Warning
            // Message (optional): Message displayed to the user
            // Name (required): The name of this CartValidationOutput record. For example CartId:BackgroundOperationId
            // RelatedEntityId (required): Foreign key to WebCart, CartItem, CartDeliveryGroup
            // Type (required): One of the following - SystemError, Inventory, Taxes, Pricing, Shipping, Entitlement, Other
            CartValidationOutput cartValidationError = new CartValidationOutput(
                BackgroundOperationId = jobInfo.jobId,
                CartId = cartId,
                Level = 'Error',
                Message = errorMessage.left(255),
                Name = (String)cartId + ':' + jobInfo.jobId,
                RelatedEntityId = cartId,
                Type = 'Shipping'
            );
            insert(cartValidationError);
            return integrationStatus;
    }
    
    private Decimal getTotalProductWeight(Id cartId) {
        Decimal totalProductWeight = 0;
        
        Set<Id> productIds = new Set<Id>();
        Map<Id, CartItem> cartItemsMap = new Map<Id, CartItem>();
		List<CartItem> allCartItems = [SELECT Id, CartId, Product2Id, Quantity FROM CartItem WHERE CartId = :cartId];
        for(CartItem cartItem : allCartItems) {
            productIds.add(cartItem.Product2Id);
            cartItemsMap.put(cartItem.Product2Id, cartItem);
        }

        // List<Product2> allFedExProducts = [SELECT Id, sstation__Weight__c, Weight__c, Shipping_Method__c FROM Product2 WHERE Id IN :productIds AND Shipping_Method__c = 'FedEx'];
         List<Product2> allFedExProducts = [SELECT Id, sstation__Weight__c, Shipping_Method__c FROM Product2 WHERE Id IN :productIds AND Shipping_Method__c = 'FedEx'];
         if(allFedExProducts.size() > 0){
            for(Product2 fedExProduct : allFedExProducts) {
                CartItem fedExCartItem = cartItemsMap.get(fedExProduct.Id);
                /*Decimal productWeight = (fedExCartItem.Quantity != null ? fedExCartItem.Quantity : 1) * 
                                        ((fedExProduct.sstation__Weight__c != null ? fedExProduct.sstation__Weight__c : 0) + 
                                        ((fedExProduct.Weight__c != null ? fedExProduct.Weight__c : 0) / 16));*/
                Decimal productWeight = (fedExCartItem.Quantity != null ? fedExCartItem.Quantity : 1) * 
                                        ((fedExProduct.sstation__Weight__c != null ? fedExProduct.sstation__Weight__c : 0));
                totalProductWeight = totalProductWeight + productWeight;
            }
            if(totalProductWeight == 0) {
                totalProductWeight = 1;
            }
        }
        
        return totalProductWeight;
    }

    private Id getShippingChargeProduct2Id(Id orderDeliveryMethodId) {
        // The Order Delivery Method should have a Product2 associated with it, because we added that in getDefaultOrderDeliveryMethod if it didn't exist.
        List<OrderDeliveryMethod> orderDeliveryMethods = [SELECT ProductId FROM OrderDeliveryMethod WHERE Id = :orderDeliveryMethodId WITH SECURITY_ENFORCED];
        return orderDeliveryMethods[0].ProductId;
    }
    
    private Id getOrderDeliveryMethod(ShippingOptionsAndRatesFromExternalService shippingOption) {
        Id product2IdForThisDeliveryMethod = getDefaultShippingChargeProduct2Id('Shipping Charge for ' + shippingOption.serviceName);
		Id orderDeliveryMethodId = null;

        // Check to see if a default OrderDeliveryMethod already exists.
        // If it doesn't exist, create one.
		String name = shippingOption.serviceName;
        List<OrderDeliveryMethod> orderDeliveryMethods = [SELECT Id, ProductId, Carrier, ClassOfService FROM OrderDeliveryMethod WHERE Name = :name WITH SECURITY_ENFORCED];
        if (orderDeliveryMethods.isEmpty()) {
            OrderDeliveryMethod defaultOrderDeliveryMethod = new OrderDeliveryMethod(
                Name = name,
				Carrier = shippingOption.name,
                isActive = true,
                ProductId = product2IdForThisDeliveryMethod,
				ClassOfService = shippingOption.provider
            );
            insert(defaultOrderDeliveryMethod);
            orderDeliveryMethodId = defaultOrderDeliveryMethod.Id;
        }
        else {
            // If the OrderDeliveryMethod doesn't have a Product2 associated with it, assign one
            OrderDeliveryMethod defaultOrderDeliveryMethod = orderDeliveryMethods[0];
            if (defaultOrderDeliveryMethod.ProductId == null || defaultOrderDeliveryMethod.Carrier == null || defaultOrderDeliveryMethod.ClassOfService == null) {
                defaultOrderDeliveryMethod.ProductId = product2IdForThisDeliveryMethod;
				defaultOrderDeliveryMethod.Carrier = shippingOption.name;
				defaultOrderDeliveryMethod.ClassOfService = shippingOption.provider;
                update(defaultOrderDeliveryMethod);
                orderDeliveryMethodId = defaultOrderDeliveryMethod.Id;
            }
            else {
                orderDeliveryMethodId = defaultOrderDeliveryMethod.Id;
            }
        }
        
        return orderDeliveryMethodId;
    }

    private Id getFreightOrderDeliveryMethod() {
        Id product2IdForThisDeliveryMethod = getDefaultShippingChargeProduct2Id('Shipping Charge for Freight');
		Id orderDeliveryMethodId = null;

        // Check to see if a default OrderDeliveryMethod already exists.
        // If it doesn't exist, create one.
		String name = 'Freight';
        List<OrderDeliveryMethod> orderDeliveryMethods = [SELECT Id, ProductId, Carrier, ClassOfService FROM OrderDeliveryMethod WHERE Name = :name WITH SECURITY_ENFORCED];
        if (orderDeliveryMethods.isEmpty()) {
            OrderDeliveryMethod defaultOrderDeliveryMethod = new OrderDeliveryMethod(
                Name = name,
                Carrier = 'TBD',
                isActive = true,
                ProductId = product2IdForThisDeliveryMethod,
                ClassOfService = 'TBD'
            );
            insert(defaultOrderDeliveryMethod);
            orderDeliveryMethodId = defaultOrderDeliveryMethod.Id;
        }
        else {
            // If the OrderDeliveryMethod doesn't have a Product2 associated with it, assign one
            OrderDeliveryMethod defaultOrderDeliveryMethod = orderDeliveryMethods[0];
            if (defaultOrderDeliveryMethod.ProductId == null) {
                defaultOrderDeliveryMethod.ProductId = product2IdForThisDeliveryMethod;
                update(defaultOrderDeliveryMethod);
                orderDeliveryMethodId = defaultOrderDeliveryMethod.Id;
            }
            else {
                orderDeliveryMethodId = defaultOrderDeliveryMethod.Id;
            }
        }
        
        return orderDeliveryMethodId;
    }
    
    private Id getDefaultShippingChargeProduct2Id(String shippingChargeProduct2Name) {
        // In this example we will name the product representing shipping charges based on the value passed in.
        // Check to see if a Product2 with that name already exists.
        // If it doesn't exist, create one.
        List<Product2> shippingChargeProducts = [SELECT Id FROM Product2 WHERE Name = :shippingChargeProduct2Name WITH SECURITY_ENFORCED];
        if (shippingChargeProducts.isEmpty()) {
            Product2 shippingChargeProduct = new Product2(
                isActive = true,
                Name = shippingChargeProduct2Name,
                sstation__Currency_Type__c = 'USD',
                sstation__Msrp__c = 0.00
            );
            insert(shippingChargeProduct);
            return shippingChargeProduct.Id;
        }
        else {
            return shippingChargeProducts[0].Id;
        }
    }

}