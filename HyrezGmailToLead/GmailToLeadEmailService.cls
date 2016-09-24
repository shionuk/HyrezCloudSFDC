/*
Author: 		Shion Earl-Krogseth
Date:   		22/09/2016
Description:	Email service that takes in forwarded emails from a Google Mail account and coverts them to leads.
*/

global class GmailToLeadEmailService implements Messaging.InboundEmailHandler {
	
	global Messaging.InboundEmailResult handleInboundEmail(Messaging.inboundEmail email,
																Messaging.InboundEnvelope env) {
 		System.debug(email.plainTextBody);
		Messaging.InboundEmailResult result = new Messaging.InboundEmailResult();						
		List<User> userRecordByEmail = [select Id from User where Email = : email.fromAddress LIMIT 1];
		if(!userRecordByEmail.isEmpty()){			
			Lead newLead = GmailToLead.ConvertToLead(email.plainTextBody);		
			if(newLead != null)
			{
				GmailToLead.CreatTaskForLead(userRecordByEmail[0].Id, newLead.Id, email.Subject, email.plainTextBody);				
			}
		}		
		result.success = true;
		return result;
	}
}