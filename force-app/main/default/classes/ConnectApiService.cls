public interface ConnectApiService {
	ConnectApi.ProductDetail getProduct(
        String webstoreId,
        String productId,
        String effectiveAccountId,
        List<String> fields,
        Boolean excludeFields,
        List<String> mediaGroups,
        Boolean excludeMedia,
        Boolean excludeEntitlementDetails,
        Boolean excludePrimaryProductCategory
        );        
        ConnectApi.ProductPrice getProductPrice(String webStoreId, String productIdId, String effectiveAccountId);
}
