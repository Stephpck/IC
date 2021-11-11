public without sharing class B2BICFAQController {
    @AuraEnabled
    public static List<FAQWrapper> getFAQList(){
        List<FAQWrapper> faqWrapperList = new List<FAQWrapper>();
        List<FAQObject__c> faqList = [SELECT Name, Question__c, Answer__c FROM FAQObject__c WHERE Active__c = true ORDER BY Order__c ];

        for (FAQObject__c faq : faqList) {
            FAQWrapper wrapper = new FAQWrapper();
            wrapper.name = faq.Name;
            wrapper.question = faq.Question__c;
            wrapper.answer = faq.Answer__c; 
            faqWrapperList.add(wrapper);
        }

        return faqWrapperList;

    }

    public class FAQWrapper {
        @AuraEnabled
        public String name;

        @AuraEnabled
        public String question;

        @AuraEnabled
        public String answer;
    }
}
