trigger UserProfileTrigger on User (before insert) {
    if(Trigger.isBefore) {
		if(Trigger.isInsert) {
            UserProfileTriggerHandler.handleBeforeInsert((List<User>) Trigger.new);
		}
	}
}