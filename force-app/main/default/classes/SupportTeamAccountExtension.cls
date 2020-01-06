public class SupportTeamAccountExtension {
    
    public Account acc {get;set;}
    public Id acctid; 
    public List<ServiceResource> lstuser {get;set;}
 
  
    public SupportTeamAccountExtension(ApexPages.StandardController controller) 
    {
        acc = (Account)controller.getRecord();
        acctid = acc.id;
        GetSupportTeamMembers();
    }

    public List<ServiceResource> GetSupportTeamMembers()
    {
        List<ServiceResource> lstu = New List<ServiceResource>();
        List<ServiceResource> lstnewusers = New List<ServiceResource>();
        List<ResourcePreference> lstpr = New List<ResourcePreference>();
        lstpr = [ Select Id, relatedrecordid, serviceresource.userinfo__c, serviceresource.userinfo__r.profile.name, Account__c, preferencetype from ResourcePreference where
                  relatedrecordid = :acc.id and preferencetype = 'Preferred' ];

        if(lstpr.size() == 1){

            ResourcePreference rp = lstpr[0];

 
            lstu = [Select Id, name, description, mobile_phone__c, manager2__r.name, manager2__r.manager2__r.name, manager2__r.mobile_phone__c, manager2__r.manager2__r.mobile_phone__c,
                    manager_title__c, manager2__r.manager_title__c from ServiceResource where id = :rp.serviceresourceid ];

        }//end if lstpr size

        if(lstu.size() > 0)
        {
            for(ServiceResource u :lstu)
            {
                
                system.debug('manager name is ' +u.manager2__r.name);
                system.debug('upper manager name is ' +u.manager2__r.manager2__r.name);
                
                if(u.manager2__r.manager2__r.name != null)
                {
                    ServiceResource newu2 = New ServiceResource();
                    newu2.name = u.manager2__r.manager2__r.name;
                    newu2.manager_title__c = u.manager2__r.manager_title__c;
                    newu2.mobile_phone__c = u.manager2__r.manager2__r.mobile_phone__c;
                    lstnewusers.add(newu2);
                }

                if(u.manager2__r.name != null)
                {
                    ServiceResource newu = New ServiceResource();
                    newu.name = u.manager2__r.name;
                    newu.manager_title__c = u.manager_title__c;
                    newu.mobile_phone__c = u.manager2__r.mobile_phone__c;
                    lstnewusers.add(newu);

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

                String mytheme = UserInfo.getUiThemeDisplayed();
                system.debug('mytheme is ' +mytheme);
                if(mytheme == 'Theme4d' || mytheme == 'Theme4u')
                {
                    ServiceResource newu1 = New ServiceResource();
                    newu1.name = u.name;
                    newu1.manager_title__c = 'Preferred Resource';
                    newu1.mobile_phone__c = u.mobile_phone__c;
                    system.debug(newu1);
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