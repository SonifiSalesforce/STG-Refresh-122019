// *********************************************************************************************
// Filename:     StandardCaseTrigger
// Version:      0.0.1
// Author:       Etherios
// Date Created: 8/6/2013
// Description:  Trigger on the Case object.
//  
// Copyright 2013 Etherios. All rights reserved. Customer confidential. Do not distribute.
// *********************************************************************************************
// *********************************************************************************************

trigger StandardCaseTrigger on Case (before insert, before update) {

    // Check for trigger processing blocked by custom setting
    try{ 
    	if(AppConfig__c.getValues('Global').BlockTriggerProcessing__c) {
    		return;
    	} else if(CaseTriggerConfig__c.getValues('Global').BlockTriggerProcessing__c) {
			return; 
		}
    }
    catch (Exception e) {}
    
    Id rectypeid = Utilities.RecordTypeNameToId('Case', 'Contracted Field Service');
    Id recsuppid = Utilities.RecordTypeNametoId('Case', 'Support Case');
    List<Case> lstcaseinsert = new List<Case>();
    List<Case> lstdispatchedcases = New List<Case>();
    
    Map<Id, List<Case>> statusChangeCaseMap = new Map<Id, List<Case>>();
    
    // get and store the cases service contract name 
    Map<Id,String> casesServiceContractMap = CustomCaseLogic.casesServiceContracts(Trigger.new);
    
    // Check for NEW trigger
    if (Trigger.isInsert) 
    {   
    	       	// NOTE Dispatched rules do not apply to new cases
          	
        //jjackson 10/2016 verify new support cases contain customer name and role
        CaseTriggerLogic.VerifyCustomerNameRole(trigger.new);
             
            
        for(Case c :trigger.new)
        {
        		if(c.recordtypeid == recsuppid)
        		{  lstcaseinsert.add(c); }
        }
        	
        CaseTriggerLogic.PopulateTerritoryandWorkType(lstcaseinsert);
        CaseTriggerLogic.PopulateFieldResponseTimeCase(lstcaseinsert);
        //CaseTriggerLogic.GetSpecialConsiderationMilestone(lstcaseinsert);
        
        //jjackson 10/2016 this method pertains to Hyatt email notifications under Hyatt MSA	
        CaseTriggerLogic.GetCaseEmailCriteria(lstcaseinsert, trigger.oldmap);

        
     	for (Case c : Trigger.new) {
	        if (statusChangeCaseMap.containsKey(c.AccountId)) {
	        	statusChangeCaseMap.get(c.AccountId).add(c);
	        } else {
	        	statusChangeCaseMap.put(c.AccountId, new List<Case> { c });
	        }
    	}

    	// Process status change ONLY
    	CustomCaseLogic.processStatusChange(statusChangeCaseMap, casesServiceContractMap);
    	
    	return;
           
    }
    
            
    if(trigger.IsUpdate)
    {		
    		//jjackson 5/2017, if a case being updated is a single digits BAP case, check to make sure
    		//the case ownership hasn't changed.
    		List<Case> lstcases = New List<Case>();
    		List<Case> lstthirdparty = New List<Case>();
    		List<Case> lstpopulatecase = New List<Case>();
    		Id tpid = Utilities.RecordTypeNametoId('Case', 'Contracted Field Service');
    		Id suppcaseid = Utilities.RecordTypeNametoId('Case', 'Support Case');
    		
    		for(Case c : trigger.new)
    		{
    			if(c.single_digits_case_id__c != null)
    			{  lstcases.add(c); }
    			else 
    			{	//jjackson 5/2019 FSL Project:  Look for cases that are being dispatched to or undispatched from
    				//the Dispatch queue for creating service appointments
    				if(c.send_to_dispatch_queue__c == true & trigger.oldMap.get(c.id).send_to_dispatch_queue__c == false )
    				{  lstcases.add(c); }
    				
    				if(c.send_to_dispatch_queue__c == false && trigger.oldMap.get(c.id).send_to_dispatch_queue__c == true)
    				{
    					lstcases.add(c);
    				}
    			}
    		
    		    
    		    //if(c.recordtypeid == tpid)
    		    //{
    		    	lstthirdparty.add(c);
    		   // }
    		
    			if(c.recordtypeid == rectypeid || c.recordtypeid == recsuppid)
    			{
    				lstpopulatecase.add(c);
    			}
    		
    		} 
    		
    		system.debug('lstthirdparty size is ' +lstthirdparty.size() +' in the trigger.');
    		
    		//jjackson 5/2019 FSL Project:  The CheckCaseOwner method has been updated to change ownership of the
    		//case to the Dispatch queue under certain conditions
    		
    		
  			
  			if(lstpopulatecase.size() > 0)
  			{  CaseTriggerLogic.PopulateTerritoryandWorkType(lstpopulatecase); }
  			
  			if(lstcases.size() > 0)
    		{  CaseTriggerLogic.CheckCaseOwner(lstcases, trigger.oldmap);  }
    		
    		
    		
            CaseTriggerLogic.DispatchThirdPartyCases(trigger.new, 'update', trigger.oldMap);
    	
    		//jjackson 10/2016 these methods pertain to notification emails for Hyatt MSA cases
    		CaseTriggerLogic.GetCaseEmailCriteria(trigger.new, trigger.oldmap);
    		CaseTriggerLogic.UpdateEmailFrequencyAfterSeverityChange(trigger.new, trigger.oldmap);
    		CaseTriggerLogic.StopOrRestartEmailNotification(trigger.new, trigger.oldmap);
    	
    	    //jjackson all the code below is used to identify Hilton SLA cases that within 2 hours of milestone violation
    		List<Case> casenotificationslist = New List<Case>();
    		
    		//jjackson 4/2019 for FSL project, field techs will no longer own cases, so this won't work
    		/*for(Case caserec : trigger.new)
    		{
    			
    			if((caserec.nearing_expiration__c == true && trigger.oldmap.get(caserec.id).nearing_expiration__c == false) &&
    			   caserec.recordtypeid == recid && (caserec.issue_type__c != null && !caserec.issue_type__c.Contains('Project'))) //don't send notification for project cases
    			{  casenotificationslist.add(caserec);  }
    		}
    		
    		if(casenotificationslist.size() > 0)
    		{ EmailUtilities.PendingCaseViolationNotification(casenotificationslist);  } */
    		
    		//jjackson End of case milestone violation code for Hilton SLA
    	
    }
    

    Boolean hasOld = (Trigger.oldMap != null && !Trigger.oldMap.isEmpty());
    system.debug('hasold = ' +hasOld);
    
    // NOTE This logic assumes the support office field on the Case object WILL NEVER be set
    // explicitly by the user. The Case Support Office field is expected to be set by the 
    // Account trigger ONLY. 
    // 
    // If that changes, this logic will need to be modified to include considerations for
    // changing both Support Office and Dispatched fields simultaneously when each field is
    // dependent upon the other.
    // 
    // DO NOT DO THIS UNLESS ABSOLUTELY NECESSARY!!!  
    List<Case> lstprioritychd = New List<Case>();
    Map<Id, Case> dispatchedCaseMap = new Map<Id, Case>();
    Map<Id, Case> unDispatchedCaseMap = new Map<Id, Case>();
    for (Case c : Trigger.new) {
    	
    	system.debug('case c in trigger dispatched = ' +c.dispatched__c);
    	// Get old case (or empty) for comparisons below
    	Case oldCase;
    	if (hasOld && Trigger.oldMap.containsKey(c.Id)) {
    		oldCase = Trigger.oldMap.get(c.Id);
    	} else {
    		oldCase = new Case();
    	}
    	
    	// Check to be sure we have set the initiated date/time
    	// NOTE This can be missed when using buttons to immediately create support cases
    	if(c.recordtypeid != rectypeid)
    	{  	if (Trigger.isInsert && c.Date_Time_Initiated__c == null)
    		 { c.Date_Time_Initiated__c = DateTime.now(); }
    	}
    	
    	
    	// Check for change in dispatched flag
    	if (c.Dispatched__c && !oldCase.Dispatched__c) { 
    		//dispatchedCaseMap.put(c.Id, c);
    		lstdispatchedcases.add(c);
    		system.debug('lstdispatchedcases size in trigger is ' +lstdispatchedcases.size());
    	} else if (!c.Dispatched__c && oldCase.Dispatched__c) {
    		unDispatchedCaseMap.put(c.Id, c);
    	}
    	
        // Check for status change
        // NOTE Status change is indicated by a change in status from the OLD to NEW triggers
        // OR a change in the dispatched flag between the two.
        if (c.Status != oldCase.Status || (c.Dispatched__c && !oldCase.Dispatched__c)) {
	        if (statusChangeCaseMap.containsKey(c.AccountId)) {
	        	statusChangeCaseMap.get(c.AccountId).add(c);
	        } else {
	        	statusChangeCaseMap.put(c.AccountId, new List<Case> { c });
	        }
        }
        
        
        if(c.dispatched__c == true && c.priority != trigger.oldmap.get(c.id).priority)
        {
        	lstprioritychd.add(c);
        }
        
    }  //end for loop trigger.new
  
    
    //jjackson 4/2019 FSL Project --there will not be an undispatch button on the case any longer
    //and cases will not be owned by field techs.
    // Check for undispatched cases
    //if (!unDispatchedCaseMap.isEmpty()) {
    //    CaseTriggerLogic.unDispatchCases(unDispatchedCaseMap);
    // }
    
    // Check for no cases dispatched
    //jjackson 4/2019 FSL Project:  some code has been commented out in the dispatchCases method;
    //this pertains to finding a support office and the primary engineer.  We no longer will need that
    //post FSL.  However, there is other code in the method that needs to run.  This mainly has to do 
    //with updating the elements in the CaseInteractionHistory when the trigger runs.
    if (lstdispatchedcases.size()> 0) {
        CaseTriggerLogic.dispatchCases(lstdispatchedcases);
        CaseTriggerLogic.GetSpecialConsiderationMilestone(lstdispatchedcases);
    }
    
    // Check for status changes
    if(!statusChangeCaseMap.isEmpty()) {
        CustomCaseLogic.processStatusChange(statusChangeCaseMap, casesServiceContractMap);
    }
    
   // if(lstprioritychd.size() > 0)
   // {
   // 	CaseTriggerLogic.PopulateFieldResponseTimeCase(lstprioritychd);
   // 	CaseTriggerLogic.GetSpecialConsiderationMilestone(lstprioritychd);
   // }
    
 }