public with sharing class CustomButtonCreateSupportCase {

    public Id Acctid;
	public Case suppcase {get;set;}
	public Account acc {get; set;}
	public List<Entitlement> lstents {get;set;}
	//public List<String> slalist =New List<String>();
	//public List<String> myslalist {get;set;}
	public Boolean displayPopUp {get;set;}
	public Boolean displaynewcase {get;set;}
	public Boolean slaselected {get;set;}
	public Id entid {get; set;}
	public Id scid {get;set;}
	public Id assid {get;set;}
	public date sdate {get;set;}
	public date edate {get;set;}
	public Id slaid {get;set;}
	public string stat {get;set;}
	public string productparentname;
	public static Map<Id,Entitlement> mapent = New Map<Id,Entitlement>();
	//instantiate a blank error string with each page load to clear any previous error message
	public static String msg1 = '';
	public static String msg2 = '';
	public static String msg3 = '';
	public static String msg4 = '';
	public static String msg5 = '';
	
	public CustomButtonCreateSupportCase(ApexPages.StandardController stdController)
    {
    	this.acc = (Account)stdController.getRecord();
    	Acctid = this.acc.id;
		this.suppcase = getCase();
		displayPopUp = false;
    	lstcheckedents=getCheckedEntitlement();
    	    	
    }
    
	//Sample code: get the list of field set fields for rendering on the VF page.  This method
	//pulls the correct fieldset based on the product inventory name in the entitlement
	//(the product parent name)
	public List<Schema.FieldSetMember> getFields()
	{	

		//this instantiates a list of fields that reside in a fieldset
		List<Schema.FieldSetMember> lstfieldset = New List<FieldSetMember>();

		//this pulls the fields from a fieldset (NewSupportCase1) into a fieldset list
		if(productparentname != 'Broadband Product Parent')
		{ lstfieldset = Schema.SObjectType.Case.Fieldsets.NewSupportCase1.getFields(); }
		else
		{ lstfieldset = Schema.SObjectType.Case.Fieldsets.NewSupportCase2.getFields(); }

		return lstfieldset;

	}


	private Case getCase()
	{
		String query = 'Select ';
		for(Schema.FieldSetMember f :this.getFields())
		{ query += f.getFieldPath()+', ' ;}
		query += 'Id from Case LIMIT 1';
		return Database.query(query);
	}
    
    public class cEntitlement //jjackson--wrapper class for creating list of selected quotes from the visual force page 
	{

		public Entitlement qte {get;set;}
		public Boolean selected {get;set;}
		public String estatus {get;set;}

        
		public cEntitlement(Entitlement e)
		{
			qte = e;
   			selected = false;
            qte.id = e.id;
            qte.name = e.name;
			qte.assetid = e.assetid;
            qte.startdate = e.startdate;
			qte.enddate = e.enddate;
			qte.slaprocessid = e.slaprocessid;
			qte.asset.name = e.asset.name;
			estatus = e.status;

			
		}
   } //end class cEntitlement

	
   	public List<cEntitlement> lstcheckedents {get;set;}
	public List<cEntitlement> lstselected = New List<cEntitlement>();
	Public cEntitlement checkede;

	//Sample wrapper class
   //this is a wrapper class that takes the custom setting records from MilestoneDetails__c along
   //with the severity string from the Entitlement record.  It combines this information to create
   //one list of sObject cMilestoneDet that will be used to populate the severity table on the
   //the visual force page
   public class cMilestoneDet
   {
	    public MilestoneDetails__c cs {get;set;}
		public Boolean slaselected {get;set;}
		public string mdseverity {get;set;}
		public string milestonedesc {get;set;}
		public Integer resptime {get;set;}

        
		public cMilestoneDet(MilestoneDetails__c md, String thisstring)
		{
			cs = md;
   			slaselected = false;
			mdseverity = thisstring;
			milestonedesc = cs.Description__c;
			resptime = Integer.valueof(cs.Field_Response_Time_Minutes__c);
 
		}
   }

	//these are lists for adding the cMilestoneDet records from the wrapper class above
	//this is the list that will get called by the visualforce page to display the
	//SLA table for selection of case severity
   public List<cMilestoneDet> lstmilestonedet {get;set;}
   public List<cMilestoneDet> lstmilestone = New List<cMilestoneDet>();
   
   public List<cEntitlement> getCheckedEntitlement()
	{
		lstents= [Select Id, name, accountid, servicecontractid, assetid, subscription__c, status, startdate, enddate, slaprocess.name,
		          catastrophic_severity_description__c, critical_severity_description__c, high_severity_description__c, moderate_severity_description__c,
				  slaprocessid, asset.name, low_severity_description__c from entitlement where accountid = :Acctid order by status, asset.name];

		system.debug('accountid is ' +Acctid);
		system.debug('lstents size is ' +lstents.size());
		List<cEntitlement> checklist = New List<cEntitlement>();
		List<cEntitlement> sortedchecklist = New List<cEntitlement>();

		if(lstents.size() > 0 )
		{
			for(Entitlement entl :lstents)
			{ 	
				mapent.put(entl.id, entl);
				system.debug('entitlement id added to map is ' +entl.id);
			}
		    
			

			for(Entitlement ent: lstents)
			{
				try{ checklist.add(new cEntitlement(ent)); }
				catch(Exception ex)
				{ system.debug('Error adding ent ' +ent.name +' to lstcheckedents: ' +ex.getMessage());}
			}

		}

		if(checklist.size() > 0)
		{
			for(cEntitlement ce :checklist)
			{
				if(ce.estatus == 'Active')
				{ sortedchecklist.add(ce); }
			}

			for(cEntitlement ce :checklist)
			{
				if(ce.estatus == 'Inactive')
				{  sortedchecklist.add(ce); }
			}

			for(cEntitlement ce :checklist)
			{
				if(ce.estatus == 'Expired')
				{  sortedchecklist.add(ce); }
			}

			
		}



		{ lstcheckedents = sortedchecklist; }

	   	return lstcheckedents;
	}
	
	public PageReference CreateSupportCase()
	{
		msg1 = 'You must select an active entitlement before clicking this button.';
		msg2 = 'You can choose only one entitlement to create a case.';
		msg3 = 'You must use an active entitlement to create a case.';
		msg4 = 'This entitlement has no SLA Process.  Please contact the Salesforce Support Team.';
		msg5 = 'This entitlement has no case severities.  Please contact the Salesforce Support Team.';
		Id key;
		
		for(cEntitlement ce : lstcheckedents)
		{
			if(ce.selected == true)
			{
				lstselected.add(ce);
			}
		}
		
		if(lstselected.IsEmpty())
		{
			ApexPages.Message myMsg = New ApexPages.Message(ApexPages.Severity.ERROR, msg1);
            ApexPages.addMessage(myMsg);
            return null;
		}
		
		if(lstselected.size() > 1)
		{
			ApexPages.Message myMsg = new ApexPages.Message(ApexPages.Severity.ERROR, msg2);
            ApexPages.addMessage(myMsg);
            return null;
		}
		
		if(lstselected.size() == 1)
		{
		  
		  for(cEntitlement cent :lstselected)
		  {
			  key = cent.qte.id;
			  productparentname = cent.qte.asset.name;
		  }

		  List<Entitlement> lstentl = New List<Entitlement>();
		  lstentl = [Select Id, status, catastrophic_severity_description__c, critical_severity_description__c,
		             high_severity_description__c, moderate_severity_description__c, low_severity_description__c,
					 slaprocessid, servicecontractid, assetid, asset.name, name, asset.platform__c
					 from Entitlement where id = :key ];
          

		  if(lstentl.size() == 1)
		  {
			Boolean blnnoerrorflag = true;

			Entitlement en = New Entitlement();
			en = lstentl[0];

			//get response time and milestone description from the custom setting
			Map<String,List<MilestoneDetails__c>> mapmdcs = New Map<String,List<MilestoneDetails__c>>();
			List<MilestoneDetails__c> lstmdcs = MilestoneDetails__c.getall().values();
			Map<String,MilestoneDetails__c> mpmd = New Map<String,MilestoneDetails__c>();
			for(MilestoneDetails__c thismd :lstmdcs)
			{
				if(thismd.Entitlement__c == en.name)
				{ mpmd.put(thismd.priority__c.toUpperCase(),thismd); }
			}
			
			if(en.status != '' && en.status != 'Active')
			{
				blnnoerrorflag = false;
				ApexPages.Message myMsg = new ApexPages.Message(ApexPages.Severity.ERROR, msg3);
				ApexPages.addMessage(myMsg);
				return null;
			}
			
			if(en.slaprocessid == null)
			{	
				blnnoerrorflag = false;
				ApexPages.Message myMsg = new ApexPages.Message(ApexPages.Severity.ERROR, msg4);
				ApexPages.addMessage(myMsg);
				return null;
			}
			
			String catastrophic = 'Catastrophic: ' +en.catastrophic_severity_description__c;
			String critical = 'Critical: ' +en.critical_severity_description__c;
			String high = 'High: ' +en.high_severity_description__c;
			String moderate = 'Moderate: ' +en.moderate_severity_description__c;
			String low = 'Low: ' +en.low_severity_description__c;
			if(en.catastrophic_severity_description__c != null && en.catastrophic_severity_description__c != '')
			{   
				MilestoneDetails__c catmd = New MilestoneDetails__c();
				if(mpmd.containskey('CATASTROPHIC'))
				{ catmd = mpmd.get('CATASTROPHIC'); 
				  cMilestoneDet wrappedmilestone = New cMilestoneDet(catmd, catastrophic);
				  lstmilestone.add(wrappedmilestone);
				}
			}
			if(en.critical_severity_description__c != null && en.critical_severity_description__c != '')
			{ 	
				MilestoneDetails__c critmd = New MilestoneDetails__c();
				if(mpmd.containskey('CRITICAL'))
				{ critmd = mpmd.get('CRITICAL'); 
				  cMilestoneDet critmilestone = New cMilestoneDet(critmd, critical);
				  lstmilestone.add(critmilestone);
				}
			}
			if(en.high_severity_description__c != null && en.high_severity_description__c != '')
			{ 	
				MilestoneDetails__c highmd = New MilestoneDetails__c();
				if(mpmd.containskey('HIGH'))
				{ highmd = mpmd.get('HIGH'); 
				  cMilestoneDet highmilestone = New cMilestoneDet(highmd, high);
				  lstmilestone.add(highmilestone);
				}
			 }

			if(en.moderate_severity_description__c != null && en.moderate_severity_description__c != '')
			{ 	
				MilestoneDetails__c modmd = New MilestoneDetails__c();
				if(mpmd.containskey('MODERATE'))
				{ modmd = mpmd.get('MODERATE'); 
				  cMilestoneDet modmilestone = New cMilestoneDet(modmd, moderate);
				  lstmilestone.add(modmilestone);
				}

			}
			if(en.low_severity_description__c != null && en.low_severity_description__c != '')
			{ 	
				MilestoneDetails__c lowmd = New MilestoneDetails__c();
				if(mpmd.containskey('LOW'))
				{ lowmd = mpmd.get('LOW'); 
				  cMilestoneDet lowmilestone = New cMilestoneDet(lowmd, low);
				  lstmilestone.add(lowmilestone);
				}
			}

			system.debug('lstmilestone size is ' +lstmilestone.size());

			//now all the entitlement sla's are added to local list lstmilestone.  Apply lstmilestone
			//to lstmilestonedet, which is the list that displays on the vf page
			lstmilestonedet = lstmilestone;

			
			if(en.slaprocessid != null && (critical == '' && catastrophic == '' && high == '' && moderate == '' && low == ''))
			{
				blnnoerrorflag = false;
				ApexPages.Message myMsg = new ApexPages.Message(ApexPages.Severity.ERROR, msg5);
				ApexPages.addMessage(myMsg);
				return null;
			}
			
			if(lstselected.size() == 1 && blnnoerrorflag == true)
    		{
    			entid = en.Id;
				scid = en.servicecontractid;
				assid = en.assetid;
				String platform = en.asset.platform__c;
				String assetname = en.asset.name;
				Map<String,CaseProductTypes__c> csmap = CaseProductTypes__c.getAll();
				//displayPopUp = true; //this is rendering the output panel but it is on the same vf page as the entitlement table. Need to pop it out.
				Id rectypeid = Utilities.RecordTypeNameToId('Case', 'Support Case');
				system.debug('rectypeid is ' +rectypeid);
				Case newcase = New Case();
				newcase.recordtypeid = rectypeid;
				newcase.accountid = Acctid;
				newcase.assetid = assid;
				newcase.entitlementid = entid;
				newcase.service_contract_name__c = scid;
				newcase.status = 'Open';
				newcase.createddate = system.now();
				if(csmap.containskey(assetname) && assetname != 'Interactive Product Parent')
				{ newcase.case_product_type__c = csmap.get(assetname).Product_Inventory__c; }
				else {
				  newcase.case_product_type__c = '';
				}

				if(assetname == 'Interactive Product Parent')
				{
					if(platform != null)
					{
						if(platform.contains('OCX'))
						{ newcase.case_product_type__c = 'Interactive - ONCO'; }
						else {
						  newcase.case_product_type__c = 'Interactive';
						}
					}
					else {
						newcase.case_product_type__c = 'Interactive';
					}
				}//end if asset name
				
				suppcase = newcase;
				displayPopUp = true;
				displaynewcase = true;


    		}
		}//end if en !=null
		
	  }//end if lstselected
		
		return null;
	
	}//end CreateSupportCase

	public pagereference ClearErrMessage()
	{
		PageReference pr = ApexPages.currentPage();
		pr.setRedirect(true);
		return pr;
	}
	
	public pagereference CreateNonContracted()
	{
		List<Entitlement> lste = New List<Entitlement>();
		String eid;
		if(test.isRunningTest())
		{
			eid = '550F0000000kVz9';
		}
		else {
			
			eid = AppConfig__c.getValues('Global').Base_SLA__c;
		}
		
		lste = [Select Id, name, catastrophic_severity_description__c, critical_severity_description__c, moderate_severity_description__c,
		        low_severity_description__c, servicecontractid from Entitlement where id = :eid ];

		Entitlement en = New Entitlement();
		en = lste[0];
		Map<String,List<MilestoneDetails__c>> mapmdcs = New Map<String,List<MilestoneDetails__c>>();
		List<MilestoneDetails__c> lstmdcs = MilestoneDetails__c.getall().values();
		Map<String,MilestoneDetails__c> mpmd = New Map<String,MilestoneDetails__c>();
		for(MilestoneDetails__c thismd :lstmdcs)
		{
				if(thismd.Entitlement__c == en.name)
				{ mpmd.put(thismd.priority__c.toUpperCase(),thismd); }
		}		
		
		if(lste.size() == 1)
		{
			
			Id rectypeid = Utilities.RecordTypeNameToId('Case', 'Support Case');
			
			String catastrophic = 'Catastrophic: ' +en.catastrophic_severity_description__c;
			String critical = 'Critical: ' +en.critical_severity_description__c;
			String moderate = 'Moderate: ' +en.moderate_severity_description__c;
			String low = 'Low: ' +en.low_severity_description__c;
			
			if(en.catastrophic_severity_description__c != null && en.catastrophic_severity_description__c != '')
			{   
				MilestoneDetails__c catmd = New MilestoneDetails__c();
				if(mpmd.containskey('CATASTROPHIC'))
				{ catmd = mpmd.get('CATASTROPHIC'); 
				  cMilestoneDet wrappedmilestone = New cMilestoneDet(catmd, catastrophic);
				  lstmilestone.add(wrappedmilestone);
				}
			}
			if(en.critical_severity_description__c != null && en.critical_severity_description__c != '')
			{ 	
				MilestoneDetails__c critmd = New MilestoneDetails__c();
				if(mpmd.containskey('CRITICAL'))
				{ critmd = mpmd.get('CRITICAL'); 
				  cMilestoneDet critmilestone = New cMilestoneDet(critmd, critical);
				  lstmilestone.add(critmilestone);
				}
			}
			
			if(en.moderate_severity_description__c != null && en.moderate_severity_description__c != '')
			{ 	
				MilestoneDetails__c modmd = New MilestoneDetails__c();
				if(mpmd.containskey('MODERATE'))
				{ modmd = mpmd.get('MODERATE'); 
				  cMilestoneDet modmilestone = New cMilestoneDet(modmd, moderate);
				  lstmilestone.add(modmilestone);
				}

			}
			if(en.low_severity_description__c != null && en.low_severity_description__c != '')
			{ 	
				MilestoneDetails__c lowmd = New MilestoneDetails__c();
				if(mpmd.containskey('LOW'))
				{ lowmd = mpmd.get('LOW'); 
				  cMilestoneDet lowmilestone = New cMilestoneDet(lowmd, low);
				  lstmilestone.add(lowmilestone);
				}
			}

			if(lstmilestone.size() > 0)
			{
				lstmilestonedet = lstmilestone;
			}
			displayPopUp = true;
			displaynewcase = true;

			Case noncase = New Case();
			noncase.entitlementid = eid;
			noncase.service_contract_name__c = lste[0].servicecontractid;
			noncase.recordtypeid = rectypeid;
			noncase.status = 'Open';
			noncase.accountid = Acctid;
			suppcase = noncase;
			displayPopUp = true;
			displaynewcase = true;

		}
		
		return null;


	}

	public pagereference CancelPopUp()
	{
		return new PageReference('/lightning/r/Account/'+Acctid+'/view');
		
	}

	public pagereference SaveCase()
	{
		String privalue;
		for(cMilestoneDet str : lstmilestonedet)
		{
			system.debug('milestone string str is ' +str);
		
			if(str.slaselected == true)
			{
				if(str.mdseverity.contains('Catastrophic'))
				{ privalue = 'Catastrophic'; }
				if(str.mdseverity.contains('Critical'))
				{ privalue = 'Critical'; }
				if(str.mdseverity.contains('High'))
				{ privalue = 'High'; }
				if(str.mdseverity.contains('Moderate'))
				{ privalue = 'Moderate'; }
				if(str.mdseverity.contains('Low'))
				{ privalue = 'Low'; }
			}
		}

		system.debug('priority selected is ' +privalue);

		if(privalue == null)
		{ ApexPages.Message myMsg = new ApexPages.Message(ApexPages.Severity.ERROR, 'You must choose an SLA value to save a case.'); }
		else
		{ suppcase.priority = privalue; }

		insert suppcase;
		displayPopUp = false;
		Pagereference casePage = New Pagereference('/lightning/r/Case/' +suppcase.id +'/view');
		suppcase = null;
		casePage.setRedirect(true);
		return casePage;
	}
	
}