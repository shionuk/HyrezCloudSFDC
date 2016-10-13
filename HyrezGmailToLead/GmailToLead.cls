/*
Author: 		Shion Earl-Krogseth - @shionuk
Date:   		22/09/2016
Description:	APEX code block for Email service that takes in 
				forwarded emails from a Google Mail account and coverts them to leads.
				This class provides two execution contexts. 
				1) Single Execution - Method: CreateLeadFromEmail
				2) Bulkified Execution - Method: CreateLeadsFromEmailCollection
*/
public class GmailToLead {	
	private static final string GmailForwardMarker = '---------- Forwarded message ----------'; 
	
	/***************************************************************************
		Single Execution Methods (Suitable to be used inside an Inbound Email Service)
	****************************************************************************/
	public static void CreateLeadFromEmail(Messaging.InboundEmail email){

		List<User> userRecordByEmail = [select Id from User where Email = : email.fromAddress LIMIT 1];
		if(!userRecordByEmail.isEmpty()){			
			Lead newLead = SingleConvertToLead(email.plainTextBody);		
			if(newLead != null)
			{
				SingleCreateTaskForLead(userRecordByEmail[0].Id, newLead.Id, email.Subject, email.plainTextBody);				
				List<Messaging.InboundEmail> pEmailMessageCollection = new List<Messaging.InboundEmail>();
				pEmailMessageCollection.add(email);				
				CreateLeadsFromEmailCollection(pEmailMessageCollection);

			}
		}
	}

	public static Lead SingleConvertToLead(string pEmailTextBody)
	{
		try {
			Lead leadRecord;
			if(DailyLimitChecker()) {								
				leadRecord = SingleParseForwardHeaderBlockToLead(pEmailTextBody);				
				if(leadRecord != null) {
					Database.DMLOptions dml = new Database.DMLOptions();
					dml.DuplicateRuleHeader.AllowSave = true; 
					if(leadRecord.Id != null) {
						Database.SaveResult sr = Database.insert(leadRecord, dml); 		
					} else {
        				Database.SaveResult sr = Database.update(leadRecord, dml); 		
					}					
				}			
			}
			return leadRecord;
		} catch(Exception ex) {
			System.debug(ex);
			return null;
		}
	}

	@TestVisible private static void SingleCreateTaskForLead(Id pUserId, Id pLeadId, string emailSubject,string emailBody)
	{
		try {
			Task taskRecord = new Task();
			taskRecord.Subject = emailSubject;
			taskRecord.Type = 'Email';
			taskRecord.Status = 'Completed';
			taskRecord.Description = emailBody;
			taskRecord.WhoID = pLeadId;
			taskRecord.OwnerId = pUserId;
			insert taskRecord;								
		} catch(Exception ex) {
			System.debug(ex);
			
		}
	}



	/***************************************************************************
		Bulkified Execution Methods 		
	****************************************************************************/
	public static void CreateLeadsFromEmailCollection(List<Messaging.InboundEmail> pEmailMessageCollection)
	{	
		//Firstly lets see if the daily limit has been reached.
		if(DailyLimitChecker()) {

			//While in most cases you will only be presented with one sender address. As good practice we will write the code 
			//so you can do bulk insertion of email from various senders and map them to existing users in Salesforce without
			// breaking limits.			
			set<String> emailAddresses = new set<String>();
			for(Messaging.InboundEmail emailMessage : pEmailMessageCollection){

				Lead tempLead = ParseForwardHeaderBlockToLead(emailMessage.plainTextBody);
				if(!emailAddresses.contains(tempLead.Email)){
				emailAddresses.add(tempLead.Email); 
				}

			}
			System.debug('emailAddresses: ' + emailAddresses);				
			
			//Email addresses must be unique inside the User object so we can use the email address as a key
			//inside a map collection to allow us to create map so we can set record ownership.
			// so later in the code we will get the User Id from it using the fromAddress from the EmailMessage.
			List<Lead> leadRecordByEmail = [select Id,Email from Lead where Email IN : emailAddresses];
			Map<string,Id> LeadEmailToIdCollection = new Map<string,Id>();
			for(Lead leadRecord : leadRecordByEmail){
				LeadEmailToIdCollection.put(leadRecord.Email,leadRecord.Id);
			}

			//In this code we will consider a lead to be unique using the email address used in it. So
			//we will pull in all leads with existing emails addresses and append to these and not create
			//new leads
			List<Lead> existingLeadCollection = [select Id,Name,FirstName,LastName,Email from Lead where Email IN : LeadEmailToIdCollection.keySet()];
			System.debug('LeadEmailToIdCollection: ' + LeadEmailToIdCollection.size());
			System.debug('existingLeadCollection: ' + existingLeadCollection.size());
			Map<string,Lead> ExistingLeadsByEmailCollection = new Map<string,Lead>();
			for(Lead leadRecord : existingLeadCollection){
				ExistingLeadsByEmailCollection.put(leadRecord.Email,leadRecord);
			}

			Map<Messaging.InboundEmail,Lead> emailMessageAndLeadMap = ConvertEmailMessagesToLeads(pEmailMessageCollection,ExistingLeadsByEmailCollection, LeadEmailToIdCollection);
			try {
				if(!emailMessageAndLeadMap.isEmpty()) {
					
					List<Lead> insertLeads = new List<Lead>();
					List<Lead> updateLeads = new List<Lead>();
					
					Database.DMLOptions dml = new Database.DMLOptions();					
					dml.DuplicateRuleHeader.AllowSave = true; 
					dml.DuplicateRuleHeader.runAsCurrentUser = true;

					for(Lead item : emailMessageAndLeadMap.values()){
						if(item.Id == null) {							
							insertLeads.add(item);								
						} else {
							updateLeads.add(item);
						}
					}
					//no upsert method on Database class that supports using Database.DMLOptions
					if(!insertLeads.isEmpty()) {
						System.debug('Inserting new leads.');						
						List<Database.SaveResult> sr = Database.insert(insertLeads,dml);						
					}
					if(!updateLeads.isEmpty()) {
						System.debug('Updating existing leads.');						
						List<Database.SaveResult> sr = Database.update(updateLeads,dml);
					}					
					List<Task> emailActivityForLeads = AddEmailMessagesToLeads(emailMessageAndLeadMap, LeadEmailToIdCollection); 
					if(!emailActivityForLeads.isEmpty()) {
						System.debug('emailActivityForLeads: ' + emailActivityForLeads.size());
						insert emailActivityForLeads;
					}
				}						
			} catch(Exception ex) {
				System.debug(ex);			
			}
		}
	}


	/***************************************************************************
		Helper Methods
	****************************************************************************/

	private static Map<Messaging.InboundEmail,Lead> ConvertEmailMessagesToLeads(List<Messaging.InboundEmail> pEmailMessageCollection, Map<string,Lead> pExistingLeadsByEmailCollection,  Map<string,Id> UserEmailToIdCollection)
	{		
		Map<Messaging.InboundEmail,Lead> returnCollection = new Map<Messaging.InboundEmail,Lead>();
		for(Messaging.InboundEmail emailMessage : pEmailMessageCollection) {
			Lead leadRecord = ParseForwardHeaderBlockToLead(emailMessage.plainTextBody, pExistingLeadsByEmailCollection);			
			//set the record owner if the user exists by searching for their userId using their Email address.
			if(UserEmailToIdCollection.containsKey(emailMessage.fromAddress)){
				leadRecord.OwnerId = UserEmailToIdCollection.get(emailMessage.fromAddress);	
			}
			
			if(leadRecord != null) {

				returnCollection.put(emailMessage,leadRecord);	
			}			
		}
		return returnCollection;		
	}

	private static List<Task> AddEmailMessagesToLeads(Map<Messaging.InboundEmail,Lead> emailMessageAndLeadMap,  Map<string,Id> UserEmailToIdCollection) {

		List<Task> resultCollection = new List<Task>();
		for(Messaging.InboundEmail emailMessage : emailMessageAndLeadMap.keySet()) {
			Task taskRecord = new Task();
			taskRecord.Subject = emailMessage.Subject;
			taskRecord.Type = 'Email';
			taskRecord.Status = 'Completed';
			taskRecord.ActivityDate = System.today();
			taskRecord.Description = emailMessage.plainTextBody;
			taskRecord.WhoID = emailMessageAndLeadMap.get(emailMessage).Id;
			if(UserEmailToIdCollection.containsKey(UserEmailToIdCollection.get(emailMessageAndLeadMap.get(emailMessage).Email))){
				taskRecord.OwnerId = UserEmailToIdCollection.get(emailMessageAndLeadMap.get(emailMessage).Email);
			}		
			resultCollection.add(taskRecord);
		}
		return resultCollection;
	}

	

	private static Lead ParseForwardHeaderBlockToLead(string pEmailTextBody, Map<string,Lead> pExistingLeadsByEmailCollection) {
		
		string tempString;				
		if(pEmailTextBody.contains(GmailForwardMarker)) {						
			Integer startIndex = pEmailTextBody.indexOf(GmailForwardMarker, 0);				
			if(startIndex != -1) {				
				string tempFirstName;
				string tempLastName;
				string tempEmail;				
				startIndex = startIndex + GmailForwardMarker.length();
				tempString = ParseText(pEmailTextBody, 'From:','<', startIndex).trim();				
				tempFirstName = tempString.split(' ')[0];
				tempLastName = tempString.split(' ')[1];				
				tempEmail = ParseText(pEmailTextBody, '<','>', startIndex);		
				System.debug('tempFirstName:' + tempFirstName);
				System.debug('tempLastName:' + tempLastName);										
				Lead leadRecord = pExistingLeadsByEmailCollection.get(tempEmail);
				if(leadRecord == null) {
					leadRecord = new Lead();
					leadRecord.FirstName = tempFirstName;
					leadRecord.LastName = tempLastName;
					leadRecord.Email = tempEmail;
				}								
				leadRecord.Company = ParseText(pEmailTextBody, '@','.', startIndex);
				leadRecord.Description = 'Subject: ' + ParseText(pEmailTextBody, 'Subject:','To:', startIndex) + '\n\n' + pEmailTextBody;
				leadRecord.Title = '[GENERATED_BY_GMAIL_TO_LEAD]';				
				return leadRecord;				
			}
			return null;
		} else {
			return null; 	
		}
	}

	private static Lead SingleParseForwardHeaderBlockToLead(string pEmailTextBody) {
		
		string tempString;				
		if(pEmailTextBody.contains(GmailForwardMarker)) {						
			Integer startIndex = pEmailTextBody.indexOf(GmailForwardMarker, 0);				
			if(startIndex != -1) {				
				string tempFirstName;
				string tempLastName;
				string tempEmail;				
				startIndex = startIndex + GmailForwardMarker.length();
				tempString = ParseText(pEmailTextBody, 'From:','<', startIndex).trim();				
				tempFirstName = tempString.split(' ')[0];
				tempLastName = tempString.split(' ')[1];				
				tempEmail = ParseText(pEmailTextBody, '<','>', startIndex);
				List<Lead> LeadSearch = [select Id FROM Lead where FirstName = : tempFirstName AND LastName = : tempLastName AND Email = : tempEmail LIMIT 1];
				
				System.debug('LeadSearch: ' + LeadSearch);

				Lead leadRecord;
				if(!LeadSearch.isEmpty()) {
					leadRecord = LeadSearch[0];
				} else {
					leadRecord = new Lead();
				}				
				leadRecord.FirstName = tempFirstName;
				leadRecord.LastName = tempLastName;
				leadRecord.Email = tempEmail;
				leadRecord.Company = ParseText(pEmailTextBody, '@','.', startIndex);
				leadRecord.Description = 'Subject: ' + ParseText(pEmailTextBody, 'Subject:','To:', startIndex) + '\n\n' + pEmailTextBody;
				leadRecord.Title = '[GENERATED_BY_GMAIL_TO_LEAD]';	
				System.debug('leadRecord: ' + leadRecord);	
				return leadRecord;				
			}
			return null;
		} else {
			return null; 	
		}
	}

	private static Lead ParseForwardHeaderBlockToLead(string pEmailTextBody) {
		
		string tempString;				
		if(pEmailTextBody.contains(GmailForwardMarker)) {						
			Integer startIndex = pEmailTextBody.indexOf(GmailForwardMarker, 0);				
			if(startIndex != -1) {				
				string tempFirstName;
				string tempLastName;
				string tempEmail;				
				startIndex = startIndex + GmailForwardMarker.length();
				tempString = ParseText(pEmailTextBody, 'From:','<', startIndex).trim();				
				tempFirstName = tempString.split(' ')[0];
				tempLastName = tempString.split(' ')[1];				
				tempEmail = ParseText(pEmailTextBody, '<','>', startIndex);				
				Lead leadRecord = new Lead();	
				leadRecord.FirstName = tempFirstName;
				leadRecord.LastName = tempLastName;
				leadRecord.Email = tempEmail;
				leadRecord.Company = ParseText(pEmailTextBody, '@','.', startIndex);
				leadRecord.Description = 'Subject: ' + ParseText(pEmailTextBody, 'Subject:','To:', startIndex) + '\n\n' + pEmailTextBody;
				leadRecord.Title = '[GENERATED_BY_GMAIL_TO_LEAD]';					
				return leadRecord;				
			}
			return null;
		} else {
			return null; 	
		}
	}



	private static string ParseText(string pEmailTextBody,string pSearchStartText,string pSearchEndText, Integer startIndex) {
		startIndex = pEmailTextBody.indexOf(pSearchStartText, startIndex);	
		Integer endIndex;
		string result;
		if(startIndex != -1){
			startIndex = startIndex	+ pSearchStartText.length();
			endIndex = pEmailTextBody.indexOf(pSearchEndText, startIndex);
			return pEmailTextBody.subString(startIndex,endIndex);
		} else {
			return null;
		}
	}

	@TestVisible private static boolean DailyLimitChecker(){
		List<Lead> result = [select Id from Lead where CreatedDate = TODAY AND Title LIKE '%[GENERATED_BY_GMAIL_TO_LEAD]%'];
		GmailToLeadDailyLimit__c LimitSetting = GmailToLeadDailyLimit__c.getInstance();
		if(result.size() < LimitSetting.Limit__c){
			return true;
		} else {
			return false;
		}
	}

	
}