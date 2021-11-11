public inherited sharing class B2BCheckoutSummaryController {

    @AuraEnabled
    public static CartSummaryResult getCartSummary(Id cartId) {
  
      WebCart cart = [
        SELECT
          Id,
          TotalProductAmount,
          TotalChargeAmount,
          TotalTaxAmount,
          GrandTotalAmount,
          AccountId
        FROM WebCart
        WHERE Id = :cartId
      ];

      List<CartItem> chargeLines = [
        SELECT Name, TotalPrice
        FROM CartItem
        WHERE CartId = :cartId AND Type = 'Charge'
      ];

      Boolean includesFreight = cartContainsFreight(cartId);
      Boolean includesFedEx = cartContainsFedEx(cartId);

      return new CartSummaryResult(
        cart,
        chargeLines,
        includesFreight,
        includesFedEx
      );
    }
  
    public class CartSummaryResult {
      @AuraEnabled
      public WebCart cart;
      @AuraEnabled
      public List<CartItem> chargeLines;
      @AuraEnabled
      public Boolean includesFreight;
      @AuraEnabled
      public Boolean includesFedEx;
  
      public CartSummaryResult(
        WebCart c,
        List<CartItem> cl,
        Boolean f,
        Boolean x
      ) {
        this.cart = c;
        this.chargeLines = cl;
        this.includesFreight = f;
        this.includesFedEx = x;
      }
    }

    private static Boolean cartContainsFreight(Id cartId) {
        Boolean containsFreight = false;
        
        Set<Id> productIds = new Set<Id>();
		    List<CartItem> allCartItems = [SELECT Id, CartId, Product2Id FROM CartItem WHERE CartId = :cartId];
        for(CartItem cartItem : allCartItems) {
            productIds.add(cartItem.Product2Id);
        }

        List<Product2> allFreightProducts = [SELECT Id, Shipping_Method__c FROM Product2 WHERE Id IN :productIds AND Shipping_Method__c = 'Freight'];
        if(allFreightProducts.size() > 0){
            containsFreight = true;
        }
        
        return containsFreight;
    }

    private static Boolean cartContainsFedEx(Id cartId) {
      Boolean containsFedEx = false;
      
      Set<Id> productIds = new Set<Id>();
      List<CartItem> allCartItems = [SELECT Id, CartId, Product2Id FROM CartItem WHERE CartId = :cartId];
      for(CartItem cartItem : allCartItems) {
          productIds.add(cartItem.Product2Id);
      }

      List<Product2> allFedExProducts = [SELECT Id, Shipping_Method__c FROM Product2 WHERE Id IN :productIds AND Shipping_Method__c = 'FedEx'];
      if(allFedExProducts.size() > 0){
          containsFedEx = true;
      }
      
      return containsFedEx;
    }
  
    @AuraEnabled
    public static OrderSummaryResult getOrderSummary(Id orderSummaryId) {
      OrderSummary orderSummary = [
        SELECT
          Id,
          TotalAdjustedProductAmount,
          TotalAdjustedDeliveryAmount,
          TotalAdjustedProductTaxAmount,
          GrandTotalAmount
        FROM OrderSummary
        WHERE Id = :orderSummaryId
      ];

      List<OrderItemSummary> orderItemSummaryCharges = [
        SELECT Name, Product2.Name, TotalPrice
        FROM OrderItemSummary
        WHERE OrderSummaryId = :orderSummaryId AND Type = 'Delivery Charge'
      ];

      Boolean includesFreight = orderContainsFreight(orderSummaryId);
      Boolean includesFedEx = orderContainsFedEx(orderSummaryId);

      return new OrderSummaryResult(
        orderSummary,
        orderItemSummaryCharges,
        includesFreight,
        includesFedEx
      );
    }
  
    public class OrderSummaryResult {
      @AuraEnabled
      public OrderSummary orderSummary;
      @AuraEnabled
      public List<OrderItemSummary> chargeLines;
      @AuraEnabled
      public Boolean includesFreight;
      @AuraEnabled
      public Boolean includesFedEx;
  
      public OrderSummaryResult(
        OrderSummary c,
        List<OrderItemSummary> cl,
        Boolean f,
        Boolean x
      ) {
        this.orderSummary = c;
        this.chargeLines = cl;
        this.includesFreight = f;
        this.includesFedEx = x;
      }
    }

    private static Boolean orderContainsFreight(Id orderSummaryId) {
        Boolean containsFreight = false;
        
        Set<Id> productIds = new Set<Id>();
		    List<OrderItemSummary> allOrderSummaryItems = [SELECT Id, OrderSummaryId, Product2Id FROM OrderItemSummary WHERE OrderSummaryId = :orderSummaryId];
        for(OrderItemSummary orderItem : allOrderSummaryItems) {
            productIds.add(orderItem.Product2Id);
        }

        List<Product2> allFreightProducts = [SELECT Id, Shipping_Method__c FROM Product2 WHERE Id IN :productIds AND Shipping_Method__c = 'Freight'];
        if(allFreightProducts.size() > 0){
            containsFreight = true;
        }
        
        return containsFreight;
    }

    private static Boolean orderContainsFedEx(Id orderSummaryId) {
      Boolean containsFedEx = false;
      
      Set<Id> productIds = new Set<Id>();
      List<OrderItemSummary> allOrderSummaryItems = [SELECT Id, OrderSummaryId, Product2Id FROM OrderItemSummary WHERE OrderSummaryId = :orderSummaryId];
      for(OrderItemSummary orderItem : allOrderSummaryItems) {
          productIds.add(orderItem.Product2Id);
      }

      List<Product2> allFedExProducts = [SELECT Id, Shipping_Method__c FROM Product2 WHERE Id IN :productIds AND Shipping_Method__c = 'FedEx'];
      if(allFedExProducts.size() > 0){
        containsFedEx = true;
      }
      
      return containsFedEx;
    }
  
  }
  