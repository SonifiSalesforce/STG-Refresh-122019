//jjackson 11/2019:  code coverage for this extension class is supplied by unit test SupportTeamAccountExtTest.cls

public class SupportTeamCaseExtension {
    
    public Case suppcase {get;set;}
    public Id caseid; 
    public Id acctid;
    public List<serviceresource> lstuser {get;set;}
    public ResourcePreference rp = New ResourcePreference();
 
  
    public SupportTeamCaseExtension(ApexPages.StandardController controller) 
    {
        suppcase = (Case)controller.getRecord();
        caseid = suppcase.id;
        Case thiscase = [Select Id, Accountid from Case where id = :caseid LIMIT 1 ];
        acctid = thiscase.accountid;
        
        
        GetSupportTeamMembers();
    }

    public List<ServiceResource> GetSupportTeamMembers()
    {
        List<ServiceResource> lstu = New List<ServiceResource>();
        List<ServiceResource> lstnewusers = New List<ServiceResource>();
        List<ResourcePreference> lstpr = New List<ResourcePreference>();
        lstpr = [ Select Id, relatedrecordid, serviceresourceid, serviceresource.userinfo__c, Account__c, preferencetype from ResourcePreference where
                  relatedrecordid = :acctid and preferencetype = 'Preferred' ];

        if(lstpr.size() == 1){

            rp = lstpr[0];

 
            lstu = [Select Id, name, description, mobile_phone__c, manager2__r.name, manager2__r.manager2__r.name, 
                   manager2__r.mobile_phone__c, manager2__r.manager2__r.mobile_phone__c, manager_title__c, 
                   manager2__r.manager_title__c from ServiceResource where id = :rp.serviceresourceid ];

        }//end if lstpr size

        if(lstu.size() > 0)
        {
            for(ServiceResource u :lstu)
            {
                
                //system.debug('manager name is ' +u.manager2__r.name);
                //system.debug('upper manager name is ' +u.manager2__r.manager2__r.name);
                system.debug('preferred resource name is ' +u.name);
                
                if(u.manager2__r.manager2__r.name != null)
                {
                    ServiceResource newu2 = New ServiceResource();
                    newu2.name = u.manager2__r.manager2__r.name;
                    newu2.manager_title__c = u.manager2__r.manager_title__c;
                    newu2.mobile_phone__c = u.manager2__r.manager2__r.mobile_phone__c;

                    if(newu2.manager_title__c != 'Field Operations VP')
                    { lstnewusers.add(newu2); }
                }

                if(u.manager2__r.name != null)
                {
                   ServiceResource newu = New ServiceResource();
                    newu.name = u.manager2__r.name;
                    newu.manager_title__c = u.manager_title__c;
                    newu.mobile_phone__c = u.manager2__r.mobile_phone__c;
                    if(newu.manager_title__c != 'Field Operations VP')
                    { lstnewusers.add(newu); }

                }

                if(u.description == 'Lead FSR Technician' || u.description == 'Area Service Manager')
                {
                    ServiceResource newlead = New ServiceResource();
                    newlead.name = u.name;
                    if(u.description == 'Lead FSR Technician')
                    { newlead.manager_title__c = 'Lead Tech'; }
                    if(u.description == 'Area Service Manager')
                    { newlead.manager_title__c = 'Manager'; }
                    newlead.mobile_phone__c = u.mobile_phone__c;
                    lstnewusers.add(newlead);


                }

                if(u.id == rp.serviceresourceid)
                {
                    ServiceResource newu1 = New ServiceResource();
                    newu1.name = u.name;
                    newu1.manager_title__c = 'Preferred Resource';
                    newu1.mobile_phone__c = u.mobile_phone__c;
                    lstnewusers.add(newu1);
                }

                
            }// end for loop

        }
        else {
            
            ApexPages.addMessage(new ApexPages.Message(ApexPages.Severity.INFO, 'No field support team is assigned to this account.'));
        }

        lstuser = lstnewusers;
        return lstuser;
    }

  
}