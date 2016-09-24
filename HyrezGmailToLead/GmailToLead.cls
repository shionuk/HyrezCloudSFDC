/*
Author: 		Shion Earl-Krogseth - @shionuk
Date:   		22/09/2016
Description:	APEX code block for Email service that takes in 
				forwarded emails from a Google Mail account and coverts them to leads.
*/
public class GmailToLead {	
	private static final string GmailForwardMarker = '---------- Forwarded message ----------'; 
	public static Lead ConvertToLead(string pEmailTextBody)
	{
		try {
			Lead leadRecord;
			if(DailyLimitChecker()) {				
				leadRecord = ParseForwardHeaderBlockToLead(pEmailTextBody);				
				if(leadRecord != null) {
					upsert leadRecord;	
				}			
			}
			return leadRecord;
		} catch(Exception ex) {
			System.debug(ex);
			return null;
		}
	}

	public static void CreatTaskForLead(Id pUserId, Id pLeadId, string emailSubject,string emailBody)
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
				List<Lead> LeadSearch = [select Id FROM Lead where FirstName = : tempFirstName AND LastName = : tempLastName AND Email = : tempEmail LIMIT 1];
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