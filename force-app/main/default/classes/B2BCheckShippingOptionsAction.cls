public with sharing class B2BCheckShippingOptionsAction {
    @InvocableMethod
    public static List<B2BCheckShippingOptionsResult> isFedExNeeded(List<B2BCheckShippingOptionsRequest> requests) {
		Set<Id> cartIds = new Set<Id>();
		for(B2BCheckShippingOptionsRequest request : requests) {
			cartIds.add(request.cartId);
		}

        B2BCheckShippingOptionsResult result = new B2BCheckShippingOptionsResult();

		List<CartItem> allCartItems = [SELECT Id, CartId, Product2Id FROM CartItem WHERE CartId IN :cartIds ORDER BY CartId];
        Set<Id> productIds = new Set<Id>();
        for(CartItem cartItem : allCartItems) {
            productIds.add(cartItem.Product2Id);
        }

        List<Product2> allFedExProducts = [SELECT Id, Shipping_Method__c FROM Product2 WHERE Id IN :productIds AND Shipping_Method__c = 'FedEx'];
        if(allFedExProducts.size() > 0){
            result.fedExNeeded = true;
        }
        else {
            result.fedExNeeded = false;
        }

        List<B2BCheckShippingOptionsResult> resultList = new List<B2BCheckShippingOptionsResult>();
        resultList.add(result);
		return resultList;
	}

	public class B2BCheckShippingOptionsRequest {
		@InvocableVariable(label='Cart Id' description='Cart id' required=true)
		public Id cartId;
	}

    public class B2BCheckShippingOptionsResult {
		@InvocableVariable(label='FedEx Needed' description='FedEx Needed' required=true)
		public Boolean fedExNeeded;
	}

}
