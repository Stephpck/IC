@IsTest(SeeAllData = true)
public with sharing class LightningLoginFormControllerTest {

 @IsTest
 static void LightningLoginFormControllerInstantiation() {
  LightningLoginFormController controller = new LightningLoginFormController();
  System.assertNotEquals(controller, null);
 }

 @IsTest
 static void testIsUsernamePasswordEnabled() {
  System.assertEquals(true, LightningLoginFormController.getIsUsernamePasswordEnabled());
 }

 @IsTest
 static void testIsSelfRegistrationEnabled() {
  System.assertEquals(false, LightningLoginFormController.getIsSelfRegistrationEnabled());
 }

 @IsTest
 static void testGetSelfRegistrationURL() {
  System.assertEquals(null, LightningLoginFormController.getSelfRegistrationUrl());
 }

 @IsTest
 static void testAuthConfig() {
  Auth.AuthConfiguration authConfig = LightningLoginFormController.getAuthConfig();
  System.assertNotEquals(null, authConfig);
 }

 @IsTest
 static void testExperienceId() {
  System.assertEquals(LightningLoginFormController.setExperienceId('12345'), 'This method can be invoked only from within a community.');
  System.assertEquals(LightningLoginFormController.setExperienceId(null), null);
 }

 @IsTest
 static void testLogin() {
  System.assertEquals(LightningLoginFormController.login(null, null, null), null);
 }
}