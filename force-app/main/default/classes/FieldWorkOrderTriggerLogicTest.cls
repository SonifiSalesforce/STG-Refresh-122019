@isTest
public with sharing class FieldWorkOrderTriggerLogicTest {
	
	static testmethod void PopulateWorkOrderExceptionsAndEvents()
	{
		system.debug('Begin Test PopulateWorkOrderExceptionsAndEvents');
		
		Account a = DataGenerator.createAccounts(1, true)[0];
		Account suppAcc = DataGenerator.createAccounts(1, true)[0];
		
		Id supportOfficeId = Account.SObjectType.getDescribe().getRecordTypeInfosByName().get('Support Office').getRecordTypeId();
		suppAcc.RecordTypeId = supportOfficeId;
		update suppAcc;
		a.Support_Office__c = suppAcc.Id;
		a.Service_Contract_Exceptions__c = 'Test Exception';
		update a;
		
		Case case1 = (Case) DataGenerator.createSObjectWithDefaultValues('Case');
		case1.AccountId = a.Id;
		case1.Support_Office__c = suppAcc.Id;
		case1.Dispatched__c = true;
		case1.Status='Open';
		case1.Subject = 'Test Subject';
		case1.Priority = 'Low';
		case1.Origin = 'Customer Incoming Call';
		case1.Customer_Name__c = 'Joe Blow';
		case1.Customer_Role__c = 'Engineering';
		case1.Case_Product_Type__c = 'Interactive';
		case1.Issue_Type__c = 'Mobile';
		case1.Issue_Sub_Type__c = 'Content';
		case1.Issue_Details__c = 'Multi Lingual';
		case1.Issue_Details_Description__c = 'Testing Description';
		upsert case1;
		
		Case suppcase = CreateTestRecords.DefaultSupportCase();
		Date start = system.today();
    	Date done = system.today().addmonths(3);
    	ServiceContract sc = New ServiceContract(Name='TestWarranty', accountid=suppcase.accountid,
    	                     startdate=start, enddate=done);
    	insert sc;
    	Entitlement ent = New Entitlement(Name = 'TestTPEntitlement', accountid = suppcase.accountid,
    	startdate=start, enddate=done, servicecontractid=sc.id);
    	insert ent;
    	suppcase.entitlementid = ent.id;
    	suppcase.service_contract_name__c = sc.id;
    	update suppcase;
    	
    	ThirdPartyEntitlementName__c setting = New ThirdPartyEntitlementName__c();
    	setting.Name='TestTPEntitlement';
    	setting.ThirdPartySiteId__c = '0099887';
    	insert setting;
	
		WorkOrder wo = New WorkOrder(Date__c = system.Now(), Accountid = a.id, caseid = case1.id, status='New', invoice_summary__c = 'Work Completed.',
	                             Signature_Name__c = 'Joan Jackson', Customer_Email__c = 'jjackson@sonifi.com', signature_date__c = system.Now(),
	                             submit_for_billing__c = false, customer_title__c = 'GM');
	    insert wo;
	    
	    WorkOrder fwo = New WorkOrder(Date__c = system.Now(), Accountid = suppcase.accountid, caseid = suppcase.id, status = 'New');
	    insert fwo;
    	
    	test.StartTest();
    	
    	WorkOrder getwo = [ Select Id, workordernumber, priority, case_issue_type__c, subject, service_contract_exceptions__c from
    	                    WorkOrder where id = :wo.id LIMIT 1 ];
    	                    
    	List<FieldWorkOrder_Events__c> listevents = New List<FieldWorkOrder_Events__c>();
    	listevents = [ Select Id, Field_Work_Order__c, event_name__c from FieldWorkOrder_Events__c where Field_Work_Order__c = :wo.id ];
    	
    	Id tpfwoid = Utilities.RecordTypeNameToId('WorkOrder', 'Third Party FWO');
    	system.debug('third party fwo rectypeid is ' +tpfwoid);
    	
    	WorkOrder newwo = [ Select Id, entitlementid, entitlement.name, servicecontractid, servicecontract.name, recordtypeid, caseid from WorkOrder where caseid = :suppcase.id LIMIT 1];
    	system.debug('newwo entitlement name is ' +newwo.entitlement.name);
    	system.debug('newwo service contract is ' +newwo.servicecontract.name);
    	system.debug('newwo recordtypeid is ' +newwo.recordtypeid);
    	
    	test.StopTest();
    	
    	system.assert(listevents.size() == 2);
    	system.assert(getwo.service_contract_exceptions__c == 'Test Exception');
    	system.debug(getwo.subject == 'Test Subject');
		
	}//end testPopulateWorkOrderExceptionsAndEvents
	
	//this test also covers the CreateFieldWorkOrderEvents method in the trigger logic
	static testmethod void testPopulateTech()
	{
		Account newacc = CreateTestRecords.DefaultHospitalityAccount();
		newacc.Service_Contract_Exceptions__c = 'Test Exception';
		update newacc;
		
		Id suppcaseid = Utilities.RecordTypeNametoId('Case', 'Support Case');
		Id fwoid = Utilities.RecordTypeNametoId('WorkOrder', 'FWO');
		
		Case suppcase = New Case(Subject='Test Subject', accountid=newacc.id, status='Open', priority='Low',
		                        Origin='Customer Incoming Call', recordtypeid=suppcaseid,
		                        case_product_type__c = 'Interactive', Issue_Type__c = 'Connectivity',
		                        Issue_Sub_Type__c = 'Circuit', Issue_Details__c = 'Circuit - Hotel',
		                        Customer_Name__c = 'Joe Blow', Customer_Role__c = 'Engineer');
		insert suppcase;
		
		
	
		WorkOrder wo = New WorkOrder(Date__c = system.Now(), Accountid = newacc.id, caseid = suppcase.id, status='New', invoice_summary__c = 'Work Completed.',
	                             Signature_Name__c = 'Joan Jackson', Customer_Email__c = 'jjackson@sonifi.com', signature_date__c = system.Now(), recordtypeid = fwoid,
	                             submit_for_billing__c = false, customer_title__c = 'GM');
    	insert wo;
    	
    	test.StartTest();
    	
    	wo.submit_for_billing__c = true;
    	update wo;
    	
    	WorkOrder getwo = [ Select Id, workordernumber, priority, case_issue_type__c, subject, service_contract_exceptions__c, ownerid,
    	                    submit_for_billing__c, technician__c from
    	                    WorkOrder where accountid = :newacc.id LIMIT 1 ];
    	                    
    	List<FieldWorkOrder_Events__c> listfwoe = [ Select Id, event_type__c, field_work_order__c, event_name__c from
    	                                           FieldWorkOrder_Events__c where field_work_order__c = :getwo.id ];
    	
    	    	
    	test.StopTest();
    	
    	system.assert(getwo.technician__c != null);
    	system.assert(listfwoe.size() == 2);
    	
	}//end testPopulateTech
	
	//Note:  There is no separate test method for the approval process because when the submit for billing box is checked on
	//these work orders, that code runs and is covered.
	static testmethod void testTripAndLabor()
	{
		Account a = DataGenerator.createAccounts(1, true)[0];
		Account suppAcc = DataGenerator.createAccounts(1, true)[0];
		Account hca = DataGenerator.createAccounts(1, true)[0];
		Account thirdpartyacc = DataGenerator.CreateAccounts(1,true)[0];
		Account partner = DataGenerator.CreateAccounts(1,true)[0];
		
		Id hcrectype = Utilities.RecordTypeNameToId('Account', 'Healthcare Site');
		Id tpcontracted = Utilities.RecordTypeNameToId('Account', 'Third Party Contracted Service');
		Id tppartner = Utilities.RecordTypeNametoId('Account', 'Third Party');
		Id cfscaseid = Utilities.RecordTypeNametoId('Case', 'Contracted Field Service');
		
		
		Id supportOfficeId = Account.SObjectType.getDescribe().getRecordTypeInfosByName().get('Support Office').getRecordTypeId();
		suppAcc.RecordTypeId = supportOfficeId;
		upsert suppAcc;
		a.Support_Office__c = suppAcc.Id;
		a.Service_Contract_Exceptions__c = 'Test Exception';
		a.physical_state__c = 'SD';
		upsert a;
		hca.recordtypeid = hcrectype;
		hca.physical_state__c = 'SD';
		hca.support_office__c = suppAcc.Id;
		upsert hca;
		partner.recordtypeid = tppartner;
		upsert partner;
		thirdpartyacc.recordtypeid = tpcontracted;
		upsert thirdpartyacc;
		
		Account_Third_Party_Partner__c atpp = New Account_Third_Party_Partner__c(Related_Account__c = thirdpartyacc.id, 
		                                          Third_Party_Partner_Account__c = partner.id);
		insert atpp;
		
		
		
		
		Asset a1 = New Asset(accountid = a.id, Name = 'Interactive Product Parent', status = 'Installed Activated', quantity = 100);
		Asset a2 = New Asset(accountid = hca.id, Name = 'FTG Product Parent', status = 'Installed Activated', quantity = 100);
		List<Asset> lstasset = New List<Asset>();
		lstasset.add(a1);
		lstasset.add(a2);
		insert lstasset;
		
		Product2 p1 = New Product2(productcode = '40-0001-058-0', Name = 'LABOR, FS, HEALTHCARE', IsActive = true);
		Product2 p2 = New Product2(productcode = '40-0001-057-0', Name = 'TRIP CHARGE, FS, HEALTHCARE', IsActive = true);
		Product2 p3 = New Product2(productcode = '40-0001-009-0', Name = 'LABOR, FS, iTV/FTG', IsActive = true);
		Product2 p4 = New Product2(productcode = '40-0001-036-0', Name = 'TRIP CHARGE, FS, iTV/FTG', IsActive = true);
		Product2 p5 = New Product2(productcode = '40-0001-132-0', Name = 'LABOR, ITV NON-CHARGEABLE', IsActive = true);
		Product2 p6 = New Product2(productcode = '40-0001-133-0', Name = 'LABOR, HEALTHCARE NON-CHARGEABLE', IsActive = true);
		Product2 p7 = New Product2(productcode = '40-0001-142-0', Name = 'LABOR, THIRD PARTY', IsActive = true);
		Product2 p8 = New Product2(productcode = '40-0001-143-0', Name = 'TRIP, THIRD PARTY', IsActive = true);
		
		List<Product2> newpartslist = New List<Product2>();
		newpartslist.add(p1);
		newpartslist.add(p2);
		newpartslist.add(p3);
		newpartslist.add(p4);
		newpartslist.add(p5);
		newpartslist.add(p6);
		newpartslist.add(p7);
		newpartslist.add(p8);
			
		insert newpartslist;
		
		List<Case> lstcase = New List<Case>();
		
		Case case1 = (Case) DataGenerator.createSObjectWithDefaultValues('Case');
		case1.AccountId = a.Id;
		case1.Support_Office__c = suppAcc.Id;
		case1.Dispatched__c = true;
		case1.Status='Open';
		case1.Subject = 'Test Subject';
		case1.Priority = 'Low';
		case1.Origin = 'Customer Incoming Call';
		case1.Case_Product_Type__c = 'Interactive';
		case1.Customer_Name__c = 'Joe Blow';
		case1.Customer_Role__c = 'Engineering';
		case1.Issue_Type__c = 'Mobile';
		case1.Issue_Sub_Type__c = 'Content';
		case1.Issue_Details__c = 'Multi Lingual';
		case1.Issue_Details_Description__c = 'Testing Description';
		case1.Assetid = a1.id;
		lstcase.add(case1);
		
		Case case2 = (Case) DataGenerator.createSObjectWithDefaultValues('Case');
		case2.AccountId = hca.Id;
		case2.Support_Office__c = suppAcc.Id;
		case2.Dispatched__c = true;
		case2.Status='Open';
		case2.Subject = 'Test Healthcare Subject';
		case2.Priority = 'Low';
		case2.Origin = 'Customer Incoming Call';
		case2.Customer_Name__c = 'Joe Blow';
		case2.Customer_Role__c = 'Engineering';
		case2.Case_Product_Type__c = 'FTG';
		case2.Issue_Type__c = 'Hardware - FTG';
		case2.Issue_Sub_Type__c = 'Rack - FTG';
		case2.Issue_Details__c = 'Combiner';
		case2.Issue_Details_Description__c = 'Testing HC Description';
		case2.Assetid = a2.id;
		lstcase.add(case2);
		
		Case case3 = (Case) DataGenerator.createSObjectWithDefaultValues('Case');
		case3.AccountId = a.Id;
		case3.Support_Office__c = suppAcc.Id;
		case3.Dispatched__c = true;
		case3.Status='Open';
		case3.Subject = 'Test Not Contracted Subject';
		case3.Priority = 'Low';
		case3.Origin = 'Customer Incoming Call';
		case3.Case_Product_Type__c = 'FTG';
		case3.Customer_Name__c = 'Joe Blow';
		case3.Customer_Role__c = 'Engineering';
		case3.Issue_Type__c = 'Hardware - FTG';
		case3.Issue_Sub_Type__c = 'Rack - FTG';
		case3.Issue_Details__c = 'Combiner';
		case3.Issue_Details_Description__c = 'Testing Non-Contracted Description';
		lstcase.add(case3);
		
		Case case4 = (Case) DataGenerator.createSObjectWithDefaultValues('Case');
		case4.AccountId = thirdpartyacc.id;
		case4.Dispatched__c = false;
		case4.Status = 'Open';
		case4.Subject = 'Test Contracted Field Service Case';
		case4.recordtypeid = cfscaseid;
		case4.priority = 'Low';
		case4.origin = 'Third Party Field Service';
		case4.case_product_type__c = 'Interactive';
		case4.issue_type__c = 'Hardware';
		case4.issue_sub_type__c = 'DCR/Catcher';
		case4.issue_details__c = 'Bad LNB DCR/Catcher';
		case4.third_party_partner__c = atpp.id;
		case4.partner_ticket_number__c = '12344556';
		lstcase.add(case4);
		insert lstcase;
		
		
		
	
		WorkOrder wo1 = New WorkOrder(Date__c = system.Now(), Accountid = a.id, caseid = case1.id, status='New', invoice_summary__c = 'Work Completed.',
	                             Signature_Name__c = 'Joan Jackson', Customer_Email__c = 'jjackson@sonifi.com', signature_date__c = system.Now(),
	                             submit_for_billing__c = false, customer_title__c = 'GM');
 
    	WorkOrder wo2 = New WorkOrder(Date__c = system.Now(), Accountid = hca.id, caseid = case2.id, status='New', invoice_summary__c = 'Healthcare Work Completed.',
	                             Signature_Name__c = 'Joan Jackson', Customer_Email__c = 'jjackson@sonifi.com', signature_date__c = system.Now(),
	                             submit_for_billing__c = false, customer_title__c = 'GM');
	
		WorkOrder wo3 = New WorkOrder(Date__c = system.Now(), Accountid = a.id, caseid = case3.id, status='New', invoice_summary__c = 'NonContracted Work Completed.',
	                             Signature_Name__c = 'Joan Jackson', Customer_Email__c = 'jjackson@sonifi.com', signature_date__c = system.Now(),
	                             submit_for_billing__c = false, customer_title__c = 'GM');
	                             
	    WorkOrder wo4 = New WorkOrder(Date__c = system.Now(), Accountid = thirdpartyacc.id, caseid = case4.id, status='New', invoice_summary__c = 'Contracted Field Service Work.',
	                             Signature_Name__c = 'Joan Jackson', Customer_Email__c = 'jjackson@sonifi.com', signature_date__c = system.Now(),
	                             submit_for_billing__c = false, customer_title__c = 'GM');
	
	   	test.StartTest();
    	List<WorkOrder> lstwo = New List<WorkOrder>();
    	lstwo.add(wo1);
    	lstwo.add(wo2);
    	lstwo.add(wo3);
    	lstwo.add(wo4);
    	insert lstwo;
    	
 
    	List<WorkOrder> wolist = [Select Id, workordernumber, submit_for_billing__c, case_product_type__c from WorkOrder ];
    	List<WorkOrder> updwo = New List<WorkOrder>();
    	
    	for(WorkOrder wo : wolist)
    	{
    		wo.submit_for_billing__c = true;
    		updwo.add(wo);
    	}
    	
    	update updwo;
    	
    	List<WorkOrderLineItem> lstlines = New List<WorkOrderLineItem>();
    	lstlines = [Select Id, qty__c, product_code__c, part_number__c, workorderid from WorkOrderLineItem where workorderid in :wolist ];
    	test.StopTest();
    	
    	system.debug('lstlines size is ' +lstlines.size());
    	//system.assert(lstlines.size() == 9);
    	
    	
	}
	
	static testmethod void LinkAssociatedItemsTest()
	{
		Account a = CreateTestRecords.DefaultHospitalityAccount();
		Id uid = UserInfo.getUserId();
		Id workOrderRecordType = Utilities.RecordTypeNametoId('Work_Order__c', 'Install');
		
		Work_Order__c wo = new Work_Order__c(RecordTypeId = workOrderRecordType, site__c = a.Id, install_manager__c = uid,
	                                               approver__c = uid, Division__c = 'Domestic', Region__c = 'Southwest', project_coordinator__c = uid,
	                                               ownerid = uid, status__c = 'Scheduled');
        insert wo;
        
        Order__c o = CreateTestRecords.DefaultOrder(a.id);
        
        List<Order_Item__c> oilist = New List<Order_Item__c>();
        
        
        Order_Item__c oi1 = New Order_Item__c(Name='FTG Product Parent', status__c = 'Pending Installation Activate', Account__c = a.id, 
                            order__c = o.id);
        oilist.add(oi1);
                            
        Order_Item__c oi2 = New Order_Item__c(Name='Interactive Product Parent', status__c = 'Pending Installation Activate', Account__c = a.id, 
                            order__c = o.id);
        oilist.add(oi2);
                            
        Order_Item__c oi3 = New Order_Item__c(Name='BYOD Product Parent', status__c = 'Pending Installation Activate', Account__c = a.id, 
                            order__c = o.id);
        oilist.add(oi3);
                            
        Order_Item__c oi4 = New Order_Item__c(Name='Broadband Product Parent', status__c = 'Pending Installation Activate', Account__c = a.id, 
                            order__c = o.id);
        oilist.add(oi4);
                            
        Order_Item__c oi5 = New Order_Item__c(Name='Public Viewing Product Parent', status__c = 'Pending Installation Activate', Account__c = a.id, 
                            order__c = o.id);
        oilist.add(oi5);
                            
        Order_Item__c oi6 = New Order_Item__c(Name='DRE Product Parent', status__c = 'Pending Installation Activate', Account__c = a.id, 
                            order__c = o.id);
        oilist.add(oi6);
        
        //insert the new order items, then we can create associated items
        insert oilist;
        
        //create the associated items
        List<Associated_Item__c> ailist = New List<Associated_Item__c>();
        Associated_Item__c ai1 = New Associated_Item__c(order_item__c = oi1.id, work_order__c = wo.id, flagged_for_billing__c = true, Status__c = 'Pending Installation Activate',
                                                        Name = 'FTG Product Parent', quantity__c = 100);
        ailist.add(ai1);
                                                        
        Associated_Item__c ai2 = New Associated_Item__c(order_item__c = oi2.id, work_order__c = wo.id, flagged_for_billing__c = true, Status__c = 'Pending Installation Activate',
                                                        Name = 'Interactive Product Parent', quantity__c = 100);
        ailist.add(ai2);                                                
                                                        
         Associated_Item__c ai3 = New Associated_Item__c(order_item__c = oi3.id, work_order__c = wo.id, flagged_for_billing__c = true, Status__c = 'Pending Installation Activate',
                                                        Name = 'BYOD Product Parent', quantity__c = 100);
         ailist.add(ai3);                                                   
                                                             
         Associated_Item__c ai4 = New Associated_Item__c(order_item__c = oi4.id, work_order__c = wo.id, flagged_for_billing__c = true, Status__c = 'Pending Installation Activate',
                                                        Name = 'Broadband Product Parent', quantity__c = 100);
         ailist.add(ai4);                                               
                                                        
         Associated_Item__c ai5 = New Associated_Item__c(order_item__c = oi5.id, work_order__c = wo.id, flagged_for_billing__c = true, Status__c = 'Pending Installation Activate',
                                                        Name = 'Public Viewing Product Parent', quantity__c = 100);
         ailist.add(ai5);  
                                                        
         Associated_Item__c ai6 = New Associated_Item__c(order_item__c = oi6.id, work_order__c = wo.id, flagged_for_billing__c = true, Status__c = 'Pending Installation Activate',
                                                        Name = 'DRE Product Parent', quantity__c = 100);
         ailist.add(ai6);     
         
         insert ailist; 
         
         //add records to the custom setting Product Parent Usage so the test can see them
         List<Product_Parent_Usage__c> pulist = New List<Product_Parent_Usage__c>();
         Product_Parent_Usage__c pu1 = New Product_Parent_Usage__c(Name = 'Broadband Product Parent', WO_Name_Abbrev__c = 'GIA', Usage__c = 'GIA' );
         Product_Parent_Usage__c pu2 = New Product_Parent_Usage__c(Name = 'BYOD Product Parent', WO_Name_Abbrev__c = 'BYOD', Usage__c = 'BYOD' );  
         Product_Parent_Usage__c pu3 = New Product_Parent_Usage__c(Name = 'DRE Product Parent', WO_Name_Abbrev__c = 'DRE', Usage__c = 'DRE' );    
         Product_Parent_Usage__c pu4 = New Product_Parent_Usage__c(Name = 'FTG Product Parent', WO_Name_Abbrev__c = 'FTG', Usage__c = 'FTG' );   
         Product_Parent_Usage__c pu5 = New Product_Parent_Usage__c(Name = 'Interactive Product Parent', WO_Name_Abbrev__c = 'Interactive', Usage__c = 'iTV' ); 
         Product_Parent_Usage__c pu6 = New Product_Parent_Usage__c(Name = 'Public Viewing Product Parent', WO_Name_Abbrev__c = 'PV', Usage__c = 'PV' );
         pulist.add(pu1);  
         pulist.add(pu2);
         pulist.add(pu3);
         pulist.add(pu4);
         pulist.add(pu5);
         pulist.add(pu6);
         insert pulist; 
         
         test.startTest();
         
         Id recid = Utilities.RecordTypeNametoId('WorkOrder', 'Install');
         WorkOrder w = New WorkOrder(recordtypeid = recid, status='New', Accountid = a.id, Sonifi_Work_Order__c = wo.id);
         insert w;
         
         w.Interactive__c = true;
         w.FTG__c = true;
         w.DRE__c = true;
         w.GIA__c = true;
         w.BYOD__c = true;
         w.PV__c = true;
         
         update w;
         
         List<Associated_Item__c> lstgetai = New List<Associated_Item__c>();
         lstgetai = [Select Id, workorder__c from associated_Item__c where workorder__c = :w.id];
         system.assert(lstgetai.size() == 6);
         
         w.Interactive__c = false;
         w.FTG__c = false;
         w.DRE__c = false;
         w.GIA__c = false;
         w.BYOD__c = false;
         w.PV__c = false;
         
         update w;
         
         List<Associated_Item__c> lstgetai2 = New List<Associated_Item__c>();
         lstgetai2 = [Select Id, workorder__c from associated_item__c where workorder__c = :w.id];
         system.assert(lstgetai2.size() == 0);
         
         test.stopTest();
         
                                                                                                                       
	}//end LinkAssociatedItemsTest
	
	static testmethod void testAssignRecTypes()
	{
		Case c = CreateTestRecords.DefaultSupportCase();

		Id acctrectype = Utilities.RecordTypeNameToId('Account', 'Hospitality Site');
		
		Account acc = New Account(Name = 'Test Hotel Account2', Type = 'Hotel Site', recordtypeid = acctrectype,
		                         account_status__c = 'Active', Major_Account_Flag__c='None', phone = '1234567891',
		                         fax = '5556667777', physical_street_address_line_1__c = '2224 Testing Street',
		                         physical_city__c = 'Sioux Falls', physical_state__c = 'SD',
		                         physical_postal_code__c = '57104', Time_Zone__c = 'America/Chicago',
		                         of_rooms__c = 100);
				
		Account tpacc = CreateTestRecords.DefaultThirdPartyContractedAccount();
		Account tppacc = CreateTestRecords.DefaultThirdPartyAccount();
		Account_Third_Party_Partner__c tpp = CreateTestRecords.LinkAccountToPartner(tpacc.id, tppacc.id);
				
		Case tpcase = CreateTestRecords.DefaultContractedFieldServiceCase(tpacc.id, tpp.id);
		
		Work_Order__c swo = CreateTestRecords.DefaultInstallWorkOrder(acc.id);
		
		WorkOrder fwo = New Workorder(caseid = c.id, date__c = system.today());
		
		WorkOrder tpfwo = New WorkOrder(caseid = tpcase.id, date__c = system.today());
		
		WorkOrder installwo = New WorkOrder(Sonifi_Work_Order__c = swo.id, date__c = system.today());
		
		
		test.startTest();
		
			insert fwo;
			
			WorkOrder getfwo = [ Select caseid, recordtype.name from WorkOrder where caseid = :c.id ];
			system.assert(getfwo.recordtype.name == 'FWO');
			
			insert tpfwo;
			
			WorkOrder gettpfwo = [Select caseid, recordtype.name from WorkOrder where caseid = :tpcase.id];
			system.assert(gettpfwo.recordtype.name == 'Third Party FWO');
			
			insert installwo;
			WorkOrder newinstallwo = [Select sonifi_work_order__c, recordtype.name from WorkOrder where 
			                          sonifi_work_order__c = :swo.id];
			system.assert(newinstallwo.recordtype.name == 'Install');
			
			
			
		test.stopTest();
	}

	static testmethod void DeploymentWorkOrderTest()
	{
		Account acc = CreateTestRecords.DefaultHospitalityAccount();
		Work_Order__c installwo = CreateTestRecords.DefaultInstallWorkOrder(acc.id);
		WorkOrder fieldwo = New WorkOrder(sonifi_work_order__c = installwo.id);
		insert fieldwo;

		test.startTest();

		WorkOrder getwo = [Select id, workordernumber, accountid, recordtype.name from WorkOrder LIMIT 1];
		system.assert(getwo.accountid == acc.id);
		system.assert(getwo.recordtype.name == 'Install');

		test.stopTest();

	}
	
	static testmethod void SiteSurveyWorkOrderTest()
	{
		//Insert custom setting record for FSL_RecordType_WorkType__c
		FSL_RecordType_WorkType__c rec_rtwt = new FSL_RecordType_WorkType__c();
		rec_rtwt.name = 'Site Survey';
		rec_rtwt.WorkTypeName__c = 'Site Survey';
		insert rec_rtwt;

		//Insert Work Type records
		List<WorkType> lstwt_insert = new List<WorkType>();
		WorkType rec_wt_01 = new WorkType(name = 'Site Survey', DurationType = 'Hours', EstimatedDuration = 7.00);
		WorkType rec_wt_02 = new WorkType(name = 'Site Survey Desktop', DurationType = 'Hours', EstimatedDuration = 4.00);
		lstwt_insert.add(rec_wt_01);
		lstwt_insert.add(rec_wt_02);
		insert lstwt_insert;

		Account acct = CreateTestRecords.DefaultHospitalityAccount();
		Id surveyrec = Utilities.RecordTypeNametoId('Site_Survey__c', 'Site Survey');
		Site_Survey__c ss = New Site_Survey__c(site__c = acct.id, recordtypeid = surveyrec, status__c = 'Not Started');
		insert ss;

		test.startTest();
		WorkOrder sswo = New WorkOrder(accountid = acct.id, site_survey__c = ss.id);
		insert sswo;

		WorkOrder getfwo = [Select Id, recordtype.name, accountid, subject, street, duration from workorder LIMIT 1  ];
		test.stopTest();

		system.assert(getfwo.recordtype.name == 'Site Survey Work Order');
		system.assertEquals(getfwo.duration, 7.00);  //Verify correct Work Type was used
		system.assert(getfwo.subject.contains('Site Survey'));
	}
}//end FieldWorkOrderTriggerLogicTest