public with sharing class CaseChangeSLAExtension {
    public Case thiscase {get;set;}
    public Case mycase = New Case();
    public Id caseid;
    public static List<Entitlement> lstentl = New List<Entitlement>();
    public List<cMilestoneDet> lstmilestonedet {get;set;}
    public List<cMilestoneDet> lstmilestone = New List<cMilestoneDet>();
    public Map<String,MilestoneDetails__c> mpmd = New Map<String,MilestoneDetails__c>();

    public CaseChangeSLAExtension(ApexPages.StandardController stdController)
    {
    	thiscase = (Case)stdController.getRecord();
        caseid = thiscase.id;
        String errmsg = 'Cannot display a list of case severities because there is no Entitlement linked to this case.';
		
        mycase = [Select Id, Entitlementid, priority, field_response_time_entitlement__c,
                  case_milestone_synopsis__c, target_date_time__c, dispatched__c, disptached_date_time__c
                  from Case where id = :caseid LIMIT 1];

        Id EntId = mycase.EntitlementId;

        if(EntId != null)
    	{ lstentl = [Select Id, status, catastrophic_severity_description__c, critical_severity_description__c,
		             high_severity_description__c, moderate_severity_description__c, low_severity_description__c,
					 slaprocessid, servicecontractid, assetid, asset.name, name, asset.platform__c
					 from Entitlement where id = :EntId ];
        }
        else {
            
            ApexPages.Message myMsg = new ApexPages.Message(ApexPages.Severity.INFO, errmsg);
				ApexPages.addMessage(myMsg);
        }

        if(lstentl.size() == 1)
        {
            Entitlement en = New Entitlement();
		    en = lstentl[0];

            //get response time and milestone description from the custom setting
            
		    Map<String,List<MilestoneDetails__c>> mapmdcs = New Map<String,List<MilestoneDetails__c>>();
		    List<MilestoneDetails__c> lstmdcs = MilestoneDetails__c.getall().values();
		    
		    for(MilestoneDetails__c thismd :lstmdcs)
		    {
			    if(thismd.Entitlement__c == en.name)
			    { mpmd.put(thismd.priority__c.toUpperCase(),thismd); }
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

            lstmilestonedet = lstmilestone;




        }  //end if lstentl size = 1
    }//end CaseChange controller method

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

    public Pagereference UpdateCasePriority()
    {
        String privalue;
        Integer resptime;
        String synopsis;

		for(cMilestoneDet str : lstmilestonedet)
		{
			//system.debug('milestone string str is ' +str);
		
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
		{ 
            mycase.priority = privalue;
            system.debug('privalue is ' +privalue.toUpperCase());

            for(String key :mpmd.keyset())
            {
                system.debug('key in mpmd is ' +key);
            }


            if(mpmd.containskey(privalue.toUpperCase()))
            {
                MilestoneDetails__c thismilestone = mpmd.get(privalue.toUpperCase());
                if(thismilestone.special_considerations__c == false)
                {
                    resptime = (integer.valueof(thismilestone.field_response_time_minutes__c));
                    system.debug('resptime is ' +resptime);
                    mycase.field_response_time_entitlement__c = resptime;
                    mycase.case_milestone_synopsis__c = thismilestone.description__c;

                 //jjackson -- the workflow rule that calculates the new target-date-time is
				 //resulting in a wrong value.  Let's see what using code does.
				   if(mycase.Dispatched__c == true && mycase.disptached_date_time__c != null)
                   {   system.debug('dispatched timestamp = ' +mycase.disptached_date_time__c);
				   	   Datetime addhrs = mycase.disptached_date_time__c.addminutes(resptime);
				       system.debug('addhrs = ' +addhrs);
					   mycase.target_date_time__c = addhrs; 
				   }
                }
                else {
                    
                }
            }



        
        }

		update mycase;
		//displayPopUp = false;
		Pagereference casePage = New Pagereference('/lightning/r/Case/' +mycase.id +'/view');
		casePage.setRedirect(true);
		return casePage;
    }


        
}//end class