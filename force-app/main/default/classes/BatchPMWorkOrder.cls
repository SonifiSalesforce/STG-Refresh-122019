global class BatchPMWorkOrder implements Database.Batchable<sObject> {

    global Database.QueryLocator start (Database.BatchableContext context) {

        
        String inststatus = 'Installed Activated';
        String billstatus = 'Billing';
        String entstatus = 'Active';
        String country1 = 'USA';
        String country2 = 'Canada';
        

        //build and run the entitlement query
        String batchquery = 'Select Id, Name, Accountid, Account.Name, Account.PM_Opt_Out__c, Account.Physical_country__c, '
                            + 'asset.id, asset.name, asset.status, pm_frequency__c, status, '
                            + 'servicecontractid from Entitlement where '
                            + 'pm_frequency__c != null AND pm_frequency__c > 0 '
                            + 'AND account.pm_opt_out__c = false AND assetid != null AND accountid != null '
                            + 'AND (Account.Physical_country__c = :country1 OR Account.Physical_Country__c = :country2) '
                            + 'AND (asset.status = :inststatus OR asset.status = :billstatus) '
                            + 'AND status = :entstatus';

        try{ return Database.getQueryLocator(batchquery); }
        catch(Exception e) {return null; }
    }

    global void execute(Database.BatchableContext context, List<sObject> sObjects )
    {
        //check for records to process
        if(sObjects == null || sObjects.isEmpty())
        {  return;  }

 
        //process records
        BatchPMWorkOrderCreation.CreatePMWorkOrders((List<Entitlement>) sObjects);
        
    }

    global void finish (Database.BatchableContext batch)
    {
        //send notification email to lead techs in the Schedule PM Field Work Orders queue.
        EmailUtilities.NotifyAfterPMWorkOrderBatchProcess();
    }
}
//To manually run this process or to do a test run, execute the below in
//the Developer Console (Execute Anonymous);
//BatchPMWorkOrder batchprocess = New BatchPMWorkOrder();
//Database.executeBatch(batchprocess);