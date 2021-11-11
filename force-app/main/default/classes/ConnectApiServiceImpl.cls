public class ConnectApiServiceImpl implements ConnectApiService {
    public ConnectApi.ProductDetail getProduct(
        String webstoreId,
        String productId,
        String effectiveAccountId,
        List<String> fields,
        Boolean excludeFields,
        List<String> mediaGroups,
        Boolean excludeMedia,
        Boolean excludeEntitlementDetails,
        Boolean excludePrimaryProductCategory
        ) {
        return ConnectApi.CommerceCatalog.getProduct(webstoreId, productId, effectiveAccountId, fields, excludeFields, mediaGroups, excludeMedia, excludeEntitlementDetails, excludePrimaryProductCategory);
    }
    public ConnectApi.ProductPrice getProductPrice(String webStoreId, String productIdId, String effectiveAccountId) {
        return ConnectApi.CommerceStorePricing.getProductPrice(webstoreId, productIdId, effectiveAccountId);
    }
}