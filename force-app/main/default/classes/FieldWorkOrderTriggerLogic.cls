/*  
	shawks 12/2019: BUG-01021 - Use Record Type of Site Survey to determine Work Type of FWO to determine duration
	08/2019 Post FSL - jjackson - Made the following code changes:  When a work order is linked to a case,
	auto-populate the work type and service territory to match what is on the case; For work orders created from 
	a Sonifi deployment work order, auto-populate the Account and Address;  Changed the FWO trigger code
	to populate the Service Contract Exceptions field for PM FWO's; Added new method PopulateSiteSurveyWorkOrderFields
	for standard work orders that are linked to Site Survey records.
	07/2019 Post FSL-jjackson--Adding code for the following:  Change ownership on PM FWO 
	service resource that is assigned to the PM by the maintenance plan
	05/2019 jjackson Added new method AssignRecordTypes for FSL project.  This assigns the appropriate
	work order record depending on whether work order is linked to a case or sonifi work order, or is a PM.
	04/2019 jjackson Added new method LinkAssociatedItems for FSL project. This links and unlinks associated
	items to standard work order object for creating a Service Report in Field Service Lightning.
	02/2018 jjackson Add Professional Solutions case product type to the CreateTripLaborChildLines
	method so that trip and labor field work order line items for trip and labor can be auto-created
	when a case linked to a fwo has a case product type of Professional Solutions.
	01/2018 jjackson Entitlements for Third Party Partners:  added code to PopulateWorkOrderUponCreation
	to automatically assign field work order record type of Third Party FWO if the related case is a support
	case but the entitlement name on the case is contained in custom setting list ThirdPartyEntitlementName. 
	11/2017 jjackson Added code to PopulateTechField that will skip trying to get
    the user's ceridian name and region from the custom setting if the value of the
    account_country__c field is Canada.
	10/2017 jjackson Added code to EmailUponApproval method to cover email notifications for
    third party fwo's.  
	6/2017 jjackson Change PopulateWorkOrderUponCreation depending on whether the work order
    in the trigger is a third party work order or a regular work order
	Joan Jackson, Sonifi Solutions, November 2016
	This code governs functionality on the field service work order (WorkOrder object);
*/


public with sharing class FieldWorkOrderTriggerLogic
{
	static Map<String,Id> mpsp = New Map<String,Id>();
	//shawks BUG-01021 - Comment out; change to include record
	//static Map<String,Id> mpwt = New Map<String,Id>();
	static Map<String,WorkType> mpwt = New Map<String,WorkType>();

	
	public static List<WorkOrder> AssignRecordTypes (List<WorkOrder> triggernewlist)
	{
		List<WorkOrder> lstwo = New List<WorkOrder>();
		List<RecordType> lstrectypes = New List<RecordType>();
		Map<String,Id>mprecnametoid = New Map<String,Id>();
		Map<Id,WorkOrder> mpcaseidtowo = New Map<Id,WorkOrder>();
		Map<Id,WorkOrder> mpsonifiwotowo = New Map<Id,WorkOrder>();
		Map<Id,WorkOrder> mpsurveytowo = New Map<Id,WorkOrder>();
		List<WorkOrder> lstpmwo = New List<WorkOrder>();
		List<WorkType> lstwt = New List<WorkType>();
		List<FSL__Scheduling_Policy__c> lstsp = New List<FSL__Scheduling_Policy__c>();
		

		lstsp = [Select Id, Name from FSL__Scheduling_Policy__c ];
		//shawks BUG-01021 - Comment out; change to include more info
		//lstwt = [ Select Id, name from worktype ];
		lstwt = [ Select Id, name, EstimatedDuration, DurationType from worktype ];

		for(WorkType wt : lstwt)
		//shawks BUG-01021 - Comment out; change to include record
		//{  mpwt.put(wt.name,wt.id); }
		{  mpwt.put(wt.name,wt); }

		for(FSL__Scheduling_Policy__c sp :lstsp)
		{  mpsp.put(sp.name,sp.id); }

		for(WorkOrder w :triggernewlist)
		{
			if(w.caseid != null)
			{
				mpcaseidtowo.put(w.caseid,w);
			}
			
			system.debug('mpcaseidtowo size is ' +mpcaseidtowo.size());
			
			if(w.sonifi_work_order__c != null)
			{
				mpsonifiwotowo.put(w.sonifi_work_order__c,w);
			}
			
			system.debug('mpsonifiwotowo size is ' +mpsonifiwotowo.size());
			
			if(w.site_survey__c != null)
			{  mpsurveytowo.put(w.site_survey__c,w);  }
			
			system.debug('mpsurveytowo size is ' +mpsurveytowo.size());
			
			if(w.caseid == null && w.sonifi_work_order__c == null && w.site_survey__c == null)
			{
				lstpmwo.add(w);
			}
			
		}

		lstrectypes = [Select Id, Name, SobjectType from Recordtype where SobjectType = 'WorkOrder'];
		               
		for(RecordType r :lstrectypes)
		{ 
			//system.debug('AssignRecordTypes line 93 record type name is ' +r.name);
			mprecnametoid.put(r.name,r.Id);
		}
		
		system.debug(mprecnametoid);
		
		if(mpcaseidtowo.size() > 0)
		{
			List<Case> lstcase = New List<Case>();
			lstcase = [Select Id, recordtype.name,service_territory__c, work_type__c from Case where id in :mpcaseidtowo.keyset()];
			
			for(Case c :lstcase)
			{
				if(mpcaseidtowo.containskey(c.id))
				{
					WorkOrder wo = New WorkOrder();
					wo = mpcaseidtowo.get(c.id);
					if(c.recordtype.name == 'Support Case')
					{
						wo.recordtypeid = mprecnametoid.get('FWO');
						wo.serviceterritoryid = c.service_territory__c;
						wo.worktypeid = c.work_type__c;
						lstwo.add(wo);
					}
					
					system.debug('lstwo size is ' +lstwo.size());
					
					if(c.recordtype.name == 'Contracted Field Service')
					{
							wo.recordtypeid = mprecnametoid.get('Third Party FWO');
							wo.worktypeid = c.work_type__c;
							lstwo.add(wo);
					}
				}
			}//end for loop case
		}//end if mpcaseidtowo.size > 0
		
		if(mpsonifiwotowo.size() > 0)
		{
			List<Work_Order__c> lstsonwo = New List<Work_Order__c>();
			lstsonwo = [ Select Id, recordtype.name, site__c, site__r.physical_street_address_line_1__c,
			             site__r.physical_city__c, site__r.physical_state__c, site__r.physical_postal_code__c,
						 site__r.physical_country__c, name
						  from work_order__c where 
			                 id in :mpsonifiwotowo.keyset() ];
			                 
			for(Work_Order__c iwo :lstsonwo)
			{
				if(mpsonifiwotowo.containskey(iwo.id))
				{
					WorkOrder sonwo = New WorkOrder();
					sonwo = mpsonifiwotowo.get(iwo.id);
					if(mprecnametoid.containskey(iwo.recordtype.name))
					{
						sonwo.recordtypeid = mprecnametoid.get(iwo.recordtype.name);
						sonwo.accountid = iwo.site__c;
						sonwo.Street = iwo.site__r.physical_street_address_line_1__c;
				  		sonwo.City = iwo.site__r.physical_city__c;
				  		sonwo.State = iwo.site__r.physical_state__c;
				  		sonwo.PostalCode = iwo.site__r.physical_postal_code__c;
				  		sonwo.Country = iwo.site__r.physical_country__c;
					    sonwo.Subject = iwo.name;

						lstwo.add(sonwo);
					}
				}
			}
		} //end if mpsonifiwotowo size > 0
		
		if(mpsurveytowo.size() > 0)
		{
			
			PopulateSiteSurveyWorkOrderFields(mpsurveytowo);
		}

		
		if(lstpmwo.size() > 0)
		{
			for(WorkOrder pmwo :lstpmwo)
			{
				pmwo.recordtypeid = mprecnametoid.get('Preventive Maintenance');
				
			}

			//jjackson PM's are excluded from the fwo list that gets passed into this trigger method,
			//so we are passing pmwo's in here.
			PopulateExceptions(lstpmwo);
		}		
		return lstwo;
	} //end AssignRecordTypes
	
	//jjackson 4/2019 FSL Project
	public static void LinkAssociatedItems(List<WorkOrder> installworkorderlist, Map<Id,WorkOrder> trigoldmap)
	{
		
		//get custom setting
		List<Product_Parent_Usage__c> ppulist = Product_Parent_Usage__c.getall().values();
		Map<String,String> mpcustomsetting = New Map<String,String>();
		Map<Id,Id> mpswotofwo = New Map<Id,Id>();
		List<String> woremove = New List<String>();
		List<Associated_Item__c> lstupdaitemsadd = New List<Associated_Item__c>();
		Map<Id,List<String>> mpswoaddproducts = New Map<Id,List<String>>();
		Map<Id,List<String>> mpsworemproducts = New Map<Id,List<String>>();
        
		for(Product_Parent_Usage__c p :ppulist)
		{
			mpcustomsetting.put(p.WO_Name_Abbrev__c,p.Name);
			system.debug(p.WO_Name_Abbrev__c +', ' +p.Name);
		}
		
		for(WorkOrder w :installworkorderlist)
		{
            if(w.sonifi_work_order__c != null)
			{ mpswotofwo.put(w.sonifi_work_order__c,w.id); 
			
            List<String> woaddabbrevs = New List<String>();
 
			//look for products where the boxes are checked
			if(w.byod__c == true && trigoldmap.containskey(w.id) && trigoldmap.get(w.id).byod__c == false)
			{
				if(mpcustomsetting.containskey('BYOD'))
				{  woaddabbrevs.add(mpcustomsetting.get('BYOD')); 
					
				}
			}
			
			if(w.FTG__c == true && trigoldmap.containskey(w.id) && trigoldmap.get(w.id).FTG__c == false)
			{	
				if(mpcustomsetting.containskey('FTG'))
				{  woaddabbrevs.add(mpcustomsetting.get('FTG')); 
					
				}
			}
				
			if(w.Interactive__c == true && trigoldmap.containskey(w.id) && trigoldmap.get(w.id).Interactive__c == false)
			{
				if(mpcustomsetting.containskey('Interactive'))
				{  woaddabbrevs.add(mpcustomsetting.get('Interactive'));  
					
				}
			}
			
			if(w.GIA__c == true && trigoldmap.containskey(w.id) && trigoldmap.get(w.id).GIA__c == false)
			{
				//addid.add(w.sonifi_work_Order__c);
				if(mpcustomsetting.containskey('GIA'))
				{  woaddabbrevs.add(mpcustomsetting.get('GIA'));  
					//mpswotofwo.put(w.sonifi_work_order__c,w.id);
				}
				
			}
			
			if(w.DRE__c == true && trigoldmap.containskey(w.id) && trigoldmap.get(w.id).DRE__c == false)
			{
				//addid.add(w.sonifi_work_Order__c);
				if(mpcustomsetting.containskey('DRE'))
				{   woaddabbrevs.add(mpcustomsetting.get('DRE'));  
					//mpswotofwo.put(w.sonifi_work_order__c,w.id);
				}
				
			}
			
			if(w.DS__c == true && trigoldmap.containskey(w.id) && trigoldmap.get(w.id).DS__c == false)
			{
				//addid.add(w.sonifi_work_Order__c);
				if(mpcustomsetting.containskey('DS'))
				{  woaddabbrevs.add(mpcustomsetting.get('DS'));  
					//mpswotofwo.put(w.sonifi_work_order__c,w.id);
				}
				
			}
			
			if(w.NOBL__c == true && trigoldmap.containskey(w.id) && trigoldmap.get(w.id).NOBL__c == false)
			{
				//addid.add(w.sonifi_work_Order__c);
				if(mpcustomsetting.containskey('NOBL'))
				{  woaddabbrevs.add(mpcustomsetting.get('NOBL'));  
					//mpswotofwo.put(w.sonifi_work_order__c,w.id);
				}
				
			}
			
			if(w.PS__c == true && trigoldmap.containskey(w.id) && trigoldmap.get(w.id).PS__c == false)
			{
				//addid.add(w.sonifi_work_Order__c);
				if(mpcustomsetting.containskey('PS'))
				{  woaddabbrevs.add(mpcustomsetting.get('PS'));  
					//mpswotofwo.put(w.sonifi_work_order__c,w.id);
				}
				
			}
			
			if(w.PV__c == true && trigoldmap.containskey(w.id) && trigoldmap.get(w.id).PV__c == false)
			{
				//addid.add(w.sonifi_work_Order__c);
				if(mpcustomsetting.containskey('PV'))
				{  woaddabbrevs.add(mpcustomsetting.get('PV'));  
					//mpswotofwo.put(w.sonifi_work_order__c,w.id);
				}
				
			}
			
			if(w.SC__c == true && trigoldmap.containskey(w.id) && trigoldmap.get(w.id).SC__c == false)
			{
				//addid.add(w.sonifi_work_Order__c);
				if(mpcustomsetting.containskey('SC'))
				{  woaddabbrevs.add(mpcustomsetting.get('SC'));  
					//mpswotofwo.put(w.sonifi_work_order__c,w.id);
				}
				
			}
			
			if(w.SCR__c == true && trigoldmap.containskey(w.id) && trigoldmap.get(w.id).SCR__c == false)
			{
				//addid.add(w.sonifi_work_Order__c);
				if(mpcustomsetting.containskey('SCR'))
				{  woaddabbrevs.add(mpcustomsetting.get('SCR'));  
				   //mpswotofwo.put(w.sonifi_work_order__c,w.id);
				}
				
			}
			
			//if there are product parent names in the string list, add the sonifi work order id as key and string list as value
            if(woaddabbrevs.size() > 0)
            { mpswoaddproducts.put(w.Sonifi_Work_Order__c, woaddabbrevs); }
           }//end if sonifi_work_order__c != null
        }//end for loop workorder for linking associtems
		
		//query for the associated items that have a sonifi work order id in add products map
		List<Associated_Item__c> lstaddai = New List<Associated_Item__c>();
		lstaddai = [Select id, work_order__c, workorder__c, name from associated_Item__c where work_order__c in
		            :mpswoaddproducts.keyset() AND name like '%Product Parent'];
		
		//loop through assoc items to get the product parents that need to be linked to a standard work order
		for(Associated_Item__c ai :lstaddai)
		{
		   List<String> lstaddprodparents = New List<String>();
		   if(mpswoaddproducts.containskey(ai.work_Order__c))
		   {
				lstaddprodparents = mpswoaddproducts.get(ai.work_order__c);
				for(String namestring :lstaddprodparents) //loop through prod parent name strings to find any that match ai.name
				{
				  if(namestring == ai.name && mpswotofwo.containskey(ai.work_order__c))
				  { ai.workorder__c = mpswotofwo.get(ai.work_order__c); 
				    lstupdaitemsadd.add(ai);
				  }
				}
		   }
		}
		
        //loop through again to find removals
		for(WorkOrder w : installworkorderlist)
		{
		   if(w.sonifi_work_order__c != null)
		   {
		     List<String> lstremoveproducts = New List<String>();
			 
			//look for products where the boxes were unchecked
			if(w.byod__c == false && trigoldmap.containskey(w.id) && trigoldmap.get(w.id).byod__c == true)
			{	
					if(mpcustomsetting.containskey('BYOD'))
					{
						lstremoveproducts.add(mpcustomsetting.get('BYOD'));
					}
			}
			
			if(w.DRE__c == false && trigoldmap.containskey(w.id) && trigoldmap.get(w.id).DRE__c == true)
			{	
					if(mpcustomsetting.containskey('DRE'))
					{
						lstremoveproducts.add(mpcustomsetting.get('DRE'));
					}
			}
			
			if(w.GIA__c == false && trigoldmap.containskey(w.id) && trigoldmap.get(w.id).GIA__c == true)
			{	
					if(mpcustomsetting.containskey('GIA'))
					{
						lstremoveproducts.add(mpcustomsetting.get('GIA'));
					}
			}
			
			if(w.FTG__c == false && trigoldmap.containskey(w.id) && trigoldmap.get(w.id).FTG__c == true)
			{	
					if(mpcustomsetting.containskey('FTG'))
					{
						lstremoveproducts.add(mpcustomsetting.get('FTG'));
					}
			}
			
			if(w.Interactive__c == false && trigoldmap.containskey(w.id) && trigoldmap.get(w.id).Interactive__c == true)
			{	
					if(mpcustomsetting.containskey('Interactive'))
					{
						lstremoveproducts.add(mpcustomsetting.get('Interactive'));
					}
			}
			
			if(w.DS__c == false && trigoldmap.containskey(w.id) && trigoldmap.get(w.id).DS__c == true)
			{	
					if(mpcustomsetting.containskey('DS'))
					{
						lstremoveproducts.add(mpcustomsetting.get('DS'));
					}
			}
			
			if(w.NOBL__c == false && trigoldmap.containskey(w.id) && trigoldmap.get(w.id).NOBL__c == true)
			{	
					if(mpcustomsetting.containskey('NOBL'))
					{
						lstremoveproducts.add(mpcustomsetting.get('NOBL'));
					}
			}
			
			if(w.PS__c == false && trigoldmap.containskey(w.id) && trigoldmap.get(w.id).PS__c == true)
			{	
					if(mpcustomsetting.containskey('PS'))
					{
						lstremoveproducts.add(mpcustomsetting.get('PS'));
					}
			}
			
			if(w.PV__c == false && trigoldmap.containskey(w.id) && trigoldmap.get(w.id).PV__c == true)
			{	
					if(mpcustomsetting.containskey('PV'))
					{
						lstremoveproducts.add(mpcustomsetting.get('PV'));
					}
			}
				
			if(w.SC__c == false && trigoldmap.containskey(w.id) && trigoldmap.get(w.id).SC__c == true)
			{	
					if(mpcustomsetting.containskey('SC'))
					{
						lstremoveproducts.add(mpcustomsetting.get('SC'));
						system.debug('removing SC assoc item from field work order.');
					}
			}
			
			if(w.SCR__c == false && trigoldmap.containskey(w.id) && trigoldmap.get(w.id).SCR__c == true)
			{	
					if(mpcustomsetting.containskey('SCR'))
					{
						lstremoveproducts.add(mpcustomsetting.get('SCR'));
					}
			}

			
			if(lstremoveproducts.size() > 0)
			{ mpsworemproducts.put(w.id,lstremoveproducts); }
		}//end if sonifi_work_order__c != null
	   } //end for loop
		
		for(Id key :mpsworemproducts.keyset())
		{
			system.debug('key in mpsworemproducts is ' +key);
		}
	   //get the associated item product parents linked to mpsworemproducts key
	   
	   List<Associated_Item__c> lstremoveai = New List<Associated_Item__c>();
	   lstremoveai = [ Select id, work_order__c, name, workorder__c from associated_item__c where
	                 workorder__c in :mpsworemproducts.keyset() AND name like '%Product Parent' ];
					 
		for(Associated_Item__c a :lstremoveai)
		{
			List<String> lstparentnames = new List<String>();
			if(mpsworemproducts.containskey(a.workorder__c))
			{
				lstparentnames = mpsworemproducts.get(a.workorder__c);
				for(String parentname :lstparentnames)
				{
					if(a.name == parentname)
					{
						a.workorder__c = null;
						lstupdaitemsadd.add(a);
					}
				}
			}
		
		
		}

		if(lstupdaitemsadd.size() > 0)
		{
			try{
				update lstupdaitemsadd;
			
			}
			catch(DMLException dex)
			{ system.debug('DML exception updating associated items: ' +dex.getmessage());}
			
			catch (Exception e)
			{ system.debug('Error found in LinkAssociatedItems: '  +e.getmessage()); }
		
		
		}//end if lstupdaitemsadd > 0
		
		
		
		
	}//end LinkAssociatedItems
	
	
	
	
	//jjackson June 2017 added code to set the record type of the field work order based on the record
	//type of the related case.
	public static void PopulateWorkOrderUponCreation(List<WorkOrder> lstnewfwo)
	{
		List<WorkOrder> lstprocesswo = New List<WorkOrder>();
		List<Case> lstcasedetails = New List<Case>();
		Set<Id> setcaseid = New Set<Id>();
		Set<String> setentname = New Set<String>();
		Map<Id, Case> mpcasedetails = New Map<Id,Case>();
		List<ThirdPartyEntitlementName__c> cslist = [Select Name from ThirdPartyEntitlementName__c ];
		Id rectypeidtpp = Utilities.RecordTypeNameToId('WorkOrder', 'Third Party FWO');
		Id rectypeidfwo = Utilities.RecordTypeNameToId('WorkOrder', 'FWO');
		Id casetpprectype = Utilities.RecordTypeNameToId('Case', 'Contracted Field Service' );
		
		for(WorkOrder fwo : lstnewfwo)
		{
			if(fwo.caseid != null)
			{  lstprocesswo.add(fwo);  }
		}
		
		for(ThirdPartyEntitlementName__c cs : cslist)
		{  setentname.add(cs.name);  }
		
		if(lstprocesswo.size() > 0)
		{
             for(WorkOrder wo : lstprocesswo)
             {  setcaseid.add(wo.caseid);  }  //get all the case ids and add them to a set for querying case details to put on the wo
		
		
			if(!setcaseid.IsEmpty())  //if there are case ids in the set, query for case details for the work order
			{
				lstcasedetails = [ Select Id, AccountId, Ownerid, Status, Priority, EntitlementId, Service_Contract_Name__c, AssetId,
			                   Account.RecordTypeId, Subject, Issue_Details_Description__c, Non_SONIFI_Issue__c, RecordtypeId, Entitlement.Name
			                   from Case where id in :setcaseid ];
			}
		
			if(lstcasedetails.size() > 0) //if the case list has cases in it, add them to a map
			{ for(Case c : lstcasedetails)
		  	{ mpcasedetails.put(c.Id, c);  }
			}
			
			if(mpcasedetails.size() > 0) //if there are cases in the map, add case info to the work orders in lstprocesswo
			{
				for(WorkOrder processwo : lstprocesswo)
				{
					if(mpcasedetails.containskey(processwo.CaseId))
					{

						processwo.priority = mpcasedetails.get(processwo.caseid).priority;
						processwo.accountid = mpcasedetails.get(processwo.caseid).accountid;
	
						processwo.non_sonifi_issue__c = mpcasedetails.get(processwo.caseid).non_sonifi_issue__c;
						processwo.subject = mpcasedetails.get(processwo.caseid).subject;
						processwo.description = mpcasedetails.get(processwo.caseid).issue_details_description__c;

						if(mpcasedetails.get(processwo.caseid).recordtypeid != casetpprectype) //if the case is not a contracted field service case
						{
							//jjackson 1/2018 if the case is a support case that does not have an ATT entitlement, create regular FWO
						  if(!setentname.Contains(mpcasedetails.get(processwo.caseid).entitlement.name))  //if the entitlement name is not in the
						  {                                                                                 //set that contains third party entitlements
							processwo.assetid = mpcasedetails.get(processwo.caseid).assetid;
						 	processwo.entitlementid = mpcasedetails.get(processwo.caseid).entitlementid;
						 	processwo.servicecontractid = mpcasedetails.get(processwo.caseid).service_contract_name__c;
						 	//processwo.recordtypeid = rectypeidfwo;  jjackson 5/2019
						  }
						}

						String recordtypename = Utilities.RecordTypeIdToName('Account', mpcasedetails.get(processwo.caseid).Account.RecordtypeId);
						system.debug('recordtypename is ' +recordtypename);
						if(recordtypename == 'Healthcare Site')
						{  processwo.healthcare_site__c = true;  }

                        //jjackson if the case record type is contracted field service 
						//if(mpcasedetails.get(processwo.caseid).recordtypeid == casetpprectype) jjackson 5/2019
						//{  processwo.recordtypeid = rectypeidtpp; }
						
						//jjackson 1/2018 if the case record type is not contracted field service case but
						//the case has a third party entitlement, create a third party fwo
						if(mpcasedetails.get(processwo.caseid).recordtypeid != casetpprectype &&
						    setentname.Contains(mpcasedetails.get(processwo.caseid).entitlement.name))
						{
							//processwo.recordtypeid = rectypeidtpp; jjackson 5/2019
							processwo.assetid = mpcasedetails.get(processwo.caseid).assetid;
						 	processwo.entitlementid = mpcasedetails.get(processwo.caseid).entitlementid;
						 	processwo.servicecontractid = mpcasedetails.get(processwo.caseid).service_contract_name__c;
							
						}
					}
				}//end for loop lstprocesswo
			}//end if mpcasedetails size > 0
			
		}//end if lstprocesswo size is > 0
	}//end PopulateWorkOrderUpon Creation
	
	//jjackson--when the field work order status changes to Submitted for Billing or the Submit for Billing box is checked, put the case owner into the technician__c
	//field on the work so that the person who worked on the order is not lost when the approval process changes the ownership.
	//if only the submit for billing box is checked, change the status on the work order to Submitted for Billing
	public static void PopulateTechField(List<WorkOrder> lstupdworkorders)
	{
			 
		  Map<Id,Id> mpworkorderowner = New Map<Id,Id>();
		  Set<Id> setownerid = New Set<Id>();
		  Map<Id,String> mpuser = New Map<Id,String>();
		  
		  for(WorkOrder wo : lstupdworkorders)
		  {		
		  		String owner = wo.ownerid;
		  		if(!owner.contains('00G')) //only add ownerid to the setownerid if the owner of the work order is not a queue
		  	    {  setownerid.add(wo.ownerid);  
		  	       mpworkorderowner.put(wo.id, wo.ownerid);  //if status is changed to submitted for billing or submit to billing = true, add to map and list
		  	    }//all add the origina ownerid to set so we can query name from the user object
		  	    
		  	    system.debug('mpworkorderowner size is ' +mpworkorderowner.size());
		  	    
		  	    if(wo.Additional_Tech2__c != null)
		  	    { setownerid.add(wo.Additional_Tech2__c); } //also add the user id of the additional technician
		  	    
		  	    if(wo.Additional_Tech3__c != null)
		  	    { setownerid.add(wo.Additional_Tech3__c); }
		  	    system.debug('work order in trigger is ' +wo.workordernumber +', ' +wo.status +', ' +wo.submit_for_billing__c);
		  	    if(wo.status != 'Submitted for Billing' && wo.submit_for_billing__c == true)
		  	    { wo.status = 'Submitted for Billing';  }
		  }//end for loop lstupdworkorders
		  
		  List<User> lstgetusernames = [ Select Id, Name from User where Id in :setownerid ];
		  
		  system.debug('lstgetusernames size is ' +lstgetusernames.size());
		  
		  if(lstgetusernames.size() > 0 )
		  {
		  	for(User u : lstgetusernames)
		  	{  mpuser.put(u.Id, u.Name);  }
		  } 
		
		  	for(WorkOrder updwo : lstupdworkorders)
		  	{
		  		if(mpworkorderowner.containskey(updwo.Id))
		  		{
		  			updwo.technician__c = mpworkorderowner.get(updwo.Id);  //update technician field with owner id
                    //no dml statement needed because this is running in before update trigger
                    
                    //now get the name from the map to find matching ceridian name in the custom setting
                    //also need the netsuite region for the report--it resides in the custom setting
                    //Added an "else" because when unit test is running, the Salesforce to Ceridian custom
                    //setting is not available.  For testing we must populate the variables with strings.
                   if(!test.isRunningTest())
                   {
                    if(mpuser.containskey(updwo.technician__c))
                    {
                      if(updwo.Account_Country__c != 'Canada')
                      {
                    	String techname = mpuser.get(updwo.technician__c);
                    	Salesforce_to_Ceridian_Users__c cs = Salesforce_to_Ceridian_Users__c.getInstance(techname);
                    	String ceridianname = cs.Ceridian_Name__c;
                    	String region = cs.FSR_Region__c;
                    	updwo.ceridian_name1__c = ceridianname;
                    	updwo.FSR_Region__c = region;
                    	
                      }
       	
                    }
                    else
                    {  system.debug('salesforce user id not found so could not get ceridian name.'); }
                   }
                   else //populate the variables with string values for unit tests
                   {
                   	  String techname = 'Elmer Fudd';
                   	  String ceridianname = 'Elmer Fudd';
                   	  String region = 'Northeast';
                   	  updwo.ceridian_name1__c = ceridianname;
                   	  updwo.FSR_Region__c = region;
                   }
		  		}
		  		
		  		
		  		//jjackson 11/2017 exclude Canadian work orders from finding ceridian names
		  		if(updwo.account_Country__c != 'Canada')
		  		{
		  			//also need the ceridian name for the additional tech2 and tech3
		  			if(updwo.Additional_Tech2__c != null && mpuser.containskey(updwo.Additional_Tech2__c))
		  			{
		  				String addtech = mpuser.get(updwo.Additional_Tech2__c);
		  				Salesforce_to_Ceridian_Users__c cs = Salesforce_to_Ceridian_Users__c.getInstance(addtech);
		  				String ceridname = cs.Ceridian_Name__c;
		  				updwo.tech2_ceridian_name__c = ceridname;
		  			}
		  		
		  			if(updwo.Additional_Tech3__c != null && mpuser.containskey(updwo.Additional_Tech3__c))
		  			{
		  				String addtech = mpuser.get(updwo.Additional_Tech3__c);
		  				Salesforce_to_Ceridian_Users__c cs = Salesforce_to_Ceridian_Users__c.getInstance(addtech);
		  				String ceridname = cs.Ceridian_Name__c;
		  				updwo.tech3_ceridian_name__c = ceridname;
		  			}
		  		}//end if account country is not Canada

		  	}//end for loop lstwo
		
	}//end populatetechnicanfield
	
	//jjackson whenever a field work order is created, pre-populate the field work order events list with line items
	//to track labor hours spent on each individual category for billing purposes
	//jjackson 7/2019 form PM FWO's, create a field work order event just for the PM and exclude others
	public static void CreateFieldWorkOrderEvents(List<WorkOrder> lstwo)
	{   
		system.debug('**********BEGIN CreateFieldWorkOrderEvents***********');
		
		Id rectypeidfwo = Utilities.RecordTypeNameToId('WorkOrder', 'FWO');
		Id pmrectype = Utilities.RecordTypeNameToId('WorkOrder', 'Preventive Maintenance');
		List<FieldWorkOrder_Events__c> lstnewfwoevents = New List<FieldWorkOrder_Events__c>();
		List<FieldWorkOrder_Event_Settings__c> lstevents = New List<FieldWorkOrder_Event_Settings__c>();

		//get the custom setting for all the values that go into the Field Work Order Event records
		Map<String,FieldWorkOrder_Event_Settings__c> mapcs = New Map<String, FieldWorkOrder_Event_Settings__c>();
		if(!test.IsRunningTest())
		{	mapcs = FieldWorkOrder_Event_Settings__c.getAll();
			lstevents = mapcs.Values();
		}
		
		for(WorkOrder wo : lstwo)
		{
           if(wo.recordtypeid == rectypeidfwo) //jjackson 6/2017 only create the work order events if the record type is not third party
           {
			if(test.IsRunningTest())
			{
				FieldWorkOrder_Event_Settings__c event1 = New FieldWorkOrder_Event_Settings__c(Name = 'Event-1', Event_Description__c = 'Circuit|Modem|Etc.', Event_Name__c = 'Connectivity',
				                                            Event_Type__c = 'System Event');
				                                      
				FieldWorkOrder_Event_Settings__c event2 = New FieldWorkOrder_Event_Settings__c(Name = 'Event-2', Event_Description__c = 'Signal|Service|Etc.', Event_Name__c = 'Public Area TVs',
				                                            Event_Type__c = 'Other Event');
				lstevents.add(event1);
				lstevents.add(event2);
				
				system.debug('events list size during test is ' +lstevents.size());
				           
			}
			
			for(FieldWorkOrder_Event_Settings__c fwoe : lstevents)
			{	
				if(fwoe.Event_Description__c != null && !fwoe.Event_Description__c.contains('Maintenance'))
				{

				
			    	FieldWorkOrder_Events__c newrec = New FieldWorkOrder_Events__c();
				
					newrec.event_name__c = fwoe.event_name__c;
					newrec.event_type__c = fwoe.event_type__c;
					newrec.event_description__c = fwoe.event_description__c;
					newrec.field_work_order__c = wo.id;
				
					lstnewfwoevents.add(newrec);
				}
			}
		 }//end if recordtype is fwo

		if(wo.recordtypeid == pmrectype)
		{
			for(FieldWorkOrder_Event_Settings__c fwoe : lstevents)
			{
				if(fwoe.Event_Description__c != null && fwoe.Event_Description__c.contains('Maintenance'))
				{

				
			    	FieldWorkOrder_Events__c newrec = New FieldWorkOrder_Events__c();
				
					newrec.event_name__c = fwoe.event_name__c;
					newrec.event_type__c = fwoe.event_type__c;
					newrec.event_description__c = fwoe.event_description__c;
					newrec.field_work_order__c = wo.id;
				
					lstnewfwoevents.add(newrec);
				}
			}
		}
		
	  }//end for loop lstwo
		
		if(lstnewfwoevents.size() > 0)
		{  insert lstnewfwoevents;  }
		
		system.debug('**************END CreateFieldWorkOrderEvents**************');
	}
	
	//jjackson When a field work order's status changes to Submitted for Billing, automatically put the record
	//into the billing approval process
	public static void StartWorkOrderApprovalProcess(List<WorkOrder> lstapprovewo)
	{
		   for(WorkOrder updwo : lstapprovewo)
		   {
			//for each work order in this loop, start the approval process
		  	  Approval.ProcessSubmitRequest req = New Approval.ProcessSubmitRequest();
		  	  req.setComments('Submitted for approval.');
		  	  req.setObjectId(updwo.Id);
		  	  Approval.ProcessResult result = Approval.process(req);
		  	  system.debug('field work order ' +updwo.workordernumber +' was successfully submitted for approval');
		   }	
	}

	//When a field work order is billed, auto-create the trip and labor child line items depending on a) what type of
	//product inventory is related to the work order; b) whether the site is healthcare, hotel, or the work was performed
	//by a service partner.
	//jjackson 7/2019 create trip/labor line items for PM's and for STAYCAST fwo's
	public static void CreateTripLaborChildLines(List<WorkOrder> lstbillingwo)
	{
		system.debug('*****************BEGIN CreateTripLaborChildLines********************');
		

		Set<String> setproductcodes = New Set<String>();
		String NonChargeablepn;
		Map<String,Id> mpproductcodetoid = New Map<String,Id>();
		Map<Id,String> mpidtocasetype = New Map<Id,String>();
		Map<Id,String> mpidtoproducttype = New Map<Id,String>();
		Map<String,FieldWorkOrderTripandLabor__mdt> mplabortypes = New Map<String,FieldWorkOrderTripandLabor__mdt>();
		Map<Id,String> mpwoidtoassetproducttype = New Map<Id,String>();
		Set<Id> sethealthcaresites = New Set<Id>();  //if site is a healthcare site, set the accountid aside
		List<WorkOrderLineItem> lstinsertitems = New List<WorkOrderLineItem>();
		List<WorkOrderLineItem> lstprodtypelineitems = New List<WorkOrderLineItem>();
		List<WorkOrder> lstworkorderassets = New List<WorkOrder>();
		List<FieldWorkOrderTripandLabor__mdt> listtriplabor = New List<FieldWorkOrderTripandLabor__mdt>();
		Id fworectypeid = Utilities.RecordTypeNameToId('WorkOrder', 'FWO');
		Id fwotprectypeid = Utilities.RecordTypeNameToId('WorkOrder', 'Third Party FWO');
		id fwopmtypeid = Utilities.RecordTypeNameToId('WorkOrder', 'Preventive Maintenance');
		List<WorkOrder> lstthirdpartywo = New List<WorkOrder>();

		lstworkorderassets = [ Select Id, recordtypeid, assetid, accountid, asset.product2.name, account.recordtype.name from WorkOrder 
		                      where id in :lstbillingwo and recordtypeid = :fwopmtypeid ];

		if(lstworkorderassets.size() > 0)
			for(WorkOrder w :lstworkorderassets)
			{
				if(w.assetid != null && w.asset.product2.name.contains('Product Parent'))
				{   mpwoidtoassetproducttype.put(w.id, w.asset.product2.name.substringbefore(' '));}

				if(w.account.recordtype.name == 'Healthcare Site')
				{
					sethealthcaresites.add(w.accountid); //jjackson save healthcare site ids here so we can
				}                                        //determine whether fwo is linked to a healthcare site
			}
		
		for(WorkOrder wo : lstbillingwo)
		{
			if(wo.recordtypeid == fworectypeid)
			{
				{ mpidtocasetype.put(wo.Id, wo.case_product_type__c); 
		  		system.debug('case product type is ' +wo.case_product_type__c);
				}
			}

			if(wo.recordtypeid == fwopmtypeid && mpwoidtoassetproducttype.size() > 0 && mpwoidtoassetproducttype.containskey(wo.id))
			{
				String producttype;
				producttype = mpwoidtoassetproducttype.get(wo.id);
				mpidtocasetype.put(wo.id,producttype);
			}
		}
		
		//query custommetadata type FieldWorkOrderTripandLabor__mdt that stores all the trip and labor part numbers by
		//site type and product inventory type
		listtriplabor = [ Select product_code__c, work_order_product_parent__c, work_type__c,
		                  label, developername, case_product_type__c from fieldworkordertripandlabor__mdt ];
	
		//system.debug('listtriplabor size is ' +listtriplabor.size());
		
		//store all the custom metadata records in a map so we can pull out the ones we need depending on the work order type                                                  
		for(FieldWorkOrderTripandLabor__mdt trip : listtriplabor)
		{  mplabortypes.put(trip.developername,trip);  
		   setproductcodes.add(trip.product_code__c);  //get all the productcodes so the product2 id can be queried
		 //  system.debug(trip.developername +', ' +trip.product_code__c);
		}
		
        system.debug('setproductcodes size is ' +setproductcodes.size());		
		List<Product2> lstproduct2 = New List<Product2>();
		lstproduct2 = [ Select Id, productcode, name, isactive from product2 where productcode in :setproductcodes AND isactive = true ];
		//system.debug('lstproduct2 size is ' +lstproduct2.size());
		//create a map of product code to product2 id for use later
		for(Product2 prod : lstproduct2)
		{
			mpproductcodetoid.put(prod.productcode,prod.Id);
			//system.debug('adding to mpproductcodetoid ' +prod.productcode + ', ' +prod.id );
		}
		
		for(WorkOrder wo : lstbillingwo)  //first process all the work orders that have a product type
		{
			String casetype; //clear value of case product type variable with each new work order in the loop 
			Boolean blsub = false;
			Boolean blhc = false;
			Id rectypeid = wo.recordtypeid;  //jjackson 6/2017 get record type id of each work order

			if(rectypeid == fwotprectypeid)
			{ lstthirdpartywo.add(wo); }
		
		  if(rectypeid == fworectypeid || rectypeid == fwopmtypeid )
		  {	
			if(mpidtocasetype.containskey(wo.id))
			{  casetype = mpidtocasetype.get(wo.Id); }  //get the case product type related to the field work order
			else
			{  system.debug('mpidtocaseproduct did not contain a case product type for ' +wo.workordernumber);  }

			//system.debug('productparent = ' +productparent);

		  if(casetype != null)	
		  {
		  	
		   if(wo.recordtypeid == fworectypeid || wo.recordtypeid == fwopmtypeid) //proceed down this path for regular work orders only
		   {
			//determine whether the work order is for hotel, healthcare, or was done by a service partner
			if(wo.sub_partner_performed_work__c == true || wo.contractor_name__c != null)
			{  blsub = true; }
			if(wo.healthcare_site__c == true)
			{  blhc = true;  }
			if(sethealthcaresites.size() >0 && sethealthcaresites.contains(wo.accountid))
			{  blhc = true; }

		
			//create blank field work order child lines for trip and labor
			WorkOrderLineItem laborline = New WorkOrderLineItem();
			WorkOrderLineItem tripline = New WorkOrderLineItem();
			WorkOrderLineItem nonchargeable = New WorkOrderLineItem();  //create non-chargeable labor line for all work orders
			
			//Instantiate records for FieldWorkOrderTripandLabor custom metadata
			FieldWorkOrderTripandLabor__mdt trip = New FieldWorkOrderTripandLabor__mdt();
			FieldWorkOrderTripandLabor__mdt labor = New FieldWorkOrderTripandLabor__mdt();
			FieldWorkOrderTripandLabor__mdt nclabor = New FieldWorkOrderTripandLabor__mdt();
			
		
			if(blsub == true) //if the work was performed by a service partner
			{
				//system.debug('blsub = ' +blsub);
				
		  		if(blhc == true) //if it is a  healthcare site
		  		{   //system.debug('blhc = ' +blhc);
		  			
					trip = mplabortypes.get('SP_Healthcare_Trip');
					labor = mplabortypes.get('SP_Healthcare_Labor');
					nclabor = mplabortypes.get('SP_Healthcare_NCLabor');
		  		}
		  		else  //if not a hospital, we then need to look at what type of case product is on the work order
		  		{
		  		  if(wo.recordtypeid == fworectypeid || wo.recordtypeid == fwopmtypeid)
		  		  {
		  			//system.debug('inside else statement where blhc = false');
		  			if(casetype == 'Interactive' ||casetype == 'FTG'||casetype == 'STAYCAST'||casetype == 'Interactive - ONCO'||casetype=='Professional Solutions')
		  			{
		  				//system.debug('inside if prodparent = itv, ftg, or sonicast');
		  				trip = mplabortypes.get('SP_ITV_Trip');
						labor = mplabortypes.get('SP_ITV_Labor');
						nclabor = mplabortypes.get('SP_ITV_NCLabor');
		  			}
		  			else 
		  			{
		  				if(casetype == 'Broadband')
		  				{  //system.debug('inside else if prod parent is broadband');
		  					trip = mplabortypes.get('SP_GIA_Trip');
							labor = mplabortypes.get('SP_GIA_Labor');
							nclabor = mplabortypes.get('SP_GIA_NCLabor');
		  				}
		  			}
		  		  }//end if record type is for a regular field work order
	
		  		}//end else
		    }//end if blsub = true
		else //if work was not performed by a service partner
		{
			if(blhc == true) //if this is a healthcare site
		    {
		    	//the ITV records can be used because the trip/labor part numbers are the same for ITV/FTG
		    	trip = mplabortypes.get('Healthcare_ITV_Trip');
				labor = mplabortypes.get('Healthcare_ITV_Labor');
				nclabor = mplabortypes.get('Healthcare_ITVNC_Labor');
		    }
		    else //if not a healthcare site
		    {
		    	//now we must check the product parent on the work order to get the right trip and labor lines
		    	if(casetype == 'Interactive'||casetype == 'STAYCAST'||casetype=='Interactive - ONCO'||casetype=='Professional Solutions')
		    	{
		    		trip = mplabortypes.get('Hotel_ITV_Trip');
					labor = mplabortypes.get('Hotel_ITV_Labor');
					nclabor = mplabortypes.get('Hotel_ITV_NCLabor');
		    	}
		    	if(casetype == 'FTG')
		    	{
		    		trip = mplabortypes.get('Hotel_FTG_Trip');
					labor = mplabortypes.get('Hotel_FTG_Labor');
					nclabor = mplabortypes.get('Hotel_FTG_NCLabor');
		    	}
		    	if(casetype == 'Broadband')
		    	{
		    		trip = mplabortypes.get('Hotel_GIA_Trip');
					labor = mplabortypes.get('Hotel_GIA_Labor');
					nclabor = mplabortypes.get('Hotel_GIA_NCLabor');
		    	}
		    }//end else
		}//end else
		
		  if(trip != null)
		  {
		  	if(mpproductcodetoid.containskey(trip.product_code__c))
		  	{ tripline.part_number__c = mpproductcodetoid.get(trip.product_code__c); 
		  	  tripline.qty__c = 1.0;
		  	  tripline.workorderid = wo.id;
		  	  lstinsertitems.add(tripline);
		  	}
		  	else
		  	{  system.debug(' for this field work order could not find trip product code in the mpproductcodetoid map: ' +wo.Id);  }
		  	 
		  }
		  else
		  { system.debug('mplabortype map for trip was null for field work order' +wo.Id);  }
		  
		  if(labor != null)
		  {
		  	if(mpproductcodetoid.containskey(labor.product_code__c))
		  	{ laborline.part_number__c = mpproductcodetoid.get(labor.product_code__c); 
		  	  laborline.workorderid = wo.Id;
		  	  lstinsertitems.add(laborline);
		  	}
		  	else
		  	{  system.debug('for this field work order could not find labor product code in the mpproductcodetoid map: ' +wo.Id);  }
		  	
		  }
		  
		  if(nclabor != null)
		  {
		  	if(mpproductcodetoid.containskey(nclabor.product_code__c))
		  	{ nonchargeable.part_number__c = mpproductcodetoid.get(nclabor.product_code__c); 
		  	  nonchargeable.workorderid = wo.Id;
		  	  lstinsertitems.add(nonchargeable);
		  	}
		  	else
		  	{  system.debug('for this field work order could not find non-chargeable labor product code in the mpproductcodetoid map: ' +wo.Id);  }
		  }
		 }//end if recordtype is fworectypeid or fwopmotypeid
		}//end if case type != null
		else
		{  system.debug('Did not find a case type for field work order ' +wo.workordernumber);  }
	   }//end if record type is fwo record type
	  }//end for loop

		//jjackson 10/2017 added this to process third party fwo's a little differently
	  if(lstthirdpartywo.size() > 0)
	  {
	  	for(WorkOrder tpwo : lstthirdpartywo)
	  	{   
	  		FieldWorkOrderTripandLabor__mdt tptripinfo = New FieldWorkOrderTripandLabor__mdt();
	  		FieldWorkOrderTripandLabor__mdt tplaborinfo = New FieldWorkOrderTripandLabor__mdt();
	  		WorkOrderLineItem tripline = new WorkOrderLineItem();
	  		WorkOrderLineItem laborline = new WorkOrderLineItem();

	  		if(tpwo.sub_partner_performed_work__c == false)
	  		{
	  			tptripinfo = mplabortypes.get('Third_Party_Trip');
	  			tplaborinfo = mplabortypes.get('Third_Party_Labor');
	  		}
	  		else
	  		{
	  			tptripinfo = mplabortypes.get('Third_Party_SP_Trip');
	  			tplaborinfo = mplabortypes.get('Third_Party_SP_Labor');
	  		}		  	

	  		if(tptripinfo != null)
	  		{
	  			if(mpproductcodetoid.containskey(tptripinfo.product_code__c))
	  			{
	  				Id partid = mpproductcodetoid.get(tptripinfo.product_code__c);
	  				tripline.part_number__c = partid;
	  			}
	  			tripline.workorderid = tpwo.id;
	  			lstinsertitems.add(tripline);
	  		}

	  		if(tplaborinfo != null)
	  		{
	  			if(mpproductcodetoid.containskey(tplaborinfo.product_code__c))
	  			{
	  				Id partid = mpproductcodetoid.get(tplaborinfo.product_code__c);
	  				laborline.part_number__c = partid;
	  			}
	  			laborline.workorderid = tpwo.id;
	  			lstinsertitems.add(laborline);
	  		}
          }//end for loop lstthirdparty

	  	}//end if lstthirdpartywo size > 0
	  
	   if(!lstinsertitems.IsEmpty())
		{
		  	try{insert lstinsertitems;  }
		  	catch(Exception e)
		  	{  system.debug('ERROR inserting trip and labor work order line items for field work order: ' +e.getMessage()); }
		  	
		}
		
		
	  
	  system.debug('*************************END CLASS CreateTripLaborChildLines**********************');
	  
	}//end CreateTripLaborChildLines
	
                                                       
	
	public static void PopulateExceptions(List<WorkOrder> triggernewlist)
	{
		system.debug('****************BEGIN PopulateExceptions*************');

		set<Id> setacctids = New Set<Id>();
		Map<Id,String> mpacct = New Map<Id,String>();
		List<Account> lstgetaccounts = New List<Account>();
		
		for(WorkOrder wo : triggernewlist)
		{  setacctids.add(wo.accountid);  
			//system.debug('accountid added to set is ' +wo.accountid);
		}
		
		lstgetaccounts = [ Select Id, Service_Contract_Exceptions__c from Account where id in :setacctids];
		//system.debug('lstgetaccounts size is ' +lstgetaccounts.size());
		if(lstgetaccounts.size() > 0)
		{
			for(Account a : lstgetaccounts)
			{	//system.debug('service contract exception is ' +a.service_contract_exceptions__c);
				if(a.service_contract_exceptions__c != null)	
			    {  mpacct.put(a.Id, a.service_contract_exceptions__c);  }
			}
		}
		
		//system.debug('mpacct size is ' +mpacct.size());
		if(mpacct.size() > 0)
		{
			for(WorkOrder updwo : triggernewlist)
			{
			  if(mpacct.containskey(updwo.accountid))
			  {  updwo.service_contract_exceptions__c = mpacct.get(updwo.accountid); } 
			}
		}
		//no dml update statement because this is running in a before trigger.

		system.debug('**************END PopulateExceptions**************');
		
	}//end method populateexceptions
	
	
	//when the work order Submit for Billing checkbox is checked, send an email to the customer 
	//(using Customer Email field or contact email field) that shows work performed and field work order events
	public static void EmailUponApproval(List<WorkOrder> lstsubmittedwo)
	{
		system.debug('***************BEGIN EmailUponApproval*******************');
		
		Id rectypeidfwo = Utilities.RecordTypeNameToId('WorkOrder', 'FWO'); //jjackson 6/2017 determine the record type
		List<FieldWorkOrder_Events__c> fwoelist = New List<FieldWorkOrder_Events__c>();
		Map<Id,WorkOrder> mpapprovedwo = New Map<Id,WorkOrder>();
		Map<Id, List<FieldWorkOrder_Events__c>> mpfwotofwoe = New Map<Id,List<FieldWorkOrder_Events__c>>();
		
		//put the submitted for billing work orders in a map if the record type is FWO.  We don't want to send
		//emails out where the record type is for a third party partner work order        
		for(WorkOrder wo : lstsubmittedwo)
		{
		   if(wo.recordtypeid == rectypeidfwo)   //jjackson 6/2017
		   {   mpapprovedwo.put(wo.id, wo);  }

		} 
		
	if(mpapprovedwo.size() > 0)  //the following code processes third party work orders
	{	//query the field work order events related to the work orders that are billing approved
		fwoelist = [ Select field_work_order__c, Event_Name__c, Event_Description__c, LongComments__c, Hours__c, event_type__c 
		             from FieldWorkOrder_Events__c where
		             hours__c != null AND hours__c > 0 AND field_work_order__c in :mpapprovedwo.keyset() ];
		             
        
		//create another map that matches work order id to the related list of field work order events
		
		//SAMPLE CODE Create map of type <Id,List<SObject>>
		for(FieldWorkOrder_Events__c fwoe : fwoelist)
		{
			if(mpfwotofwoe.containskey(fwoe.field_work_order__c))
			{
				mpfwotofwoe.get(fwoe.field_work_order__c).add(fwoe);
			}
			else
			{
				List<FieldWorkOrder_Events__c> templist = New List<FieldWorkOrder_Events__c>();
				templist.add(fwoe);
				mpfwotofwoe.put(fwoe.field_work_order__c, templist);
			}
		}
 
 		EmailUtilities.FieldWorkOrderCustomerNotification(mpapprovedwo, mpfwotofwoe);
 		
 		system.debug('*****************************END EmailUponApproval***********************');          
	} //end if mpapprovedwo size > 0	
  }//end method EmailUponApproval

  //jjackson 8/2019 auto-populate some fields when a site survey FWO is created.
  //shawks BUG-01021 - Alter SOQL and add list and map to determine FWO Work Type, Duration, Duration Type
  public static void PopulateSiteSurveyWorkOrderFields(Map<Id,WorkOrder> mpsurveyfwo)
  {
	  system.debug('***********BEGIN PopulateSiteSurveyWorkOrderFields*************');

	  //shawks BUG-01021 - Set default Site Survey record type; used if value not found in "FSL RecordType WorkType" custom setting
	  String RecordType_Name = 'Site Survey - Default';  //"Default" will be used later if a custom setting match is not found
	  Set<Id> setsurveyid = New Set<Id>();
	  List<Site_Survey__c> lstss = New List<Site_Survey__c>();
	  Map<Id,Site_Survey__c> mpss = New Map<Id,Site_Survey__c>();
	  List<FSL_RecordType_WorkType__c> lstcs = New List<FSL_RecordType_WorkType__c>();
	  Map<string,string> mpcs = New Map<string,string>();
	  List<WorkOrder> lstfwoemail = New List<WorkOrder>();
	  Id ssrectype = Utilities.RecordTypeNametoId('WorkOrder', 'Site Survey Work Order');

	  for(WorkOrder w :mpsurveyfwo.values())
	  {  setsurveyid.add(w.site_survey__c); }

	  //query info from the related accounts to populate into the work order
	  lstss = [Select Id, site__r.physical_street_address_line_1__c, site__r.physical_city__c, site__r.physical_state__c,
	              site__r.physical_postal_code__c, site__r.physical_country__c, site__r.Name, RecordType.Name
				  from Site_survey__c
				  where Id in :setsurveyid ];

	  for(Site_survey__c ss :lstss)
	  {  mpss.put(ss.id,ss );  }

	  system.debug('mpss size is ' +mpss.size());

	  //shawks BUG-01021 - Find Site Survey Record Types and related Work Types from Custom Setting called "FSL RecordType WorkType"
	  lstcs = [ SELECT Name, WorkTypeName__c FROM FSL_RecordType_WorkType__c ];

	  for(FSL_RecordType_WorkType__c FSL_RT_WT : lstcs)
	  { mpcs.put(FSL_RT_WT.Name, FSL_RT_WT.WorkTypeName__c); }
	  system.debug('mpcs size is ' +mpcs.size());

	  for(Id key :mpsurveyfwo.keyset())
	  {
		  WorkOrder wo = New WorkOrder();
		  wo = mpsurveyfwo.get(key);
		  if(wo.site_survey__c != null)
		  {
			  if(!test.isRunningTest())
			  {  
				//shawks BUG-01021 - Comment out since set later now
				//wo.worktypeid = mpwt.get('Site Survey'); 
			  	wo.scheduling_policy__c = mpsp.get('Site Survey');
			  }

			  wo.priority = 'Low';
			  wo.Status = 'New';
			  wo.Date__c = system.now();
			  wo.recordtypeid = ssrectype;
			  
			  system.debug('wo site survey id is ' +wo.site_survey__c);

			  if(mpss.containskey(wo.site_survey__c))
			  {
				  Site_Survey__c s = New Site_Survey__c();
				  s = mpss.get(wo.site_survey__c);
				  wo.accountid = s.site__c;
			  	  wo.Subject = 'Site Survey - ' +s.site__r.Name;
				  wo.Street = s.site__r.physical_street_address_line_1__c;
				  wo.City = s.site__r.physical_city__c;
				  wo.State = s.site__r.physical_state__c;
				  wo.PostalCode = s.site__r.physical_postal_code__c;
				  wo.Country = s.site__r.physical_country__c;
				  //shawks BUG-01021 - Set Work Type, Duration, Duration Type based on Site Survey Record Type
				  if(mpwt.get(mpcs.get(s.RecordType.Name)) <> null)  //Change value if found in custom setting and WorkType object
				  { RecordType_Name = s.RecordType.Name; }
				  wo.worktypeid = mpwt.get(mpcs.get(RecordType_Name)).id;
				  wo.Duration = mpwt.get(mpcs.get(RecordType_Name)).EstimatedDuration;
				  wo.DurationType = mpwt.get(mpcs.get(RecordType_Name)).DurationType;
			  }
		  }
	  }
  }
}//end class FieldWorkOrderTriggerLogic