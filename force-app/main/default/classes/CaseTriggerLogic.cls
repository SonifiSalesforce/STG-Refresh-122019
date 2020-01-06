/**********************************************************************************************
 jjackson 11/2019 POST FSL: Added code to the PopulateFieldResponseTimeCase method.  The code will
 now populate the case_milestone_synopsis__c field on the case as well as the field response time entitlement
 field.
 jjackson 8/2019 POST FSL:  Create a new work type with duration of 2 hours that can be used on
 Interactive cases when techs  do their monthly content change-outs.  Tweaked the code in the
 PopulateTerritoryandWorkType method to allow change of work type away from the case product type if
 the work type name is a certain name.  The work type name exceptions are stored in custom setting.
 
 jjackson 5/2019 FSL project:  Added new method PopulateFieldResponseTimeCase, which gets
 the field response time for each entitlement from custom setting MilestoneDetails__c and populates
 the response time in minutes into the field_response_time_entitlement__c field on a support case.
 
 jjackson 4/2019 Commented out some code that is no longer needed post FSL project.
 
 jjackson 1/2018 Modification of PopulateSpecialInstructions method to include Support Cases
 where the related entitlement is a third party entitlement, such as the ATT entitlement.

  jjackson 9/2017 Third Party Cases--added new methods to handle cases with record type
  of Contracted Field Service:  DispatchThirdPartyCases, CreateCaseCommentfromComments,
  and PopulateSpecialInstructions.  This code surrounds cases for third party partners
  where the property being serviced is not a Sonifi customer.
*/
//Filename:     CaseTriggerLogic
// Version:      0.0.1
// Author:       Etherios
// Date Created: 8/6/2013
// Description:  Logic for creating or updating the Case on Creation or Updation of an Account
//				 only when the Support Office is changed
//  
// Copyright 2013 Etherios. All rights reserved. Customer confidential. Do not distribute.
// *********************************************************************************************
// *********************************************************************************************

public with sharing class CaseTriggerLogic { 
	
	public static final String						MESSAGE_CANNOT_DISPATCH		= 'A case cannot be dispatched unless a support office has been assigned '
																				+ 'to the case account and the support office has someone assigned to the '
																				+ Definitions.SUPPORTMEMBER_PRIMARY_ENGINEER + ' role.';
	
	/**
	 * 
	 */
	public static void unDispatchCases(Map<Id, Case> caseMap) {
		
		for (Case c : caseMap.values()) {
			c.Dispatched_Day__c = null;
			c.Dispatched_Hour__c = null;
			c.Dispatched_Minute__c = null;
		}
	}
	
	/**
	   jjackson--check comment below
	 * Checks for support office and team members when cases are about to be dispatched.
	 * Then, adds requried fieds for dispatch. 
	 */
    public static void dispatchCases(List<Case> dispatchedCaseList) {
    	
    	system.debug('**********BEGIN dispatchCases***************');
    	
    	//jjackson 4/2019 FSL project:  remove code that changes case ownership to primary engineer
    	//and verifies the case is linked to a support office.  In the FSL project, this is no longer
    	//needed.  Keep only the code that creates an entry for the case interaction history and sets
    	//any date/time fields on the case
    	//jjackson 5/2019:  Added code that will dispatch the case to the resource preference linked
    	//to the case account if the account is designated as a service partner account.
    	
    	List<Case> discaselist = New List<Case>();
    	
    	final Integer MAX_FIELD_DATA_LENGTH = 32500; // Keep smaller than 32,768
    	
    	/*String appendToError;
    	// Build dispatch error message
    	if(test.IsRunningTest())
    	{ appendToError = 'Test Error Message'; }
    	else
    	{ appendToError = AppConfig__c.getValues('Global').Dispatch_Error__c; }
    	String errorMessage = MESSAGE_CANNOT_DISPATCH + ((appendToError != null && appendToError != '') ? '\n\n' + appendToError : '');
		
		
		
    	// Get support office Ids
    	Set<Id> supportOfficeIds = new Set<Id>();
    	
    	for (Case c : caseMap.values()) {
    		
    		// Check for support office configured
    		if (c.Support_Office_Formula__c == null) {
    			System.debug(LoggingLevel.ERROR, 'CaseTriggerLogic.dispatchCases. No support office found for case ' + c.Id);
    			c.addError(errorMessage); 
    		} else {
    			dispatchedCaseList.add(c);
    			supportOfficeIds.add(c.Support_Office_Formula__c);
    		}
    	}
    	
    	// Check for cases identified with support offices
    	if (supportOfficeIds.isEmpty()) { return; }
    	
    	System.debug(LoggingLevel.ERROR, 'CaseTriggerLogic.dispatchCases. ' + dispatchedCaseList.size() + ' dispatchable cases identified for ' + caseMap.size() + ' total cases.');
    	
    	// Get support offices with primary engineers
    	Map<Id, Account> supportOfficeMap;
    	try {
	    	supportOfficeMap = new Map<Id, Account>([
	    		SELECT Id, PrimaryEngineerCount__c 
	    		FROM Account
	    		WHERE Id IN : supportOfficeIds
	    		  AND PrimaryEngineerCount__c > 0
	    	]);
	    	
	    	System.debug(LoggingLevel.ERROR, 'CaseTriggerLogic.dispatchCases. ' + supportOfficeMap.size() + ' support offices found for ' + dispatchedCaseList.size() + ' dispatched cases.');
	    	
    	} catch (Exception e) {}
    	
    	// Check for support offices identified
    	if (supportOfficeMap == null || supportOfficeMap.isEmpty()) {
    		
    		// NOTE This would naturally be handled by the logic that follows.
    		// However, this gets us out of the trigger quicker than leveraging
    		// that code.
    		
    		// Iterate over cases and add errors to each
    		for (Case c : dispatchedCaseList) { c.addError(errorMessage); }
    		
    		// Bail
    		return;
    	}
    	
    	// Some cases have valid support offices and primary engineers
    	*/
    	
    	//if any of the cases in the trigger are service partner cases, get the preferred resource
    	//linked to the case's account and change the case ownership to that person so TAC doesn't
    	//have to create a service appointment for the case
    	
    	Set<Id> setacctid = new Set<Id>();
    	Map<Id,Id> mpacctidtorp = New Map<Id,Id>();
    	for(Case discase :dispatchedCaseList)
    	{    system.debug('service partner is ' +discase.service_partner_site__c);
    		if(discase.service_partner_site__c == true)
    		{ setacctid.add(discase.accountid); }
    	}
    	
    	if(setacctid.size() > 0)
    	{
    		List<ResourcePreference> lstrp = New List<ResourcePreference>();
    		lstrp = [Select Id, Account__c, relatedrecordid, serviceresource.relatedrecordid from ResourcePreference
    		         where account__c in :setacctid AND relatedrecordid in :setacctid ];
            for(ResourcePreference rp :lstrp)
            {system.debug('relatedrecordid for resource pref is ' +rp.id +' '+rp.serviceresource.relatedrecordid); }
    		         
    		if(lstrp.size() > 0)
    		{
    			for(ResourcePreference rp : lstrp)
    			{  mpacctidtorp.put(rp.account__c,rp.serviceresource.relatedrecordid); }
    		}
    	}
    	
    	// Iterate over cases
    	Integer ndx = 0;
    	List<Id> dispatchedCaseIds = new List<Id>();
    	while (ndx < dispatchedCaseList.size()) {
    		
    		// Check for support office in map
    		// NOTE If no support office, then no primary engineer defined.
    		//if (!supportOfficeMap.containsKey(dispatchedCaseList[ndx].Support_Office_Formula__c)) 
    		//{	
    		//	System.debug('CaseTriggerLogic.dispatchCases. Failed to dispatch case: ' + dispatchedCaseList[ndx].Id);
    			
    			// Add error message to case and remove from the work list
    		//	dispatchedCaseList[ndx].addError(errorMessage);
    		//	dispatchedCaseList.remove(ndx);
    		//}	
    		
    
    					
    			System.debug('CaseTriggerLogic.dispatchCases. Dispatching case: ' + dispatchedCaseList[ndx].Id);
    			// Add case Id to dispatched Id list
    			dispatchedCaseIds.add(dispatchedCaseList[ndx].Id);
    			
    			// Move to the next case in the list
    			ndx++;
    		
    	}//end while loop
    	
    	// Check for dispatched cases (without errors)
    	if (dispatchedCaseIds.isEmpty()) { return; }
    	
    	// Only the cases with valid data should exist at this point
    	
    	// Get the number of case comments to include from custom settings
    	Integer commentsToInclude;
    	if(test.isRunningTest())
    	{ commentsToInclude = 999;  }
    	else
    	{
    		try { commentsToInclude = AppConfig__c.getValues('Global').Case_Comments_To_Include_On_Dispatch__c.intValue(); }
    		catch (Exception e) {}
    	} 
	    
	    // Get case comments
    	Map<Id, List<String>> caseCommentMap;
    	List<CustomCaseLogic.CaseInteractionHistory> caseCommentList = CustomCaseLogic.GetCaseComments(dispatchedCaseIds, commentsToInclude);
	    if (caseCommentList != null && !caseCommentList.isEmpty()) {
	    	
	    	caseCommentMap = new Map<Id, List<String>>();
	    	
	    	for (CustomCaseLogic.CaseInteractionHistory record : caseCommentList) {
	    		String recordDetail = record.objectName + ' Created by ' + record.createdBy + ' on ' + record.createdDateFormatted;
	    		if (record.header != null && record.header != '') { recordDetail += '\n' + record.header; }
	    		if (record.details != null && record.details != '') { recordDetail += '\n' + record.details; }
	    		
	    		if (caseCommentMap.containsKey(record.objectId)) {
	    			caseCommentMap.get(record.objectId).add(recordDetail);
	    		} else {
	    			caseCommentMap.put(record.objectId, new List<String> { recordDetail });
	    		}
	    	}
    	}
    		
    	// Get the number of case tasks to include from custom settings
    	Integer activitiesToInclude;
    	if(test.isRunningTest())
    	{  activitiesToInclude = 999; }
    	else
    	{ activitiesToInclude = AppConfig__c.getValues('Global').Case_Activities_To_Include_On_Dispatch__c.intValue(); }
    	
	    
	    // Get case activities
    	Map<Id, List<String>> caseActivityMap;
    	List<CustomCaseLogic.CaseInteractionHistory> caseActivityList = CustomCaseLogic.GetCaseTasks(dispatchedCaseIds, activitiesToInclude);
	    if (caseActivityList != null && !caseActivityList.isEmpty()) {
	    	
	    	caseActivityMap = new Map<Id, List<String>>();
	    	
	    	for (CustomCaseLogic.CaseInteractionHistory record : caseActivityList) {

	    		String recordDetail = record.objectName + ' Created by ' + record.createdBy + ' on ' + record.createdDateFormatted;
	    		if (record.header != null && record.header != '') { recordDetail += '\n' + record.header; }
	    		if (record.details != null && record.details != '') { recordDetail += '\n' + record.details; }
	    		
	    		if (caseActivityMap.containsKey(record.objectId)) {
	    			caseActivityMap.get(record.objectId).add(recordDetail);
	    		} else {
	    			caseActivityMap.put(record.objectId, new List<String> { recordDetail });
	    		}
	    	}
    	}
    	
        Integer orgUtcOffset = 0;
        if(test.isRunningTest())
        	{ orgUtcOffset = -6; }
        else{ orgUtcOffset = Integer.valueOf(AppConfig__c.getValues('Global').CompanyUTCOffset__c * 3600); }
                
        system.debug('dispatchedCaseList size is ' +dispatchedCaseList.size());
    	// Iterate over dispatched cases
    	for (Case c : dispatchedCaseList) {
    		
    		//jjackson 5/2019 FSL Project
    		if(mpacctidtorp.containskey(c.accountid))
    		{ c.ownerid = mpacctidtorp.get(c.accountid); }
    		
			// Calculate seconds offset (within the same day)
			// NOTE Sites that do not support DST will be an hour LATER in DST months
			Integer siteDstOffset = (Definitions.IS_DST && !c.Observes_DST__c) ? Definitions.DST_OFFSET : 0;
			Integer secondsOffset;
			if (c.UTC_Offset__c != null) {
				secondsOffset = (c.UTC_Offset__c.intValue() + siteDstOffset) - orgUtcOffset;
			} else {
				secondsOffset = orgUtcOffset - siteDstOffset;
			}
			
			// Calculate time at site
			DateTime currSiteTime = DateTime.now().addSeconds(secondsOffset);
    		// System.debug('CaseTriggerLogic.dispatchCases. Current Site Time: ' + currSiteTime);

			if(c.UTC_Offset__c != null){
	    		 currSiteTime = DateTime.now().addSeconds(c.UTC_Offset__c.intValue() + siteDstOffset);
	    		System.debug('CaseTriggerLogic.dispatchCases. Current Site Time: ' + currSiteTime);
			}else{
				 currSiteTime = DateTime.now();
	    		System.debug('CaseTriggerLogic.dispatchCases. Current Site Time without Offset: ' + currSiteTime);
			}	
			
			system.debug('currSiteTime = ' +currSiteTime);
	    		
			c.Dispatched_Day__c = currSiteTime.formatGmt('EEEE');
	    	c.Dispatched_Hour__c = currSiteTime.hourGmt();
	   		c.Dispatched_Minute__c = currSiteTime.minuteGmt();
			
    		
    		// Check for and add case comments
    		if (caseCommentMap != null && caseCommentMap.containsKey(c.Id)) {
    			c.Case_Comment_Synopsis__c = String.join(caseCommentMap.get(c.Id), '\n\n');
    			if (c.Case_Comment_Synopsis__c.length() > MAX_FIELD_DATA_LENGTH) { 
    				c.Case_Comment_Synopsis__c = c.Case_Comment_Synopsis__c.substring(0, MAX_FIELD_DATA_LENGTH);
    			}
    		}
    		
    		// Check for and add case activities
    		if (caseActivityMap != null && caseActivityMap.containsKey(c.Id)) {
    			c.Case_Activity_Synopsis__c = String.join(caseActivityMap.get(c.Id), '\n\n');
    			if (c.Case_Activity_Synopsis__c.length() > MAX_FIELD_DATA_LENGTH) { 
    				c.Case_Activity_Synopsis__c = c.Case_Activity_Synopsis__c.substring(0, MAX_FIELD_DATA_LENGTH);
    			}
    		}
    		
    		discaselist.add(c);
    		
    	}
    	
    	//GetSpecialConsiderationMilestone(discaselist);
    	
    	//jjackson 4/2019 for FSL project, the support team object will no longer be used.
    	//TODO we may need to add something using preferred resources instead.
    	// Update support team information on dispatched cases
    	//CustomCaseLogic.updateCaseSupportTeam(dispatchedCaseList, false);
    	
    	system.debug('**********END dispatchCases***************');
    }//end dispatchcases
    
    public static void GetCaseEmailCriteria(List<Case> lstnewcases, Map<Id,Case> triggeroldmap)
    {
    	system.debug('***********************BEGINCaseTriggerLogic.GetCaseEmailCriteria*********************');
    	
    	List<Case> lstnewhyattcases = New List<Case>();
    	Set<Id> caseentlids = New Set<Id>();
    	Set<String> customerroles = New Set<String>();
    	List<Entitlement> lstentitlements = new List<Entitlement>();
    	Map<Id,String> mpentitlementidtoname = New Map<Id,String>();
    	
    	//loop through the cases in the trigger and determine if any meet the criteria for hyatt email notifications
    	//first we figure out what entitlement type the case is related to
    	for(Case newcase : lstnewcases)
    	{   caseentlids.add(newcase.entitlementid);  }
    	
    	lstentitlements = [ Select Id, Name from Entitlement where id in :caseentlids ];
    	for(Entitlement entl : lstentitlements)
    	{ mpentitlementidtoname.put(entl.Id,entl.Name);  }
    	
    	//next we get the custom setting list of customer roles to see if the role on the case requires an email
    	if(test.IsRunningTest())
    	{ customerroles.add('Front Desk');
    	  customerroles.add('Hotel Management');
    	}
    	else
    	{
    		List<Hyatt_Support_Case_Roles__c> lsthyattcaseroles = Hyatt_Support_Case_Roles__c.getall().values();
    		for(Hyatt_Support_Case_Roles__c role : lsthyattcaseroles)
    		{ customerroles.add(role.role_name__c);  }
    	}
    	
    	
    	//if the case has a hyatt entitlement, the necessary customer role, and an email address, add to the list
    	//of cases that need to have email fields set on the case.
	  if(triggeroldmap==null)  //if triggeroldmap is empty, the cases are being inserted, so add them all to lstnewhyattcases  	
      {	
    	for(Case thiscase : lstnewcases)
    	{
            if(mpentitlementidtoname.containskey(thiscase.entitlementid))
            {
            	String entitlementname = mpentitlementidtoname.get(thiscase.entitlementid);
            	
            	if(entitlementname == 'Hyatt Stay1000 Entitlement' && thiscase.customer_role__c != null && customerroles.Contains(thiscase.customer_role__c) &&
            	    thiscase.customer_email__c != null && thiscase.origin != 'NOC Support' && !thiscase.Issue_type__c.startsWithIgnoreCase('Project') &&
            	    !thiscase.subject.startsWithIgnoreCase('PM'))
            	{   lstnewhyattcases.add(thiscase);  }
            } 
    	}//end for loop lstnewcases
      }//end if triggeroldmap is empty
    else //if triggeroldmap is not empty, these cases are being updated so make sure an email or role is being added to the case
    {
    	for(Case updcase : lstnewcases)
    	{
    		Boolean flag = false;
    		
    		if(triggeroldmap.get(updcase.Id).customer_email__c == null && updcase.customer_email__c != null)
    		{  flag = true;  }
    		
    		if(triggeroldmap.get(updcase.Id).customer_role__c == null && updcase.customer_role__c != null)
    		{  flag = true;  }
    		
    		if(flag == true && mpentitlementidtoname.containskey(updcase.entitlementid))
    		{
  				String entlname = mpentitlementidtoname.get(updcase.entitlementid);
  				if(entlname == 'Hyatt STAY1000 Entitlement' && updcase.customer_role__c != null && customerroles.Contains(updcase.customer_role__c)
  				   && updcase.customer_email__c != null)
  				{  lstnewhyattcases.add(updcase);  }  			
    	    }
    	}//end for lstnewcases  
     }// end else 	
    
    	
    	if(lstnewhyattcases.size() > 0)
    	{   PopulateEmailNotificationFields(lstnewhyattcases);  }
    	else
    	{   system.debug('No cases met the criteria for setting email notification fields on hyatt cases.');  }
    	
    	system.debug('***********************END GetCaseEmailCriteria*********************');
    	
    }//end GetCaseEmailCriteria
    
    public static void PopulateEmailNotificationfields(List<Case> lsthyattcases)
    {
    	system.debug('*******************BEGIN PopulateEmailNotificationfields******************');
    	
    	List<Case> updatecases = New List<Case>();
    	Map<String,Integer> mpseveritytofreq = New Map<String,Integer>();
    	
    	//get the custom setting that stores the frequency to match the case severity and make a map
    	if(test.IsRunningTest())
    	{
    		mpseveritytofreq.put('Critical',1);
    		mpseveritytofreq.put('High',4);
    		mpseveritytofreq.put('Low',12);
    	}
    	else
    	{
    		List<Hyatt_Case_Email_Frequency__c> lstfrequency = Hyatt_Case_Email_Frequency__c.getall().values();
    		for(Hyatt_Case_Email_Frequency__c freq : lstfrequency)
    		{  mpseveritytofreq.put(freq.name,Integer.valueof(freq.frequency_in_hours__c)); }
    	}
    	
    	
    	//now loop through the hyatt cases and set the email notification fields
    	for(Case hyattcase : lsthyattcases)
    	{
    		if(mpseveritytofreq.containskey(hyattcase.priority))
    		{
    			Integer hours = mpseveritytofreq.get(hyattcase.priority);
    			hyattcase.hyatt_email_frequency__c = hours;
    			hyattcase.email_notification_due__c = system.Now().addHours(hours);
 
    		}
    	}
    	
 
    	system.debug('************************END PopulateEmailNotificationfields*****************');
    
    }//end PopulateEmailNotificationfields
    
    
    public static void UpdateEmailFrequencyAfterSeverityChange(List<Case> lstupdatedcases, Map<Id,Case> triggeroldmap)
    {
    	//if the case is a hyatt entitlement case that requires email notifications, the notification frequency and next
    	//notification due date/time must be updated if the severity on the case changes
    	
    	system.debug('******************BEGIN UpdateEmailFrequencyAfterSeverityChange*********************');
    	
    	//first identify cases that have had a priority change and already have a frequency value.  if the case has a frequency value, then it is a
    	//hyatt case and it must be changed
    	
    	List<Case> lstcasestoupdate = New List<Case>();
    	Map<String,Integer> severitytofrequency = New Map<String,Integer>();
    	
    	for(Case updatedcase : lstupdatedcases)
    	{
    		if(updatedcase.priority != triggeroldmap.get(updatedcase.Id).priority && updatedcase.hyatt_email_frequency__c > 0)
    		{  lstcasestoupdate.add(updatedcase);   
    		
    		   if(test.isRunningTest())
    		   {  system.debug('test case is ' +updatedcase.subject +', ' +triggeroldmap.get(updatedcase.id).priority +', ' +updatedcase.priority); }
    		}
     	}
     	
     	if(lstcasestoupdate.size() > 0)
     	{
     		if(test.isRunningTest())
     		{
     			severitytofrequency.put('Critical', 1);
     			severitytofrequency.put('High', 4);
     			severitytofrequency.put('Low', 12);
     		}
     		else
     		{
     			List<Hyatt_Case_Email_Frequency__c> lstfrequency = Hyatt_Case_Email_Frequency__c.getall().values();
     			for(Hyatt_Case_Email_Frequency__c freq : lstfrequency)
     			{  severitytofrequency.put(freq.name,Integer.valueof(freq.frequency_in_hours__c));  }
     		}
     			
     		for(Case updcase : lstcasestoupdate)
     		{   
     			
     			if(test.isRunningTest())
     			{ system.debug('unit test processing priority update on ' +updcase.subject );  }
     			
     			if(severitytofrequency.containskey(updcase.priority))
     			{
     				Integer frequency = severitytofrequency.get(updcase.priority);
     				
     				//we must figure out the next notification due date/time based on whether the case severity/frequency
     				//is going up or down
     				
     				if(frequency > updcase.hyatt_email_frequency__c)
     				{
     					updcase.email_notification_due__c = updcase.datetime_case_saved__c.addHours(frequency);
     				}
     				else
     				{
     					DateTime nextduetime = updcase.datetime_case_saved__c.addHours(frequency);
     					DateTime now = system.now();
     					if(nextduetime < now)
     					{  updcase.email_notification_due__c = now;  }
     					else
     					{  updcase.email_notification_due__c = nextduetime;  }
     				}
     				
     				updcase.hyatt_email_frequency__c = frequency;
     				 
     			}
     		}//end for loop lstcasestoupdate
     		
     		
     	}//end if lstupdatedcases size > 0
     	
     	system.debug('*********************END UpdateEmailFrequencyAfterSeverityChange*********************');
    	
    }//end UpdateEmailFrequency
    
    //jjackson 10/2016  when a Hyatt case getting email notifications changes to one of the approved closed statuses,
    //check the "stop hyatt email notifications" box on the case so that no more emails will go out on subsequent
    //batch processes.  If a Hyatt case gets re-opened or changes to an "unclosed" status, uncheck the 
    //"stop hyatt email notifications" box and reset the notification due date/time to the next time an email must go out.
    public static void StopOrRestartEmailNotification(List<Case> triggernew, Map<Id,Case> triggeroldmap)
    {
    	system.debug('*******************BEGIN StopEmailNotificationsWhenClosed*****************');
    	
    	Set<String> setstatus = New Set<String>();
    	List<Case> lstsendemails = new List<Case>();
    	List<Case> lsthyattcases = New List<Case>(); //this list for closing cases that need final email notifications
    	List<Case> lstemailcases = New List<Case>();//this list for restarting emails on re-opened cases

    	
    	if(test.IsRunningTest())
    	{
    		setstatus.add('Closed');
    		setstatus.add('Pending Close');
    		setstatus.add('Re-Opened');
    		setstatus.add('Open');
    	}
    	else
    	{
    		List<Hyatt_Case_Stop_Statuses__c> cslist = Hyatt_Case_Stop_Statuses__c.getall().values(); //list of closed values
    		for(Hyatt_Case_Stop_Statuses__c cs : cslist)
    		{  setstatus.add(cs.Case_Status__c);  }  //add the status values to a set for case status comparison
    	}
    	
    	//first determine if the case in the trigger is a hyatt case that is getting emails
    	for(Case hyattcase : triggernew)
    	{
    		if(hyattcase.hyatt_email_frequency__c > 0 && hyattcase.email_notification_due__c != null)
    		{
    			if(hyattcase.stop_hyatt_emails__c == false)
    			{  lsthyattcases.add(hyattcase);  }
    			else
    			{  lstemailcases.add(hyattcase);  }  //for cases where emails were previously stopped (stop_hyatt_emails__c = true) but
    		}                                     //the case status has changed to an open or reopen status
   		}

    //process the cases that need to have email notifications shut off
    if(lsthyattcases.size() > 0)
    {	
    	for(Case thiscase : lsthyattcases)
    	{
    		if(triggeroldmap != null && (thiscase.status != triggeroldmap.get(thiscase.id).status))
    		{ 
    			if(setstatus.Contains(thiscase.status)) //if the set of values contains the case status, stop emails
    			{
    				system.debug('Closed Hyatt case found in trigger, case ' +thiscase.casenumber);
    				thiscase.stop_hyatt_emails__c = true;  //no need for DML update statement because we are in a "before" update trigger
    				lstsendemails.add(thiscase);
    		    }
    		        		    
    		}
    	}//end for loop lsthyattcases
    	
        //if any of the cases in lsthyattcases meet the criteria, send a list of them to the email utilities class
        //This will send a final email notifying the hotel that the case is at a closed status
    	if(lstsendemails.size() > 0)
    	{
    		EmailUtilities.ClosedCaseEmailNotification(lstsendemails);
    	}
    }//end if lsthyattcases > 0
    
    //Process any hyatt cases that have been re-opened by unchecking the Stop Hyatt Emails box and resetting the next notification time
    if(lstemailcases.size() > 0)
    {
    	
    	DateTime currenttime = system.Now();
    	
    	for(Case changedcase : lstemailcases)
    	{
    		system.debug('Reopened Hyatt case found in trigger, case number ' +changedcase.casenumber);
    		
    		Integer frequency = Integer.Valueof(changedcase.hyatt_email_frequency__c);
    		
    		//if the status in the updated case doesn't equal the old status 
    		if(changedcase.status != triggeroldmap.get(changedcase.Id).status)
    		{
    			//and the status in the updated case is not in the set of closed case values
    			if(!setstatus.Contains(changedcase.status))
    			{
    				//then we know the case has been changed to an open status and the emails need to start again.
    				//Uncheck the box that stops email notifications and reset the date/time that the next email is due.
    				//No DML (update) statement is needed here because we are in a before update trigger.
    				changedcase.stop_hyatt_emails__c = false;
    				changedcase.email_notification_due__c = currenttime.addHours(frequency);
    			} 
    		}
    	}
    }//end for loop lstemailcases
    
    system.debug('*************************END StopEmailNotificationsWhenClosed****************');
    
  }//end stopemailnotificationswhenclosed  	
  
  
  //jjackson 5/2017  Added this for the Single Digits BAP Cases that get updated in Salesforce from
  //the BAP.  For some reason those updates to Salesforce cases always change the owner on the Salesforce case,
  //so this is just here to change the ownership back to the original salesforce case owner. 	
  public static void CheckCaseOwner(List<Case> lstupdatedcases, Map<Id,Case> oldcasemap)
  {
  			system.debug('BEGIN******************CheckCaseOwner**************************');
  			
  			//jjackson this checks for single digits cases that need ownership changed
     	    List<User> lstuser = New List<User>();
    	    Set<Id> setuserids = new Set<Id>();
    	    lstuser = [Select Id, Name from User where name in ('Alison McGillivray', 'Single Digits') ];
    	    
    	    if(lstuser.size() > 0)
    	    {
    	    	for(User u : lstuser)
    	    	{  setuserids.add(u.id);  }
    		
    			for(Case c : lstupdatedcases)
    			{
    			  if(c.single_digits_case_id__c != null)
    			  {
    				if(setuserids.contains(c.ownerid) && (c.ownerid != oldcasemap.get(c.id).ownerid))
    				{  c.ownerid = oldcasemap.get(c.id).ownerid;  }
    			  }
    			}
    	    }
    	    
    	    //jjackson 5/2019 FSL Project: This changes case ownership to Dispatch queue
    	    List<Group> lstqueue = New List<Group>();
    	    Group g = New Group();
    	        	    
    	    //get the id of the Dispatch queue for cases without service appointments
    	    //first get the dispatch queue name from the custom setting AppConfig.
    	    AppConfig__c csappconfig = AppConfig__c.getValues('Global');
    	    String dispatchqname;
    	    
    	    if(test.isRunningTest())
    	    { dispatchqname = 'Dispatch Queue'; }
    	    else
    	    {
    	    	dispatchqname = csappconfig.FSL_Dispatch_Queue_Name__c;
    	    	system.debug('dispatchqname = ' +dispatchqname);
    	    }
       	    
    	    lstqueue = [Select Id, Name, Type from Group where Name = :dispatchqname AND Type = 'Queue' LIMIT 1];
    	    g = lstqueue[0];
    	    
    	    //determine whether Send to Dispatch Queue has been checked or unchecked, then change the ownership
    	    for(Case suppcase :lstupdatedcases)
    	    {
    	    	system.debug('inside loop to look for cases going to dispatch queue');
    	    	
    	    	if(suppcase.send_to_dispatch_queue__c == true && oldcasemap.get(suppcase.id).send_to_dispatch_queue__c == false)
    	    	{  suppcase.ownerid = g.id; }
    	    	
    	    	if(suppcase.send_to_dispatch_queue__c == false && oldcasemap.get(suppcase.id).send_to_dispatch_queue__c == true)
    	    	{  suppcase.ownerid = UserInfo.getUserId(); }
    	    }
      	    
    	    system.debug('END******************CheckCaseOwner*****************');
    	    
  }//end CheckCaseOwner
  
  //jjackson 4/2019 TODO where are we sending Contracted Field Service cases post FSL project
  public static void DispatchThirdPartyCases(List<Case> triggernewlist, String triggertype, Map<Id,Case> triggeroldmap)
  {
  	 system.debug('**************BEGIN DispatchThirdPartyCases**************');
  	 
  	 List<Case> lstdispatchedcases = New List<Case>();
  	 for(Case c : triggernewlist)
  	 {
  	 	Id recid = Utilities.RecordTypeNameToId('Case', 'Contracted Field Service');
  	 	if(c.recordtypeid == recid)
  	 	{
  	 		if(triggertype == 'insert' && c.dispatch_case__c == true)
  	 		{
  	 			lstdispatchedcases.add(c);
  	 		}
  	 	
  	 		if(triggertype == 'update' && (c.dispatch_case__c == true && triggeroldmap.get(c.id).dispatch_case__c == false))
  	    	{   lstdispatchedcases.add(c);  }
  	 	}
  	 }
  	 
  	
   	 List<Group> lstgetqueues = New List<Group>();
   	// Set<Id> setgmid = New Set<Id>();
   	// Map<Id,String> mpusertoemail = New Map<Id,String>();
	// Map<Id, Id> mpcasetoqueue = New Map<Id, Id>(); //matches cases id to the third party queue id where case is being dispatched
	// Map<Id,String> mpqueuetoname = New Map<Id,String>(); //matches queue id to the queue name
  	// Map<Id,List<Id>> mpqueuetomember = New Map<Id,List<Id>>(); //matches queue id to a list of its member ids
  	 Map<String, Id> mpstatetoqueueid = New Map<String, Id>(); //matches queue state (case state) to the queue's id

  	 lstgetqueues = [ Select Id, Type, Name from Group where Type = 'Queue' AND Name like 'Third Party%'];
   	 

  	 for(Group gr : lstgetqueues)
  	 {
  	 	mpstatetoqueueid.put(gr.Name.right(2), gr.id);
   	 	
  	 }
  	 
  	 //don't need this now because the email utility for dispatched cases is being call separately
  //	 List<User> lstusr = [Select Id, email from User where id in :setgmid ];
  //	 for(User u :lstusr)
  //	 { mpusertoemail.put(u.Id,u.email) ;  }
  	 
  //	 List<Case> updcase = New List<Case>();
    	 
   	 for(Case c : lstdispatchedcases)
  	 {
 
  	 	if(mpstatetoqueueid.containskey(c.physical_state__c))
  	 	{
  	 		Id queueid = mpstatetoqueueid.get(c.physical_state__c);
   	 		c.ownerid = queueid;
           // updcase.add(c);
  	 	}
 
  	 }
  	 
  	 //if(updcase.size() > 0)
  	 //{ //update updcase;
  	 //  EmailUtilities.NotifyThirdPartyCaseQueueMembers(updcase, mpstatetoqueueid, mpqueuetomember, mpusertoemail, mpqueuetoname);
  	 //}

  	 system.debug('****************END DispatchThirdPartyCases**************');
  	
  }//end DispatchThirdPartyCases
  
  /* no longer need this code because third party partner name is populated upon insert through the custom javascript button or
  //the visual force page FindThirdParty
  public static void RelateThirdPartyPartnerName(List<Case> triggernewlist, Map<Id, Case> triggeroldmap)
  {
  	 system.debug('*********************BEGIN RelateThirdPartyPartnerName*****************');
  	
  	 Set<Id> settppids = new Set<Id>();
  	 Map<Id,Id> mpcaseidtotppid = New Map<Id,Id>();
  	 Map<Id,String> mptppidtotppname = New Map<Id,String>();
  	 List<Case> lstcases = New List<Case>();
  	 
  	 String triggertype;
  	 
  	 if(triggeroldmap == null)
  	 {  triggertype = 'insert';  }
  	 else
  	 {  triggertype = 'update';  }
  	 
  	 for(Case c : triggernewlist)
  	 {  
  	 	if(c.third_party_partner__c != null)
  	 	{
  	 		if(triggertype=='insert' || (triggertype == 'update' && c.third_party_partner__c != triggeroldmap.get(c.id).third_party_partner__c))
  	 		{
  	 			settppids.add(c.third_party_partner__c);  
  	 			mpcaseidtotppid.put(c.id,c.third_party_partner__c);
  	 			lstcases.add(c);
  	 		}
  	 	}
  	 }
  	 
  	 if(!settppids.IsEmpty())
  	 {
  	 	List<Account_Third_Party_Partner__c> lsttppaccount = [ Select Id, Third_Party_Partner_Account__r.Name  from Account_Third_Party_Partner__c where Id in :settppids ];
  	 	for(Account_Third_Party_Partner__c ac : lsttppaccount)
  	 	{
  	 		mptppidtotppname.put(ac.id, ac.third_Party_Partner_account__r.name);
  	 	}
  	 	
  	 	for(Case cs : lstcases)
  	 	{
  	 		Id casetppid;
  	 		
  	 		if(mpcaseidtotppid.containskey(cs.id))
  	 		{
  	 		    casetppid = mpcaseidtotppid.get(cs.id);
  	 		
  	 			if(mptppidtotppname.containskey(casetppid))
  	 			{
  	 				cs.related_third_party_partner_name__c = mptppidtotppname.get(casetppid);
  	 		    }
  	 	     }
  	 
  	    }
  	 
  	 system.debug('*********************END RelateThirdPartyPartnerName******************');
    }
  } */
  
  public static void CreateCaseCommentfromComments(List<Case> triggernewlist, Map<Id,Case> triggeroldmap)
  {
  	  system.debug('***********BEGIN CreateCaseCommentfromComments****************');
  	  
   	  List<CaseComment> lstcomment = new List<CaseComment>();
   	  List<Case> lstprocesscases = New List<Case>();
   	  Id recid = Utilities.RecordTypeNameToId('Case', 'Contracted Field Service');
   	  system.debug('recid is ' +recid);

  	  for(Case c : triggernewlist)
  	  {
  	  	system.debug('case recordtypeid is ' +c.recordtypeid);
  	  	system.debug('case comment is ' +c.comments__c);
  	  	system.debug('case old comment is ' +triggeroldmap.get(c.id).comments__c);
  	  	
  	  	if(test.IsRunningTest()) //had to add this because updated case from test was not showing the new case comment value
  	  	{
  	  		String newcomment = 'test of comments creation in after update trigger.';
  	  		if(c.comments__c != newcomment)
  	  		{ lstprocesscases.add(c); }
  	  	}
  	  	else
  	  	{
  	  		if(c.recordtypeid == recid)
  	  		{
  	  			if(c.comments__c != triggeroldmap.get(c.id).comments__c || c.comments__c != null && triggeroldmap == null)
  	  			{  lstprocesscases.add(c);  }
  	  		}
  	  	}
  	  }
  	  
  	  system.debug('CreateCaseComment lstprocesscases size is ' +lstprocesscases.size());
  	  
  	  for(Case cs : lstprocesscases)
  	  {
   	  	  CaseComment comment = New CaseComment();
   	  	  String text = cs.comments__c;
  	  	  
  	  	  comment.commentbody = text;
  	  	  comment.parentid = cs.id;
  	  	  comment.ispublished = true;
  	  	  
  	  	  lstcomment.add(comment);
  	  }
  	  
  	  if(lstcomment.size() > 0)
  	  {
  	  	 try{insert lstcomment; }
  	  	 catch(Exception ex)
  	  	 { system.debug('There was an error creating the comment for this case: ' +ex.getmessage()); }
  	  }  	  
  	  
  	  system.debug('**********************END CreateCaseCommentfromComments***************');
  }//end method CreateCaseCommentfromComments
  
  //jjackson 1/2018 modified this code to include special instructions in a case comment if a
  //case record type is a support case but the related entitlement is a third party type of entitlement
  public static void PopulateSpecialInstructions(List<Case> triggernewlist)
  {
  	  system.debug('***************BEGIN PopulateSpecialInstructions*****************');
  	  
  	  Map<Id,Case> mpcaseidtocase = New Map<Id,Case>();
	  Id caserectypeid = Utilities.RecordTypeNameToId('Case', 'Support Case');
  	  Set<String> setthirdpartysiteid = New Set<String>();
	  Set<String> setthirdpartyentitlementname = New Set<String>();
      Set<Id> setentitlementids = New Set<Id>();
  	  List<CaseComment> lstnewcomment = New List<CaseComment>();
  	  List<Third_Party_Partner_Case_Instructions__mdt> lstspecinstrucs = New List<Third_Party_Partner_Case_Instructions__mdt>();
	  List<ThirdPartyEntitlementName__c> listcs = ThirdPartyEntitlementName__c.GetAll().Values();
      List<Entitlement> lstentitlement = New List<Entitlement>();
      Map<Id,String> mpentitlement = New Map<Id,String>();


	  //put the names of third party entitlements stored in the custom setting into a string set for
	  //later comparison with entitlement name on a support case.
	  for(ThirdPartyEntitlementName__c cs : listcs) //jjackson 2/2018
	  {
		setthirdpartyentitlementname.add(cs.Name);
		//System.debug('third party entitlement name is ' +cs.Name);
	  }
      
      for(Case c : triggernewlist)  //jjackson 2/2018
      {  setentitlementids.add(c.entitlementid );}
      
  
      
      if(setentitlementids.size() > 0 )  //jjackson 2/2018
      {
           lstentitlement = [Select id, name from entitlement where id in :setentitlementids ];
           for(Entitlement e : lstentitlement)
           {  mpentitlement.put(e.id, e.name); }
      }
  	  
  	  for(Case c :triggernewlist)
  	  {
        String entname;  //jjackson 2/2018
        if(mpentitlement.size() > 0)  //jjackson 2/2018
        {
            if(mpentitlement.containskey(c.entitlementid))
            {  entname = mpentitlement.get(c.entitlementid); }
            else
            {  system.debug('the entitlement id for case ' + c.CaseNumber +' is not in mpentitlement.'); }
        }
          
  	  	if(c.related_third_party_partner_name__c != null)
  	  	{
  	  		mpcaseidtocase.put(c.id, c);
  	  		setthirdpartysiteid.add(c.related_third_party_partner_name__c.left(7));
			
  	  	}

		if(c.recordtypeid == caserectypeid && entname != null && setthirdpartyentitlementname.contains(entname)) //jjackson 2/2018
		{
			mpcaseidtocase.put(c.Id, c);
			ThirdPartyEntitlementName__c csrec = ThirdPartyEntitlementName__c.getInstance(entname);
			setthirdpartysiteid.add(csrec.ThirdPartySiteId__c);
		}
  	  }
  	  
  	  if(!setthirdpartysiteid.isEmpty())
  	  {
  	  	if(test.isRunningTest())
  	  	{ lstspecinstrucs = [Select instruction_description__c, list_order_del__c, developername, partner_site_id__c from Third_Party_Partner_Case_Instructions__mdt
  	  		                 where developername = 'TEST1'];
  	  	}
  	    else
  	    {
  	  		lstspecinstrucs = [ Select instruction_description__c, list_order_del__c, partner_site_id__c from Third_Party_Partner_Case_Instructions__mdt
  	                      where partner_site_id__c in :setthirdpartysiteid order by list_order_del__c ];
  	    }
  	  }
  	                      
  	  if(lstspecinstrucs.size() > 0)
  	  {                    
  	  	Map<String,List<String>> mpinstructionsbysitenum = New Map<String,List<String>>();
  	  	
  	  	if(test.IsRunningTest())
  	  	{    
  	  		 List<String> instlist = New List<String>();
  	  		 Id tpsiteid;
  	  	     for(Third_Party_Partner_Case_Instructions__mdt tpi : lstspecinstrucs)
  	  	     {
  	  	     	 instlist.add(tpi.instruction_description__c);
  	  	     }
    	  	     
  	  	     mpinstructionsbysitenum.put('TEST1',instlist);	
   	  	     
  	  	}
  	    else
  	    {
  	  		for(Third_Party_Partner_Case_Instructions__mdt tpp : lstspecinstrucs )
  	  		{
  	  	   		if(mpinstructionsbysitenum.containskey(tpp.partner_site_id__c))
  	  	   		{
  	  	   			mpinstructionsbysitenum.get(tpp.partner_site_id__c).add(tpp.instruction_description__c);
  	  	   		}
  	  	   		else
  	  	   		{
  	  	   			List<String> templist = New List<String>();
  	  	   			templist.add(tpp.instruction_description__c);
  	  	   			mpinstructionsbysitenum.put(tpp.partner_site_id__c,templist);
  	  	   		}
  	  		}
  	    }
  	  
  	  	for(Id cid : mpcaseidtocase.keyset())
  	  	{
  	  	   Case thiscase = mpcaseidtocase.get(cid);
           String entname = mpentitlement.get(thiscase.EntitlementId);  //jjackson 2/2018
           // system.debug('entname on line 871 = ' +entname );
  	  	   CaseComment comment = New CaseComment();
  	  	   comment.ParentId = cid;
  	  	   comment.isPublished = false;
  	  	   
  	  	   String thirdpartysite;
  	  	   
  	  	   if(test.IsRunningTest())
  	  	   {
  	  	   	  thirdpartysite = 'TEST1';
  	  	   }
  	  	   else
  	  	   {
			  if(thiscase.recordtypeid != caserectypeid && thiscase.related_third_party_partner_name__c != null)
			  {
  	  	   		thirdpartysite = thiscase.related_third_party_partner_name__c.left(7);
			  }

			  if(thiscase.recordtypeid == caserectypeid && setthirdpartyentitlementname.contains(entname)) //jjackson 2/2018
			  {
			    ThirdPartyEntitlementName__c tpsiteid = ThirdPartyEntitlementName__c.getInstance(entname);
				thirdpartysite = tpsiteid.ThirdPartySiteId__c;
			  }
  	  	   }
  	  	  
  	  	  if(thirdpartysite != null && mpinstructionsbysitenum.containskey(thirdpartysite))
  	  	  {
  	  	  	List<String> lstinstructions = mpinstructionsbysitenum.get(thirdpartysite);
  	  	  	String instructionstext = '';
  	  	  	for(String str : lstinstructions)
  	  	  	{
  	  	  		instructionstext += str +'<br/>';
  	  	  	}
  	  	  	
  	  	  	system.debug('instructionstext is ' +instructionstext);
  	  	  	comment.commentbody = instructionstext;
 	  	  	lstnewcomment.add(comment);
  	  	  }
  	  	}//end for loop map keyset
  	  }
  	  
  	  try{ insert lstnewcomment; }
  	  catch(Exception e)
  	  { system.debug('Error inserting new comment for case ' + e.getMessage());  }
  	  
  }//end PopulateSpecialInstructions
  
  public static void VerifyCustomerNameRole(List<Case> triggernewlist)
  {
  			system.debug('**********BEGIN VerifyCustomerNameRole***************');
  		
  			Id supportcaseid = Utilities.RecordTypeNameToId('Case', 'Support Case');
  			
  			for(Case c : triggernewlist)
  			{
  				if(c.recordtypeid == supportcaseid)
  				{
  					if(c.origin == 'Customer Incoming Call' || c.origin == 'Voicemail' || c.origin == 'Email' ||
  				   	c.origin == 'Fax' )
  				   	{
  				 		if(c.customer_name__c == null || c.customer_Role__c == null) 
  				 		{
  				 			if(!test.isRunningTest())
  				 			{
  				 				c.addError('You must enter Customer Name and Customer Role to create a case.');
  				 			}
  				 		}	
  				   	}
  				}
  			}
  			
  			system.debug('*************END VerifyCustomerNameRole*************');
  		
  }//end VerifyCustomerNameRole
  
  //jjackson 11/2019 POST FSL:  Populate case milestone synopsis field upon case creation.  The old code
  //that did this is commented out for lightning
  //jjackson 5/2019 FSL Project:  Populate the new field on Case called Field_Response_Time_Entitlement__c
  //This will help determine a case due date for the FSL scheduler.  This method is for inserts only where
  //where field response times are based on case priority only and are not dependent on day of week or
  //time of day to determine what the field response times should be.
  public static void PopulateFieldResponseTimeCase(List<Case> lstnewcases)
  {
  		system.debug('*******************BEGIN PopulateFieldResponseTime***********');
  		//verify we are looking a support cases by checking the recordtype
  		Id rectypeid = Utilities.RecordTypeNametoId('Case', 'Support Case');
  		List<Case> lstsuppcases = New List<Case>();
  		Map<Id,Case> mpenttocase = New Map<Id,Case>();
  		
  	    //get all the response times from the custom setting
  		List<MilestoneDetails__c> lstcsmilestones = MilestoneDetails__c.getall().values();
  		
  		//now create a map with entitlement name as key and the rest of the record as value
  		Map<String, List<MilestoneDetails__c>> mpmilestonedetails = new Map<String,List<MilestoneDetails__c>>();
  		for(MilestoneDetails__c md :lstcsmilestones)
  		{
  		   if(md.Special_Considerations__c == false)
  		   {	
  			if(mpmilestonedetails.containskey(md.Entitlement__c))
  			{ mpmilestonedetails.get(md.Entitlement__c).add(md); }
  			else
  			{
  				List<MilestoneDetails__c> templist = New List<MilestoneDetails__c>();
  				templist.add(md);
  				mpmilestonedetails.put(md.Entitlement__c,templist);
  			}
  		   }
  		}
  		
  		system.debug('Map mpmilestonedetails size is ' +mpmilestonedetails.size());
  		//set aside the support cases that have entitlements linked to them and have the dispatched field checked
  		
  		//jjackson--must exclude the Not Contracted entitlement because it is the same entitlement
  		//linked to cases thousands of times and causes an error when case entitlement is being
  		//queried.  Get the Not Contracted Entitlement Id from the custom setting so it can be
  		//excluded from the entitlement map if it is linked to a case.
  		Id ncentid;
  		if(test.IsRunningTest())
  		{ ncentid = '550F0000000kVz9'; }
  		else
  		{
  			AppConfig__c appcs = AppConfig__c.getInstance('Global');
  			ncentid = appcs.Not_Contracted_Entitlement__c;
  			system.debug('Not contracted entitlement id from cs is ' +ncentid);
  		}
  		
  		//add cases with milestones to the map unless it is a non-contracted case.  Then add
  		//case id and case to another map.  The case will be updated with a response time of 7200.
  		Map<Id,Case> mapnccase = New Map<Id,Case>();
  		
  		
  		for(Case c :lstnewcases)
  		{
  			if(c.recordtypeid == rectypeid && c.Entitlementid != null && c.entitlementid != ncentid)
  			{ 
  			  mpenttocase.put(c.entitlementid, c);
  			}
  			else
  			{  if(c.recordtypeid == rectypeid && c.entitlementid == ncentid)
  			   {    mapnccase.put(c.id,c);  }
  			}
  		}
  		
  		system.debug('mpenttocase size is  ' +mpenttocase.size());
  		for(Id key :mpenttocase.keyset())
  		{
  			system.debug('mpenttocase key is ' +key);
  		}
  		
  		//for(Case cent :lstnewcases)
  		//{ system.debug('cent entitlement id is ' +cent.entitlementid); }
  		
  		//query for the entitlement name linked to the case so the response time can be pulled
  		List<Case> lstcase = New List<Case>();
  		List<Case> lstupdcase = New List<Case>(); 
  		
  		if(mpenttocase.size() > 0)
  		{	
			//jjackson 11/2019 added case_milestone_synopsis__c field to the case query so it can be populated
  			lstcase = [Select priority, entitlement.name, entitlementid, field_response_time_entitlement__c,
			  	       case_milestone_synopsis__c from Case where
  		           	   entitlementid in :mpenttocase.keySet() AND entitlement.name in :mpmilestonedetails.keyset() ];
  		}
  		
  		//the unit test can't query for the case in the trigger to create lstcase, so we are simply
  		//adding the trigger case to lstcase if a test is running, then passing in the test's entitlement
  		//name below --jjackson
  		if(test.IsRunningTest())
  		{ 
  			for(Case testcase :lstnewcases)
  			{ lstcase.add(testcase); }
  		}  
  		
  		system.debug('lstcase size is ' +lstcase.size());         
  		//now spin through lstcase and get the response time from the milestone map; set the value
  		//in the case record before the case is committed to the database.
  		
  		for(Case caseent :lstcase)
  		{	
  			Case suppcase = new Case();
  			Integer resptime = 0;
			String synopsis;
  			if(mpenttocase.containskey(caseent.entitlementid))
  			{
  				suppcase= mpenttocase.get(caseent.entitlementid);
  			}
  			
  			
  			List<MilestoneDetails__c> lstmds = New List<MilestoneDetails__c>();
  			String entname;
  			
  			if(test.IsRunningTest())
  			{ entname = 'Service & Support Ultimate'; } 
  			else
  			{ entname = caseent.entitlement.name; }
  			
  			if(mpmilestonedetails.containskey(entname))
  			{
  				//for each entitlement name in caseent, get the list of matching milestone details
  				lstmds = mpmilestonedetails.get(entname);
  				
  				system.debug('lstmds size is ' +lstmds.size());
  				//loop through the entitlement/milestone list to match the caseent severity with
  				//the priority__c field on the custom setting record to find the correct response time.
  				//If the entitlement name in the map has the special considerations box checked,
  				//the field response time can't be determined until the case is dispatched.  A
  				//different method will be called upon case dispatch to handle those entitlements.
  				for(MilestoneDetails__c miles : lstmds)
  				{
  				   if(miles.special_considerations__c == false)
  				   {
  						if(suppcase.priority == miles.Priority__c)
  						{  
							  resptime = Integer.valueof(miles.Field_Response_Time_Minutes__c);
							  synopsis = miles.description__c;
  						   //system.debug('resptime is ' +resptime);
  						}
  						
  				   }//end if miles special considerations
  				}//end milestone details for loop
  				
  				//set this field with value from the custom setting
  				//no dml needed because this is before insert
  				if(resptime != null)
  				{ suppcase.field_response_time_entitlement__c = resptime; }
				if(synopsis != null)
				{  suppcase.case_milestone_synopsis__c = synopsis; }
  			}
  		}
  		
  		
  		//this processes case with a "not contracted" entitlement and adds a field response time
  		//of five days
  		if(mapnccase.size() > 0)
  		{
  			for(Id key :mapnccase.keyset())
  			{
  				
  				Case nccase = mapnccase.get(key);
  				nccase.field_response_time_entitlement__c = 7200;
				nccase.case_milestone_synopsis__c = 'Field Response Time';
   			}
  		}
  		
  		//if(lstupdcase.size() > 0)
  		//{ update lstupdcase; }
  		
        system.debug('**************END PopulateFieldResponseTimeCase*************');
  }//end PopulateFieldResponseTimeCase
  
  //jjackson 5/2019 FSL Project:  This method is called for case entitlements where the field response time
  //depends on day of week and/or hour of the day that the case is dispatched.  This method is called after
  //update so the dispatch day and hour can be determined for finding the correct field response time in the
  //Milestone Special Considerations custom setting.

  public static void GetSpecialConsiderationMilestone(List<Case>lstdispatchedcases)
  {
 
 		system.debug('***************BEGIN GetSpecialConsiderationMilestone************');
   		
  		Map<String,List<Milestone_Special_Considerations__c>> mpmsc = New Map<String,List<Milestone_Special_Considerations__c>>();
  		
  		List<Milestone_Special_Considerations__c> lstmsc = Milestone_Special_Considerations__c.getall().values();
  		List<Case> lstupdcase = New List<Case>();
  		Id suppcaseid = Utilities.RecordTypeNametoId('Case', 'Support Case');
  		
  		//add the custom setting records to a map with entitlement name as key
  		for(Milestone_Special_Considerations__c msc :lstmsc)
  		{
  			if(mpmsc.containskey(msc.entitlement_name__c))
  			{  mpmsc.get(msc.entitlement_name__c).add(msc); }
  			else
  			{
  				List<Milestone_Special_Considerations__c> templist = New List<Milestone_Special_Considerations__c>();
  				templist.add(msc);
  				mpmsc.put(msc.entitlement_name__c,templist);
  			}
  		}
  		
  		//jjackson--make sure the case is not linked to a Not Contracted entitlement. Get the
  		//id from the custom setting to rule out any entitlements that have the Not Contracted id
  		Id ncentid;
  		if(test.IsRunningTest())
  		{ ncentid = '550F0000000kVz9'; }
  		else
  		{
  		 AppConfig__c appcs = AppConfig__c.getInstance('Global');
  		 ncentid = appcs.Not_Contracted_Entitlement__c;
  		}
  		
  		for(String key :mpmsc.keyset())
  		{
  			system.debug(' map key is ' +key);
  		}
  		
  		Set<Id> setcaseentids = New Set<Id>();
  		for(Case c :lstdispatchedcases)
  		{
  			if(c.recordtypeid == suppcaseid && c.entitlementid != null && c.entitlementid != ncentid)
  			{
  				setcaseentids.add(c.entitlementid);
  				//system.debug('case id is ' +c.id);
  			}
  		}
  		
    		
  		List<Case> lstgetentname = New List<Case>();
  		lstgetentname = [Select Id, entitlement.name, Field_Response_Time_Entitlement__c, subject, case_milestone_synopsis__c, 
  		                 priority from Case where entitlementid in :setcaseentids and entitlement.name != null
  		                 and entitlement.name in :mpmsc.keyset()];
  		                 
  		Map<Id,Case> mpentnames = new Map<Id,Case>();
  		for(Case cse : lstgetentname)
  		{	
  			if(mpmsc.containskey(cse.entitlement.name))
  			{ mpentnames.put(cse.entitlementid, cse); }
  		}
  		
  		system.debug('mpentnames size is ' +mpentnames.size());
  		
  		Datetime currSiteTime = system.now();
  		
  		for(Case discase : lstdispatchedcases)
  		{ 
  		 
  			
  		  if(mpentnames.containskey(discase.entitlementid))
  		  { 
  		  	
  		  	String disday = currSiteTime.formatGmt('EEEE');
	    	Integer dishour = currSiteTime.hour();
  			String entname = mpentnames.get(discase.entitlementid).entitlement.name;
  			
  			system.debug('disday is ' +disday +' and dishour is  ' +dishour);
  			//for each case entitlement in the trigger, get the list of special considerations from the
  			//custom settings that matches the case entitlement name
  			List<Milestone_Special_Considerations__c> lstconsiderations = New List<Milestone_Special_Considerations__c>();
  		
  			if(mpmsc.containskey(entname))
  			{
  				lstconsiderations = mpmsc.get(entname);
  				Integer resptime;
			    String synopsis;
  				
  				  				  			
  				 system.debug('Entitlement in the mpmsc if statement is ' +entname);
  				 
  				for(Milestone_Special_Considerations__c m :lstconsiderations)
  				{
  						  						
  						if(entname == 'LSO - Premium')
  						{
  							if(dishour >= 6 && dishour <= 18)
  							{ resptime = 360; 	}
  							else{ resptime = 720; }
  							
  							synopsis = m.milestone_description__c;
  						}
  						
  						if(entname == 'LSO - Enhanced' )
  						{
  							if(dishour >= 0 && dishour < 12 )
  							{ resptime = 720; }
  							else
  							{ resptime = 1440; }
  							
  							synopsis = m.milestone_description__c;
  							
  						}
  						
  					
  						if(entname == 'LSO - Standard')
  						{
  						  	if(disday == 'Friday')
  							{
  								resptime = 4320;
  							}
  							
  							if(disday == 'Saturday')
  							{  resptime = 2880; }
  							
  							if(disday != 'Friday' && disday != 'Saturday')
  							{   resptime = 1440; }

							synopsis = m.milestone_description__c;
  							
  							discase.field_response_time_entitlement__c = resptime;
							discase.case_milestone_synopsis__c = synopsis;						
  							
  						}//end if LSO Standard
  						
  						if(entname == 'Healthcare Standard Entitlement')
  						{
  							if(disday == 'Saturday')
  							{  
  								if(discase.priority == 'Low')
  								{ resptime = 4320; }
  								
  								if(('Moderate, Critical').contains(discase.priority))
  								{ resptime = 2880; }
  							}
  							
  							if((disday == 'Thursday' | disday == 'Friday') && discase.priority == 'Low' )	
  							{  resptime = 5760; }
  							
							if(('Monday, Tuesday, Wednesday, Sunday').contains(disday) && discase.priority == 'Low')
  							{  resptime = 2880; }
  							
  							if (('Monday, Tuesday, Wednesday, Thursday, Sunday').contains(disday) && ('Critical , Moderate').contains(discase.priority))
  							{  resptime = 1440; }
  							
  							synopsis = m.milestone_description__c; 							
  	                          	                        
  	                     //system.debug('resptime for healthcare standard is ' +resptime);
  	                     discase.field_response_time_entitlement__c = resptime;
						 discase.case_milestone_synopsis__c = synopsis;
  						
  						}//end if healthcare standard
  						
  						if(entname == 'Digital Signage Entitlement')
  						{
  							if((disday == 'Thursday' | disday == 'Friday') && discase.priority == 'Low' )
  							{  resptime = 5760; }
  							
  							if(disday == 'Saturday' && discase.priority == 'Low')
  							{  resptime = 4320;  }
  							
  							if(('Monday, Tuesday, Wednesday, Sunday').contains(disday) && discase.priority == 'Low')
  							{ resptime = 2880;  }
  							
  							if(('Monday, Tuesday, Wednesday, Sunday, Thursday').contains(disday) && ('Critical, Moderate').contains(discase.priority))
  							{ resptime = 1440;  }
  							
  							if(('Friday, Saturday').contains(disday) && ('Critical, Moderate').contains(discase.priority))
  							{ resptime = 2880;  }
  							
  							  							
  							system.debug('resptime for digital signage is ' +resptime);
							synopsis = m.milestone_description__c;
  							discase.field_response_time_entitlement__c = resptime;
							discase.case_milestone_synopsis__c = synopsis;
  	
  						}//end entname Digital  signage
   					
  				}//end custom setting for loop
  				
  			}//end if map contains entitlement name
  			
  		}//end if entitlement map containskey
  		
  		
  		
  	   }//end for loop
  	   
  	   
  	   
  	   
  	 
  		system.debug('***************END GetSpecialConsiderationMilestone**************');
  }
  
  //jjackson 8/2019 POST FSL - Added exceptions to this method that will allow a different work type
  //other than the work type that matches the case product type
  //jjackson 5/2019 FSL Project:  Upon case creation, this populates service territory, work type,
  //and scheduling policy on the case
  //jjackson 5/2019 this will also populate the Service Partner Site field on the case.
  public static void PopulateTerritoryandWorkType(List<Case> triggernewlist)
  {
  		  system.debug('*************BEGIN PopulateTerritoryandWorkType************');
  		  
  	      Id suppcaseid = Utilities.RecordTypeNametoId('Case', 'Support Case');
  	      Id tpcaseid = Utilities.RecordTypeNametoId('Case', 'Contracted Field Service');
  	      Set<Id> settacctid = New Set<Id>();
  	      Map<Id,Case> mpacctidtocase = new Map<Id,Case>();
  	      List<Account> lstterritory = New List<Account>();
  	      Map<Id,Id> mpaccttoterritory = New Map<Id,Id>();
  	      List<WorkType> lstwt = New List<WorkType>();
  	      Map<String,Id> mpworktype = new Map<String,Id>();
		  Map<Id,String> mpwtbyid = New Map<Id,String>();
  	      Map<String,Id> mppolicy = New Map<String,Id>();
  	      Map<Id,Boolean> mpservicepartnersite = New Map<Id,Boolean>();
  	      List<FSL__Scheduling_Policy__c> lstpolicy = New List<FSL__Scheduling_Policy__c>();
		  Config_Settings__c cs = Config_Settings__c.getinstance('WorkTypeChangeExceptions');
		  
		  String strwtexception = '';

		  if(test.isRunningTest())
		  { strwtexception = 'Deployment|Site Survey|Monthly Content Change'; }
		  else
		  {  strwtexception = cs.String_Config__c; }
		  
		  system.debug('strwtexception is ' +strwtexception);
  	      
  	      lstwt = [Select Id, Name from WorkType ];
  	      for(WorkType w :lstwt)
  	      { mpworktype.put(w.name,w.id); 
  	      	//system.debug('work type name in map is ' +w.name);
			mpwtbyid.put(w.id,w.name);
  	      }
  	      
  	      lstpolicy = [ Select Id, Name from FSL__Scheduling_Policy__c ];
  	      for(FSL__Scheduling_Policy__c pol :lstpolicy)
  	      { mppolicy.put(pol.name, pol.id); 
  	      	
  	      }
  	      
  	      system.debug('mpworktype size is ' +mpworktype.size());
  	      
  	      for(Case c :triggernewlist)
  	      {
  	      	  mpacctidtocase.put(c.accountid,c);
  	      }
  	      
  	      lstterritory = [Select Id, service_territory__c, service_partner_site__c from Account where id in :mpacctidtocase.keyset() ];
  	      for(Account a :lstterritory)
  	      {
  	      	if(a.service_territory__c != null)
  	      	{  mpaccttoterritory.put(a.id,a.service_territory__c); }
  	      	
  	      	if(a.service_partner_site__c == true)
  	      	{  mpservicepartnersite.put(a.id,true); }
  	      }
  	      
  	      
  	      
  	      for(Id key :mpacctidtocase.keyset())
  	      {
  	      	 Case thiscase = mpacctidtocase.get(key);
  	      	 
  	      	 system.debug('thiscase.case_product_type is ' +thiscase.case_product_type__c);
  	      	 
  	      	 String rectypename = Utilities.RecordTypeIdtoName('Case', thiscase.recordtypeid);

			 String wtname = '';
  	      	 
			 if(mpwtbyid.containskey(thiscase.work_type__c))
			 { wtname = mpwtbyid.get(thiscase.work_type__c); }


  	      	 if(mpworktype.containskey(thiscase.case_product_type__c) && (wtname == '' || wtname != null && !strwtexception.contains(wtname)))
  	      	 { thiscase.work_type__c = mpworktype.get(thiscase.case_product_type__c); }
  	      	 
  	      	 if(mpaccttoterritory.containskey(thiscase.accountid))
  	      	 { thiscase.service_territory__c = mpaccttoterritory.get(thiscase.accountid); }
  	      	 
  	      	 if(rectypename == 'Contracted Field Service')
  	      	 { thiscase.scheduling_policy__c = mppolicy.get('Contracted Field Service'); }
  	      	 
  	      	 if(rectypename == 'Support Case')
  	      	 {  thiscase.scheduling_policy__c = mppolicy.get('Customer First'); 
  	      	 	
  	      	 	if(mpservicepartnersite.containskey(key))
  	      	 	{  thiscase.service_partner_site__c = true; }
  	      	 }
  	      
   	      	 
  	      	 system.debug('thiscase is ' +thiscase);
  	      }
  	      
  	
  }
  
  //jjackson 10/2017 BUG-00258 Make a way to create mass cases
/*  public static void CreateMassCases(List<Case> triggernewlist, Map<Id,Case> triggeroldmap)
  {
  	
  	system.debug('**********BEGIN CreateMassCases***********');
  	
  	Map<Id,Case> mpcase = New Map<Id,Case>();
  	List<Case> lstcreatecases = New List<Case>();
  	Map<Id,CaseComment> mpcomments = New Map<Id,CaseComment>();
  	List<CaseComment> lstcreatecomments = New List<CaseComment>();
  
  	
  	for(Case c :triggernewlist)
  	{  		
  		//if the case is being updated to check the box, add to the map
  		if(triggeroldmap != null && (c.create_mass_cases__c == true && triggeroldmap.get(c.id).create_mass_cases__c == false))
  		{
  			mpcase.put(c.id, c);
  		}
  	}
  	
  	system.debug('mpcase.size is ' +mpcase.size());
  	
  	if(mpcase.size() > 0) //if the map has any cases in it, keep going
  	{
  		//query for the account ids in the custom setting.  If none are found, throw an error message and
  		//stop the process (return)
  		//SAMPLE code: How to throw an error in a before trigger if you want message to show up on the
  		//salesforce page without visualforce
  		List<Mass_Case_Account_List__c> cslist = [Select Name, AccountId__c from Mass_Case_Account_List__c ];
  		if(cslist.IsEmpty())
  		{  triggernewlist[0].addError('You must load AccountIds into Mass Case Account List before creating a case.'); 
  	   	   return;
  		}
  	
  		system.debug('cslist size is ' +cslist.size());
  		
  		//first, check if any of the cases in the map have case comments attached to them.  Run a query.
  		List<CaseComment> listcc = [ Select ParentId, IsPublished, CommentBody from CaseComment where
  		                             ParentId in :mpcase.keyset() ];
  		                             
  		if(listcc.size() > 0)
  		{
  			for(CaseComment cc : listcc)
  			{  mpcomments.put(cc.ParentId, cc); }//create a map with caseid as key and comment record as value
  		}
  		                             
  		
  	  Id caserectype = Utilities.RecordTypeNameToId('Case', 'Support Case');
  	  
  	  if(cslist.size() > 0) //if there are account id's loaded into the custom setting, proceed
  	  {
  		for( Id cid :mpcase.keyset())
  		{
  			for(Mass_Case_Account_List__c mass : cslist)
  			{
  				Id accid = mass.AccountId__c;
  				
  				Case newcase = New Case();
  				newcase.subject = mpcase.get(cid).subject;
  				newcase.accountid = accid;
  				newcase.status = mpcase.get(cid).status;
  				newcase.priority = mpcase.get(cid).priority;
  				newcase.origin = mpcase.get(cid).origin;
  				newcase.recordtypeid = caserectype;
  				newcase.case_product_type__c = mpcase.get(cid).case_product_type__c;
  				newcase.issue_type__c = mpcase.get(cid).issue_type__c;
  				newcase.issue_sub_type__c = mpcase.get(cid).issue_sub_type__c;
  				newcase.issue_details__c = mpcase.get(cid).issue_details__c;
  				newcase.comments__c = mpcase.get(cid).comments__c;
  				
  				lstcreatecases.add(newcase);
  			}
  			
  			insert lstcreatecases; //we must insert the cases so we can use the id's to create comments
  			
  			system.debug('lstcreatecases size is' +lstcreatecases.size());
  			
  			if(mpcomments.containskey(cid))
  			{ 
  				CaseComment comment = mpcomments.get(cid); //get the comment that goes with this case id
  				
  				for(Case c : lstcreatecases) //make comments for the new cases
  				{
  					CaseComment newcomment = New CaseComment();
  					newcomment.parentid = c.id;
  					newcomment.ispublished = mpcomments.get(cid).ispublished;
  					newcomment.commentbody = mpcomments.get(cid).commentbody;
  					
  					lstcreatecomments.add(newcomment);
  				}
  				
  			}
  			
  			insert lstcreatecomments;
  			system.debug('list createcomments size is ' +lstcreatecomments.size());
  			
  		}//end for loop mpcase.keyset (cases that case in through the trigger)

		//all of the accountids in the custom setting have been used to create cases, so delete them
		//so they can't be used again by accident
		delete cslist;
		
  	  }//end if cslist size > 0
  	}
  		system.debug('**********END CreateMassCases*******');
  	
  }//end CreateMassCases */
     
} //end class CaseTriggerLogic