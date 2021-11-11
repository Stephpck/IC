trigger UserProfileTrigger on User (before insert, before update, after insert, after update) {
	if(Trigger.isAfter && Trigger.isInsert) {
		UserProfileTriggerHandler.handleAfterInsert((List<User>) Trigger.new);
	} else if(Trigger.isAfter && Trigger.isUpdate) {
		UserProfileTriggerHandler.handleAfterUpdate(Trigger.oldMap, Trigger.newMap);
	} else if(Trigger.isBefore && Trigger.isInsert) {
		UserProfileTriggerHandler.handleBeforeInsert((List<User>) Trigger.new);
	} else if(Trigger.isBefore && Trigger.isUpdate) {
		UserProfileTriggerHandler.handleBeforeUpdate(Trigger.oldMap, Trigger.newMap);
	}
}