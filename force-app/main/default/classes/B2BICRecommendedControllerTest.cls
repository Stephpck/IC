@IsTest public with sharing class B2BICRecommendedControllerTest {
    @TestSetup
    private static void createData() {
        B2BTestUtils utils = new B2BTestUtils();
        utils.setupStore();
    }
    
    @IsTest
    public static void getRelatedProductsListEmpty() {
        B2BTestUtils utils = new B2BTestUtils();
        B2BICRecommendedController.connectApiSvc = new MockConnectApiServiceEmpty();

        User user = [SELECT Id, Contact.AccountId FROM User WHERE Email='storebuyercontact@b2btestutils.test'];
        Id communityId = B2BTestUtils.getNetworkId();
        Id effectiveAccountId = user.Contact.AccountId;

        Product2 prod1 = [SELECT Id, Name FROM Product2 WHERE Name='Test Product 1'];        

        System.runAs(user) {
            List<B2BICRecommendedController.ProductWrapper> wrapperList = B2BICRecommendedController.getRelatedProductsList(communityId, prod1.Id, effectiveAccountId);
            System.assert(wrapperList != null);
            System.assert(wrapperList.size() == 2);
            for (B2BICRecommendedController.ProductWrapper wrapper : wrapperList) {
                System.assert(wrapper.name != null);
                System.assert(wrapper.price == null);
                System.assert(wrapper.productUrl != null);
                System.assert(wrapper.images != null);
                System.assertEquals(0, wrapper.images.size());
            }
        }
    }

    class MockConnectApiServiceEmpty implements ConnectApiService {
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
            ConnectApi.ProductDetail productDetail = new ConnectApi.ProductDetail();
            return productDetail;
        }
        
        public ConnectApi.ProductPrice getProductPrice(String webStoreId, String productIdId, String effectiveAccountId) {
            return null;
        }
    }

    @IsTest
    public static void getRelatedProductsListList() {
        B2BTestUtils utils = new B2BTestUtils();
        B2BICRecommendedController.connectApiSvc = new MockConnectApiServiceList();

        User user = [SELECT Id, Contact.AccountId FROM User WHERE Email='storebuyercontact@b2btestutils.test'];
        Id communityId = B2BTestUtils.getNetworkId();
        Id effectiveAccountId = user.Contact.AccountId;

        Product2 prod1 = [SELECT Id, Name FROM Product2 WHERE Name='Test Product 1'];        

        System.runAs(user) {
            List<B2BICRecommendedController.ProductWrapper> wrapperList = B2BICRecommendedController.getRelatedProductsList(communityId, prod1.Id, effectiveAccountId);
            System.assert(wrapperList != null);
            System.assert(wrapperList.size() == 2);
            for (B2BICRecommendedController.ProductWrapper wrapper : wrapperList) {
                System.assert(wrapper.name != null);
                System.assert(wrapper.price == null);
                System.assert(wrapper.productUrl != null);
                System.assert(wrapper.images != null);
                System.assertEquals(1, wrapper.images.size());
                System.assertEquals('List Image', wrapper.images[0].title);
                System.assertEquals('/img/b2b/list-product-image.svg', wrapper.images[0].url);
            }
        }
    }

    class MockConnectApiServiceList implements ConnectApiService {
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
            ConnectApi.ProductDetail productDetail = new ConnectApi.ProductDetail();
            ConnectApi.ProductMedia defaultImage = new ConnectApi.ProductMedia();
            defaultImage.mediaType = ConnectApi.ProductMediaType.Image;
            defaultImage.title = 'Default Image';
            defaultImage.url = '/img/b2b/default-product-image.svg';
            productDetail.defaultImage = defaultImage;
            ConnectApi.ProductMediaGroup listGroup = new ConnectApi.ProductMediaGroup();
            listGroup.developerName = 'productListImage';
            listGroup.name = 'Product List Image';
            List<ConnectApi.ProductMedia> listImages = new List<ConnectApi.ProductMedia>();
            ConnectApi.ProductMedia listImage = new ConnectApi.ProductMedia();
            listImage.mediaType = ConnectApi.ProductMediaType.Image;
            listImage.title = 'List Image';
            listImage.url = '/img/b2b/list-product-image.svg';
            listImages.add(listImage);
            listGroup.mediaItems = listImages;
            List<ConnectApi.ProductMediaGroup> imageGroups = new List<ConnectApi.ProductMediaGroup>();
            imageGroups.add(listGroup);
            productDetail.mediaGroups = imageGroups;
            return productDetail;
        }
        
        public ConnectApi.ProductPrice getProductPrice(String webStoreId, String productIdId, String effectiveAccountId) {
            return null;
        }
    }

    @IsTest
    public static void getRelatedProductsListDefault() {
        B2BTestUtils utils = new B2BTestUtils();
        B2BICRecommendedController.connectApiSvc = new MockConnectApiServiceDefault();

        User user = [SELECT Id, Contact.AccountId FROM User WHERE Email='storebuyercontact@b2btestutils.test'];
        Id communityId = B2BTestUtils.getNetworkId();
        Id effectiveAccountId = user.Contact.AccountId;

        Product2 prod1 = [SELECT Id, Name FROM Product2 WHERE Name='Test Product 1'];        

        System.runAs(user) {
            List<B2BICRecommendedController.ProductWrapper> wrapperList = B2BICRecommendedController.getRelatedProductsList(communityId, prod1.Id, effectiveAccountId);
            System.assert(wrapperList != null);
            System.assert(wrapperList.size() == 2);
            for (B2BICRecommendedController.ProductWrapper wrapper : wrapperList) {
                System.assert(wrapper.name != null);
                System.assert(wrapper.price == null);
                System.assert(wrapper.productUrl != null);
                System.assert(wrapper.images != null);
                System.assertEquals(1, wrapper.images.size());
                System.assertEquals('Default Image', wrapper.images[0].title);
                System.assertEquals('/img/b2b/default-product-image.svg', wrapper.images[0].url);
            }
        }
    }

    class MockConnectApiServiceDefault implements ConnectApiService {
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
            ConnectApi.ProductDetail productDetail = new ConnectApi.ProductDetail();
            ConnectApi.ProductMedia defaultImage = new ConnectApi.ProductMedia();
            defaultImage.mediaType = ConnectApi.ProductMediaType.Image;
            defaultImage.title = 'Default Image';
            defaultImage.url = '/img/b2b/default-product-image.svg';
            productDetail.defaultImage = defaultImage;
            return productDetail;
        }
        
        public ConnectApi.ProductPrice getProductPrice(String webStoreId, String productIdId, String effectiveAccountId) {
            return null;
        }
    }

}
