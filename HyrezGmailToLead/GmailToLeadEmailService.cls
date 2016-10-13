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
		List<Messaging.InboundEmail> pEmailMessageCollection = new List<Messaging.InboundEmail>();
		pEmailMessageCollection.add(email);
		GmailToLead.CreateLeadsFromEmailCollection(pEmailMessageCollection);		
		result.success = true;
		return result;
	}
}