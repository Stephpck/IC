public without sharing class UserProfileTriggerHandler {
    public static Boolean active = true;
    public static final String B2B_COMMERCE_PROFILE_NAME = 'Customer Community Plus Login IC';

	public static void handleBeforeInsert(List<User> newUser) {	
        if(active) {
            Profile communityProfile = [SELECT Id FROM Profile WHERE Name = :B2B_COMMERCE_PROFILE_NAME LIMIT 1];
            for(User user : newUser){
                if(user.ProfileId == null) {
                    user.ProfileId = communityProfile.Id;
                }
            }
		}
	}
}
