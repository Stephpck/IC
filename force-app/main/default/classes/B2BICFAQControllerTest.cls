@IsTest public with sharing class B2BICFAQControllerTest {
    @TestSetup
    private static void createData() {
        B2BTestUtils utils = new B2BTestUtils();
        utils.setupStore();
        
        FAQObject__c testFAQ = new FAQObject__c(Name='TestFAQ', Question__c='Test Question', Answer__c='Test Answer', Active__c=true, Order__c=1);
        insert testFAQ;
    }

    @IsTest
    public static void getFAQList() {
        User user = [SELECT Id, Contact.AccountId FROM User WHERE Email='storebuyercontact@b2btestutils.test'];

        System.runAs(user) {
            List<B2BICFAQController.FAQWrapper> wrapperList = B2BICFAQController.getFAQList();
            System.assert(wrapperList != null);
            System.assert(wrapperList.size() == 1);
            for (B2BICFAQController.FAQWrapper wrapper : wrapperList) {
                System.assert(wrapper.name != null);
                System.assert(wrapper.question != null);
            }
        }
    }
}
