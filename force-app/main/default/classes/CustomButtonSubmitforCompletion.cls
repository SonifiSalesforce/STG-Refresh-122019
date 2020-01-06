/*
jjackson Sonifi Solutions 4/2019:  Field Service Lightning Project, also converting the installation group
to the lightning platform so this code with visualforce page will be a new button/lightning action to replace
a javascript button in classic.  TODO:  Create the visualforce page needed for the button.
*/

public with sharing class CustomButtonSubmitforCompletion {
	
	public Work_Order__c wo {get;set;}
	public Work_Order__c worec;
	public Id woid;
	public List<Work_Order__c> lstwo = New List<Work_Order__c>();
	public static Boolean isLightning = false;
	
	
	public CustomButtonSubmitforCompletion(ApexPages.StandardController controller)
    {
  		wo = (Work_Order__c)controller.getRecord();
		lstwo = [ Select recordtype.name, id, billing_approval_needed__c, approver__c, install_complete_date__c,
		          De_Installation_Date__c, primary_hotel_contact__c, name,
		          primary_hotel_contact__r.email, site__r.parent.parent.name from Work_Order__c where id = :wo.id ];
		          
		worec = lstwo[0];
		
		if(UserInfo.getUIThemeDisplayed() == 'Theme4d')
    	{  isLightning = true;  }
    }
    
    public String errormessage()
    {
    	String message = '';
    	//String rectypename = Utilities.RecordTypeIdtoName(worec.recordtypeid, 'Work_Order__c');
    	String rectypename = worec.recordtype.name;
    	system.debug(rectypename);
    	
    	//jjackson validate that work order has been through the billing approval process first;
    	if((rectypename == 'Install' || rectypename == 'De-Install') && worec.billing_approval_needed__c == true)
    	{    message = 'The work order Billing process must be approved before submitting for completion.';  }
    	
    	//jjackson 4/2019 add more validation by checking whether the primary_hotel_contract__c field
    	//on the work order is linked to a contact with an email address if the work order is for a Hyatt
    	//brand hotel.  If a Hyatt and no primary contact, throw an error.
    	
    	if(worec.site__r.parent != null)
    	{
    		
    	  if(worec.site__r.parent.parent != null)
    	  {
    	  	
    	   if(worec.site__r.parent.parent.name.contains('Hyatt'))
    	   {
    			if(rectypename == 'Install' && worec.name.contains('SC'))
    			{ 
    				if(worec.primary_hotel_contact__c == null || worec.primary_hotel_contact__r.email == null)
    	    			{ message = 'Cannot Submit for Completion.  Please select a Primary Hotel Contact ';
    	       			  message += 'that has an email address.';}
    			}
    	   }
    	 } 
    	}  
    	
    	if(rectypename == 'De-Install'  && worec.De_Installation_Date__c == null)
           	 { message = 'De-Installation Date is required.';  }
        else if(rectypename == 'Install' && worec.Install_Complete_Date__c == null)
           	 { message = 'Install Complete Date is required.';  }
           	 
        if(worec.Approver__c == null)
        {  message = 'The Approver field cannot be blank.';  }
        
        return message;
 	
    }
    
    public pageReference SubmitforCompletion()
    {
    	
    	String errormsg = errormessage();
    	if(errormsg != '' && errormsg != null)
    	{ApexPages.addMessage(new ApexPages.Message(ApexPages.Severity.ERROR,
      				                    'Error in Submit For Completion:  ' +errormsg)); 
         return null;
    	}
    	else
    	{
    	
     	
    			Id uid = UserInfo.getUserId();
    		
    			Approval.ProcessSubmitRequest req1 = new Approval.ProcessSubmitRequest();
            	req1.setComments('Submitting Work Order for Completion.');
            	req1.setObjectId(worec.id);
            	Approval.ProcessResult result = Approval.process(req1);
              	if(uid == worec.approver__c)
            	{
                	List<Id> newWorkItemIds = result.getNewWorkitemIds();
 	
                	Approval.ProcessWorkitemRequest req2 = new Approval.ProcessWorkitemRequest();
               		req2.setComments('Submitter is Approver, Auto approving');
                	req2.setAction('Approve');
                	req2.setNextApproverIds(new Id[] {UserInfo.getUserId()});
                
                	// Use the ID from the newly created item to specify the item to be worked
                	req2.setWorkitemId(newWorkItemIds.get(0));
                
                	// Submit the request for approval
                	Approval.ProcessResult result2 =  Approval.process(req2);
                	system.debug('Autoapproving result:'+result2.isSuccess());
            	}
            	
        	}//end else
        
        //Sample: set page redirect url for classic or lightning
        String thisurl;
        String hostVal = ApexPages.currentPage().getHeaders().get('Host');
        
		if(islightning == false)
		{ thisurl = 'https://' +hostVal+'/'+worec.id; }
		else
		{ thisurl = 'https://'+hostVal+'/lightning/r/Work_Order__c/' +worec.id+'/view';  }
		system.debug('thisurl = ' +thisurl);
		PageReference pr = new PageReference(thisurl);
		pr.setRedirect(false); 
		return pr; 
 
    	}//end pageref

 
}