public with sharing class BatchPMWorkOrderCreation {
    
    public static void CreatePMWorkOrders (List<Entitlement> lstentitlements)
    {
        String thismonth = string.valueof(system.today().month());
        system.debug('thismonth is ' +thismonth);
		String monthabbrev;
		String strfrequency;
		if(test.isRunningTest())
		{
			monthabbrev = 'Oct';
			strfrequency = '90';
		}
		else
        { 
			monthabbrev = PMMonthtoString__c.getinstance(thismonth).Abbreviation__c; 
			strfrequency = PMCreation__c.getinstance(monthabbrev).PMFrequency__c;
		}

        system.debug('monthabbrev is ' +monthabbrev);
        system.debug('strfrequency is ' +strfrequency);
		system.debug('PM Batch lstentitlements size is ' +lstentitlements.size());
		
        Id rectypeid = Utilities.RecordtypeNametoId('WorkOrder', 'Preventive Maintenance');
        List<Entitlement> lstbatchent = New List<Entitlement>();
        Set<Id> setacctid = New Set<Id>();
        Set<Id> setentid = New Set<Id>();
        set<Id> setcloseappts = New Set<Id>();
        Map<Id,Id> mpenttosc = New Map<Id,Id>();
        List<WorkOrder> lstpmfwo = New List<WorkOrder>();
		List<WorkOrder> lstupdpmstatus = New List<WorkOrder>();
		List<WorkOrder> lstnewpms = new List<WorkOrder>();
		List<ServiceAppointment> lstclosesa = New List<ServiceAppointment>();
		List<ServiceAppointment> lstupdclosesa = New List<ServiceAppointment>();
		Group pmqueue = [Select Id, Name, Type from Group where Name = 'Schedule PM Field Work Orders' AND Type = 'Queue' LIMIT 1];
		Group spqueue = [Select Id, Name, Type from Group where Name = 'Schedule PM SP Field Work Orders' AND type = 'Queue' LIMIT 1];

		//get the id of the "Completed" queue for work orders to change ownership of closed - incomplete pm fwo's
		Group closedgroup = [Select Id, Name, Type from Group where Name = 'Field Work Order Completed' AND Type = 'Queue' LIMIT 1];

        //loop through the entitlements and set aside those that require PM work orders this month
        if(lstentitlements.size() > 0)
        {
            for(Entitlement ent :lstentitlements)
	        {
	
		        if(strfrequency.contains(string.valueof(integer.valueof(ent.pm_frequency__c))))
		        {  lstbatchent.add(ent);  }
	
	        }
        }

        system.debug('lstbatchent size is ' +lstbatchent.size()); 

        //now that the entitlements are narrowed down to the ones that need PM work orders this month, collect some info
      if(lstbatchent.size() > 0)
      {
        for(Entitlement e :lstbatchent)
        {
            setacctid.add(e.accountid);
            setentid.add(e.id);
            mpenttosc.put(e.id, e.servicecontractid);
        }

        //query for non-closed PM FWO's linked to the same entitlements and close them as Closed - Incomplete
        lstpmfwo = [Select Id, accountid, recordtypeid, status from WorkOrder where accountid in :setacctid AND
		            recordtypeid = :rectypeid AND status = 'New' AND entitlementid in :setentid ] ;  //jjackson status = new means nothing has been done with the previous PM FWO
					
		system.debug('lstpmfwo size is ' +lstpmfwo.size());
		
		for(WorkOrder wo :lstpmfwo)
		{	
			setcloseappts.add(wo.id); //for all the work orders being closed, collect the ids to query for service appointments and close them.
			wo.status = 'Closed - Incomplete';
			wo.ownerid = closedgroup.id;
			lstupdpmstatus.add(wo);
		}
		
		system.debug('number of pm fwos closed incomplete is ' +lstupdpmstatus.size());
		
		if(lstupdpmstatus.size() > 0)
		{  
			try{ update lstupdpmstatus;  }
			catch(Exception e)
			{
				String estring = 'Error in BatchPMWorkOrderCreation trying to close work orders : ' +e.getMessage();
				if(!test.isRunningTest())
				{  CreateErrorPost(estring); }
			}
        }
		
		system.debug('closed all the work orders in lstupdpmstatus');
		
		//query for all the unfinished appointments linked to the incomplete work orders and cancel them
		lstclosesa = [Select Id, status from ServiceAppointment where parentrecordid in :setcloseappts
                      and status not in ('Canceled', 'On-Site Completed') ];

		for(ServiceAppointment sa :lstclosesa)
		{	
				sa.status = 'Canceled';
				lstupdclosesa.add(sa);
		}
		
		if(lstupdclosesa.size() > 0)
		{	
			try
			{  update lstupdclosesa; }
			catch(Exception exc)
			{
				String excep = 'Error changing appointment status to canceled: ' +exc.getMessage();
				
				if(!test.isRunningTest())
				{  CreateErrorPost(excep); }
			}
		}
		
		//
		
		///query for account info to include in the pm work orders and add to a map
		Map<Id,Account> mpaccount = New Map<Id,Account>([Select Id, Name, physical_street_address_line_1__c, physical_city__c, physical_state__c, 
		                                                 physical_postal_code__c, physical_country__c, service_territory__c,  recordtype.name,
														 service_partner_site__c from
 														 Account where id in :setacctid ]);
														 
		WorkType pmwt = [Select Id, Name, estimatedduration from WorkType where Name = 'Preventive Maintenance' LIMIT 1 ];
		
		//now create the PM FWO'service
		
		for(Entitlement ent :lstbatchent)
		{	
			Boolean partner = false;
			String acctrectypename;
			Account a = New Account();

			if(mpaccount.containskey(ent.accountid))
			{
				acctrectypename = mpaccount.get(ent.accountid).recordtype.name;
			}
			else {
				system.debug('line 107 entitlement is ' +ent.id +', ' +ent.accountid);
			}

			String subassetname = ent.asset.name.substringbefore(' ');
			WorkOrder pmfwo = New WorkOrder();
			pmfwo.recordtypeid = rectypeid;

			if(mpaccount.containskey(ent.accountid))
			{  
				Id servterr;
				a = mpaccount.get(ent.accountid);
				if(a.service_territory__c != null)
				{ servterr = a.service_territory__c; }
				partner = a.service_partner_site__c;
				pmfwo.serviceterritoryid = servterr;
				pmfwo.sub_partner_performed_work__c = partner;
			}
			pmfwo.accountid = ent.accountid;
			pmfwo.worktypeid = pmwt.id;

			if(mpaccount.containskey(ent.accountid))
			{ pmfwo.subject = 'PM - ' +mpaccount.get(ent.accountid).name.mid(9,mpaccount.get(ent.accountid).name.length()) +' - ' +Integer.valueof(ent.pm_frequency__c) +' - ' + subassetname; }
			else {
				pmfwo.subject = 'PM - ' +integer.valueof(ent.pm_frequency__c) +' - ' +subassetname;
			}
			pmfwo.assetid = ent.assetid;
			pmfwo.entitlementid = ent.id;
			pmfwo.duration = pmwt.estimatedduration;
			pmfwo.durationtype = 'Hours';
			pmfwo.status = 'New';

			if(mpaccount.containskey(ent.accountid))
			{
				pmfwo.street = a.physical_street_address_line_1__c;
            	pmfwo.city = a.physical_city__c;
            	pmfwo.state = a.physical_state__c;
            	pmfwo.postalcode = a.physical_postal_code__c;
            	pmfwo.country = a.physical_country__c;
			}

			//if the site is a service partner site, put it in a separate queue for the lead techs so they
			//can schedule a service partner to make the visit.  Otherwise it goes in the regular PM queue
			//for PM work orders that need appointments to be scheduled.
			if(partner == false)
			{ pmfwo.ownerid = pmqueue.id; }
			else {
			  pmfwo.ownerid = spqueue.id; 
			}

			if(acctrectypename != null && (acctrectypename == 'Healthcare Site' || acctrectypename == 'Healthcare System/ACO'))
			{ pmfwo.healthcare_site__c = true; }
			
			if(mpenttosc.containskey(ent.id))
			{  pmfwo.servicecontractid = mpenttosc.get(ent.id); }
			
			Date today = system.today();
            Date duedate = today.addDays(integer.valueof(ent.pm_frequency__c));
			Date cutoffdate = duedate.addDays(-1);
			if(cutoffdate != null)
			{ pmfwo.due_date__c = cutoffdate;  }
			
			
			lstnewpms.add(pmfwo);
			
		
		}//end for loop entitlements



        system.debug('lstnewpms size is ' +lstnewpms.size());

      }//end if lstbatchent size

	  Savepoint sp = Database.setSavepoint();											

		if(lstnewpms.size() > 0)
		{	

			Set<Id> setnewpmacctid = New Set<Id>();
			List<WorkOrder> lstcreatepm = New List<WorkOrder>();

			for(WorkOrder wo :lstnewpms)
			{
				setnewpmacctid.add(wo.accountid);
			}

			List<ResourcePreference> lstrp = New List<ResourcePreference>();
			lstrp = [Select Account__c, RelatedRecordId, serviceresource.isActive from ResourcePreference where account__c in :setnewpmacctid 
			         AND serviceresource.isActive = false];

			Map<Id,ResourcePreference> mpacctrp = New Map<Id,ResourcePreference>();

			if(lstrp.size() > 0)
			{

				for(ResourcePreference rp :lstrp)
					if(rp.account__c == rp.relatedrecordid && rp.serviceresource.isActive == false )
					{  mpacctrp.put(rp.account__c, rp); }
			}
			
			for(WorkOrder w :lstnewpms)
			{
				if(mpacctrp != null && mpacctrp.containskey(w.accountid))
				{  system.debug('Account id ' +w.accountid +' has an inactive service resource.'); }
				else {  
				   lstcreatepm.add(w);
				}
			}
			
			if(lstcreatepm.size() > 0)
			{
				try{ insert lstcreatepm; }
				catch(Exception ex)
				{
					String error = 'Error in BatchPMWorkOrderCreation : ' +ex.getMessage();
					if(!test.isRunningTest())
					{  CreateErrorPost(error);  }
					Database.rollback(sp);
				}
			}
		}

    }//end CreatePMWorkOrders

	//if the process errors, it will roll back.  Post the error message to the salesforce support team
	//chatter group so we know there was a problem.
	//SAMPLE code to create a chatter post to a chatter group
	public static void CreateErrorPost(String errmessage)
	{
		CollaborationGroup cgroup = [Select Id, Name from CollaborationGroup where Name = 'SFSupport' LIMIT 1];

		FeedItem postItem = New FeedItem();
		postItem.ParentId = cgroup.id;
		postItem.Type = 'TextPost';
		postItem.Title = 'Error Occurred in BatchPMWorkOrderCreation';
		postItem.Body = errmessage;
		insert postItem;
	}
}//end BatchPMWorkOrderCreation class