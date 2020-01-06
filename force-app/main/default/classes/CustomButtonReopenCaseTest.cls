@isTest (seeAllData=true)
public class CustomButtonReopenCaseTest {
    
    public static testmethod void testReopenCase() 
    {
        Id suppcaseid = Utilities.RecordTypeNametoId('Case', 'Support Case Closed');
        Datetime closedlimit = system.now().addDays(-5);
        Case testcase = [Select Id, casenumber, recordtypeid, status, priority, entitlementid, resolution__c,
                        dispatched__c, closeddate, date_time_resolved__c from Case where recordtypeid = :suppcaseid AND status = 'Closed' and
                        dispatched__c = true and closeddate > :closedlimit LIMIT 1];

        Pagereference pageref = Page.CustomButtonReopenCase;
        Test.setCurrentPage(pageref);

        CustomButtonReopenCaseExtension controller = new CustomButtonReopenCaseExtension(new ApexPages.StandardController(testcase));

        controller.c = testcase;
        controller.cid = testcase.id;
        controller.ReopenCase();

    }

    public static testmethod void testReopenOldCase() 
    {
        Id suppcaseid = Utilities.RecordTypeNametoId('Case', 'Support Case Closed');
        Datetime closedlimit = system.now().addDays(-15);
        Case testcase = [Select Id, casenumber, recordtypeid, status, priority, entitlementid, resolution__c,
                        dispatched__c, closeddate, date_time_resolved__c from Case where recordtypeid = :suppcaseid AND status = 'Closed' and
                        dispatched__c = true and closeddate > :closedlimit LIMIT 1];

        Pagereference pageref = Page.CustomButtonReopenCase;
        Test.setCurrentPage(pageref);

        CustomButtonReopenCaseExtension controller = new CustomButtonReopenCaseExtension(new ApexPages.StandardController(testcase));

        controller.c = testcase;
        controller.cid = testcase.id;
        controller.ReopenCase();

    }
}//end class custombuttonreopencasetest