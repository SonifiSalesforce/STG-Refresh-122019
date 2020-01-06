@isTest
private class StandardAssetTriggerLogicTests {

    static testMethod void updateContractLineItem() {
    	//create test data
        Account acc = new Account(Name='test aCC');
        insert acc;
    
        //shawks 20180928: CPQ - update to use out-of-box object Contract instead of Contract__c; replace Account_Name__c with AccountId
        //Contract__c con = new Contract__c(Account_Name__c = acc.id);
        Contract con = new Contract(AccountId = acc.id);
        insert con;
        
        Product2 p1 = new Product2(Name= 'Test product1');
        Product2 p2 = New Product2(Name='Test Product2');
        insert p1;
        insert p2;
        
        //shawks 20180928: CPQ - update to use CPQ object SBQQ__Subscription__c instead of Contract_Line_Item__c; replace Legal_Contract__c with SBQQ__Contract__c
        //-> replace: Name -> Name__c; quantiy__c -> SBQQ__Quantity__c; product__c -> SBQQ__Product__c
        //Contract_Line_Item__c cli1 = new Contract_Line_Item__c(Name = 'Test cli', Legal_Contract__c = con.id, quantity__c = 10, product__c=p1.id);
        //SBQQ__Subscription__c cli1 = new SBQQ__Subscription__c(SBQQ__Account__c = 'Test cli', SBQQ__Contract__c = con.id, SBQQ__Quantity__c = 10, SBQQ__Product__c=p1.id);
        SBQQ__Subscription__c cli1 = new SBQQ__Subscription__c(Name__c = 'Test cli', SBQQ__Contract__c = con.id, SBQQ__Quantity__c = 10, SBQQ__Product__c=p1.id);
        //insert cli1;
        
        //Contract_Line_Item__c cli2 = new Contract_Line_Item__c(Name = 'Test cli 2', Legal_Contract__c = con.id, quantity__c = 10, product__c=p2.id);
        SBQQ__Subscription__c cli2 = new SBQQ__Subscription__c(Name__c = 'Test cli 2', SBQQ__Contract__c = con.id, SBQQ__Quantity__c = 10, SBQQ__Product__c=p2.id);
        //insert cli2;
        //jjackson do one insert for contract line items
        insert new list<SBQQ__Subscription__c>{cli1,cli2};
        
        //shawks 20180928: CPQ - Replace Legal_Contract_Line_Item__c with Subscription__c
        //Asset a1 = new Asset(Legal_Contract_Line_Item__c = cli1.id, name = 'test asset', AccountId = acc.id, Status = 'Billing', Term_Start_Date__c = date.newInstance(2013, 1, 1),Term__c=12, Manually_Override_Term_End_Date__c = false);
        //Asset a2 = new Asset(Legal_Contract_Line_Item__c = cli2.id, name = 'test asset 2', AccountId = acc.id,Term_Start_Date__c = date.newInstance(2013, 12, 31),Term__c=48, Manually_Override_Term_End_Date__c = false);
        Asset a1 = new Asset(Subscription_item__c = cli1.id, name = 'test asset', AccountId = acc.id, Status = 'Billing', Term_Start_Date__c = date.newInstance(2013, 1, 1),Term__c=12, Manually_Override_Term_End_Date__c = false);
        Asset a2 = new Asset(Subscription_item__c = cli2.id, name = 'test asset 2', AccountId = acc.id,Term_Start_Date__c = date.newInstance(2013, 12, 31),Term__c=48, Manually_Override_Term_End_Date__c = false);
        insert a2;
        a2.Status = 'Billing';
        a1.Status = 'Installed Activated';
        
        //start test
        Test.StartTest();
        insert a1;
        
        update new list<Asset>{a1, a2};
        
        Test.stopTest();
        
        //requery the results
        //shawks 20180928: CPQ - update to use CPQ object SBQQ__Subscription__c instead of Contract_Line_Item__c
        //List<Contract_Line_Item__c> cliList = [SELECT id, Status__c FROM Contract_Line_Item__c ];
        List<SBQQ__Subscription__c> cliList = [SELECT id, Status__c FROM SBQQ__Subscription__c ];
        
        //assertions
        System.assertEquals('Installed Activated', cliList[0].Status__c);
        System.assertEquals('Billing', cliList[1].Status__c);
    }
    
    //jjackson 8/2016 this code commented out of the trigger logic, so also taking away the unit test
    
   /* static testMethod void updateEndDates() {
    	//create test data
        Account acc = new Account(Name='test aCC');
        insert acc;
    
        Contract__c con = new Contract__c(Account_Name__c = acc.id);
        insert con;
        
        Contract_Line_Item__c cli1 = new Contract_Line_Item__c(Name = 'Test cli', Legal_Contract__c = con.id, quantity__c = 10);
        insert cli1;
        
        Contract_Line_Item__c cli2 = new Contract_Line_Item__c(Name = 'Test cli 2', Legal_Contract__c = con.id, quantity__c = 10);
        insert cli2;
        
        List<Asset> assets = new List<Asset>();
        
        assets.add(new Asset(Legal_Contract_Line_Item__c = cli1.id, name = 'test asset', AccountId = acc.id, Status = 'Billing', Term_Start_Date__c = date.newInstance(2013, 1, 1),Term__c=12, Manually_Override_Term_End_Date__c = false));
        
        assets.add(new Asset(Legal_Contract_Line_Item__c = cli2.id, name = 'test asset 2', AccountId = acc.id,Term_Start_Date__c = date.newInstance(2013, 12, 31),Term__c=48, Manually_Override_Term_End_Date__c = false));
        
        assets.add(new Asset(Legal_Contract_Line_Item__c = cli2.id, name = 'test asset 3', AccountId = acc.id,Term_Start_Date__c = date.newInstance(2013, 12, 31),Term__c=12, Term_End_Date__c = date.newInstance(2014, 1, 1), Manually_Override_Term_End_Date__c = true));
        
        assets.add(new Asset(Legal_Contract_Line_Item__c = cli2.id, name = 'test asset 4', AccountId = acc.id, Manually_Override_Term_End_Date__c = false));
        
        //start test
        Test.StartTest();
        insert assets;        
        Test.stopTest();
        
        //requery the results
        Asset asset1 = [SELECT Id, Term_End_Date__c FROM Asset WHERE ID = :assets[0].Id][0];
        Asset asset2 = [SELECT Id, Term_End_Date__c FROM Asset WHERE ID = :assets[1].Id][0];
        Asset asset3 = [SELECT Id, Term_End_Date__c FROM Asset WHERE ID = :assets[2].Id][0];
        Asset asset4 = [SELECT Id, Term_End_Date__c FROM Asset WHERE ID = :assets[3].Id][0];
        
        //assertions
        //System.assertEquals(date.newInstance(2014, 1, 1), asset1.Term_End_Date__c);
        //System.assertEquals(date.newInstance(2018, 1, 1),  asset2.Term_End_Date__c);
        //System.assertEquals(date.newInstance(2014, 1, 1),  asset3.Term_End_Date__c);
        //System.assertEquals(null,  asset4.Term_End_Date__c);
    }*/
    static testMethod void testRollupSummary()
    {
    	Account a = new Account(Name = 'TestAsset');
    	insert a;
        System.debug(LoggingLevel.DEBUG,'testRollupSummary start');
    	Product2 p0 = new Product2(Name = 'Test Productparent', Family = 'FTG'); 
    	//insert p0;
    	Product2 p1 = new Product2(Name = 'Test Producthd', Channel_Type__c = 'HD');
    	//insert p1;
    	Product2 p2 = new Product2(Name = 'Test Productanalog', Channel_Type__c = 'Analog');
    	//insert p2;
    	Product2 p3 = new Product2(Name = 'Test Productsd', Channel_Type__c = 'SD');
    	Product2 p4 = new Product2(Name = 'Local Programming Fee', productcode = 'CC-localprogramming', price_category__c = 'Locals Programming');
    	//insert p3;
    	//jjackson do one insert for products
    	try {insert new list<Product2>{p0,p1,p2,p3,p4}; }
    	catch(Exception e){
    		system.debug('Exception e inserting products: ' +e.getmessage());
    	}
     	Asset ass1 = new Asset(AccountId = a.Id, Name = 'Test Asset', Product2Id = p0.Id, Status = 'Installed Activated');
    	try {insert ass1; }
    	catch(Exception ex){
    		system.debug('Exception ex inserting ass1: ' +ex.getmessage());
    	}
     	Asset ass2 = new Asset(AccountId = a.Id, Name = 'Test Asset', Parent_Asset__c = ass1.Id, Product2Id = p1.Id, Status = 'Installed Activated', Product_Parent_Id__c = ass1.id);
    	Asset ass3 = new Asset(AccountId = a.Id, Name = 'Test Asset', Parent_Asset__c = ass1.Id, Product2Id = p2.Id, Status = 'Installed Activated', Product_Parent_Id__c = ass1.id);
    	Asset ass4 = new Asset(AccountId = a.Id, Name = 'Test Asset', Parent_Asset__c = ass1.Id, Product2Id = p3.Id, Status = 'Installed Activated', Product_Parent_Id__c = ass1.id);
    	Asset ass5 = new Asset(AccountId = a.Id, Name = 'Local Program Asset', Parent_Asset__c = ass1.Id, Product2Id = p4.Id, Status = 'Installed Activated', Product_Parent_Id__c = ass1.id,
    	                       quantity = 45, price__c = 5.00);
        Asset ass6 = new Asset(AccountId = a.Id, Name = 'Local Program Asset 2', Parent_Asset__c = ass1.Id, Product2Id = p4.Id, Status = 'Installed Activated', Product_Parent_Id__c = ass1.id,
                               quantity = 1, price__c = 100.00);	                       

    	Test.startTest();
       
    	//insert ass2;
		//insert ass3;
		//insert ass4;
		//jjackson 8/2014 do one insert
		try { insert new list<Asset>{ass2,ass3,ass4,ass5,ass6};  }
		catch(Exception b){
			system.debug('Exception b inserting child assets: ' + b.getmessage());
		}
		
		ass4.Status = 'Billing';
		try { update ass4;  }
		catch(Exception c){
			system.debug('Exception c updating ass4: ' + c.getmessage());
		}
    	Test.stopTest();
    	
    	//Asset getass1 = [SELECT HD_Channel_Count__c, SD_Channel_Count__c, Analog_Channel_Count__c from Asset WHERE Id = :ass1.Id][0];
    	//system.debug('channel count rollup is hd, sd, analog: ' +getass1.HD_Channel_Count__c +', ' +getass1.SD_Channel_Count__c + ', ' +getass1.Analog_Channel_Count__c);
    	//system.assert(getass1.HD_Channel_Count__c == 1, 'HD channel count is ' +getass1.HD_Channel_Count__c);
    	//system.assert(getass1.SD_Channel_Count__c == 1, 'SD Channel count is '+getass1.SD_Channel_Count__c);
    	//system.assert(getass1.Analog_Channel_Count__c == 1, 'Analog Channel count is '+getass1.Analog_Channel_Count__c);  
    }

    //???
    static testMethod void testsetEntitleServiceContrDates_StartEnd()
	{
	    system.debug('running test testsetEntitleServiceContrDates_StartEnd');
		//Create account
        Account acc = DataGenerator.createAccounts(1,true)[0];
		acc.of_Rooms__c = 100;
		acc.Physical_City__c = 'Sioux Falls';
		acc.Physical_State__c = 'SD';
		acc.Name = 'TestAccount';
		update acc;

		//Create user
        List<User> userlist = new List<User>();
		User newuser;
		userlist = DataGenerator.CreateUsers('System Administrator',1,true);
		for(User recuser : userlist)
		    {  newuser = recuser;   }

        //Create Products
        Product2 parentproduct01 = new Product2(Name='Test Product Parent 01', ProductCode='CC-testpp01');
		Product2 parentproduct02 = new Product2(Name='Test Product Parent 02', ProductCode='CC-testpp02');
        Product2 parentproduct03 = new Product2(Name='Test Product Parent 03', ProductCode='CC-testpp03');
		insert new List<Product2>{parentproduct01,parentproduct02,parentproduct03};

        //Create Assets
        Asset asset01 = new Asset(AccountId = acc.Id, Name = 'Test Asset 01 Product Parent', Product2Id = parentproduct01.Id, Status = 'Pending Installation Activate');
        Asset asset02 = new Asset(AccountId = acc.Id, Name = 'Test Asset 02 Product Parent', Product2Id = parentproduct02.Id, Status = 'Pending Installation Activate');
        Asset asset03 = new Asset(AccountId = acc.Id, Name = 'Test Asset 03 Product Parent', Product2Id = parentproduct03.Id, Status = 'Pending Installation Activate');
    	insert new List<Asset>{asset01, asset02, asset03};

        //Create Contract
		Contract recContract = new Contract(AccountId=acc.id,Contract_Status__c='Order Approved', initial_term__c = 60, upfront_subsidy__c = 100);
		insert recContract;

		Contract con = [ Select Id from Contract where Id = :recContract.Id LIMIT 1 ];
		Id conid = con.id;
			
		//Create subscriptions
        SBQQ__Subscription__c recSub01 = new SBQQ__Subscription__c(Name__c='Test Product Parent 01', SBQQ__Contract__c=conid, Project_Type__c='Interactive New Rooms',
		                                                            Status__c='Pending Installation Activate', SBQQ__Product__c=parentproduct01.id, SBQQ__Quantity__c = 100);
			
		SBQQ__Subscription__c recSub02 = new SBQQ__Subscription__c(Name__c='Test Product Parent 02', SBQQ__Contract__c=conid, Project_Type__c='FTG New Rooms',
			                                                        Status__c='Pending Installation Activate', SBQQ__Product__c=parentproduct02.id, SBQQ__Quantity__c = 100);

        SBQQ__Subscription__c recSub03 = new SBQQ__Subscription__c(Name__c='Test Product Parent 03', SBQQ__Contract__c=conid, Project_Type__c='SONIFI New Rooms',
			                                                        Status__c='Pending Installation Activate', SBQQ__Product__c=parentproduct03.id, SBQQ__Quantity__c = 100);
        insert new List<SBQQ__Subscription__c>{recSub01, recSub02, recSub03};

        //Create custom setting to specify Legacy Service Contracts
        Legacy_Service_Contract_Names__c recLegacy01 = new Legacy_Service_Contract_Names__c(name = 'Test SC 01 Legacy', service_contract_names__c = 'Test SC 01 Legacy');
        Legacy_Service_Contract_Names__c recLegacy02 = new Legacy_Service_Contract_Names__c(name = 'Test SC 02 Legacy', service_contract_names__c = 'Test SC 02 Legacy');
        insert new List<Legacy_Service_Contract_Names__c>{recLegacy01, recLegacy02};

        //Create Service Contracts (1 Legacy, 1 Non-Legacy with Term value, and 1 Non-Legacy without a Term value)
		ServiceContract servcon01 = new ServiceContract(Name='Test SC 01', Subscription__c=recSub01.Id, Term=12, AccountId=acc.Id, NotificationNeeded__c = false);
        ServiceContract servcon02 = new ServiceContract(Name='Test SC 02 Legacy', Subscription__c=recSub02.Id, Term=12, AccountId=acc.Id, NotificationNeeded__c = false);
		ServiceContract servcon03 = new ServiceContract(Name='Test SC 03', Subscription__c=recSub03.Id, AccountId=acc.Id, NotificationNeeded__c = false);
        insert new List<ServiceContract>{servcon01, servcon02, servcon03};

        //Create entitlements
        Entitlement entl01 = new Entitlement(Name = 'Test Entitlement 01', AccountId = acc.id, Subscription__c = recSub01.id, AssetId = asset01.id,
                                             ServiceContractId = servcon01.id);
        Entitlement entl02 = new Entitlement(Name = 'Test Entitlement 02', AccountId = acc.id, Subscription__c = recSub02.id, AssetId = asset02.id, 
                                             ServiceContractId = servcon02.id);
        Entitlement entl03 = new Entitlement(Name = 'Test Entitlement 03', AccountId = acc.id, Subscription__c = recSub03.id, AssetId = asset03.id, 
                                             ServiceContractId = servcon03.id);
        insert new List<Entitlement>{entl01, entl02, entl03};

		//Create Order
        Order__c neworder = new Order__c(Name='TestOrder',Status__c='Order Approved', Site__c=acc.id);
    	insert neworder;

       	//Create Order Items
      	Order_Item__c oi01 = new Order_Item__c(Name='Test Product Parent 01',Product__c=parentproduct01.id,Account__c=acc.id,Billing_Commencement_Date__c=system.today(),
       	                                        Order__c = neworder.id, Subscription__c = recSub01.id, Status__c='Billing',
                                                asset__c = asset01.id, total_remaining_rooms__c = 100);
        	
       	Order_Item__c oi02 = new Order_Item__c(Name = 'Test Product Parent 02', Product__c=parentproduct02.id,Account__c=acc.id,Billing_Commencement_Date__c=system.today(),
       	                                        Order__c = neworder.id, Subscription__c = recSub02.id, Status__c='Billing',
                                                asset__c = asset02.id, total_remaining_rooms__c = 100);
        	
       	Order_Item__c oi03 = new Order_Item__c(Name = 'Test Product Parent 03', Product__c=parentproduct03.id,Account__c=acc.id,Billing_Commencement_Date__c=system.today(),
       	                                        Order__c = neworder.id, Subscription__c = recSub03.id, Status__c='Billing',
                                                asset__c = asset03.id, total_remaining_rooms__c = 100);
       	insert new List<Order_Item__c>{oi01, oi02, oi03};

		test.startTest();
       	//Create Work Order
        Id workOrderRecordType = Utilities.RecordTypeNameToId('Work_Order__c', 'Install');
        Work_Order__c wo = new Work_Order__c(RecordTypeId=workOrderRecordType, Status__c='In Progress', Site__c=acc.id, Install_Manager__c=newuser.id,
                                           Project_Coordinator__c=newuser.id, ownerID=newuser.id, Approver__c=newuser.id, Division__c='Domestic', Region__c='Midwest',
                                           Approval_Status__c = 'Pending Billing Approval');
        insert wo;
         	
        //Create Associated Items
        Associated_Item__c ai01 = new Associated_Item__c(Name='Test Product Parent 01', Status__c='Billing', Billing_Commencement_Date__c=system.today(),
       	                                                Order_Item__c=oi01.id, Work_Order__c=wo.id, Added_to_TurnonNotice__c=false,
                                                        Submitted_for_Billing__c=false, Flagged_for_Billing__c=true, Quantity__c=100);

       	Associated_Item__c ai02 = new Associated_Item__c(Name='Test Product Parent 02', Status__c='Billing', Billing_Commencement_Date__c=system.today(),
       	                                                Order_Item__c=oi02.id, Work_Order__c=wo.id, Added_to_TurnonNotice__c=false,
                                                        Submitted_for_Billing__c=false, Flagged_for_Billing__c=true, Quantity__c=100);

       	Associated_Item__c ai03 = new Associated_Item__c(Name='Test Product Parent 03', Status__c='Billing', Billing_Commencement_Date__c=system.today(),
       	                                                Order_Item__c=oi03.id, Work_Order__c=wo.id, Added_to_TurnonNotice__c=false,
                                                        Submitted_for_Billing__c=false, Flagged_for_Billing__c=true, Quantity__c=100);
       	insert new List<Associated_Item__c>{ai01, ai02, ai03};

       	//Update so Work Order trigger activated that should update the Asset records
        wo.Approval_Status__c = 'Billing Approved';
       	wo.Status__c = 'Billing/Go Live';
       	update wo;

        //Find the one contract
        Contract testContract = [ SELECT Id, initial_term__c FROM Contract LIMIT 1 ];
        //Set value for assert tests as an integer
        Integer intTerm = (Integer)testContract.initial_term__c;
        //Retrieve Entitlement and Service Contract info
        List<Entitlement> lstentl = [ SELECT Name, Status, StartDate, EndDate, ServiceContract.Id, ServiceContract.Name, ServiceContract.EndDate,
	           	                          ServiceContract.StartDate, ServiceContract.term, ServiceContract.NotificationNeeded__c, 
	  	                                  ServiceContract.Status, AssetId, subscription__r.SBQQ__Contract__r.initial_term__c
                                      FROM Entitlement
                                      WHERE subscription__r.SBQQ__Contract__c = :testContract.id ];

       	for(Entitlement recentl :lstentl){
            //Check Entitlement dates
            system.assertEquals(system.today(), recentl.startDate);
            system.assertEquals(system.today().addMonths(intTerm), recentl.endDate);

            //Check Service Contract dates
            system.assertEquals(system.today(), recentl.ServiceContract.StartDate);
            //Non-Legacy Service Contract with a Term
            if(recentl.ServiceContract.Name == 'Test SC 01'){
                system.assertEquals(system.today().addMonths(recentl.ServiceContract.term), recentl.ServiceContract.endDate);
                system.assertEquals(false, recentl.ServiceContract.NotificationNeeded__c);
            }
            //Legacy Service Contract
            else if(recentl.ServiceContract.Name == 'Test SC 02 Legacy'){
                system.assertEquals(system.today().addMonths(intTerm), recentl.ServiceContract.endDate);
                system.assertEquals(false, recentl.ServiceContract.NotificationNeeded__c);
            }
            //Non-Legacy Service Contract without a Term
            else{
                system.assertEquals(system.today().addMonths(3), recentl.ServiceContract.endDate);
                system.assertEquals(true, recentl.ServiceContract.NotificationNeeded__c);
            }
       	}

        //Now set initial start/end dates on contract to verify entitlements and service contracts are "trued up"
        recSub01.status__c = 'Installed Activated';
        recSub02.status__c = 'Installed Activated';
        recSub03.status__c = 'Installed Activated';
        update new List<SBQQ__Subscription__c>{recSub01, recSub02, recSub03};

        Date contractStartDate = system.today().addMonths(1);
        Date contractEndDate = system.today().addMonths(intTerm +1);
        testContract.Contract_Status__c = 'Installed Activated';
        testContract.startDate = contractStartDate;
        testContract.endDate = contractEndDate;
        update testContract;

        //Retrieve Entitlement and Service Contract info
        List<Entitlement> lstentl2 = [ SELECT Name, Status, StartDate, EndDate, ServiceContract.Id, ServiceContract.Name, ServiceContract.EndDate,
	           	                          ServiceContract.StartDate, ServiceContract.term, ServiceContract.NotificationNeeded__c, 
	  	                                  ServiceContract.Status, AssetId, subscription__r.SBQQ__Contract__r.initial_term__c
                                      FROM Entitlement
                                      WHERE subscription__r.SBQQ__Contract__c = :testContract.id ];

       	for(Entitlement recentl :lstentl2){
            //Check Entitlement start/end dates
            system.assertEquals(contractStartDate, recentl.startDate);
            system.assertEquals(contractStartDate.addMonths(intTerm), recentl.endDate);

            //Check Service Contract start/end dates
            system.assertEquals(contractStartDate, recentl.ServiceContract.StartDate);
            //Non-Legacy Service Contract with a Term
            if(recentl.ServiceContract.Name == 'Test SC 01'){
                system.assertEquals(contractStartDate.addMonths(recentl.ServiceContract.term), recentl.ServiceContract.endDate);
                system.assertEquals(false, recentl.ServiceContract.NotificationNeeded__c);
            }
            //Legacy Service Contract
            else if(recentl.ServiceContract.Name == 'Test SC 02 Legacy'){
                system.assertEquals(contractStartDate.addMonths(intTerm), recentl.ServiceContract.endDate);
                system.assertEquals(false, recentl.ServiceContract.NotificationNeeded__c);
            }
            //Non-Legacy Service Contract without a Term
            else{
                system.assertEquals(contractStartDate.addMonths(3), recentl.ServiceContract.endDate);
                system.assertEquals(true, recentl.ServiceContract.NotificationNeeded__c);
            }
       	}
       	test.stopTest();
	}

    static testMethod void testsetEntitleServiceContrDates_DeInstall()
    {
        system.debug('running test testsetEntitleServiceContrDates_DeInstall');
        //Create account
        Account acc = DataGenerator.createAccounts(1,true)[0];
		acc.of_Rooms__c = 100;
		acc.Physical_City__c = 'Sioux Falls';
		acc.Physical_State__c = 'SD';
		acc.Name = 'TestAccount';
		update acc;

		//Create user
        List<User> userlist = new List<User>();
		User newuser;
		userlist = DataGenerator.CreateUsers('System Administrator',1,true);
		for(User recuser : userlist)
		    {  newuser = recuser;   }

        //Create Products
        Product2 parentproduct01 = new Product2(Name='Test Product Parent 01', ProductCode='CC-testpp01');
		Product2 parentproduct02 = new Product2(Name='Test Product Parent 02', ProductCode='CC-testpp02');
        Product2 parentproduct03 = new Product2(Name='Test Product Parent 03', ProductCode='CC-testpp03');
		insert new List<Product2>{parentproduct01,parentproduct02,parentproduct03};
        
        //Create Assets
        Asset asset01 = new Asset(AccountId = acc.Id, Name = 'Test Asset 01 Product Parent', Product2Id = parentproduct01.Id, Status = 'Installed Activated',
                                    service_start_date__c = system.today().addMonths(-1));
        Asset asset02 = new Asset(AccountId = acc.Id, Name = 'Test Asset 02 Product Parent', Product2Id = parentproduct02.Id, Status = 'Installed',
                                    service_start_date__c = system.today().addMonths(-1));
        Asset asset03 = new Asset(AccountId = acc.Id, Name = 'Test Asset 03 Product Parent', Product2Id = parentproduct03.Id, Status = 'Installed Activated',
                                    service_start_date__c = system.today().addMonths(-1));
    	insert new List<Asset>{asset01, asset02, asset03};

        //Create Contract
		Contract recContract = new Contract(AccountId=acc.id,Contract_Status__c='Order Approved', initial_term__c = 60, upfront_subsidy__c = 100);
		insert recContract;

		Contract con = [ Select Id from Contract where Id = :recContract.Id LIMIT 1 ];
		Id conid = con.id;
			
		//Create subscriptions
        SBQQ__Subscription__c recSub01 = new SBQQ__Subscription__c(Name__c='Test Product Parent 01', SBQQ__Contract__c=conid, Project_Type__c='Interactive New Rooms',
		                                                            Status__c='Pending Installation Activate', SBQQ__Product__c=parentproduct01.id, SBQQ__Quantity__c = 100);
			
		SBQQ__Subscription__c recSub02 = new SBQQ__Subscription__c(Name__c='Test Product Parent 02', SBQQ__Contract__c=conid, Project_Type__c='FTG New Rooms',
			                                                        Status__c='Pending Installation Activate', SBQQ__Product__c=parentproduct02.id, SBQQ__Quantity__c = 100);

        SBQQ__Subscription__c recSub03 = new SBQQ__Subscription__c(Name__c='Test Product Parent 03', SBQQ__Contract__c=conid, Project_Type__c='SONIFI New Rooms',
			                                                        Status__c='Pending Installation Activate', SBQQ__Product__c=parentproduct03.id, SBQQ__Quantity__c = 100);
        insert new List<SBQQ__Subscription__c>{recSub01, recSub02, recSub03};

        //Create Service Contracts
		ServiceContract servcon01 = new ServiceContract(Name='Test SC 01', Subscription__c=recSub01.Id, Term=12, AccountId=acc.Id, NotificationNeeded__c = false,
                                                        startDate = system.today().addMonths(-1), endDate = system.today().addMonths(1));
        ServiceContract servcon02 = new ServiceContract(Name='Test SC 02', Subscription__c=recSub02.Id, Term=12, AccountId=acc.Id, NotificationNeeded__c = false,
                                                        startDate = system.today().addMonths(-1), endDate = system.today().addMonths(1));
		ServiceContract servcon03 = new ServiceContract(Name='Test SC 03', Subscription__c=recSub03.Id, AccountId=acc.Id, NotificationNeeded__c = false,
                                                        startDate = system.today().addMonths(-1), endDate = system.today().addMonths(1));
        insert new List<ServiceContract>{servcon01, servcon02, servcon03};

        //Create entitlements
        Entitlement entl01 = new Entitlement(Name = 'Test Entitlement 01', AccountId = acc.id, Subscription__c = recSub01.id, AssetId = asset01.id,
                                             ServiceContractId = servcon01.id, startDate = system.today().addMonths(-1), endDate = system.today().addMonths(1));
        Entitlement entl02 = new Entitlement(Name = 'Test Entitlement 02', AccountId = acc.id, Subscription__c = recSub02.id, AssetId = asset02.id, 
                                             ServiceContractId = servcon02.id, startDate = system.today().addMonths(-1), endDate = system.today().addMonths(1));
        Entitlement entl03 = new Entitlement(Name = 'Test Entitlement 03', AccountId = acc.id, Subscription__c = recSub03.id, AssetId = asset03.id, 
                                             ServiceContractId = servcon03.id, startDate = system.today().addMonths(-1), endDate = system.today().addMonths(1));
        insert new List<Entitlement>{entl01, entl02, entl03};

        test.startTest();
        //Update Asset to verify Entitlements and Service Contract End Dates are yesterday
        List<Asset> lstAssets = new List<Asset>();
        asset01.status = 'De-Installed';
        asset02.status = 'Cancelled';
        asset03.status = 'Canceled';
        lstAssets.add(asset01);
        lstAssets.add(asset02);
        lstAssets.add(asset03);
        update lstAssets;

        //Retrieve Entitlement and Service Contract info
        List<Entitlement> lstentl = [ SELECT Name, Status, StartDate, EndDate, ServiceContract.Id, ServiceContract.Name, ServiceContract.EndDate,
	           	                          ServiceContract.StartDate, ServiceContract.term, ServiceContract.NotificationNeeded__c, 
	  	                                  ServiceContract.Status, AssetId, subscription__r.SBQQ__Contract__r.initial_term__c
                                      FROM Entitlement
                                      WHERE subscription__r.SBQQ__Contract__c = :con.id ];

       	for(Entitlement recentl :lstentl){
            //Check Entitlement dates
            system.assertEquals(system.today().addDays(-1), recentl.endDate);
            //Check Service Contract dates
            system.assertEquals(system.today().addDays(-1), recentl.ServiceContract.endDate);
       	}
        test.stopTest();
    }
}