public with sharing class B2BICRecommendedController {
    @TestVisible
    private static ConnectApiService connectApiSvc = new ConnectApiServiceImpl();

    @AuraEnabled
    public static List<ProductWrapper> getRelatedProductsList(String communityId, String recordId, String effectiveAccountId){
        List<ProductWrapper> relatedProductsList = new List<ProductWrapper>();
        String webstoreId = B2BUtils.resolveCommunityIdToWebstoreId(communityId);

        // get categories for product in current webstore catalog
        String productCategoryId = null;
        String catalogId = [SELECT ProductCatalogId FROM WebStoreCatalog WHERE SalesStoreId = :webstoreId LIMIT 1].ProductCatalogId;
        List<ProductCategoryProduct> categories = [SELECT ProductCategoryId, IsPrimaryCategory FROM ProductCategoryProduct WHERE CatalogId = :catalogId AND ProductId = :recordId];

        // find primary category or get first if no primary exists
        for (ProductCategoryProduct cat : categories) {
            if (cat.IsPrimaryCategory) {
                productCategoryId = cat.ProductCategoryId;
                break;
            }
        }
        if (productCategoryId == null) {
            for (ProductCategoryProduct cat : categories) {
                if (cat.ProductCategoryId != null) {
                    productCategoryId = cat.ProductCategoryId;
                    break;
                }
            }
        }

        // get four products from selected category  
        List<ProductCategoryProduct> products = [SELECT ProductId FROM ProductCategoryProduct WHERE CatalogId = :catalogId AND ProductCategoryId = :productCategoryId AND ProductId != :recordId LIMIT 4];

        for (ProductCategoryProduct prod : products) {
            ProductWrapper wrapper = new ProductWrapper();
            
            String productId = prod.ProductId;
            Product2 currentProduct = null;
            List<Product2> currentProducts = [SELECT Id, Name FROM Product2 WHERE Id = :productId LIMIT 1];
            if(!currentProducts.isEmpty()){
                currentProduct = currentProducts[0];
                wrapper.name = currentProduct.Name;
                wrapper.productUrl = URL.getSalesforceBaseUrl().toExternalForm() + '/' + productId;

                try {
                    wrapper.price = connectApiSvc.getProductPrice(webstoreId, productId, effectiveAccountId);
                } catch (Exception pe){
                    system.debug('pe: ' + pe);
                }

                List<ConnectApi.ProductMedia> images = new List<ConnectApi.ProductMedia>();
                try {
                    ConnectApi.ProductDetail details = connectApiSvc.getProduct(webstoreId, productId, null, null, false, null, false, true, false);
                    if (details.mediaGroups != null) {
                        ConnectApi.ProductMediaGroup plGroup;
                        for (ConnectApi.ProductMediaGroup mediaGroup : details.mediaGroups) {
                            if (mediaGroup.developerName != null && mediaGroup.developerName.equals('productListImage')) {
                                plGroup = mediaGroup;
                            }
                        }
                        if (images.isEmpty() && plGroup != null && plGroup.mediaItems != null && plGroup.mediaItems.size() > 0) {
                            for (ConnectApi.ProductMedia item : plGroup.mediaItems) {
                                if (item.mediaType == ConnectApi.ProductMediaType.Image) {
                                    images.add(item);
                                }
                            }
                        }
                    }
                    if (images.isEmpty() && details.defaultImage != null) {
                        images.add(details.defaultImage);
                    }
                } catch (Exception ie){
                    system.debug('ie: ' + ie);
                }
                wrapper.images = images;
    
                relatedProductsList.add(wrapper);
            }
            else{
                //Product doesn't exist
            }
        }

        return relatedProductsList;

    }

    public class ProductWrapper {
        @AuraEnabled
        public String name;

        @AuraEnabled
        public ConnectApi.ProductPrice price;

        @AuraEnabled
        public String productUrl;

        @AuraEnabled
        public List<ConnectApi.ProductMedia> images;
    }
}
