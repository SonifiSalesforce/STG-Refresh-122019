public with sharing class CustomButtonReopenCaseExtension {
    
    Public Case c {get;set;}
    Public Id cid;

    public CustomButtonReopenCaseExtension(ApexPages.StandardController controller){
		c = (Case)controller.getRecord();
	    cid = c.id;
		
	}



    public Pagereference ReopenCase()
    {   
        Id openrectype = Utilities.RecordTypeNameToId('Case', 'Support Case');
        Case mycase = New Case();
        DateTime mycloseddate;
        mycase = [ Select recordtypeid, casenumber, id, status, case_re_opened_date__c, 
                     closeddate, case_close_date__c, closed_case_summary__c, close_case_comments__c,
                     resolution__c, resolved_by__c from Case
		             where Id = :cid LIMIT 1 ];

        //system.debug(mycase.casenumber);
        mycloseddate = mycase.closeddate;
        //system.debug(mycloseddate);
       

        DateTime timenow = system.now();
        
        if(mycloseddate != null)
        { 
            DateTime closedwindow = mycloseddate.addDays(7); 
            system.debug('closedwindow is ' +closedwindow);
            String msg2 = 'This case cannot be re-opened because it is has been closed longer than 7 days.';

            if(timenow > closedwindow)
            {
                ApexPages.addMessage(new ApexPages.Message(ApexPages.Severity.ERROR,
      				                    msg2)); 
		        return null;
            }
        
            mycase.status = 'Re-Opened';
            mycase.case_re_opened_date__c = system.now();
            mycase.case_close_date__c = null;
            mycase.closed_case_summary__c = '';
            mycase.close_case_comments__c = '';
            mycase.resolution__c = '';
            mycase.resolved_by__c = '';

            try{update mycase;}
            catch(Exception e)
            {
                String myMsg1 = 'Error trying to reopen case ' +mycase.casenumber +': ' +e.getMessage();
                ApexPages.addMessage(new ApexPages.Message(ApexPages.Severity.ERROR,
      				                    myMsg1)); 
                return null;
         
            }

  
        }
  
            PageReference casepage = new ApexPages.StandardController(c).view();
            casepage.setRedirect(true);
            return casepage;
        
    }//end Reopen Case
}