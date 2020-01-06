@isTest
public with sharing class WorkOrderTriggerLogicTest {

	
    static testMethod void WorkOrderTriggerLogicTest()
    {
        System.debug(' BEGIN WorkOrderTriggerLogicTest Test .  **********    START');
        Account a = CreateTestRecords.DefaultHospitalityAccount();

        //jjackson FSL Project 5/2019 create work type and scheduling policy for work order insert test of
        //PopulateFSL Fields
        //Add a record to the custom setting SonifiWorkOrderFSLFields__c 
        SonifiWorkOrderFSLFields__c csrecord = New SonifiWorkOrderFSLFields__c(Name='Install', Scheduling_Policy__c = 'Turnkey Deployments',
                                                                     Work_Type__c = 'Install');

        insert csrecord;

        WorkType wt = New WorkType(Name='Install', EstimatedDuration=120);
        insert wt;

        FSL__Scheduling_Policy__c sp = New FSL__Scheduling_Policy__c(Name='Turnkey Deployments');
        insert sp;

         Work_Order__c wo = CreateTestRecords.DefaultInstallWorkOrder(a.id);
         Site_Photo__c ss = (Site_Photo__c)DataGenerator.createSObjectWithDefaultValues('Site_Photo__c',null);
        ss.Site__c = a.Id;
        insert ss;      
        Test.startTest();
        wo.Status__c = 'Complete';
        update wo;
        Test.stopTest();

        Work_Order__c updwo = [Select Id, Scheduling_Policy__c, Work_Type__c from work_order__c where id = :wo.id ];
        system.assert(updwo.work_type__c == wt.id);
        system.assert(updwo.scheduling_policy__c == sp.id);
        List<Site_Photo__c> ssList = [SELECT Id from Site_Photo__c WHERE Id = :ss.Id];
        system.assert(ssList.size() == 0, 'Site Photos remaining' +ssList.size());
        System.debug(LoggingLevel.DEBUG,'WorkOrderTriggerLogicTest WorkOrderTriggerLogicTest Test .  **********    Finished');
    }
    
    static testMethod void sitePhotoDeletionBulkTest()
    {
    	System.debug(LoggingLevel.DEBUG,'WorkOrderTriggerLogicTest sitePhotoDeletionBulkTest Test .  **********    START');
        List<Account> aList = new List<Account>();
        for(Integer i = 0; i < 300; i++)
        {
            aList.add(new Account(Name = 'TestAccount'+i));
        }
        insert aList;

        Account a = CreateTestRecords.DefaultHospitalityAccount();
        Work_Order__c wo = CreateTestRecords.DefaultInstallWorkOrder(a.id);
        Site_Photo__c ss = new Site_Photo__c(Site__c = a.id);
        insert ss;

        test.startTest();
        wo.Status__c = 'Complete';
        update wo;

        test.stopTest();
        
        System.debug(LoggingLevel.DEBUG,'WorkOrderTriggerLogicTest sitePhotoDeletionBulkTest Test .  **********    Finished ');
    }
    
    static testMethod void testUpdateTVTypeRelated2Acc()
    {
    	System.debug(LoggingLevel.DEBUG,'WorkOrderTriggerLogicTest testUpdateTVTypeRelated2Acc Test .  **********    START');
        Account a = DataGenerator.createAccounts(1,true)[0];
        List<Work_Order__c> woList = new List<Work_Order__c>();
        for(integer i = 0; i < 5; i++){
            Work_Order__c wo = new Work_Order__c();
            wo.Site__c = a.Id;
            woList.add(wo);
        }
        insert woList;
        
        insert new List<TV_Type__c>{new TV_Type__c(Work_Order__c = woList[0].id, Other_Manufacturer__c='other manu', Other_Model__c = 'other model'), new TV_Type__c(Site__c = a.id, Other_Manufacturer__c='other manu', Other_Model__c = 'other model'), new TV_Type__c(Site__c = a.id, Other_Manufacturer__c='other manu', Other_Model__c = 'other model'), new TV_Type__c(Work_Order__c = woList[1].id, Other_Manufacturer__c='other manu', Other_Model__c = 'other model')};
        
        Test.startTest();
        woList[0].Status__c = 'Install Complete';
        update woList[0];
        Test.stopTest();
        List<TV_Type__c> tvList = [SELECT Id from TV_Type__c WHERE Site__c = :a.Id];
        system.assertEquals(1, tvList.size());
        System.debug(LoggingLevel.DEBUG,'WorkOrderTriggerLogicTest testUpdateTVTypeRelated2Acc Test .  **********   Finished');
    }


    
    static testMethod void testProductActivationBillingAfterInstall()
    {
    	system.debug('WorkOrderTriggerLogicTest testProductActivationBillingAfterInstall  **********    START');
        Id uid = Userinfo.getUserId();
        Account acc = CreateTestRecords.DefaultHospitalityAccount();
        Id workOrderRecordType = Utilities.RecordTypeNametoId('Work_Order__c', 'Install');
        
        //create and insert the asset recs that are needed by product activations
        Asset assetparent = New Asset(accountid = acc.id, name = 'Test Asset Product Parent', status = 'Installed Activated');
        insert assetparent;
        Asset ass1 = new Asset(accountid = acc.id, name = 'Test Asset1 Install', status = 'Pending Installation Activate', parent_asset__c = assetparent.id);
        Asset ass2 = new Asset(accountid = acc.id, name = 'Test Asset2 Deinstall', status = 'Pending De-Installation', parent_asset__c = assetparent.id);
        List<Asset> insertassets = new List<Asset>();
        insertassets.add(ass1);
        insertassets.add(ass2);
        insert insertassets;
        
        //create and insert the order item recs that are needed by the associated items
        Order_Item__c oiparent = New Order_Item__c(asset__c=assetparent.id, status__c = 'Installed Activated', total_rooms_ordered__c = 500,
                                                   total_remaining_rooms__c = 500, name = 'Test Product Parent');
        insert oiparent;
        Order_Item__c oi1 = New Order_Item__c(asset__c = ass1.id, status__c = 'Pending Installation Activate',
                                              total_rooms_ordered__c = 500, total_remaining_rooms__c = 500, Name = 'Testoi1', parent__c = oiparent.id);
        Order_Item__c oi2 = New Order_Item__c(asset__c = ass2.id, status__c = 'Pending De-Installation',
                                              total_rooms_ordered__c = 600, total_remaining_rooms__c = 600, Name = 'Testoi2', parent__c = oiparent.id);
        List<Order_Item__c> insertoi = New List<Order_Item__c>();
        insertoi.add(oi1);
        insertoi.add(oi2);
        insert insertoi;
        
        //Create the work order that is needed by the associated items
        Work_Order__c wo = new Work_Order__c(RecordTypeId = workOrderRecordType, site__c = acc.Id, install_manager__c = uid,
	                                               approver__c = uid, Division__c = 'Domestic', Region__c = 'Southwest', project_coordinator__c = uid,
	                                               ownerid = uid, approval_status__c = 'Pending Billing Approval');
        insert wo;
        
        //create the associated items
        Associated_Item__c ai1 = New Associated_Item__c(order_item__c = oi1.id, work_order__c = wo.id, 
                                                        Name = 'Testai1', quantity__c = 100);
        Associated_Item__c ai2 = New Associated_Item__c(order_item__c = oi2.id, work_order__c = wo.id,
                                                        Name = 'Testai2', quantity__c = 100);
        Test.startTest();
          insert new List<Associated_Item__c>{ai1, ai2};  //jjackson put this inside the test because SOQL limitations were being exceeded
                //Update Associated Item fields and set Work Order to complete
            List<Associated_Item__c> lstassocitm = [ Select Id, Status__c, Name, Quantity__c from Associated_Item__c];
            List<Associated_Item__c> lstupdaitem = new List<Associated_Item__c>();
            for(Associated_Item__c recai : lstassocitm )
            {
            	if(recai.Name == 'Testai1')
            	{
            		recai.Quantity__c = 500;
            		recai.Status__c = 'Billing';
                    recai.billing_commencement_date__c = system.today();
                    recai.flagged_for_billing__c = true;
            		lstupdaitem.add(recai);
            	}
            	if(recai.Name == 'Testai2')
            	{
            		recai.Quantity__c = 600;
            		recai.Status__c = 'De-Installed';
                    recai.billing_commencement_date__c = system.today();
                    recai.flagged_for_billing__c = true;
            		lstupdaitem.add(recai);
            	}
            		
            }
 
            update lstupdaitem;
            wo.Approval_Status__c = 'Billing Approved';
            wo.status__c = 'Billing/Go Live';
            wo.billing_approval_needed__c = true;
            update wo;
        
            Test.stopTest();
            //Assert Part Activation with type Activation is inserted on Asset
            //Assert Field updates went to Order Item
            List<Product_Activation__c> paList = [SELECT id, associated_item__c from Product_Activation__c ];
            system.debug('paList size is ' +paList.size());
            //system.debug('testProductActivationBillingAfterInstall Test . There should be one Product Activation, there are : '+paList.size());
            //system.assert(paList.size() > 0, 'There should be two Product Activations, there are : '+paList.size());
            //jjackson Do one select statement for order items and loop through
            List<Order_Item__c> lstoi = [Select Id, Status__c, Name from Order_Item__c ];
   
            //jjackson Order item status is changing to same status as associated item due to new code on the associated item trigger logic
            for(Order_Item__c oi : lstoi)
            {
            	system.debug('order item after ai update is ' + oi);
            	if(oi.Name == 'Testoi1' )
            	{
            		//System.debug(LoggingLevel.DEBUG,'WorkOrderTriggerLogicTest testProductActivationBillingAfterInstall Test .  **********Status should be Billing, is: '+oi.Status__c);
                    system.assert(oi.Status__c == 'Installed Activated', 'Status should be Installed Activated, is: '+oi.Status__c);
            	}
            	if(oi.Name == 'Testoi2')
            	{
            		//System.debug(LoggingLevel.DEBUG,'WorkOrderTriggerLogicTest testProductActivationBillingAfterInstall Test .  ********** Status should be De-Installed, is: '+oi.Status__c);
                    system.assert(oi.Status__c == 'De-Installed', 'Status should be De-Installed, is: '+oi.Status__c);
            	}
            }
  
            Asset updass2 = [SELECT Status from Asset WHERE Name = 'Test Asset2 Deinstall' LIMIT 1];
            //System.debug('testProductActivationBillingAfterInstall Test.  Asset status should be Pending De-Installation, is :'+updass2.Status);
            system.assert(updass2.Status == 'De-Installed', 'Asset status should be De-Installed, is :'+updass2.Status);
                    
    } //end testProductActivationBillingAfterInstall
    
 
}