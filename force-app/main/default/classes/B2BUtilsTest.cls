@IsTest public with sharing class B2BUtilsTest {
    @TestSetup
    private static void createData() {
        B2BTestUtils utils = new B2BTestUtils();
        utils.setupStore();
    }

    @IsTest public static void resolveCommunityIdToWebstoreId_FirstTime() {
        Id communityId = B2BTestUtils.getNetworkId();
        Id expectedWebstoreId = [SELECT Id FROM WebStore LIMIT 1].Id;
        String webstoreId = B2BUtils.resolveCommunityIdToWebstoreId(communityId);
        System.debug('WebstoreId: '+webstoreId);
        
        System.assertEquals(expectedWebstoreId, webstoreId);
    }
    
    @IsTest public static void resolveCommunityIdToWebstoreId_FromCache() {
        Id communityId = B2BTestUtils.getNetworkId();
        Id expectedWebstoreId = [SELECT Id FROM WebStore LIMIT 1].Id;
        B2BUtils.resolveCommunityIdToWebstoreId(communityId);
        String webstoreId = B2BUtils.resolveCommunityIdToWebstoreId(communityId);
        System.debug('WebstoreId: '+webstoreId);
        
        System.assertEquals(expectedWebstoreId, webstoreId);
    }
}
