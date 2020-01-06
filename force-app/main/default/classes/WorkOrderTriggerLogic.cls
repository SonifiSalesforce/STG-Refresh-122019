// Date Modified: 3/18/2014
// Description:  For Enhancement requirement 7.8 and 8.1
/****LOG***********************************************************************************
   shawks 09/03/2019 - BUG-00947 - Comment out ActivateServiceContracts; now done on asset trigger method (StandardAssetTriggerLogic.setEntitleServiceContrDates)
   jjackson 4/2019	Added savepoint and rollback for DML errors when updating assets or creating product activations
   shawks 9/18-10/18   CPQ:        Update code to update out-of-box objects, fields, and references;
                                   Add abbreviations to WorkOrderNameCompareUpdate: BYOD, HCDIG, HCDWB, NOBL
   jjackson 5/2018     BUG-00783   Email notification to Customizations when rack build with Pro:Centric gets a To Warehouse date
   shawks 01/26/2018 - BUG-00775:  Update so Healthcare Notification emails are not sent for non-healthcare work orders (no “Healthcare” project types for its associated items)
   shawks 10/12/2017 - BUG-00752:  Mapping when associated items are sorted remove duplicate lines from TONs
   shawks 09/18/2017 - BUG-00176:  Move Delivery Method to Legal Contract Line Items
   shawks 09/13/2017 - BUG-00744:  3rd Party Turn On Notices sent to incorrect Public Folder for Healthcare Sites
   shawks 06/19/2017 - BUG-00717:  Healthcare Email Notifications
   shawks 02/16/2017 - BUG-00687:  Add Work Order Number to Turn On Notices
   shawks 11/18/2016 - BUG-00680:  Add Project Number to Turn On Notices
/*****************************************************************************************/

public with sharing class WorkOrderTriggerLogic {
	
	//jjackson 11/2014 BUG-00263 when work order is submitted for billing, generate turn on notice after billing approval
	//this must be done before product activations are created because that code sets the flagged_for_billing field back to false
	public static void TurnonNoticeAfterApproval(List<Work_Order__c> lstwotriggernew, Map<Id,Work_Order__c> mptriggerold)
	{
		system.debug('******************************START TurnonNoticeAfterApproval *****************************************');
		Set<String> setwochanged = new set<String>();
		for(Work_Order__c recwo : lstwotriggernew)
		{
		 if(recwo.Approval_Status__c == 'Billing Approved' && recwo.Approval_Status__c != mptriggerold.get(recwo.id).Approval_Status__c||
		    recwo.Approval_Status__c == 'Billing Approved' && mptriggerold.get(recwo.id).Approval_Status__c == null)	

		   {  setwochanged.add(recwo.id); 
		   	  system.debug('work orders added to set are ' +recwo.id);   }
		   	  
		   //system.debug('work order id, approval status, status, billing approval needed are '+recwo.name + ',' +recwo.approval_status__c +', ' + recwo.status__c +',' +recwo.billing_approval_needed__c); 
		 }

		 //we know which work orders had the approval status change, so get the associated items that were flagged for billing
		 //during the approval process
		List<Associated_Item__c> lstbillingitems = new list<Associated_Item__c>();
		lstbillingitems = [Select Id, Name, Quantity__c, Billing_Commencement_Date__c, Status__c, Flagged_for_Billing__c, Submitted_for_Billing__c, Added_to_Turnonnotice__c, Work_Order__c
		                   from Associated_Item__c where Work_Order__c in :setwochanged
		                   AND Added_to_Turnonnotice__c = true AND Status__c in ('Billing', 'De-Installed') ];
		//now we have the correct associated items that were approved for billing, so pass into turn on notice creation code
		system.debug('lstbillingitems is empty = ' +lstbillingitems.IsEmpty());
		List<Associated_Item__c> lstupdai = new List<Associated_Item__c>();
		if(!lstbillingitems.isEmpty())
		{  WorkOrderTriggerLogic.CreateTurnOnNotice(lstbillingitems);  }
	    
	    system.debug('****************************END TurnonNoticeAfterApproval *********************************');
	}

    public static void updateOwner(Map<Id, Work_Order__c> oldMap, List<Work_Order__c> newRecords){
        Utilities.writeLog('**********    START', WorkOrderTriggerLogic.class, 'updateOwner', LoggingLevel.DEBUG); 
         
        Set<ID> contactIds = new Set<ID>();
        Map<Id,Work_Order__c> updateWorkOrders = new Map<Id,Work_Order__c>();
        
        for(Work_Order__c workOrder : newRecords){
            if(workOrder.Assign_Record__c == true && workOrder.Crew_Person_Turnkey__c != null){
                contactIds.add(workOrder.Crew_Person_Turnkey__c);
                updateWorkOrders.put(workOrder.Id, workOrder);
            }
        }
        
        List<User> ownerUsers = [SELECT u.Id, u.Name, u.ContactId FROM User u WHERE u.ContactId IN :contactIds];
        
        Map<ID, User> contactUserMap = new Map<ID, User>();
        for(User ownerUser : ownerUsers){
            contactUserMap.put(ownerUser.ContactId, ownerUser);
        }
        
        for(Work_Order__c updateWorkOrder : newRecords) {
            if(updateWorkOrder.Assign_Record__c == true && updateWorkOrders.containsKey(updateWorkOrder.Id)){
                if(contactUserMap.containsKey(updateWorkOrder.Crew_Person_Turnkey__c)){
                    updateWorkOrder.OwnerId = contactUserMap.get(updateWorkOrder.Crew_Person_Turnkey__c).Id;
                }
            }
            updateWorkOrder.Assign_Record__c = false;
        }
        
        Utilities.writeLog('**********    END', WorkOrderTriggerLogic.class, 'updateOwner', LoggingLevel.DEBUG); 
    }
    

    public static void deleteSitePhoto(List<Work_Order__c> woList)
    {
        Utilities.writeLog('**********    START', WorkOrderTriggerLogic.class, 'deleteSitePhoto', LoggingLevel.DEBUG); 
        
        //Pull Record Type Id for Record Type 'Install' on Work ORder
        ID rtId = Utilities.RecordTypeNameToIdWithObject(Definitions.RECORDTYPE_Install, 'Work_Order__c');
        if(rtId == null)
        {
            Utilities.writeLog('Work Order Install Record Type not found', WorkOrderTriggerLogic.class, 'deleteSitePhoto', LoggingLevel.DEBUG); 
            woList[0].addError('Work Order Install Record Type not found');
        }
        Set<ID> accountIDs = new Set<ID>();
        //Pull List of Account IDs of Work Orders
        for(Work_Order__c wo : woList)
        {
            if(wo.Site__c != null)
                accountIDs.add(wo.Site__c);
        } 
        Utilities.writeLog('related AccountIDs of Work Orders '+accountIds, WorkOrderTriggerLogic.class, 'deleteSitePhoto', LoggingLevel.DEBUG); 
                
        //Use Account IDs of Work Orders to pull up Site Surveys related to Work Orders
        List<Site_Photo__c> ssList = [SELECT Id,Site__c from Site_Photo__c WHERE Site__c IN :accountIDs];
        Map<Id,List<Site_Photo__c>> ssMap = new Map<Id,List<Site_Photo__c>>();
        //Create Map of Site Surveys to Work Orders
        for(Work_Order__c wo: woList)
        {
            for(Site_Photo__c ss : ssList)
            {
                if(wo.Site__c == ss.Site__c)
                {
                    if(ssMap.containsKey(wo.Id))
                    {
                        List<Site_Photo__c> ssSubListTemp = ssMap.get(wo.Id);
                        ssSublistTemp.add(ss);
                    }
                    else
                    {
                        List<Site_Photo__c> ssSubList = new List<Site_Photo__c>();
                        ssSubList.add(ss);
                        ssMap.put(wo.id, ssSubList);
                    }
                }
            }
        }
        //Utilities.writeLog('Work Order to related Site Survey Map '+ssMap, WorkOrderTriggerLogic.class, 'deleteSitePhoto', LoggingLevel.DEBUG); 
        
        //Going through work orders
        List<Site_Photo__c> ssToDelete = new List<Site_Photo__c>();
        for(Work_Order__c wo : woList)
        {
            if(wo.RecordTypeId == rtId)
            {
                if(wo.Status__c == 'Complete')
                {
                    if(ssMap.containsKey(wo.Id))
                    {
                        //Utilities.writeLog('To be Deleted Site Survevys of Work Order '+wo, WorkOrderTriggerLogic.class, 'deleteSitePhoto', LoggingLevel.DEBUG); 
                        ssToDelete.addAll(ssMap.get(wo.Id));
                    }
                }
            }
        }
        try{
            
            delete ssToDelete;
        }
        catch(DMLException e)
        {
            Utilities.writeLog('Exception in deleting Site Surveys: '+e.getMessage(), WorkOrderTriggerLogic.class, 'deleteSitePhoto', LoggingLevel.DEBUG); 
            woList[0].addError('Exception in deleting Site Surveys: '+e.getMessage());
        }
        Utilities.writeLog('**********    END', WorkOrderTriggerLogic.class, 'deleteSitePhoto', LoggingLevel.DEBUG); 
    }
    
    
    public static void updateTVTypeRelated2Acc(Map<Id, Work_Order__c> woMap, Map<Id, Work_Order__c> oldWoMap){
        //initialize vars
        Set<String> workOrderIds = new Set<String>();
        String queryOrderIds = '';
        List<TV_Type__c> listTVTypes = new List<TV_Type__c>();
        List<TV_Type__c> newTVTypes = new List<TV_Type__c>();
        TV_Type__c tempTV = new TV_Type__c();
        Set<Id> accountIds = new Set<Id>();
        List<TV_Type__c> deleteTvs = new List<TV_Type__c>(); 
        
        //find the work orders where the status has changed to complete
        for(Id workId : woMap.KeySet()){
            if(woMap.get(workId).Status__c == 'Install Complete' && oldWoMap.get(workId).Status__c != 'Install Complete' && woMap.get(workId).Site__c != null){
                workOrderIds.add(workId);
                queryOrderIds += ', \'' + workId + '\'';
                accountIds.add(woMap.get(workId).Site__c);
            }
        }
        
        //if there are ids in the query
        if(queryOrderIds.length() != 0){
            queryOrderIds = '(' + queryOrderIds.substring(1) + ')';
            
            //query for the tv types related to the work order
            listTVTypes = Database.query('SELECT ' + String.join(Utilities.getSObjectFields(TV_Type__c.getSObjectType()), ',') + ' FROM TV_Type__c WHERE Work_Order__c IN ' + queryOrderIds);
            deleteTVs = [SELECT id FROM TV_Type__c WHERE Site__c IN :accountIds];
            
            //delete tvs if list is not empty
            if(deleteTVs.size() > 0){
                delete deleteTVs;
            }
        }
        
        //clone the tvs
        for(TV_Type__c tv : listTVTypes){
            if(woMap.get(tv.Work_Order__c).Site__c != null){
                tempTV = tv.clone(false, true);
                tempTV.Site__c = woMap.get(tv.Work_Order__c).Site__c;
                tempTV.Work_Order__c = null;
                newTVTypes.add(tempTV);
            }
        }
        
        //insert the tvs if it is not empty
        if(newTVTypes.size() > 0){
            insert newTVTypes;
        }
    }
    
    //***********************BEGIN NEW INSTALLATION BILLING METHODS*************************************
    
    public static void CreateProductActivations(List<Work_Order__c> triggernewlist)
{
	system.debug('*************************Begin WorkOrderTriggerLogic.CreateProductActivations*****************');  
	
	List<Work_Order__c> listwo = New List<Work_Order__c>();
	List<Associated_Item__c> listinstallitems = New List<Associated_Item__c>();
	List<Associated_Item__c> listdeinstallitems = New List<Associated_Item__c>();
	List<Associated_Item__c> woitems = New List<Associated_Item__c>();
	List<Associated_Item__c> resetflaglist = new List<Associated_Item__c>();
	List<Associated_Item__c> listupdaterelated = new List<Associated_Item__c>();
	Map<Id,String> workorderidtorectype = New Map<Id,String>();
	Set<Id> workorderids = New Set<Id>();
	Set<Id> associtemids = New Set<Id>();
	
	Savepoint sp = Database.setSavepoint();
	
	for(Work_Order__c wo : triggernewlist)
	{
	  if(wo.approval_status__c == 'Billing Approved' && wo.status__c == 'Billing/Go Live')
	  {	
		workorderids.add(wo.id);  //create a set of unique work order ids
		system.debug('createproductactivations work order name is ' +wo.name);
	  }
	}
  
  system.debug('createproductactivations: workorderids size is ' +workorderids.size()); 
  if(!workorderids.IsEmpty())
  {	//first get all the associated items, order items, and product inventory related to the work orders
	//shawks BUG-00176: Remove Delivery Method reference
	woitems = [ Select work_order__c, system_status__c, work_order__r.status__c, work_order__r.approval_status__c, work_order__r.install_complete_date__c,
				work_order__r.de_installation_date__c, flagged_for_billing__c, submitted_for_billing__c, added_to_turnonnotice__c, name, quantity__c, order_item__r.asset__c,
				status__c, billing_commencement_date__c, de_installation_date__c, dtv_account__c, order_item__r.total_rooms_ordered__c,
				receiver_id__c, serial_number__c, card_id__c, order_item__c, order_item__r.total_remaining_rooms__c, order_item__r.system_status__c,
				order_item__r.asset__r.service_start_date__c, order_item__r.asset__r.service_end_date__c, order_item__r.asset__r.InstallDate, order_item__r.asset__r.status,
				order_item__r.asset__r.card_id__c, order_item__r.asset__r.receiver_id__c, order_item__r.asset__r.serialnumber, order_item__r.asset__r.term__c, order_item__r.asset__r.isdeleted,
				Id, (Select Id, Associated_Item__c, name from product_activation__r)
				from
				Associated_Item__c where work_order__c in :workorderids AND flagged_for_billing__c = true AND submitted_for_billing__c = false ];
				
   Map<Id,Product_Activation__c> aitemtopa = New Map<Id,Product_Activation__c>();
   List<Product_Activation__c> palist = New List<Product_Activation__c>();
   List<Associated_Item__c> listupdateoionly = New List<Associated_Item__c>();
   
   system.debug('woitems size is ' +woitems.size());
   
   for(Associated_Item__c aitem : woitems)
   {
   	  for(Product_Activation__c pa : aitem.product_activation__r)
   	  {  aitemtopa.put(pa.associated_item__c, pa);
   	  	//system.debug('a product activation was found for associated item ' +pa.name);  
   	  }
   }	

   //now spin through each work order item and separate into installs and deinstalls for creating product activations.  If any of the associated item records
   //already have related product activations, remove them and do not create activations
  try{
   if(woitems.size() > 0 )
   {
	  for(Associated_Item__c associtem : woitems)
	  {
	    if(!aitemtopa.keyset().Contains(associtem.id)) //only proceed if the assoc item id is not in the assoc item to pa map
		{	
		  if(associtem.order_item__r.asset__c != null)
		  {	
		   if(associtem.order_item__r.asset__r.isdeleted == false)
		   {
			if(associtem.status__c == 'Billing')
			{  listinstallitems.add(associtem);   }
		
			if(associtem.status__c == 'De-Installed')
			{  listdeinstallitems.add(associtem);   }
		   }
		  }
		  else
		  { listupdateoionly.add(associtem);  }  //for assoc items that have no product inventory, update the order item only
		}//end if productactivation is null
	    //now update the flags on the associated items and change Billing to Installed Activated
			associtem.added_to_turnonnotice__c = false;
			associtem.flagged_for_billing__c = false;
			associtem.submitted_for_billing__c = true;
			if(associtem.status__c == 'Billing')
			{ associtem.status__c = 'Installed Activated' ; }
			resetflaglist.add(associtem);
		 //system.debug('assoc item added to resetflaglist is ' +associtem.Name);
       }//end for loop associtem
     }
  
  
  //call the applicable method for returning a list of new product activations or deactivations.  
  //then merge the install/de-install associated item lists for updating product inventory and order items

  List<Product_Activation__c> listactivations = new List<Product_Activation__c>();
  List<Product_Activation__c> listdeactivations = new List<Product_Activation__c>();
  List<Product_Activation__c> insertactivations = new List<Product_Activation__c>();
  if(listinstallitems.size() > 0 )
  {
  	 listactivations = CreateActivations(listinstallitems);
  	 
  	 for(Associated_Item__c instai : listinstallitems)
  	 {  listupdaterelated.add(instai);     }
  }
  
  if(listdeinstallitems.size() > 0)
  {  listdeactivations = CreateDeactivations(listdeinstallitems);  
  
  	 for(Associated_Item__c deinstai : listdeinstallitems)
  	 {  listupdaterelated.add(deinstai);               }
  }

 //combine product activations and deactivations into one list and do one insert
  if(!listactivations.IsEmpty())
  {
	for(Product_Activation__c instpa : listactivations)
	{  
	   insertactivations.add(instpa);   
	}
  }
  
  if(!listdeactivations.IsEmpty())
  {
	for(Product_Activation__c deinstpa : listdeactivations)
	{   
    	  insertactivations.add(deinstpa);  
    }		  
  }
  
 
      insert insertactivations;
  }//end try
  catch(DMLException e)
  { system.debug('Error in CreateProductActivations insert:  '  +e.getmessage());  
  	Database.rollback(sp);
  }
  catch(Exception ex)
  { system.debug('Error in CreateProductActivations: ' +ex.getmessage());
  	Database.rollback(sp);
  }
  

  //now do product inventory and order items updates using the combined (install/deinstall) list of associated items
  try{
	UpdateProductInventory(listupdaterelated);
	//now that product inventory items are updated, add associated items to the list that don't have
	//asset records related to them
	for(Associated_Item__c ai : listupdateoionly)
	{  listupdaterelated.add(ai);  }
	system.debug('calling UpdateOrderItems with following list:');
	//for(Associated_Item__c item : listupdaterelated)
	//{
	//	system.debug('update order item for ' +item.Name +', ' +item.quantity__c +' ,' +item.order_item__r.total_remaining_rooms__c +', ' +item.status__c);
	//}
	UpdateOrderItems(listupdaterelated);
	system.debug('completed product inventory and order item update for install items.');
	
  //do the update on the associated item flags and change Pending Billing to Billing
         update resetflaglist;   
         system.debug('just now updated Billing assoc item records to Installed Activated.');
   }// end try
   catch(DMLException ex)
   {  system.debug(' DML Error in Work OrderTriggerLogic.CreateProductActivations resetflaglist:  ' +ex.getMessage());  
   	  Database.rollback(sp);
   }
   
   catch(Exception e)
   {  system.debug('Error in CreateProductActivations: ' +e.getmessage()); 
   	  Database.rollback(sp);
   }
  

	//for(Associated_Item__c ai : resetflaglist)
	//{ system.debug('assoc items were reset as follows: ' +ai.Name +', ' +ai.added_to_turnonnotice__c +', ' + ai.flagged_for_billing__c +', ' +ai.submitted_for_billing__c);  }
  
  }//end if workorderids is not empty
   system.debug('*************************END CreateProductActivations****************************');
 
}//end CreatProductActivations

//after the work order is evaluated and associated items are pulled, pass the
//associated items to this method for creating product activations
public static List<Product_Activation__c> CreateActivations(List<Associated_Item__c> installassocitems)
{
	system.debug('*********************BEGIN CreateActivations*****************************');
	
	List<Product_Activation__c> listinsertpa = New List<Product_Activation__c>();

	for(Associated_Item__c instai : installassocitems)
	{
	  		Product_activation__c newpa = New Product_activation__c();
			newpa.Name = instai.Name;
			if(instai.work_order__r.install_complete_date__c != null)
			{	newpa.Installation_Completion_Date__c = instai.work_order__r.install_complete_date__c;  }
			else
			{   newpa.Installation_completion_Date__c = instai.Billing_Commencement_Date__c;   }
		
			newpa.Billing_Commencement_Date__c = instai.Billing_Commencement_Date__c;
			Id assetid = instai.order_item__r.asset__c;
			newpa.Product_Inventory__c = assetid;
			//system.debug('CreateActivations:  asset id is ' +instai.order_item__r.asset__c + ', ' + instai.name + ', ' + instai.order_item__r.asset__r.isdeleted);
			newpa.Quantity__c = instai.Quantity__c;
			newpa.Type__c = 'Activation';
			newpa.Associated_Item__c = instai.Id;
		
			listinsertpa.add(newpa);
			//system.debug('new product activation is ' +newpa.Name +', ' +newpa.type__c);
		

	}

	system.debug('******************************END CreateActivations**************************'); 
	
	return listinsertpa;
}

//pass any de-installed work order items (associated items)
//into this method for creating deactivations
public static List<Product_Activation__c> CreateDeactivations(List<Associated_Item__c> deinstallassocitems)
{
	system.debug('**************************BEGIN Create Deactivations*************************');
	
	List<Product_Activation__c> listinsertpa = New List<Product_Activation__c>();

	for(Associated_Item__c instai : deinstallassocitems)
	{

		Product_activation__c newpa = New Product_activation__c();
		newpa.Name = instai.Name;
		if(instai.work_order__r.de_installation_date__c != null)
		{	newpa.de_install_date__c = instai.work_order__r.de_installation_date__c;  }
		else
		{   newpa.de_install_date__c = system.today();   }
		Id assetid = instai.order_item__r.asset__c;
		newpa.Product_Inventory__c = assetid;
		newpa.Quantity__c = instai.Quantity__c;
		newpa.Type__c = 'Deactivation';
		newpa.Associated_Item__c = instai.Id;
		
		//system.debug('new product deactivation is' +newpa.Name +', ' +newpa.type__c +', ' +instai.order_item__r.asset__c +', ' + instai.order_item__r.asset__r.isdeleted);

		listinsertpa.add(newpa);

	}
	
	system.debug('*********************END CreateDeactivations***************************');
	
	return listinsertpa;
}

//once product activations and deactivations are created and flags are reset on associated items, update the product inventory and order item lines
public static void UpdateProductInventory(List<Associated_Item__c> associtemlist)
{
	//jjackson 4/2016 Note that the status of product inventory items only changes to Billing and not
	//Installed Activated.  This was requested by Hotel Contracts.  They did not want the PI status to
	//change to Installed Activated until the work order goes through final approval.
	
	system.debug('***********************BEGIN WorkOrderTriggerLogic.UpdateProductInventory******************');
	
	List<Asset> listupdateassets = New List<Asset>();
    Savepoint sp = Database.setsavepoint();
	
	//separate the assoc item records into Billing or De-Installed so related asset records can be updated accordingly
	try{
		for(Associated_Item__c instai : associtemlist)
		{
		  Asset assetrec = New Asset();
		  system.debug('inside updateproductinventory and assoc item status is ' +instai.status__c);
			if(instai.status__c == 'Installed Activated') 
			{

				Id assetid = instai.order_item__r.asset__c;
				assetrec.Id = assetid;
				if(instai.receiver_id__c != null)
				{assetrec.receiver_id__c = instai.receiver_id__c;}
				if(instai.serial_number__c != null)
				{assetrec.serialnumber = instai.serial_number__c;}
				if(instai.card_id__c != null) 
				{assetrec.card_id__c = instai.card_id__c;}
				if(instai.dtv_account__c != null) 
				{assetrec.dtv_account_number__c = instai.dtv_account__c;}
				//shawks BUG-00176: Comment out since Delivery Method of Asset set on Contract Line Items now
				//if(instai.order_item__r.delivery_method__c != null)
				//{assetrec.delivery_method__c = instai.order_item__r.delivery_method__c; }
				
				//only update the product inventory status to Billing if it is not already at Installed Activated
				if(instai.order_item__r.asset__r.status == 'Pending Installation Activate')
				{ assetrec.status = 'Billing';  }
				
				//only update the service start date if there isn't one.  We don't want the initial start date overwritten if
				//this is a phased install
				if(instai.order_item__r.asset__r.service_start_date__c == null)
				{  assetrec.service_start_date__c = instai.billing_commencement_date__c;  }
				
				//update the install date and service start date but not the service end date.
				//service end date gets added later by legal contract trigger code when a term end date is 
				//added to the legal contract.
				if(instai.order_item__r.asset__r.installdate == null)
				{assetrec.installdate = instai.billing_commencement_date__c; }
				
				assetrec.system_status__c = instai.system_status__c;
				listupdateassets.add(assetrec);
			 }
			 else if(instai.status__c == 'De-Installed')
			 {
			    Id assetid = instai.order_item__r.asset__c;
				assetrec.Id = assetid;
				if(instai.order_item__r.asset__r.status == 'Pending De-Installation')
				{  assetrec.status = 'De-Installed';  }
				if(instai.work_order__r.de_installation_date__c != null)
				{  assetrec.cancellation_date__c = instai.work_order__r.de_installation_date__c;  }
				else
				{  assetrec.cancellation_date__c = system.today();  }
				listupdateassets.add(assetrec);
				
     		 }
	     }//end for loop assoc items list
	
	
		if(listupdateassets.size() > 0)
		{  upsert listupdateassets;   }
	}//end try 
	catch(Exception e)
	{ system.debug('Error in WorkOrderTriggerLogic.UpdateProductInventory: ' +e.getMessage());     
	  Database.rollback(sp);
	}

	system.debug('**********************END UpdateProductInventory***************************');
	
} //end update product inventory


public static void UpdateOrderItems(List<Associated_Item__c> associtemlist)
{
	system.debug('****************BEGIN WorkOrderTriggerLogic.UpdateOrderItems**********************');
	
    //calculate the remaining rooms on the related order item and update
	List<Order_Item__c> listupdoi = New List<Order_Item__c>();
	for(Associated_Item__c aitem : associtemlist)
	{
		  system.debug('aitem total remaining rooms to begin is ' +aitem.order_item__r.total_remaining_rooms__c);
	      Order_Item__c updoi = New Order_Item__c();
		  updoi.id = aitem.order_item__c;
		  
		  Integer remainingrms = 0;
		  
		if(aitem.order_item__r.total_remaining_rooms__c > 0  && (Integer.ValueOf(aitem.order_item__r.total_remaining_rooms__c) >= Integer.ValueOf(aitem.quantity__c)))  
		{  remainingrms = Integer.ValueOf(aitem.order_item__r.total_remaining_rooms__c) - Integer.ValueOf(aitem.quantity__c);  
           system.debug('first if statement remainingrms is ' +remainingrms); 
		}
		     
	    system.debug('UpdateOrderItems remaining rms is ' +remainingrms +' for ' +aitem.Name +' where qty is ' +aitem.quantity__c);

		updoi.total_remaining_rooms__c = remainingrms;
        
        listupdoi.add(updoi);
	}
	
	Savepoint s = Database.setSavepoint();
	try{ upsert listupdoi;  }
	catch(Exception e)
	{system.debug('Error in WorkOrderTriggerLogic.UpdateOrderItems: ' +e.getMessage());       
	 Database.rollback(s);
	}
	
	system.debug('**********************END WorkOrderTriggerLogic.UpdateOrderItems***********************');
} //end UpdateOrderItems
    
   //*******************************END NEW INSTALLATION BILLING METHODS************************************** 
    


public static void WorkOrderNameCompareUpdate(List<Work_Order__c> lsttriggernew, Map<Id,Work_Order__c> oldWoMap, String triggertype)
{

		system.debug('**********************BEGIN WorkOrderNameCompareUpdate **************************');
		//loop through the map and create new map of work order number to record.  Can't use work order id as key because
		//there is no record id in a before insert trigger.  There are no "insert" or "update" DML statements because
		//this runs in a Before trigger, so the name change will take place once this record is committed by the trigger
		
		Map<String,Id> mpwotorectypeid = New Map<String,Id>();
		Map<String,List<String>> mpwotoprodparents = New Map<String,List<String>>();
		List<Associated_Item__c> lstassocitm = New List<Associated_Item__c>();
		Set<String> parentwoids = New Set<String>();
		Set<Id> childrenwo = New Set<Id>();
		List<Work_Order__c> lstupdwo = New List<Work_Order__c>();
		List<Work_Order__c> parentworkorders = New List<Work_Order__c>();
		Map<String,Id> mapchildtoparent = New Map<String,Id>();
		Map<Id,String> mapwoidtonumber = New Map<Id,String>();
		Map<String,String> mpppu = New Map<String,String>();

		//create a map from the product parent usage custom setting
		List<Product_Parent_Usage__c> lstppu = Product_Parent_Usage__c.getall().values();
		for(Product_Parent_Usage__c p :lstppu)
		{
			mpppu.put(p.Name, p.WO_Name_Abbrev__c);
		}

		
		system.debug('lsttriggernew size is ' +lsttriggernew.size() +' and triggertype is ' +triggertype);
		//loop through lsttriggernew to identify child work orders; we will have to get their parent
		//work order numbers by querying based on the parent id in parent_work_order__c
		for(Work_Order__c wo : lsttriggernew)
		{
			if(wo.parent_work_order__c != null)
			{ childrenwo.add(wo.parent_work_order__c);  
			  mapchildtoparent.put(wo.work_order_number__c,wo.parent_work_order__c);
			}
		}
		
		//get the parent work orders of any children and make a map of work order id to work order number
		parentworkorders = [ Select Id, work_order_number__c, Name from work_order__c where id in :childrenwo ];
		for(Work_Order__c pwo : parentworkorders)
		{ mapwoidtonumber.put(pwo.id,pwo.work_order_number__c);
		  parentwoids.add(pwo.work_order_number__c);
		}
		
		for(Work_Order__c worec : lsttriggernew)
		{
			mpwotorectypeid.put(worec.work_order_number__c,worec.recordtypeid);
			//we want to add work order ids to a set to remove duplicate id's if both the parent work order and its children are in the trigger
			if(worec.parent_work_order__c == null)  //if parent_work_order__c has no value, this is a parent work order
			{  parentwoids.add(worec.work_order_number__c);  }
		}
		
		//get a list of all the associated item product parents that go with these work orders and create another map
		//with parent work order numberd as the key and list of related product parents as the value
		lstassocitm = [ Select Id, Name, work_order__c, work_order__r.work_order_number__c from associated_item__c where work_order__r.work_order_number__c in :parentwoids AND Name like '%Product Parent' ];
		system.debug('lstassocitm size in work order name creation is ' +lstassocitm.size());
		for(Associated_Item__c ai : lstassocitm)
		{
			if(mpwotoprodparents.containsKey(ai.work_order__r.work_order_number__c))
            	{
                	mpwotoprodparents.get(ai.work_order__r.work_order_number__c).add(ai.name);
            	}
                else
            	{
					List<String> temp = new List<String>();
					temp.add(ai.name);
					mpwotoprodparents.put(ai.work_order__r.work_order_number__c,temp);  //create a map with work order id as key and list of product parent names as value
             	}
		}
		
		//now look through the work orders in the trigger.  Compile new work order name and add it to the new work order.
		for(Work_Order__c wo : lsttriggernew)
		{
			Id rectypeid;
			String newname = '';
			String basename = '';
			String rectypename = '';
			String abbreviations = '';
			List<String> lstprodparents = New List<String>();
			Set<String> setabbrevs = New Set<String>();
			Boolean changename = false;
			String parentnumber;
			if(wo.parent_work_order__c == null)
			{  parentnumber = wo.work_order_number__c;  }
			else
			{  parentnumber = mapwoidtonumber.get(mapchildtoparent.get(wo.work_order_number__c)); }

			rectypeid = mpwotorectypeid.get(wo.work_order_number__c);
			Map<Id,Schema.RecordTypeInfo> rtmap = Schema.getGlobalDescribe().get('Work_Order__c').getDescribe().getRecordTypeInfosById();
			rectypename = rtmap.get(rectypeid).getName();
			system.debug('rectypename is ' +rectypename);
			basename = wo.site_id__c +' - ' +rectypename + ' - ';
			system.debug('work order base name is ' +basename);
			
			Work_Order__c updwo = New Work_Order__c(); //must create a new(blank) work order record and assign the wo record in the map to it in order to update it

   		  if(mpwotoprodparents.containskey(parentnumber))	
		  {	
		    lstprodparents = mpwotoprodparents.get(parentnumber);
		    
		    if(test.IsRunningTest()) //have to do this because the test can't see the custom setting
		    {
		    	setabbrevs.add('FTG');
		    	setabbrevs.add('Interactive');
		    }
		    else
		    {	
            	for(String ppname : lstprodparents)
				{ 
					//system.debug('processing this product parent: ' +ppname);
					String abb;
					if(mpppu.containskey(ppname))
					{ abb = mpppu.get(ppname); 
					  setabbrevs.add(abb);
					}
					
				}
			}
			system.debug('setabbrevs contains ' +setabbrevs);
			if(setabbrevs.contains('Interactive'))
			   abbreviations += 'Interactive-';
			if(setabbrevs.contains('FTG'))
			   abbreviations += 'FTG-';
			if(setabbrevs.contains('DRE'))
			   abbreviations += 'DRE-';
			if(setabbrevs.contains('GIA'))
			   abbreviations += 'GIA-';
			if(setabbrevs.contains('PV'))
			   abbreviations += 'PV-';
			if(setabbrevs.contains('HCTab'))
			   abbreviations += 'HCTab-';
			if(setabbrevs.contains('SS'))
			   abbreviations += 'SS-';
			if(setabbrevs.contains('SC'))
			   abbreviations += 'SC-';
			if(setabbrevs.contains('SCR'))
			   abbreviations += 'SCR-';
			if(setabbrevs.contains('TIE'))
			   abbreviations += 'TIE-';
			if(setabbrevs.contains('PS'))
			   abbreviations += 'PS-';
			if(setabbrevs.contains('BYOD'))
			   abbreviations += 'BYOD-';
			if(setabbrevs.contains('HCDIG'))
			   abbreviations += 'HCDIG-';
			if(setabbrevs.contains('HCDWB'))
			   abbreviations += 'HCDWB-';
			if(setabbrevs.contains('NOBL'))
			   abbreviations += 'NOBL-';
			if(setabbrevs.contains('DS'))
			   abbreviations += 'DS';

			//don't remove the ending dash
			//String subabbrev;  
			//if(abbreviations.right(1) == '-')
			//{ subabbrev = abbreviations.substring(0,abbreviations.length()-1); } //remove the ending - if there is one
			//else
			//{ subabbrev = abbreviations;  }
			
			newname = basename+abbreviations;
			String subnewname; //must keep newname to 80 characters or less to fit in the name field
			if(newname.length() > 79)
            {    subnewname = newname.substring(0,79);  }
            else
            {    subnewname = newname;  }
			
			if(triggertype == 'update' && oldWoMap.containskey(wo.id)) //if this is update trigger, compare old name to new name.  if different, change boolean to true
			{
				String oldname = oldWoMap.get(wo.id).Name;
				if(newname != oldname)
				{  changename = true; 
					system.debug('checking to see if this code is hit if there is an update and no name change');
				}

			}
			
			//only do this update if triggertype is insert or changename = true
		   if(triggertype == 'insert' || changename == true)
           {		  
			  //updwo = wo;  //assign the work order record in the trigger to a new work order record so the name can be updated
			  wo.name = subnewname;

			 system.debug('WorkOrderNameCompareUpdate newname = ' +newname);
		   }
				
		  }//end if the parent work orders have product parent lines
		  else
		  {
			  wo.name = basename;  //don't need an insert DML statement because this trigger record is not committed yet
			
			  system.debug('WorkOrderNameCompareUpdate basename = ' +basename);
		  }
			
		} //end for loop work orders in new map

		system.debug('*****************************END WorkOrderNameCompareUpdate **********************');
		
}//end WorkOrderNameCompareUpdate
    
    //jjackson BUG-00331 Update Order status to Fulfilled when Work Order status goes to Work Order Complete
    public static void UpdateOrderStatus(List<Work_Order__c> wotriggernewlist, Map<Id,Work_Order__c> wotriggeroldmap){
    	system.debug('**********************START UpdateOrderStatus*****************************');
    
    	Set<Id> woids = new Set<Id>();
    	Set<Id> orderids = new Set<Id>();
    	String workorderstatus;
    	Map<Id,Associated_Item__c> mpassocitem = New Map<Id,Associated_Item__c>();
 
 	    workorderstatus = 'Work Order Complete';
 
        //iterate through the list of work orders and determine if the status field has been changed to Work Order Complete
    	for(Work_Order__c recwo : wotriggernewlist)
    	{
    		if(recwo.Status__c == workorderstatus && wotriggeroldmap.get(recwo.id).Status__c != workorderstatus)
    		{
    			if(recwo.parent_work_order__c == null)
    			{  woids.add(recwo.id);  }
    		}
  
    		system.debug('old wo status is ' +wotriggeroldmap.get(recwo.id).status__c +' and new status is ' +recwo.status__c);
    	}
    	
    	if(!woids.IsEmpty())
    	{
    		List<Associated_Item__c> lstassocitems = [Select Id, Name, Order_Item__r.order__c, Order_Item__r.order__r.status__c, work_order__c from Associated_Item__c 
    		                                          where Work_Order__c in :woids AND name like '%Product Parent' ];
            List<Order__c> lstupsertorders = New List<Order__c>();
    	
    		for(Associated_Item__c recaitem : lstassocitems)
    		{  mpassocitem.put(recaitem.order_item__r.order__c,recaitem); } //add to map to remove duplicate order id's
    		
    		for(Associated_Item__c ai : mpassocitem.values()) //now loop the map values (assoc item records) to update orders
    		{
    			system.debug('looping through assoc item map in UpdateOrderStatus');
     		  Order__c updorder = New Order__c();
    		  if(ai.order_item__r.order__c != null)
    		  {
    		  	updorder.id = ai.order_item__r.order__c;
    		  	updorder.status__c = 'Order Fulfilled';
    		  	lstupsertorders.add(updorder);
    		  	
    		  	system.debug('updating order id to order fulfilled: ' +ai.order_item__r.order__c);
    		  
    		  }
    		}
 
 			system.debug('lstupsertorder size is ' +lstupsertorders.size());
    		if(lstupsertorders.size() > 0)
     		{
 				try{  upsert lstupsertorders;  }
    			catch(Exception ex)
    			{
        			system.debug('Error in UpdateOrderStatus: '+ex.getMessage());
        		}
     		}
     		
    		system.debug('************************END UpdateOrderStatus*******************************');
    	
    	}
    	
    }  //end UpdateOrderStatus
    
    //jjackson October 2014 BUG-00263 when a work order goes to Billing/Go Live, create a turn on notice and pass it to a method in the email utility
    //shawks: BUG-00717 - Healthcare TON email include additional info; send to different email address/email folder
    public static void CreateTurnOnNotice(List<Associated_Item__c> lstselectedassocitms){
   		 	system.debug('***************STARTING CreateTurnOnNotice*********************************');

            //need to get contract id for each order in the work order so need a long dot notation soql 	
   		 	String message;
   		 	Set<Id> setwoids;
   		 	List<Associated_Item__c> lstwoassocitms = new list<Associated_Item__c>();
            Map<Id,String> mpwocity = new map<Id,String>();
            Map<Id,String> mpwostate = new map<Id,String>();
            Map<Id,Decimal> mpworooms = new map<Id,Decimal>();
            Map<Id,String> mpwosupport = new map<Id,String>();
            Map<Id,String> mpwoacctname = new map<Id,String>();
            Map<Id,String> mpwoim = new map<Id,String>();
            Map<Id,String> mpwopc = new map <Id,String>();
            Map<Id,String> mpwopm = new map<Id,String>();
            Map<Id,String> mpwocrew = new map<Id,String>();
            Map<Id,String> mprecordtypename = new Map<Id,String>();  //map that matches record type Id to name
   		 	Map<Id,Associated_Item__c> mpassocitem = new Map<Id,Associated_Item__c>();
   		 	Map<Id,String> mpwoprojecttype = new Map<ID,String>();
   		 	Map<Id,String> mpwonum = new map<Id,String>(); //shawks:BUG-00687 - Map for Work Order Number
   		 	Map<Id,String> mpwoaccttype = New Map<Id,String>(); //shawks:BUG-00717 - Maps for Healthcare 
   		 	Map<Id,String> mpwopo = New Map<Id,String>();
   		 	Map<Id,String> mpwocreatedby = New Map<Id,String>();
   		 	Map<Id,List<Associated_Item__c>> mprelateditems = new map<Id,List<Associated_Item__c>>();
   		 	Set<Id> workorderids = new set<Id>();
   	
   			//get all the associated items along with site, order item, order, and contract info for assoc item id's in the selected list
   		 	//shawks BUG-00680 - add Project Number
   		 	//shawks:BUG-00717 - Add Account Type, PO Number, and Created By
   		 	//shawks:CPQ - Replace order_item__r.legal_contract_id__c -> order_item__r.Contract_Number__c; Remove unneeded order_item__r.order__r.legal_contract__r.Name
   		 	lstwoassocitms = [ Select Name,Status__c, Id, billing_commencement_date__c, de_installation_date__c, project_type__c, hierarchyorder__c,
   		 	                  added_to_turnonnotice__c, work_order__c,order_Item__c, quantity__c, project_number__c,
   		 	                  order_item__r.order__c,order_item__r.Contract_Number__c,order_item__r.parent__c, order_item__r.parent__r.name,
   		 	                  work_order__r.Name, work_order__r.crew__r.Name, work_order__r.project_type__c,
   		 	                  work_order__r.project_manager__r.Name,work_order__r.project_coordinator__r.Name,work_order__r.support_office__c, work_order__r.work_order_number__c,
   		 	                  work_order__r.Install_Manager__r.Name,work_order__r.id,work_order__r.site__r.of_rooms__c, work_order__r.recordtypeid,
   		 	                  work_order__r.account_type__c, work_order__r.po__c, work_order__r.createdby.name,
   		 	                  work_order__r.site__r.Physical_City__c,work_order__r.site__r.Physical_State__c,work_order__r.site__r.Name, work_order__r.de_installation_date__c
   		 	                  from associated_Item__c where id in :lstselectedassocitms Order by hierarchyorder__c ];
   		 	                  
   		 	for(Associated_Item__c associtmrec : lstwoassocitms)
   		 	{
   		 		{  workorderids.add(associtmrec.work_order__c); }
   		 	}

   		 	//get a map of all the work order record type id's with corresponding name                  
   		 	Map<String,Schema.RecordTypeInfo> mprecordtypeschema = Schema.SobjectType.Work_Order__c.getRecordTypeInfosByName();
   		 	mprecordtypename.put(mprecordtypeschema.get('Install').getRecordTypeId(),'Install');
   		 	mprecordtypename.put(mprecordtypeschema.get('De-Install').getRecordTypeId(),'De-Install');
   		 	
   		 	for(Id woid : workorderids)
   		 	{
   		 		List<Associated_Item__c> lstrelateditems = new list<Associated_Item__c>();
   		 		List<Associated_Item__c> lstordereditems = new list<Associated_Item__c>();
   		 		for(Associated_Item__c recassocitm : lstwoassocitms)
   		 		{
   		 			if(recassocitm.work_order__c == woid)
   		 			
   		 			{   lstrelateditems.add(recassocitm);    }
   		 		}
   		 		
   		 		mprelateditems.put(woid,lstrelateditems);
   		 	}
   		 	
   		 	for(Associated_Item__c recai : lstwoassocitms)
   		 	{
   		 		mpassocitem.put(recai.id,recai);  //create a map of associated items
   		 		
   		 			mpwocity.put(recai.work_Order__c,recai.work_order__r.site__r.physical_city__c); //map city to work order
                	mpwostate.put(recai.work_order__c,recai.work_order__r.site__r.physical_state__c); //map state to work order
                	mpwonum.put(recai.work_order__c,recai.work_order__r.work_order_number__c); //shawks:BUG-00687
                	mpwoaccttype.put(recai.work_order__c,recai.work_order__r.account_type__c); //shawks:BUG-00717
                	mpwopo.put(recai.work_order__c,recai.work_order__r.po__c);  //shawks:BUG-00717
                	mpwocreatedby.put(recai.work_order__c,recai.work_order__r.createdby.name);
                	mpwoacctname.put(recai.work_order__c,recai.work_order__r.site__r.name);
                	mpworooms.put(recai.work_order__c,recai.work_order__r.site__r.of_rooms__c);
                	mpwosupport.put(recai.work_order__c,recai.work_order__r.support_office__c);
                	mpwoim.put(recai.work_order__c,recai.work_order__r.install_manager__r.Name);
                	mpwopc.put(recai.work_order__c,recai.work_order__r.project_coordinator__r.Name);
                	mpwopm.put(recai.work_order__c,recai.work_order__r.project_manager__r.Name);
            		mpwocrew.put(recai.work_order__c,recai.work_order__r.crew__r.Name);
            		mpwoprojecttype.put(recai.work_order__c,recai.project_type__c);
   		 	}
   		 	
   		 	//now all the info is saved in maps and we can build the email message.
   		 	//Loop through the changed work orders and create each message to pass to EmailUtilities.cls
   		 	//List<Work_Order__c> lstwochanged = mpworkorderchanged.values();
   		 	//List<Associated_Item__c> lstorderedai = new List<Associated_Item__c>();  //shawks BUG-00752 - List not needed now
   		 	List<Associated_Item__c> lstrelatedai = new List<Associated_Item__c>();
   		 	List<Associated_Item__c> lstupdateai = new List<Associated_Item__c>();
   		 	String sitename = '';
   		 	Date billingdate;
   		 	String converteddate = '';
   		 	String workordertype = '';
   		 	String headerstring = '';
   		 	String headerstring2 = '';
   		 	String projectType;   //shawks BUG-00744
   		 	List<Work_Order__c> lstupdpreviousstat = new list<Work_Order__c>();
   		 	for(Id recwoid : workorderids)
   		 	{
   		 		projectType = ''; //shawks BUG-00744 - Initialize variable for each work order
   		 		lstrelatedai = mprelateditems.get(recwoid);
            	workordertype = GetTurnonType(lstrelatedai); //spin through the items to determine whether they are installed, deinstalled, or both

            	
            	if(workordertype == 'Install')
   		 		   {  headerstring = 'ITEMS INSTALLED                BILLING COMM. DT     ';   }
   		 		if(workordertype == 'Deinstall')
   		 		   {  headerstring = 'ITEMS DEINSTALLED              DE-INSTALLATION DT    ';  }
 
   		 		
   		 		//system.debug('work order type is ' +workordertype);
   		 		message = '';
   		 		sitename = mpwoacctname.get(recwoid);
   		 		//message += wochanged.Name +'\n';//+'<br/><br/>';                
                message += 'Site: ' +sitename +'\n';// +'<br/>';
            	message += 'City/State: '+mpwocity.get(recwoid) +', ' +mpwostate.get(recwoid) +'\n';// +'<br/>';
            	message += 'Site Number of Rooms: ' +mpworooms.get(recwoid) +'\n';// +'<br/>';
            	message += 'Work Order Number: ' +mpwonum.get(recwoid) +'\n'; //shawks:BUG-00687 - Add WO# to Turn On Notice output
            	if(mpwoaccttype.get(recwoid) == 'Healthcare Site') //shawks:BUG-00717 - Add PO # for Heathcare TON
            	   {  message += 'PO #: ' +mpwopo.get(recwoid) +'\n';  }
            	message += 'Project Type:  ' +mpwoprojecttype.get(recwoid) +'\n'+'\n';// +'<br/><br/>';

            	if(workordertype == 'Turnonandoff')
            	{   message += MixedTurnOnNotice(lstrelatedai);  }
            	else
            	{   message += headerstring +'CONTRACT ID    QUANTITY    PROJECT' +'\n'+'\n';
            	
            	    //shawks BUG-00752 - Associated Items are ordered during query above so additional ordering is not needed
            	    //lstorderedai = PutRelatedItemsinOrder(lstrelatedai);
              		//for(Associated_Item__c associtm : lstorderedai)
              		for(Associated_Item__c associtm : lstrelatedai)
            		{
	                    billingdate = null;
	                    //shawks BUG-00744 - If Healthcare project, set variable for EmailUtilities.EmailTurnOnNotice call
	                    if(associtm.project_type__c == 'Healthcare')
	                       { projectType = associtm.project_type__c; }
            		//change the format of the billing commencement date to something more readable
            	  		if(associtm.status__c == 'Billing' || associtm.status__c == 'Installed Activated')
            			{ billingdate = mpassocitem.get(associtm.Id).Billing_Commencement_Date__c;  }
            	  
            	  		if(associtm.status__c == 'De-Installed')
            	    	{ billingdate = mpassocitem.get(associtm.Id).work_order__r.De_Installation_Date__c;  }
            	
            	  		if(billingdate != null)
            		  	{ converteddate = billingdate.month() + '-' + billingdate.day() +'-' +billingdate.year(); }
            	  		else
            		  	{ converteddate = 'no date provided';  }
            		 
            			if(associtm.name.contains('Product Parent'))
            		    	//shawks BUG-00680 - add Project Number
            		    	//shawks CPQ - Replace: order_item__r.legal_contract_id__c -> order_item__r.Contract_Number__c
            		    	//{message += mpassocitem.get(associtm.Id).Name +'     ' +converteddate +'   '+mpassocitem.get(associtm.Id).order_item__r.legal_contract_id__c +'   '+mpassocitem.get(associtm.Id).Quantity__c+ '   ' +mpassocitem.get(associtm.Id).project_number__c+ '\n';}
            		    	{message += mpassocitem.get(associtm.Id).Name +'     ' +converteddate +'   '+mpassocitem.get(associtm.Id).order_item__r.Contract_Number__c +'   '+mpassocitem.get(associtm.Id).Quantity__c+ '   ' +mpassocitem.get(associtm.Id).project_number__c+ '\n';}
            		    else if(associtm.order_item__r.parent__r.Name.contains('Product Parent'))
            		    	//{message += '     ' +mpassocitem.get(associtm.Id).Name +'       ' +converteddate +'   '+mpassocitem.get(associtm.Id).order_item__r.legal_contract_id__c +'    '+mpassocitem.get(associtm.Id).Quantity__c+'\n';  }
            		    	{message += '     ' +mpassocitem.get(associtm.Id).Name +'       ' +converteddate +'   '+mpassocitem.get(associtm.Id).order_item__r.Contract_Number__c +'    '+mpassocitem.get(associtm.Id).Quantity__c+'\n';  }
            		    else
            		    	//{message += '           ' +mpassocitem.get(associtm.Id).Name +'    ' +converteddate +'   '+mpassocitem.get(associtm.Id).order_item__r.legal_contract_id__c +'     '+mpassocitem.get(associtm.Id).Quantity__c+'\n';  }
            		    	{message += '           ' +mpassocitem.get(associtm.Id).Name +'    ' +converteddate +'   '+mpassocitem.get(associtm.Id).order_item__r.Contract_Number__c +'     '+mpassocitem.get(associtm.Id).Quantity__c+'\n';  }
            		        	      
             		     //jjackson reset added_to_turnonnotice field to false now that turnonnotice is being created
             		     associtm.added_to_turnonnotice__c = false;
             		     lstupdateai.add(associtm);
             		  }
            	   } //else workordertype is install or deinstall
                	//system.debug('message line items are:  ' +message);
   		 	
   		 	    	message += '\n';
   		 	    	message += 'Install Crew:  ' +mpwocrew.get(recwoid)+'\n'; //+//'<br/>';
   		 	    	if(mpwoaccttype.get(recwoid) == 'Healthcare Site') //shawks:BUG-00717 - Add Created By for Heathcare TON
                       {  message += 'Created By: ' +mpwocreatedby.get(recwoid) +'\n';  }
   		 	    	message += 'Support Office:  ' +mpwosupport.get(recwoid)+'\n';// +'<br/>';
   		 	    	message += 'Install Manager:  ' +mpwoim.get(recwoid)+'\n'; //+//'<br/>';
   		 	    	message += 'Project Manager:  ' +mpwopm.get(recwoid)+'\n'; //+/'<br/>';
   		 	    	message += 'Project Coordinator:  ' +mpwopc.get(recwoid)+'\n';// +'<br/>';
   		 	    	
   		 	    	//shawks BUG-00744 - Update EmailUtilities.EmailTurnOnNotice call to send project type parameter instead of account type
   		 	    	//try{  EmailUtilities.EmailTurnOnNotice(message, sitename,workordertype, mpwoaccttype.get(recwoid)); }
   		 	    	try{  EmailUtilities.EmailTurnOnNotice(message, sitename, workordertype, projectType); }
   		 	    	
   		 	    	catch(Exception ex){
   		 		     system.debug('Error in CreateTurnOnNotice: ' +ex.getMessage());  }
   		 	    
   		 	    	//system.debug('email message is ' +message);
   		    }  // workorderids loop
   		    
   		        Savepoint sp = Database.setSavepoint();
   		        
   		     	try{  update lstupdateai;  }
   		 	    
   		 	    catch(DMLException dmlex)
   		 	    {Database.rollback(sp);
   		 	     system.debug('DML Error in CreateTurnOnNotice:  ' + dmlex.getMessage());  }
  		 	
   		 	system.debug('***************END CreateTurnOnNotice ***********************************');
   		 	
   	 } //end CreateTurnOnNotice
    
    //Spin through the list of selected associated items being submitted for billing and determine whether they
    //are all installed activated, all de-installed, or a mixture of both.  
    public static String GetTurnonType(List<Associated_Item__c> lstassocitems){
    	    system.debug('*****************START GetTurnonType ***********************');
    	    
    	    String turnontype = '';
    	    Boolean blninstall = false;
    	    Boolean blndeinstall = false;
    	        	    
    	    for(Associated_Item__c recassocitm : lstassocitems)
    	    {
    	    	if(recassocitm.status__c == 'Billing')
    	    	{   blninstall = true;    }
    	    	
    	    	if(recassocitm.status__c == 'De-Installed')
    	    	{   blndeinstall = true;  }
    	    }
    	    
    	    if(blninstall == true && blndeinstall == false)
    	        { turnontype = 'Install';  }
    	        
    	    if(blninstall == false && blndeinstall == true)
    	        { turnontype = 'Deinstall'; }
    	        
    	    if(blninstall == true && blndeinstall == true)
    	        { turnontype = 'Turnonandoff';   }
    	        
    	    
    	    if(blninstall == false && blndeinstall == false)	
    	    {	
    	    	turnontype = '';
    	    	ApexPages.addMessage(new ApexPages.Message(ApexPages.Severity.INFO,
                                                       '<b>ERROR Creating Turn On Notice:  </b>',
                                                       'To create a turn-on notice, line items must have status of Billing, Installed Activated, and/or De-Installed.'));  
    	    }
    	        	    system.debug('**************** END GetTurnonType ************************');
    	        	    
    	    return turnontype;
 
    } //end GetTurnonType
    
    /*shawks BUG-00752 - Ordering is not needed since query uses ORDER BY
    public static List<Associated_Item__c> PutRelatedItemsinOrder(List<Associated_Item__c> lstrelateditems){
    	    system.debug('***********************START PutRelatedItemsinOrder**********************************');
    		
    		Double x = 0;
    		String y = '';
    		Double z = 0;
    		String keystring = '';
    		
    		Map<String,Associated_Item__c> mpordered = new map<String,Associated_Item__c>();
    		List<Associated_Item__c> lstorderedrelateditems = new List<Associated_Item__c>();
    		Map<Id,String> mpparentlines = new map<Id,String>();
    		
    		for(Associated_Item__c recai : lstrelateditems)
    		{
    		  	
    		  	      mpordered.put(recai.hierarchyorder__c,recai);   //first add the product parent lines to the map with an order value
    		  	      mpparentlines.put(recai.id,recai.hierarchyorder__c); 
    		}
            
            
    	
    	//now every assoc item has a sequential order value as a map key
    	//put the map keys in a list and sort, then go back and get each assoc item from
    	//the map using the keys from the list.  They are now in order--add to new list.
    	List<String> keysetlist = new List<String>();
    	keysetlist.addAll(mpordered.keyset());
    	keysetlist.sort();
    		
    	if(keysetlist.size() > 0 )
        {    for(String key : keysetlist)
             {
                  Associated_Item__c airec = new Associated_Item__c();
                  airec = mpordered.get(key);
                  lstorderedrelateditems.add(airec);
             }
        }
           system.debug('***********************END PutRelatedItemsinOrder************************************');
       
       return lstorderedrelateditems;            
    }//end PutRelatedItemsinOrder
    */
   
    public static String MixedTurnOnNotice(List<Associated_Item__c> lstrelateditms){
              system.debug('********************BEGIN MIXEDTURNONNOTICE  ****************************');
               String header = 'ITEMS INSTALLED                BILLING COMM. DT     ';
               String header2 = 'ITEMS DEINSTALLED             DE-INSTALLATION DT    ';
               List<Associated_Item__c> deinstorderedlist = new list<Associated_Item__c>();
               List<Associated_Item__c> instorderedlist = new list<Associated_Item__c>();
               //List<Associated_Item__c> deinstlist = new list<Associated_Item__c>();  //shawks BUG-00752 - Input list is ordered so not needed
               //List<Associated_Item__c> instlist = new list<Associated_Item__c>();    //shawks BUG-00752 - Input list is ordered so not needed
               List<Associated_Item__c> lstupdateaitem = new list<Associated_Item__c>();
               String turnonmessage = '';
               Date billingdate;
               String converteddate;
               
               for(Associated_Item__c recitems : lstrelateditms)
               {
                 if(recitems.status__c == 'Billing' || recitems.status__c == 'Installed Activated')
                 {  instorderedlist.add(recitems);  }  //{    instlist.add(recitems);    }  //shawks BUG-00752 - Input list is ordered so list is ordered
                 
                 if(recitems.status__c == 'De-Installed')
                 {  deinstorderedlist.add(recitems);  }  //{    deinstlist.add(recitems);     }  //shawks BUG-00752 - Input list is ordered so list is ordered
                 
                 //since we are looping through the associated items anyway, reset the added_to_turnonnotice__c field to false
                 recitems.added_to_turnonnotice__c = false;
                 lstupdateaitem.add(recitems);
                 
    		   }
               
               //shawks BUG-00752 - Input list is ordered so not needed
               //deinstorderedlist = PutRelatedItemsinOrder(deinstlist);  
               //instorderedlist = PutRelatedItemsinOrder(instlist);
               
               turnonmessage += header +'CONTRACT ID    QUANTITY    PROJECT' +'\n'+'\n';
               
               for(Associated_Item__c institem : instorderedlist)
               {  billingdate = null;
               	  converteddate = '';
                  billingdate = institem.Billing_Commencement_Date__c;  
               	  if(billingdate != null)
            		  	{ converteddate = billingdate.month() + '-' + billingdate.day() +'-' +billingdate.year(); }
            	  else
            		  	{ converteddate = 'no date provided';  }
               	
               	   if(institem.name.contains('Product Parent'))
            		    //shawks BUG-00680 - add Project Number
            		    //shawks CPQ - Replace: order_item__r.legal_contract_id__c -> order_item__r.Contract_Number__c
            		    //{turnonmessage += institem.Name +'     ' +converteddate +'   '+institem.order_item__r.legal_contract_id__c +'   '+institem.Quantity__c +'   '+institem.project_number__c+'\n';}
            		    {turnonmessage += institem.Name +'     ' +converteddate +'   '+institem.order_item__r.Contract_Number__c +'   '+institem.Quantity__c +'   '+institem.project_number__c+'\n';} 
            	   else if(institem.order_item__r.parent__r.Name.contains('Product Parent'))
            		    //{turnonmessage += '     ' +institem.Name +'       ' +converteddate +'   '+institem.order_item__r.legal_contract_id__c +'    '+institem.Quantity__c+'\n';  }
            		    {turnonmessage += '     ' +institem.Name +'       ' +converteddate +'   '+institem.order_item__r.Contract_Number__c +'    '+institem.Quantity__c+'\n';  }
            	   else
            		    //{turnonmessage += '           ' +institem.Name +'    ' +converteddate +'   '+institem.order_item__r.legal_contract_id__c +'     '+institem.Quantity__c+'\n';  }
            		    {turnonmessage += '           ' +institem.Name +'    ' +converteddate +'   '+institem.order_item__r.Contract_Number__c +'     '+institem.Quantity__c+'\n';  }
              	}  //end loop of installed line items
              	
              	turnonmessage += '\n';
              	turnonmessage += '\n';
              	turnonmessage += header2 +'CONTRACT ID    QUANTITY    PROJECT' +'\n'+'\n';
              	
              	for(Associated_Item__c deinstitem : deinstorderedlist)  //there is no BCD date for deinstalled lines, so use the converted date from last installed line
               {                 	
               	   if(deinstitem.name.contains('Product Parent'))
            		    	//shawks CPQ - Replace: order_item__r.legal_contract_id__c -> order_item__r.Contract_Number__c
            		    	//{turnonmessage += deinstitem.Name +'     ' +converteddate +'   '+deinstitem.order_item__r.legal_contract_id__c +'   '+deinstitem.Quantity__c+'   '+deinstitem.project_number__c+'\n';}
            		    	{turnonmessage += deinstitem.Name +'     ' +converteddate +'   '+deinstitem.order_item__r.Contract_Number__c +'   '+deinstitem.Quantity__c+'   '+deinstitem.project_number__c+'\n';} 
            		    	else if(deinstitem.order_item__r.parent__r.Name.contains('Product Parent'))
            		    	//{turnonmessage += '     ' +deinstitem.Name +'       ' +converteddate +'   '+deinstitem.order_item__r.legal_contract_id__c +'    '+deinstitem.Quantity__c+'\n';  }
            		    	{turnonmessage += '     ' +deinstitem.Name +'       ' +converteddate +'   '+deinstitem.order_item__r.Contract_Number__c +'    '+deinstitem.Quantity__c+'\n';  }
            		    	else
            		    	//{turnonmessage += '           ' +deinstitem.Name +'    ' +converteddate +'   '+deinstitem.order_item__r.legal_contract_id__c +'     '+deinstitem.Quantity__c+'\n';  }
            		    	{turnonmessage += '           ' +deinstitem.Name +'    ' +converteddate +'   '+deinstitem.order_item__r.Contract_Number__c +'     '+deinstitem.Quantity__c+'\n';  }
             	}  //end loop of deinstalled line items
                   system.debug('*********************END MixedTurnOnNotice ***************************');
                
                Savepoint sp = Database.SetSavepoint();
                
                try
                { update lstupdateaitem;   }
                
                catch(DMLException dmle)
                {  Database.rollback(sp);
                   system.debug('DML Error in MixedTurnOnNotice:  ' + dmle.getMessage());   }
                
                catch(Exception e)
                {  Database.rollback(sp);
                 	system.debug('Error in MixedTurnOnNotice:  ' +e.getMessage());   }
                  
                return turnonmessage;             	
           
             } //end MixedTurnOnNotice 

       /*shawks 20190903: BUG-00947 - Comment out ActivateServiceContracts
       public static void ActivateServiceContracts(List<Work_Order__c> wotriggernewlist, Map<Id,Work_Order__c> mpwotriggerold)
       {
     	system.debug('**************************START StandardOrderTriggerLogic.ActivateServiceContracts******************************');
     	
     	List<ServiceContract> lstservicecons = New List<ServiceContract>();
     	List<ServiceContract> lstupdservcont = New List<ServiceContract>();
     	Set<String> legacynames = new Set<String>();
     	Set<Id> setbillingworkorders = new Set<Id>();
     	Map<Id,Date> mplclitobcd = new Map<Id,Date>();  //this maps legal contract line item id to billing commencement date
     	Map<Id,String> mplclitostatus = new Map<Id,String>();  //this maps legal contract line item id to associated item status
     	
     	for(Work_Order__c worec : wotriggernewlist)
     	{
     		if(worec.Status__c != mpwotriggerold.get(worec.Id).Status__c && worec.Status__c == 'Billing/Go Live')
     		{	setbillingworkorders.add(worec.Id);
     			system.debug('work order at Billing/Go Live is ' +worec.Id);   }
     	}
     	
     	if(!setbillingworkorders.IsEmpty())
     	{//get a list of legacy service contract names from Custom Setting Legacy_Service_Contract_Names__c
     		List<Legacy_Service_Contract_Names__c> legacysc = Legacy_Service_Contract_Names__c.getall().values();
        	if(test.isRunningTest())
        	{  legacynames.add('Legacy');  }  //put this here because test can't pull values from custom settings
        	else
        	{
       			for(Legacy_Service_Contract_Names__c name : legacysc)
         		{   legacynames.add(name.Name);  }
        	}
			
			//get associated item and order item info from associated items related to the work orders
			//shawks CPQ - Replace: Legal_Contract_Line_Item__c -> Subscription__c
			List<Associated_Item__c> lstassocitems = new List<Associated_Item__c>();
			lstassocitems = [Select Id, Name, Status__c, Billing_Commencement_Date__c, Work_Order__c, Order_Item__r.Id, Order_Item__r.Asset__c,
			                 Order_Item__r.Subscription__c
			                 from Associated_Item__c where Work_Order__c in :setbillingworkorders AND Status__c in ('Billing', 'De-Installed', 'Installed Activated') ];
			
			Set<Id> setlcliid = New Set<Id>();
			//add legal contract line item ids to a set so they can be used to query service contracts related to them
			//create a map of lcli id and billing_commencement_date for adding start date to service contract
			for(Associated_Item__c recai : lstassocitems)
			{
				//shawks CPQ - Replace: Legal_Contract_Line_Item__c -> Subscription__c
				//{setlcliid.add(recai.Order_Item__r.Legal_Contract_Line_Item__c);
				// mplclitobcd.put(recai.Order_Item__r.Legal_Contract_Line_Item__c,recai.Billing_Commencement_Date__c);
				// mplclitostatus.put(recai.Order_Item__r.Legal_Contract_Line_Item__c,recai.Status__c);
				 {setlcliid.add(recai.Order_Item__r.Subscription__c);
				 mplclitobcd.put(recai.Order_Item__r.Subscription__c,recai.Billing_Commencement_Date__c);
				 mplclitostatus.put(recai.Order_Item__r.Subscription__c,recai.Status__c);
				//system.debug('lcli added to map is ' +recai.Order_Item__r.Legal_Contract_Line_Item__c + ', ' +recai.Billing_Commencement_Date__c + ', ' + recai.Name);  
				}
			}
			
			//now get the service contracts that need to be turned on or shut off that are related to legal contract line items in the order
		    //shawks CPQ - Replace: Legal_Contract_Line_Item__c -> Subscription__c; Legal_Contract_Line_Item__r -> Subscription__r
     		//lstservicecons = [Select Id, Name, Product_Inventory__c, Term, StartDate, EndDate, Status, Legal_Contract_Line_Item__r.Status__c, NotificationNeeded__c,
     		//                  Legal_Contract_Line_Item__c from ServiceContract where Legal_Contract_Line_Item__c in :setlcliid AND Status in ('Active', 'Inactive') ];
     	    lstservicecons = [Select Id, Name, Product_Inventory__c, Term, StartDate, EndDate, Status, Subscription__r.Status__c, NotificationNeeded__c,
     		                  Subscription__c from ServiceContract where Subscription__c in :setlcliid AND Status in ('Active', 'Inactive') ];

     		if(!lstservicecons.IsEmpty())
     		{
     			for(ServiceContract sc : lstservicecons)
				{
		        	//system.debug('getting ready to set dates for ' +sc.Name +' for lcli id ' +sc.Legal_Contract_Line_Item__c);
				    //shawks CPQ - Replace: Legal_Contract_Line_Item__c -> Subscription__c
					Boolean legacyname = legacynames.Contains(sc.Name);
					String associtemstatus = mplclitostatus.get(sc.Subscription__c);
								
			  //if the service contract is not a legacy and has never been activated (inactive) add start/end dates
			   		if(legacyname == false && sc.Status == 'Inactive' && (associtemstatus == 'Billing' || associtemstatus == 'Installed Activated'))
			   		{	
			   	    	//system.debug('service contract term is ' +sc.Term +', ' +sc.Name);
			   			if(sc.Term > 0)
			   			{	
			   				//shawks CPQ - Replace: Legal_Contract_Line_Item__c -> Subscription__c
			   				system.debug('inside the term if statement');
			   				system.debug('bcd for line item is ' +mplclitobcd.get(sc.Subscription__c));
			   				sc.StartDate = mplclitobcd.get(sc.Subscription__c);
				 			sc.EndDate = mplclitobcd.get(sc.Subscription__c).addMonths(sc.Term);
				 			lstupdservcont.add(sc);   
				 		}
				 		else
				 		{	
				 		  //if the service contract has no term on it, default length of service contract to 90 days and check
				 		  //the boolean field to trigger a notification email
				 		  //shawks CPQ - Replace: Legal_Contract_Line_Item__c -> Subscription__c
				 			system.debug('inside the else statement');
				 			sc.StartDate = mplclitobcd.get(sc.Subscription__c);
			 				sc.EndDate = (mplclitobcd.get(sc.Subscription__c).addDays(90));
				 			sc.NotificationNeeded__c = true;
				 			lstupdservcont.add(sc);
				 		} //end if sc.term > 0			 		
			   		 } //end if legacyname == false etc.
			   		 
			   //if the service contract is not a legacy and it is already activated and the work order item is at De-Installed, change end date to today
			   		if(legacyname == false && sc.Status == 'Active' && associtemstatus == 'De-Installed')
			   		{  
			   	  		sc.EndDate = system.today();
			   	  		lstupdservcont.add(sc);  
			   	    } 
			   } //end service contract for loop
		
				try
				{
			   		if(!lstupdservcont.IsEmpty())
			   	  		update lstupdservcont;
				}
			   	catch(Exception e)
				{   system.debug('Error in StandardOrderTriggerLogic.ActivateServiceContracts:  ' +e.getMessage()); }
			}// end if lstservicecons is not empty
			else
			{system.debug('ActivateServiceContracts:  No related service contracts found.'); }
	
     	}//end if setbillingworkorders is not empty
     	system.debug('**********************************END StandardOrderTriggerLogic.ActivateServiceContracts***************************');
      }//end ActivateServiceContracts
      */

      public static void UpdateChildWorkOrderName(Map<Id,Work_Order__c> mpwotriggernew, Map<Id,Work_Order__c> mptriggerold)
      {
      	//if a work order is created with no associated item product parents, it gets the base name.  If any child work orders
      	//are then created, they also get the base name.  When associated item product parents are added to the parent work order,
      	//the work order name updates with the prod parent abbreviations, but the child work order doesn't.  This method will check
      	//to see if a work order with name being updated has child work orders that also need to be updated
      	
      	system.debug('****************************BEGIN UpdateChildWorkOrderName****************************');
      	
      	Set<Id> setwonamechange = new Set<Id>();
      	Map<Id,String> mpwoidtoname = new Map<Id,String>();
      	List<Work_Order__c> lstupdchildren = new List<Work_Order__c>();
      	
      	for(Work_Order__c wo : mpwotriggernew.values()) //loop through the trigger wo's to see if any names have changed
      	{
      	  if(wo.parent_work_order__c == null)
      	  {  
      		String woname = wo.name;
   			mpwoidtoname.put(wo.id,woname);
      	  }
      	}
      	
      	///get all child work orders and update the name if needed
      	if(mpwoidtoname.size() > 0 || mpwoidtoname != null)
      	{
      		List<Work_Order__c> lstchildwo = New List<Work_Order__c>();
      		lstchildwo = [ Select Id, Name, Parent_Work_Order__c, site_id__c, recordtypeid from work_order__c where parent_work_order__c in :mpwoidtoname.keyset() ];
      		
      		if(lstchildwo.size() > 0)
      		{
      			for(Work_Order__c cwo : lstchildwo)
      			{
      				//system.debug('child work order names are ' +cwo.name);
      				
      				Boolean changename = false;
      				String parentname = '';
      				String childname = '';
      				String parentabb = '';
      				String childabb = '';
      				String rectypename = '';
      				String basename = '';
      				String abbrevsubstring = '';
      				String newname = '';
      				parentname = mpwoidtoname.get(cwo.parent_work_order__c);
      				childname = cwo.name;
      				parentabb = parentname.substringAfterLast('- ');
      				childabb = childabb.substringAfterLast('- ');
      				if(parentabb == null)
      				{   parentabb = 'noprodparents';  }
      				   
      				if(childabb == null)
      				{   childabb = 'noprodparents';  }
      				
      				if(parentabb != childabb)
      				{ changename = true;  }
      				
      			  if(changename == true)
      			  {	      				
      				Map<Id,Schema.RecordTypeInfo> rtmap = Schema.getGlobalDescribe().get('Work_Order__c').getDescribe().getRecordTypeInfosById();
			        rectypename = rtmap.get(cwo.recordtypeid).getName(); //get the rec type name from the record type id
			        basename = cwo.site_id__c +' - ' +rectypename +' - '; //must create a new base name because child rec type is different from parent
			        //system.debug('child base name is ' +basename);
			        //get a substring of the abbreviations from the parent name to complete the child work order name
			        //system.debug('parent abbreviations are ' +abbrevsubstring);
			        if(parentabb == 'noprodparents')
			        {  newname = basename;  }
			        else
			        {  newname = basename+parentabb; }
			        
			        String subnewname;
			        if(newname.length() > 79)
			        { subnewname = newname.substring(0,79); }
			        else
			        { subnewname = newname;  }
			        
			        //update the child work order name
			        cwo.Name = subnewname;
			        lstupdchildren.add(cwo);
      			  }//end if changename is true
			        
      			} //end for loop lstchildwo
      			
      			if(!lstupdchildren.IsEmpty())
      			try{ update lstupdchildren; }
      			catch(Exception e)
      			{system.debug('Error updating child work order names: ' +e.getMessage()); }
      		} //end if lstchildwo.size > 0
      	} //end if mpwoidtoname is not null
      	
      	system.debug('***********************END Update Child Work Order Name****************************');
      	
      }//end UpdateChildWorkOrderName

   //shawks: BUG-00717 - Add new method for Healthcare Notifications for certain events
   public static void CreateHCNotification(List<Work_Order__c> lstwotriggernew, Map<Id,Work_Order__c> mptriggerold)
   {
      System.Debug('******************************START CreateHCNotification*****************************************');
      String strSeparator = '|';
      Id woRecordType_Install = Utilities.RecordTypeNameToId('Work_Order__c', 'Install');
      Id woRecordType_Sched = Utilities.RecordTypeNameToId('Work_Order__c', 'Schedules');
      Set<String> setwochanged = New Set<String>();
      Map<Id,String> mpwonum = New Map<Id,String>();
      Map<Id,String> mpwoevent = New Map<Id,String>();
      Map<Id,String> mpwoeventdate = New Map<Id,String>();
      Map<Id,String> mpwoponum = New Map<Id,String>();
      Map<Id,Id> mpwonewcrewid = New Map<Id,Id>();
      Map<Id,Account> mpwonewcrewname = New Map<Id,Account>();

      Map<String,Schema.RecordTypeInfo> mprecordtypeschema = Schema.SobjectType.Work_Order__c.getRecordTypeInfosByName();
      
      for(Work_Order__c recnewwo : lstwotriggernew)
      {
             //Initialize variables per Work Order
             String strEvent = '';
             String strEventDate = '';
             //Check if a Install record type
             if(recnewwo.RecordTypeId == woRecordType_Install)
             {
                //Check if Equipment Delivery Date was just set
                if(recnewwo.Equipment_Delivery_Date__c != null && mptriggerold.get(recnewwo.id).Equipment_Delivery_Date__c == null)
                {
                   setwochanged.add(recnewwo.id);
                   mpwonum.put(recnewwo.id, recnewwo.Work_Order_Number__c);              //Map Work Order Number to Work Order
                   //Create Event and Event Date strings that will be mapped to the Work Order Id
                   strEvent = buildSepString(strEvent,'Equipment Delivery',strSeparator);
                   strEventDate = buildSepString(strEventDate,recnewwo.Equipment_Delivery_Date__c.format(),strSeparator);
                   mpwoponum.put(recnewwo.id, recnewwo.po__c);                           //Map Purchase Order to Work Order
                   if(recnewwo.crew__c != mptriggerold.get(recnewwo.id).crew__c)  //Check if crew has changed
                   {
                      mpwonewcrewid.put(recnewwo.id, recnewwo.crew__c);                  //Map Crew Id to Work Order
                   }
                }  //End - Check if Equipment Delivery Date was just set
                //Check if Install Complete Date was just set
                if(recnewwo.Install_Complete_Date__c != null && mptriggerold.get(recnewwo.id).Install_Complete_Date__c == null)
                {
                   setwochanged.add(recnewwo.id);
                   mpwonum.put(recnewwo.id, recnewwo.Work_Order_Number__c);              //Map Work Order Number to Work Order
                   //Create Event and Event Date strings that will be mapped to the Work Order Id
                   strEvent = buildSepString(strEvent,'Install Complete',strSeparator);
                   strEventDate = buildSepString(strEventDate,recnewwo.Install_Complete_Date__c.format(),strSeparator);
                   mpwoponum.put(recnewwo.id, recnewwo.po__c);                           //Map Purchase Order to Work Order
                   if(recnewwo.crew__c != mptriggerold.get(recnewwo.id).crew__c)  //Check if crew has changed
                   {
                      mpwonewcrewid.put(recnewwo.id, recnewwo.crew__c);                  //Map Crew Id to Work Order
                   }
                }  //End - Check if Install Complete Date was just set
             }
             //Check if a Schedules record type
             if(recnewwo.RecordTypeId == woRecordType_Sched)
             {
                //Check if Billing Date was just set
                if(recnewwo.Billing_Date__c != null && mptriggerold.get(recnewwo.id).Billing_Date__c == null)
                {
                   setwochanged.add(recnewwo.id);
                   mpwonum.put(recnewwo.id, recnewwo.Work_Order_Number__c);              //Map Work Order Number to Work Order
                   //Create Event and Event Date strings that will be mapped to the Work Order Id
                   strEvent = buildSepString(strEvent,'Feature Go Live',strSeparator);
                   strEventDate = buildSepString(strEventDate,recnewwo.Billing_Date__c.format(),strSeparator);
                   mpwoponum.put(recnewwo.id, recnewwo.po__c);                           //Map Purchase Order to Work Order
                }  //End - Check if Billing Date was just set
             }  //End - Check if a Schedules record type
             //Create maps relating Events and Event Dates to Work Order Id
             mpwoevent.put(recnewwo.id,strEvent);
             mpwoeventdate.put(recnewwo.id,strEventDate);
      }  //End - recnewwo for loop

      //Check if work order has new Crew; find crew name and map to crew Id 
      if(!mpwonewcrewid.isEmpty())
      {
         mpwonewcrewname.putAll([ SELECT Id, Name
                                  FROM Account
                                  WHERE Id IN :mpwonewcrewid.values() ]);         
      }

      //Pull data for work orders from the database
      //shawks BUG-00775 - Add project type to query
      List<Work_Order__c> lstworkorders =  [ SELECT Id, name
                                                   ,Account_Type__c
                                                   ,RecordType.Name
                                                   ,site__r.name
                                                   ,Work_Order_Number__c
                                                   ,crew__r.name
                                                   ,CreatedBy.Name
                                                   ,(SELECT Id, project_number__c, project_type__c
                                                     FROM Associated_Items__r
                                                     WHERE Name LIKE '%Product Parent%')
                                             FROM Work_Order__c
                                             WHERE Id = :setwochanged
                                               AND site__r.type = 'Healthcare Site'
                                               AND RecordTypeId IN (:woRecordType_Install, :woRecordType_Sched) ];

      //Retrieve email address from Custom Setting
      String email;
      List<String> emailAddress = new list<String>();
      if(test.isRunningTest())
      { 
       	 email = 'shawks@sonifi.com'; 
         emailAddress.add(email);
      }
      else
      { 
         EmailAddress_TON__c cs = EmailAddress_TON__c.getInstance('HealthcareEmailNotification');
         email = cs.EmailAddress__c;
         //email = 'shawks@sonifi.com'; 
         emailAddress.add(email);  
      }

      //Create email components
      for(Work_Order__c wo : lstworkorders)
      {
        //Initialize maps per Work Order
        Map<Integer,String> mpStrEvent = New Map<Integer,String>(SepStringToMap(mpwoevent.get(wo.id),strSeparator));
        Map<Integer,String> mpStrEventDate = New Map<Integer,String>(SepStringToMap(mpwoeventdate.get(wo.id),strSeparator));
        //shawks BUG-00775 - Check if Healthcare project; move setting of project string (strProject) out of LOOP since same for all events
        //Find related projects
        Boolean blnHC_Project = false;
        String strProject = '';
        Set<String> woprojects = New Set<String>();
        for(Associated_Item__c woassocitems : wo.Associated_Items__r)
        {
           if(!blnHC_Project && woassocitems.project_type__c == 'Healthcare')
           {
              blnHC_Project = true;
           }

           if(woassocitems.project_number__c != null)
           {
              //Add to Set so duplicates are removed
              woprojects.add(woassocitems.project_number__c);
           }
        }
        //Set Project string
        strProject = SetToSepString(woprojects,',');
        //Only create and send email if project type of one of associated items is "Healthcare"
        if(blnHC_Project)
        {
           //Loop through events
           for(Integer i = 0; i < mpStrEvent.size(); i++)
           {
              String emailSubject = '';
              String emailBody = '';
              emailSubject += wo.site__r.name + ': ' +mpStrEvent.get(i);
              emailBody += 'Site ID: ' +wo.site__r.name +'\n';
              emailBody += 'Work Order #: ' +wo.Work_Order_Number__c +'\n';
              emailBody += 'Project #: ' +strProject +'\n';
              emailBody += 'Event: ' +mpStrEvent.get(i) +'\n';
              emailBody += 'Event Date: ' +mpStrEventDate.get(i) +'\n';

              if(mpwoponum.get(wo.id) != null)  //Check if there is a Purchase Order #
              {  emailBody += 'PO #: ' +mpwoponum.get(wo.id) +'\n';  }
              else
              {  emailBody += 'PO #: \n';  }

              if(mpStrEvent.get(i) != 'Feature Go Live')  //If not Schedules-Billing (Feature Go Live) - set crew and create by
              {
                 if(mpwonewcrewid.containsKey(wo.id))  //Check if new Crew; set Crew Name
                 {  emailBody += 'Crew: ' +mpwonewcrewname.get(mpwonewcrewid.get(wo.id)).Name +'\n';  }
                 else
                 {  emailBody += 'Crew: ' +wo.Crew__r.Name +'\n';  }
                 emailBody += 'Created by: ' +wo.CreatedBy.Name +'\n';
              }
              //Send email with EmailNotification call
              try
              {  EmailUtilities.EmailNotification(emailAddress, emailSubject, emailBody);  }
              catch(Exception ex)
              {  System.Debug('Error in CreateNotification: ' +ex.getMessage());  }
           }  //End Event for loop
        }  //End if blnHC_Project        
      }  //End wo for loop
      
      System.Debug('******************************END CreateHCNotification*****I*************************************');
   }  //End CreateNotification

   //shawks: BUG-00717 - Convert a set to a string separated by a separator (',', '|', etc.)
   public static String SetToSepString(Set<String> inputSet, String separatorValue)
   {
      if(inputSet.isEmpty())
      {  return null;  }

      String outputString = '';
      Integer i = 1;
      for(String recSet : inputSet)
      {
         if(i == 1)
         {  outputString = recSet;  }
         else
         {  outputString += separatorValue + recSet;  }
         i = i + 1;
      }
      return outputString;
   }  //End SetToSepString

   //shawks: BUG-00717 - Convert a string separated by a separator (',', '|', etc.) to a map
   public static Map<Integer,String> SepStringToMap(String inputString, String separatorValue)
   {
      if(inputString == '' || inputString == null)
      {  return null;  }

      Integer endIndex = 0;
      String strSubstring;
      Map<Integer,String> outputMap = New Map<Integer,String>();

      strSubstring = inputString;
      for(Integer i = 0; i <= inputString.countMatches(separatorValue); i++)
      {
         endIndex = strSubstring.indexOf(separatorValue,0);
         if(endIndex > -1)  //Check if separator value found (-1 if not found)
         {
			outputMap.put(i,strSubstring.substring(0,endIndex));
            strSubstring = strSubstring.substring(endIndex + 1);
         }
         else  //No separator found
		 {  outputMap.put(i,strSubstring);  }
      }
      return outputMap;
   }  //SepStringToMap

   //shawks: BUG-00717 - Concentenate a string with a new string separated by a separator
   public static String buildSepString(String strNow, String newString, String separatorValue)
   {
      String outString;
	  if(strNow == '' || strNow == null)
	  {  outString = newString;  }
	  else
	  {  outString = strNow + separatorValue + newString; }
	  return outString;
   }  //buildSepString
    
    public static void ProCentricNotification(List<Work_Order__c> triggernewlist, Map<Id,Work_Order__c> triggeroldmap)
	{
			system.debug('***************BEGIN PROCENTRIC NOTIFICATION****************');
			
			Set<Id> setworkorderid = New Set<Id>();  //set of work order id's belonging to rack build parent work orders
			Id rackbuildid = Utilities.RecordTypeNameToId('Work_Order__c', 'Rack Build');
			List<Associated_Item__c> lstai = New List<Associated_Item__c>();
			Map<Id, Work_Order__c> mprackbuildwo = New Map<Id,Work_Order__c>();
			
			for(Work_Order__c wo : triggernewlist)
			{
				if(wo.recordtypeid == rackbuildid && wo.parent_work_order__c != null)
				{
					if(wo.to_warehouse_date__c != null && triggeroldmap.get(wo.id).to_warehouse_date__c == null ||
					  wo.to_warehouse_date__c != null && wo.to_warehouse_date__c != triggeroldmap.get(wo.id).to_warehouse_date__c)
					   {
					   	  mprackbuildwo.put(wo.parent_work_order__c, wo); //add the rack build work order to map with parent id as key
					   }
				}
			}
			
			if(!mprackbuildwo.isEmpty())  //if there is a rack build work order in the trigger where to warehouse date has changed
			{
				lstai = [ Select Id, Name, work_order__c, status__c from Associated_Item__c where 
				          work_order__c in :mprackbuildwo.keyset() AND status__c not in ('De-Installed', 'Installed Activated', 'Cancelled') AND
				          name = 'Pro:Centric Direct Customization' ]; //query the associated items to find pro:centric line items related to the rack-build's parent
				          
				          system.debug('number of procentric line items in lstai is ' +lstai.size()); 
			
			
				if(!lstai.isEmpty()) //if pro centric line items are found, pass the list of associated items to the Email Utilities class
				{
					EmailUtilities.SendProCentricNotification(lstai, mprackbuildwo);
					system.debug('work order items were sent to EmailUtilities class.');
				}
			
			}
			
			system.debug('**************END PROCENTRIC NOTIFICATION**************');
	}
	
	public static List<Work_Order__c> PopulateFSLFields(List<Work_Order__c> triggernewlist)
	{
		system.debug('**********BEGIN PopulateFSLFields***********');

		Map<String,SonifiWorkOrderFSLFields__c> csmap = New Map<String,SonifiWorkOrderFSLFields__c>();
		List<Work_Order__c> populatedlist = New List<Work_Order__c>();
		Set<String> setpolicy = New Set<String>();
		Set<String> setworktype = new Set<String>();
		List<FSL__Scheduling_Policy__c> lstpolicy = New List<FSL__Scheduling_Policy__c>();
		List<WorkType> lstworktypes = New List<WorkType>();
		Map<String,id> mpworktype = new map<String,Id>();
		Map<String,id> mppolicy = new map<String,Id>();

		List<SonifiWorkOrderFSLFields__c> fslfieldlist = SonifiWorkOrderFSLFields__c.getall().values();
		for(SonifiWorkOrderFSLFields__c field :fslfieldlist)
		{
			csmap.put(field.name, field);
			setworktype.add(field.Work_Type__c);
			setpolicy.add(field.Scheduling_Policy__c);
			//system.debug('work type from the custom setting is ' +field.Work_Type__c);
		}

		//system.debug('csmap size is ' +csmap.size());

		if(csmap.size() > 0)
		{
			lstworktypes = [Select Id, Name from WorkType where name in :setworktype ];
			//system.debug('lstworktypes size is ' +lstworktypes.size());
			for(WorkType w :lstworktypes)
			{  mpworktype.put(w.name,w.id); 
			   //system.debug('mpworktype name is ' +w.name);
			}

			system.debug('mpworktype size is ' +mpworktype.size());

			lstpolicy = [Select Id, Name from FSL__Scheduling_Policy__c where name in :setpolicy];
			for(FSL__Scheduling_Policy__c pol :lstpolicy)
			{  mppolicy.put(pol.name,pol.id); }

			system.debug('mppolicy size is ' +mppolicy.size());

			for(Work_Order__c wo :triggernewlist)
			{	
				//system.debug('recordtypeid is ' +wo.recordtypeid);
				SonifiWorkOrderFSLFields__c fslfield = New SonifiWorkOrderFSLFields__c();
				String rectypename = Utilities.RecordTypeIdtoName('Work_Order__c', wo.recordtypeid);
				system.debug('record type name is ' +rectypename);
				if(csmap.containskey(rectypename))
				{
					fslfield = csmap.get(rectypename);
	
					if(mpworktype.containskey(fslfield.Work_Type__c))
					{ wo.work_type__c = mpworktype.get(fslfield.Work_Type__c); }

					if(mppolicy.containskey(fslfield.Scheduling_Policy__c))
					{ wo.scheduling_policy__c = mppolicy.get(fslfield.Scheduling_Policy__c); }


				}
				
				
				populatedlist.add(wo);
			} //end for loop triggernewlist
		}//end if csmap size

		system.debug('**************END PopulateFSLFields****************');

		return populatedlist;

	}//end PopulateFSLFields

   
}//end WorkOrderTriggerLogic.cls