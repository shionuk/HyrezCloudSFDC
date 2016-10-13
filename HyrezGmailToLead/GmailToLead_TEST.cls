@isTest
private class GmailToLead_TEST {
	
	private static final string testPositiveMessageBody = '---------- Forwarded message ---------- From: [Test] [Tester] <testsender@testcompany.co.uk> Date: Tue, Sep 1, 2016 at 00:00 AM Subject: A test Email To: "test@testclass.com" <test@testclass.com>';		 
	private static final string testNegativeMessageBody = '---------- Forwarded message ---------- From: [Test] [Tester] <testsender@testcompany.co.uk> Date: Tue, Sep 1, 2016 at 00:00 AM Subject: A test Email To: "test@testclass.com" <test@testclass.com>';		 
	private static final Integer BULK_SIZE = 200;

	@isTest static void test_ConvertEmailToLead_NoExistingLead_Single() {

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
			Lead testLead = GmailToLead.SingleConvertToLead(testPositiveMessageBody);
			System.assertNotEquals(null,testLead);
			GmailToLead.SingleCreateTaskForLead(testUser.Id, testLead.Id, 'A test Email', testPositiveMessageBody);
			List<Task> testTasks = [select Id from Task where OwnerId = : testUser.Id AND Subject = 'A test Email'];
			System.assertEquals(1,testTasks.size());
		}
		Test.stopTest();
	}

	@isTest static void test_ConvertEmailToLead_ExistingLead_Single() {
		
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
		
		Test.startTest();			
		System.runAs(testUser) {
			Lead testLead = GmailToLead.SingleConvertToLead(testPositiveMessageBody);			
			System.assertNotEquals(null,testLead);
			GmailToLead.SingleCreateTaskForLead(testUser.Id, testLead.Id, 'A test Email', testPositiveMessageBody);
			List<Task> testTasks = [select Id from Task where OwnerId = : testUser.Id AND Subject = 'A test Email'];
			System.assertEquals(1,testTasks.size());
		} 
		Test.stopTest();
	}	

	@isTest static void test_ConvertEmailToLead_Negatives_Single() {
		
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
			Lead testLead = GmailToLead.SingleConvertToLead(testNegativeMessageBody);		
			System.assertEquals(null,null);			
		}
		Test.stopTest();
	}	

	@isTest static void test_ConvertEmailToLead_ExceededDailyLimit_Single() {
		
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
            testLeads.add(new Lead(FirstName = 'Test'+i,LastName = 'Test'+i,Email=i + 'test@test.com', Company = i + 'Test', Title = '[GENERATED_BY_GMAIL_TO_LEAD]'));
        }
        
        System.debug('testLeads: ' + testLeads);
        Database.DMLOptions dml = new Database.DMLOptions();
		dml.DuplicateRuleHeader.AllowSave = true; 
        List<Database.SaveResult> sr = Database.insert(testLeads, dml); 

		Test.startTest();			
		System.runAs(testUser) {
			System.assertEquals(false,GmailToLead.DailyLimitChecker());
			Lead testLead = GmailToLead.SingleConvertToLead(testPositiveMessageBody);
			System.assertEquals(null,null);			
		}
		Test.stopTest();
	}	

	@isTest static void test_ConvertEmailToLead_NoExistingLead_Bulkified() {

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
		
		string emailContent = testPositiveMessageBody;
		List<Messaging.inboundEmail> testEmails = new List<Messaging.inboundEmail>();
	    for(Integer i=0;i<BULK_SIZE;i++) {
	    	emailContent = testPositiveMessageBody.replace('[Test]','[Test]'+ i);
	    	emailContent = testPositiveMessageBody.replace('[Tester]','[Tester]'+ i);
	    	emailContent = testPositiveMessageBody.replace('testsender','testsender'+ i);
	    	emailContent = testPositiveMessageBody.replace('testcompany','testcompany'+ i);	    
	    	Messaging.inboundEmail email = new Messaging.inboundEmail();
	    	email.Subject = 'Test'+i;
	    	email.plainTextBody = emailContent;
	    	email.FromAddress = 'testemail@test.com';	    	
	    	testEmails.add(email);
	    }
	  
		Test.startTest();	
		System.runAs(testUser) {
			GmailToLead.CreateLeadsFromEmailCollection(testEmails);
			List<Lead> testLeads = [select Id from Lead];
			System.assertNotEquals(null,testLeads);
			System.assertEquals(200,testLeads.size());	
			List<Task> testTasks = [select Id from Task];
			System.assertEquals(200,testTasks.size());							
		}
		Test.stopTest();
	}


	@isTest static void test_ConvertEmailToLead_ExistingLead_Bulkified() {
		
		Integer LOCAL_BULK_SIZE = BULK_SIZE + 300; 

		Profile p = [SELECT Id FROM Profile WHERE Name='Standard User'];
    	User testUser = new User(Alias = 'standt', Email='mystandarduser@test.com',EmailEncodingKey='UTF-8', LastName='TestUser', LanguageLocaleKey='en_US',
    	LocaleSidKey='en_GB', ProfileId = p.Id,
    	TimeZoneSidKey='Europe/London', UserName='mystandarduser@test.com');
      	insert testuser;

    	GmailToLeadDailyLimit__c testLimitSetting = new GmailToLeadDailyLimit__c();
    	testLimitSetting.Limit__c = LOCAL_BULK_SIZE; 
    	testLimitSetting.SetupOwnerId = testuser.Id;
    	insert testLimitSetting;

    	string emailContent = testPositiveMessageBody;
		List<Messaging.inboundEmail> testEmails = new List<Messaging.inboundEmail>();
	    for(Integer i=0;i<BULK_SIZE;i++) {
	    	emailContent = testPositiveMessageBody.replace('[Test]','[Test]'+ i);
	    	emailContent = testPositiveMessageBody.replace('[Tester]','[Tester]'+ i);
	    	emailContent = testPositiveMessageBody.replace('testsender','testsender'+ i);
	    	emailContent = testPositiveMessageBody.replace('testcompany','testcompany'+ i);	     
	    	Messaging.inboundEmail email = new Messaging.inboundEmail();
	    	email.Subject = 'Test'+i;
	    	email.plainTextBody = emailContent;
	    	email.FromAddress = 'mystandarduser@test.com';	    	
	    	testEmails.add(email);
	    }
		
		Test.startTest();	
		System.runAs(testUser) {			
			System.assertEquals(BULK_SIZE,testEmails.size());	
			GmailToLead.CreateLeadsFromEmailCollection(testEmails);
			List<Lead> testLeads = [select Id from Lead];
			System.assertNotEquals(null,testLeads);
			System.assertEquals(BULK_SIZE,testLeads.size());	
			List<Task> testTasks = [select Id from Task];
			System.assertEquals(BULK_SIZE,testTasks.size());	
			System.debug('Exexuting second CreateLeadsFromEmailCollection.');	
			GmailToLead.CreateLeadsFromEmailCollection(testEmails);
			testLeads = [select Id from Lead];			
			System.assertEquals(BULK_SIZE,testLeads.size());	
			testTasks = [select Id from Task];
			System.assertEquals(BULK_SIZE + BULK_SIZE,testTasks.size());		
		}
		Test.stopTest();
	}	

	@isTest static void test_ConvertEmailToLead_ExceededDailyLimit_Bulkified() {
		
		Profile p = [SELECT Id FROM Profile WHERE Name='Standard User'];
    	User testUser = new User(Alias = 'standt', Email='mystandarduser@test.com',EmailEncodingKey='UTF-8', LastName='TestUser', LanguageLocaleKey='en_US',
    	LocaleSidKey='en_GB', ProfileId = p.Id,
    	TimeZoneSidKey='Europe/London', UserName='mystandarduser@test.com');
      	insert testuser;

    	GmailToLeadDailyLimit__c testLimitSetting = new GmailToLeadDailyLimit__c();
    	testLimitSetting.Limit__c = BULK_SIZE;
    	testLimitSetting.SetupOwnerId = testuser.Id;
    	insert testLimitSetting;
    	
    	string emailContent = testPositiveMessageBody;
		List<Messaging.inboundEmail> testEmails = new List<Messaging.inboundEmail>();
	    for(Integer i=0;i<BULK_SIZE;i++) {
	    	emailContent = testPositiveMessageBody.replace('[Test]','[Test]'+ i);
	    	emailContent = testPositiveMessageBody.replace('[Tester]','[Tester]'+ i);
	    	emailContent = testPositiveMessageBody.replace('testsender','testsender'+ i);
	    	emailContent = testPositiveMessageBody.replace('testcompany','testcompany'+ i);	    
	    	Messaging.inboundEmail email = new Messaging.inboundEmail();
	    	email.Subject = 'Test'+i;
	    	email.plainTextBody = emailContent;
	    	email.FromAddress = 'testemail@test.com';	    	
	    	testEmails.add(email);
	    }

		List<Lead> testLeads = new List<Lead>();
        for(Integer i=0;i<testLimitSetting.Limit__c;i++) {
            testLeads.add(new Lead(FirstName = 'Test'+i,LastName = 'Test'+i,Email=i + 'test@test.com', Company = 'Test', Title = '[GENERATED_BY_GMAIL_TO_LEAD]'));
        }
        insert testLeads;
               		
		Test.startTest();			
		System.runAs(testUser) {
			System.assertEquals(false,GmailToLead.DailyLimitChecker());
			Lead testLead = GmailToLead.SingleConvertToLead(testPositiveMessageBody);		
			System.assertEquals(null,testLead);			
		}
		Test.stopTest();
	}	
	
}