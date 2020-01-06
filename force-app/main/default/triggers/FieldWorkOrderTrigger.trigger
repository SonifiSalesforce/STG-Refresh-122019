trigger FieldWorkOrderTrigger on WorkOrder (after insert, after update, before insert, before update) {
    
    
    
    List<WorkOrder> fwolist = New List<WorkOrder>();
    List<WorkOrder> installslist = New List<WorkOrder>();
    List<WorkOrder> lsttriggerwo = New List<WorkOrder>();
    Id rectype = Utilities.RecordTypeNameToId('WorkOrder', 'Third Party FWO');
    
    if(trigger.IsInsert)
    {
        if(trigger.IsBefore)
        {
        	//jjackson 4/2019 FSL project
    		//Separate standard work orders into those for break/fix and those for installs/deployments
    		lsttriggerwo = FieldWorkOrderTriggerLogic.AssignRecordTypes(trigger.new);
    		for(WorkOrder wo :lsttriggerwo)
    		{
    			if(wo.caseid != null && wo.sonifi_work_order__c == null)
    			{
    				fwolist.add(wo);
    			}
    			
    			if(wo.sonifi_work_order__c != null && wo.caseid == null)
    			{
    				installslist.add(wo);
    			}
    		}
            FieldWorkOrderTriggerLogic.PopulateWorkOrderUponCreation(fwolist);
            FieldWorkOrderTriggerLogic.PopulateExceptions(fwolist);
        }//end trigger is before
        
        if(trigger.IsAfter)
        {   

            
        	FieldWorkOrderTriggerLogic.CreateFieldWorkOrderEvents(trigger.new);  
        
        
        }
        
    }//end trigger is insert
    
    if(trigger.IsUpdate)
    {
        //there are three methods that look for status changed to Submitted for Billing.  Find those first, then pass them into the
        //methods instead of writing redundant code inside the methods
        //Get the values in custom setting Field_WorkOrder_DoNotProcess to determine whether work order should go through the
        //billing approval process.  If the work order status is at one of the values in the custom setting, it is being
        //send through for a second time so don't created all the related elements
        List<Field_WorkOrder_DoNotProcess__c> lststatus = New List<Field_WorkOrder_DoNotProcess__c>();
        Set<String> statusset = New Set<String>();
        lststatus = Field_WorkOrder_DoNotProcess__c.getall().values();
        for(Field_WorkOrder_DoNotProcess__c cs : lststatus)
        {  statusset.add(cs.Name);  }
        List<WorkOrder> lstupdwo = New List<WorkOrder>();
        List<WorkOrder> lstresubmit = New List<WorkOrder>();
        Map<Id,WorkOrder> mpbillingapproved = New Map<Id,WorkOrder>();
        Set<Id> updid = New Set<Id>();
        
        //jjackson 9/2019  determine whether the work order is for a site survey and exclude from the billing process
        Id ssfwoid = Utilities.RecordTypeNametoId('WorkOrder', 'Site Survey Work Order');

        for(WorkOrder wo : trigger.new)
        {
            if(!statusset.Contains(trigger.newmap.get(wo.id).status))
            {
                if(wo.submit_for_billing__c == true && trigger.oldmap.get(wo.id).submit_for_billing__c == false && wo.recordtypeid != ssfwoid)
                   
                {  lstupdwo.add(wo);  
                	//system.debug('in trigger lstupdwo size is ' +lstupdwo.size());
                }
            }
            else
            {
                if(wo.submit_for_billing__c == true && trigger.oldmap.get(wo.id).submit_for_billing__c == false && wo.recordtypeid != ssfwoid)
                {  lstresubmit.add(wo);  }
            }
            
            //set aside the third party field work orders where billing is approved for sending an email notice
            //jjackson 10/2017
            if(wo.billing_approved__c == true && trigger.oldmap.get(wo.id).billing_approved__c == false &&
               wo.recordtypeid == rectype)
            {  mpbillingapproved.put(wo.id,wo);  }
            
            if(wo.sonifi_work_order__c != null)
            {  installslist.add(wo); }

        }
        

        if(trigger.isBefore)
        {
            if(lstupdwo.size() > 0)
            {  FieldWorkOrderTriggerLogic.PopulateTechField(lstupdwo);  
               
            }
            
            
            
        }
        
        if(trigger.isAfter)
        {   

            //jjackson 9/2019  after a site survey service appointment is created, the
            //site survey fwo ownership is changed to a queue.  Separate fwo's that are for
            //site surveys here then call the email notification method
            
            List<WorkOrder> lstsswo = New List<WorkOrder>();
            
            for(WorkOrder wo :trigger.new)
            {   
                if(wo.site_survey__c != null)
                {   lstsswo.add(wo); }
            }

            if(lstsswo.size() > 0 )
            {   
                Group grp = [Select Name, Id from Group where Name = 'Assign Site Survey FWO'];
                List<Workorder> lstnotifyleads = new List<WorkOrder>();

                for(WorkOrder w :lstsswo)  //for site survey fwos
                {   
                    if(w.ownerid == grp.id && trigger.oldMap.get(w.id).ownerid != grp.id) //if the fwo owner was changed to the queue
                    { lstnotifyleads.add(w); }//then add the work order to a list for the email notification

                    if(lstnotifyleads.size() > 0)
                    { EmailUtilities.NotifyLeadsofSiteSurveyFWO(lstnotifyleads); } //then send the email notification to the lead techs

                }

            }
           



            if(installslist.size() > 0)
            {
                FieldWorkOrderTriggerLogic.LinkAssociatedItems(installslist, trigger.oldmap);
            }
        
            
            if(lstupdwo.size() > 0)
            {   
                FieldWorkOrderTriggerLogic.CreateTripLaborChildLines(lstupdwo); 
                FieldWorkOrderTriggerLogic.StartWorkOrderApprovalProcess(lstupdwo);
                FieldWorkOrderTriggerLogic.EmailUponApproval(lstupdwo);
                
            }

            
            if(lstresubmit.size() > 0)
            {  FieldWorkOrderTriggerLogic.StartWorkOrderApprovalProcess(lstresubmit);  }
            
           if(mpbillingapproved.size() > 0)
           {  EmailUtilities.FieldWorkOrderThirdPartyNotification(mpbillingapproved);  }
            
        }
    }
}//end trigger