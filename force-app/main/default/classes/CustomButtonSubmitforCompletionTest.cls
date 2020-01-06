@isTest
private class CustomButtonSubmitforCompletionTest {

    static testMethod void SubmitButton() {
    
    	Account a = CreateTestRecords.DefaultHospitalityAccount();
    	Id userid = UserInfo.getUserId();
    	Id rectypeid = Utilities.RecordtypeNametoId('Work_Order__c', 'Install');
    	Id recid = Utilities.RecordtypeNametoId('Contact', 'Hospitality Contact');
    	
    	Contact c = New Contact(firstname='Joe', lastname='Blow', Accountid = a.id, Title='Director', Role__c='Engineering Contact',
    	                        recordtypeid = recid, status__c = 'Active', Phone='999-999-9999', email='invalidemail@email.com');
    	                        
    	insert c;
    	
    	Work_Order__c wo = New Work_Order__c(Site__c = a.id, Name=a.name +' - Install', Install_manager__c = userid, project_coordinator__c = userid,
    	                                      Number_of_rooms__c = 100, Ownerid = userid, status__c = 'Billing/Go Live', Approver__c = userid,
    	                                      recordtypeid = rectypeid, Division__c = 'Domestic', Region__c = 'Northwest', Install_Complete_Date__c = system.Today(),
    	                                      Billing_Approval_Needed__c = false, Primary_Hotel_Contact__c = c.id);
    	insert wo;
    	
    	Work_Order__c wo1 = New Work_Order__c(Site__c = a.id, Name=a.name +' - Install', Install_manager__c = userid, project_coordinator__c = userid,
    	                                      Number_of_rooms__c = 100, Ownerid = userid, status__c = 'Billing/Go Live', Approver__c = userid,
    	                                      recordtypeid = rectypeid, Division__c = 'Domestic', Region__c = 'Northwest', Install_Complete_Date__c = system.Today(),
    	                                      Billing_Approval_Needed__c = true, Primary_Hotel_Contact__c = c.id);
    	insert wo1;
    	
    	Work_Order__c wo2 = New Work_Order__c(Site__c = a.id, Name=a.name +' - Install', Install_manager__c = userid, project_coordinator__c = userid,
    	                                      Number_of_rooms__c = 100, Ownerid = userid, status__c = 'Billing/Go Live', Approver__c = userid,
    	                                      recordtypeid = rectypeid, Division__c = 'Domestic', Region__c = 'Northwest',
    	                                      Billing_Approval_Needed__c = false, Primary_Hotel_Contact__c = c.id);
    	insert wo2;
    	
       
       //jjackson SAMPLE CODE:  this simulates a button click so the pageReference method can be tested
       //on a controller extension
       ApexPages.StandardController sc = new ApexPages.StandardController(wo);
       CustomButtonSubmitforCompletion testbutton = New CustomButtonSubmitforCompletion(sc);
       PageReference pageRef = Page.CustomButtonSubmitforCompletionPage;
       pageRef.getParameters().put('Id', String.valueOf(wo.id));
       Test.setCurrentPage(pageRef);
       testbutton.SubmitforCompletion();
       
       ApexPages.StandardController scon = new ApexPages.StandardController(wo1);
       CustomButtonSubmitforCompletion testbutton1 = New CustomButtonSubmitforCompletion(scon);
       PageReference pageRef1 = Page.CustomButtonSubmitforCompletionPage;
       pageRef1.getParameters().put('Id', String.valueOf(wo1.id));
       Test.setCurrentPage(pageRef1);
       testbutton1.SubmitforCompletion();
       
       ApexPages.StandardController sc2 = new ApexPages.StandardController(wo2);
       CustomButtonSubmitforCompletion testbutton2 = New CustomButtonSubmitforCompletion(sc2);
       PageReference pageRef2 = Page.CustomButtonSubmitforCompletionPage;
       pageRef2.getParameters().put('Id', String.valueOf(wo2.id));
       Test.setCurrentPage(pageRef2);
       testbutton2.SubmitforCompletion();
       
       
       
       
        
    }
}