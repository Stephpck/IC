public without sharing class UserProfileTriggerHandler {
    public static Boolean active = true;
    public static final String B2B_COMMERCE_PROFILE_NAME = 'Customer Community Plus Login IC';
    public static final String B2B_CUSTOMER_COMMUNITY_USER = 'Customer_Community_User';

    public static Boolean ALL_OR_NONE = true;

	public static void handleBeforeInsert(List<User> newUsers) {
        if(active) {
            // validate usernames are not duplicates if profile id is null (null if created inside Experience)
            Set<String> usernames = new Set<String>();
            Map<String, User> usernameMap = new Map<String, User>();

            Id communityProfileId = getCommunityProfileId();

            for(User userValidate : newUsers) {
                if(userValidate.ProfileId == null) {
                    if(String.isNotBlank(userValidate.Email)) {
                        String userUsername = userValidate.Email + '.iw';
                        usernames.add(userUsername);
                        usernameMap.put(userUsername, userValidate);
                    }
                }
            }            
            if(!usernames.isEmpty()) {
                List<User> users = [SELECT Id, Username FROM User WHERE Username IN :usernames];
                if(!users.isEmpty()) {
                    for(User userError : users) {
                        User user = usernameMap.get(userError.Username);
                        user.addError(Label.USERNAME_IS_DUPLICATE);
                    }
                } else {
                    // contact needs account, use account of user creating new user when creating within Experience
                    List<User> loggedInUser = [SELECT Name, AccountId FROM User WHERE Id = :UserInfo.getUserId()];
                    Id accountId = null;
                    if(!loggedInUser.isEmpty()) {
                        accountId = loggedInUser[0].AccountId;
                    }

                    for(User userAdd : newUsers){
                        if(userAdd.ProfileId == null) {
                            userAdd.ProfileId = communityProfileId;
                        }
                        if(userAdd.Username == null) {
                            userAdd.Username = userAdd.Email;
                        }
                        if(userAdd.Alias == null) {
                            userAdd.Alias = getAliasFromUser(userAdd);
                        }
                        userAdd.CommunityNickname = getCommunityNicknameFromUser(userAdd);
                        
                        // if profile id is the community profile id, add a contact if no contact and update username
                        if(userAdd.ProfileId == communityProfileId) {
                            if(userAdd.ContactId == null) {
                                Contact newContact = createB2BContactForUser(userAdd, accountId);
                                userAdd.ContactId = newContact.Id;
                            }
                            userAdd.Username = userAdd.Username + '.iw';
                        }
                    }
                }
            }

		}
	}

    public static void handleAfterInsert(List<User> newUsers) {
        if(active) {
            Id communityProfileId = getCommunityProfileId();

            Set<Id> userIds = new Set<Id>();
			for(User user : newUsers) {
                if(user.ProfileId == communityProfileId) {
                    // add community permission sets if community user
                    userIds.add(user.Id);
                }
			}
			if(!userIds.isEmpty()) {
				createPermissionSetGroupAssignmentsForUsers(userIds);
			}
        }
    }

    public static void handleBeforeUpdate(Map<Id, User> oldMap, Map<Id, User> newMap) {
		if (active) {
            // not updating username automatically, do not need to check duplicates
		}
	}

    public static void handleAfterUpdate(Map<Id, User> oldMap, Map<Id, User> newMap) {
		if(active) {
			Set<Id> updatedContacts = new Set<Id>();
			for(User user : newMap.values()) {
				updatedContacts.add(user.ContactId);
			}
            
            updateExistingContacts(updatedContacts);

		}
	}

    private static Id getCommunityProfileId() {
        Id communityProfileId = null;
        List<Profile> communityProfiles = [SELECT Id FROM Profile WHERE Name = :B2B_COMMERCE_PROFILE_NAME];
        if(communityProfiles.size() > 0) {
            communityProfileId = communityProfiles[0].Id;
        }
        return communityProfileId;
    }

    private static Contact createB2BContactForUser(User u, Id accountId) {
		Contact c = new Contact();
        c.FirstName = u.FirstName;
        c.LastName = u.LastName;
        c.Email = u.Email;
        c.AccountId = accountId; 
		Database.insert(c);
		return c;
	}

    private static String getCommunityNicknameFromUser(User u) {
		String str = getRandomString(); //add random string to prevent duplicates
		String nick = u.FirstName != null ? u.FirstName + u.LastName + str : u.LastName + str;
		if(nick.length() > 40) {
			return nick.substring(0,40);
		}
		return nick;
	}

	private static String getAliasFromUser(User u) {
		String str = getRandomString();
		String alias = u.FirstName != null ? u.FirstName + u.LastName + str : u.LastName + str;
		alias = alias.replace(' ', '');
		if(alias.length() > 8) {
			return alias.substring(0,8);
		}
		return alias;
	}

	private static String getRandomString() {
		Blob blobkey = crypto.generateAesKey(128);
		String key = EncodingUtil.convertToHex(blobkey);
		return key.substring(0,10);
	}

	@future
    private static void createPermissionSetGroupAssignmentsForUsers(Set<Id> userIds) {
		List<PermissionSetGroup> permissionSetGroups = [
			SELECT Id 
			FROM PermissionSetGroup 
			WHERE DeveloperName = :B2B_CUSTOMER_COMMUNITY_USER
		];

		List<PermissionSetAssignment> permissionSetGroupAssignmentsToCreate = new List<PermissionSetAssignment>();
		for(Id userId : userIds) {
			// assign to each user
			for (PermissionSetGroup psg : permissionSetGroups) {
				PermissionSetAssignment psga = new PermissionSetAssignment();
				psga.AssigneeId = userId;
				psga.PermissionSetGroupId = psg.Id;
				permissionSetGroupAssignmentsToCreate.add(psga);
			}
		}
		Database.insert(permissionSetGroupAssignmentsToCreate, ALL_OR_NONE);
	}

    @future
    private static void updateExistingContacts(Set<Id> updatedContacts) {
        // find contact and update fields
        List<Contact> existingContacts = [SELECT Id, FirstName, LastName, Email FROM Contact WHERE Id IN :updatedContacts];
        List<User> updatedUsers = [SELECT Id, FirstName, LastName, Email, ContactId FROM User WHERE ContactId IN :updatedContacts];

        Map<Id, User> contactMappedUsers = new Map<Id, User>();
        for(User u : updatedUsers) {
            contactMappedUsers.put(u.ContactId, u);
        }

        for(Contact c : existingContacts) {
            User contactUser = contactMappedUsers.get(c.Id);
            c.FirstName = contactUser.FirstName;
            c.LastName = contactUser.LastName;
            c.Email = contactUser.Email;
        }

        update existingContacts;

	}
}
