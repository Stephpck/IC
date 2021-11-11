@IsTest public with sharing class UserProfileTriggerHandlerTest {
    @TestSetup
	static void createData() {
		B2BTestUtils utils = new B2BTestUtils();
		Account acct = utils.getAccount('account1');
		insert acct;

		Profile profile = getCommerceProfile();
		Id profileId = profile.Id;

		Contact c = new Contact();
		c.FirstName = 'first';
		c.LastName = 'last';
		c.email = 'iwtest@iwtest.com';
		c.AccountId = acct.Id;
		insert c;

		User u = new User();
		u.FirstName = 'first';
		u.LastName = 'last';
		u.Email = 'iwtest@iwtest.com';
		u.Alias = 'alias';
		u.Username = 'iwtest@iwtest.com.iw';
		u.CommunityNickname = 'nick';
		u.LocaleSidKey = 'en_US';
		u.TimeZoneSidKey = 'America/New_York';
		u.ProfileId = profileId;
		u.LanguageLocaleKey = 'en_US';
		u.EmailEncodingKey = 'UTF-8';
		u.ContactId = c.Id;
		insert u;
	}

	private static Account getAccount() {
		return [SELECT Id FROM Account LIMIT 1];
	}

	private static Profile getCommerceProfile() {
		return [SELECT Id FROM Profile WHERE Name = :UserProfileTriggerHandler.B2B_COMMERCE_PROFILE_NAME];
	}

	private static PermissionSetGroup getPermissionSetGroup() {
		return [SELECT Id FROM PermissionSetGroup WHERE DeveloperName = :UserProfileTriggerHandler.B2B_CUSTOMER_COMMUNITY_USER];
	}

	@IsTest
	static void beforeInsertInvalid() {
        User user = [SELECT Id, Contact.AccountId FROM User WHERE Email='iwtest@iwtest.com'];
        
        System.runAs(user) {
            User u = new User();
            u.FirstName = 'f';
            u.LastName = 'l';
            u.Email = 'iwtest@iwtest.com';
            u.LocaleSidKey = 'en_US';
            u.TimeZoneSidKey = 'America/New_York';
            u.LanguageLocaleKey = 'en_US';
            u.EmailEncodingKey = 'UTF-8';

            String errorMessage = null;
            Test.startTest();
            try {
                insert u;
            } catch(Exception e) {
                errorMessage = e.getMessage();
            }
            Test.stopTest();
            System.assertEquals(true, errorMessage.contains(Label.USERNAME_IS_DUPLICATE), 'error message should be duplicate username label');
        }
	}

	@IsTest
	static void beforeUpdateInvalid() {
        User user = [SELECT Id, Contact.AccountId FROM User WHERE Email='iwtest@iwtest.com'];
        
        System.runAs(user) {
            User u = new User();
            u.FirstName = 'f';
            u.LastName = 'l';
            u.Email = 'iwtest1@iwtest.com';
            u.LocaleSidKey = 'en_US';
            u.TimeZoneSidKey = 'America/New_York';
            u.LanguageLocaleKey = 'en_US';
            u.EmailEncodingKey = 'UTF-8';
            insert u;

            String errorMessage = null;
            Test.startTest();
            try {
                u.Email = 'iwtest@iwtest.com';
                update u;
            } catch(Exception e) {
                errorMessage = e.getMessage();
            }
            Test.stopTest();
            System.assertEquals(true, errorMessage == null, 'username not being updated on contact updates, so no issue');
        }
	}

	@IsTest
	static void afterInsert() {
        User user = [SELECT Id, Contact.AccountId FROM User WHERE Email='iwtest@iwtest.com'];
        
        System.runAs(user) {
            User u = new User();
            u.FirstName = 'f';
            u.LastName = 'l';
            u.Email = 'iwtest1@iwtest.com';
            u.LocaleSidKey = 'en_US';
            u.TimeZoneSidKey = 'America/New_York';
            u.LanguageLocaleKey = 'en_US';
            u.EmailEncodingKey = 'UTF-8';

            Test.startTest();
            insert u;
            Test.stopTest();

            User activeUser = [SELECT Id, ContactId, Username, ProfileId FROM User WHERE Id = :u.Id];
            Contact c = [SELECT Id, FirstName, LastName, Email FROM Contact WHERE Id = :activeUser.ContactId];
            System.assertEquals(c.FirstName, u.FirstName, 'first name should match');
            System.assertEquals(c.LastName, u.LastName, 'last name should match');
            System.assertEquals(c.Email, u.Email, 'email should match');
            
            System.assertEquals(activeUser.Username, u.Email + '.iw', 'username should match email');
            Profile profile = getCommerceProfile();
            System.assertEquals(profile.Id, activeUser.ProfileId, 'profile should match');

            PermissionSetGroup permSetGroup = getPermissionSetGroup();
            List<PermissionSetAssignment> psas = [SELECT Id, PermissionSetGroupId, PermissionSetGroup.DeveloperName FROM PermissionSetAssignment WHERE AssigneeId = :u.Id AND PermissionSetGroupId = :permSetGroup.Id];
            System.assertEquals(1, psas.size(), 'should be 1 permission set assigned');
            System.assertEquals(permSetGroup.Id, psas.get(0).PermissionSetGroupId, 'should be permission set ' + UserProfileTriggerHandler.B2B_CUSTOMER_COMMUNITY_USER);
        }

	}

	@IsTest
	static void afterUpdate() {
        User user = [SELECT Id, Contact.AccountId FROM User WHERE Email='iwtest@iwtest.com'];
        
        System.runAs(user) {
            User u = new User();
            u.FirstName = 'f';
            u.LastName = 'l';
            u.Email = 'iwtest1@iwtest.com';
            u.LocaleSidKey = 'en_US';
            u.TimeZoneSidKey = 'America/New_York';
            u.LanguageLocaleKey = 'en_US';
            u.EmailEncodingKey = 'UTF-8';
            insert u;

            Test.startTest();
            u.FirstName = 'f2';
            u.LastName = 'l2';
            u.Email = 'iwtest2@iwtest.com';
            update u;
            Test.stopTest();

            User activeUser = [SELECT Id, ContactId FROM User WHERE Id = :u.Id];
            Contact c = [SELECT Id, FirstName, LastName, Email FROM Contact WHERE Id = :activeUser.ContactId];
            System.assertEquals(c.FirstName, u.FirstName, 'first name should match');
            System.assertEquals(c.LastName, u.LastName, 'last name should match');
            System.assertEquals(c.Email, u.Email, 'email should match');
        }
	}

}
