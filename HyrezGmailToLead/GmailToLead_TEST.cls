@isTest
private class GmailToLead_TEST {
	
	private static final string testPositiveMessageBody = '---------- Forwarded message ---------- From: Test Tester <testsender@testcompany.co.uk> Date: Tue, Sep 1, 2016 at 00:00 AM Subject: A test Email To: "test@testclass.com" <test@testclass.com>';		 
	private static final string testNegativeMessageBody = '---------- Forwarded message ---------- From: Test Tester <testsender@testcompany.co.uk> Date: Tue, Sep 1, 2016 at 00:00 AM Subject: A test Email To: "test@testclass.com" <test@testclass.com>';		 
	
	@isTest static void test_ConvertEmailToLead_NoExistingLead() {

		// Setup test data

		Profile p = [SELECT Id FROM Profile WHERE Name='Standard User'];
    	User testUser = new User(Alias = 'standt', Email='mystandarduser@test.com',EmailEncodingKey='UTF-8', LastName='TestUser', LanguageLocaleKey='en_US',
    	LocaleSidKey='en_GB', ProfileId = p.Id,
    	TimeZoneSidKey='Europe/London', UserName='mystandarduser@test.com');
      	insert testuser;

    	GmailToLeadDailyLimit__c testLimitSetting = new GmailToLeadDailyLimit__c();
    	testLimitSetting.Limit__c = 10;
    	testLimitSetting.SetupOwnerId = testuser.Id;
    	insert testLimitSetting;
		
		Test.startTest();	
		System.runAs(testUser) {
			Lead testLead = GmailToLead.ConvertToLead(testPositiveMessageBody);		
			System.assertNotEquals(null,testLead);
			GmailToLead.CreatTaskForLead(UserInfo.getUserId(), testLead.Id, 'A test Email', testPositiveMessageBody);
			List<Task> testResult = [select Id from Task where OwnerId = : testUser.Id AND Subject = 'A test Email'];
			System.assertEquals(1,testResult.size());
		}
		Test.stopTest();
	}

	@isTest static void test_ConvertEmailToLead_ExistingLead() {
		
		Profile p = [SELECT Id FROM Profile WHERE Name='Standard User'];
    	User testUser = new User(Alias = 'standt', Email='mystandarduser@test.com',EmailEncodingKey='UTF-8', LastName='TestUser', LanguageLocaleKey='en_US',
    	LocaleSidKey='en_GB', ProfileId = p.Id,
    	TimeZoneSidKey='Europe/London', UserName='mystandarduser@test.com');
      	insert testuser;

    	GmailToLeadDailyLimit__c testLimitSetting = new GmailToLeadDailyLimit__c();
    	testLimitSetting.Limit__c = 10;
    	testLimitSetting.SetupOwnerId = testuser.Id;
    	insert testLimitSetting;

    	Lead testExistingLead = new Lead(FirstName = 'Test', LastName='Tester',Email='testsender@testcompany.co.uk', Company='testcompany');
    	insert testExistingLead;
		
		Test.startTest();			System.runAs(testUser) {
			Lead testLead = GmailToLead.ConvertToLead(testPositiveMessageBody);		
			System.assertNotEquals(null,testLead);
			GmailToLead.CreatTaskForLead(UserInfo.getUserId(), testLead.Id, 'A test Email', testPositiveMessageBody);
			List<Task> testResult = [select Id from Task where OwnerId = : testUser.Id AND Subject = 'A test Email'];
			System.assertEquals(1,testResult.size());
		}
		Test.stopTest();
	}	

	@isTest static void test_ConvertEmailToLead_Negatives() {
		
		Profile p = [SELECT Id FROM Profile WHERE Name='Standard User'];
    	User testUser = new User(Alias = 'standt', Email='mystandarduser@test.com',EmailEncodingKey='UTF-8', LastName='TestUser', LanguageLocaleKey='en_US',
    	LocaleSidKey='en_GB', ProfileId = p.Id,
    	TimeZoneSidKey='Europe/London', UserName='mystandarduser@test.com');
      	insert testuser;

    	GmailToLeadDailyLimit__c testLimitSetting = new GmailToLeadDailyLimit__c();
    	testLimitSetting.Limit__c = 10;
    	testLimitSetting.SetupOwnerId = testuser.Id;
    	insert testLimitSetting;
    			
		Test.startTest();	
		System.runAs(testUser) {
			Lead testLead = GmailToLead.ConvertToLead(testNegativeMessageBody);		
			System.assertEquals(null,null);			
		}
		Test.stopTest();
	}	

	@isTest static void test_ConvertEmailToLead_ExceededDailyLimit() {
		
		Profile p = [SELECT Id FROM Profile WHERE Name='Standard User'];
    	User testUser = new User(Alias = 'standt', Email='mystandarduser@test.com',EmailEncodingKey='UTF-8', LastName='TestUser', LanguageLocaleKey='en_US',
    	LocaleSidKey='en_GB', ProfileId = p.Id,
    	TimeZoneSidKey='Europe/London', UserName='mystandarduser@test.com');
      	insert testuser;

    	GmailToLeadDailyLimit__c testLimitSetting = new GmailToLeadDailyLimit__c();
    	testLimitSetting.Limit__c = 10;
    	testLimitSetting.SetupOwnerId = testuser.Id;
    	insert testLimitSetting;
    	
		List<Lead> testLeads = new List<Lead>();
        for(Integer i=0;i<testLimitSetting.Limit__c;i++) {
            testLeads.add(new Lead(FirstName = 'Test'+i,LastName = 'Test'+i,Email=i + 'test@test.com', Company = 'Test', Title = '[GENERATED_BY_GMAIL_TO_LEAD]'));
        }
        insert testLeads;
               		
		Test.startTest();			
		System.runAs(testUser) {
			System.assertEquals(false,GmailToLead.DailyLimitChecker());
			Lead testLead = GmailToLead.ConvertToLead(testPositiveMessageBody);		
			System.assertEquals(null,null);			
		}
		Test.stopTest();
	}	
	
}