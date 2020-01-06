@isTest

public with sharing class BatchPMWorkOrderTest {
    
    public @IsTest
    static void testCreatePMWorkOrders(){
        
        OperatingHours ohours = New OperatingHours(Name='Main Operating Hours', TimeZone='America/Chicago');
        insert ohours;
        ServiceTerritory st = New ServiceTerritory(Name='TestTerritory', isActive = true, operatinghoursid=ohours.id);
        insert st;
        WorkType wt = New WorkType(Name='Preventive Maintenance', Description='Test', Work_Type_Category__c='Preventive Maintenance',
                    DurationType = 'Hours', EstimatedDuration = 2, FSL__Due_Date_Offset__c=43200, ShouldAutoCreateSvcAppt=true);
        insert wt;            
        Account a = CreateTestRecords.DefaultHospitalityAccount();
        a.service_territory__c = st.id;
        update a;

        Product2 p = New Product2(Name='FTG Product Parent', productcode = '1234-33-4567');
        insert p;
        Asset asst = New Asset(Name='FTG Product Parent', accountid=a.id, status='Installed Activated',
                     product2id = p.id, contract_type__c = 'FTG', Quantity=100, company_code__c = '01 Sonifi USA',
                     service_start_date__c = system.today());
        insert asst;
        Date mystart = system.today().addMonths(-6);
        Date myend = system.today().addMonths(24);
        ServiceContract sc = New ServiceContract(Name='Test Warranty', Warranty_Description__c = 'Full Coverage',
                            accountid=a.id, product_inventory__c = asst.id, startdate=mystart, enddate=myend, term=48 );
        insert sc;
        Entitlement e = New Entitlement(Name='Test Entitlement', accountid = a.id, assetid=asst.id,startdate=mystart,
                        enddate=myend, pm_frequency__c = 90, servicecontractid=sc.id);
        insert e;


        test.startTest();

            BatchPMWorkOrder bPM = new BatchPMWorkOrder();
		    ID id =Database.executeBatch(bPM);
		    System.debug('id is : '+id);

        test.stopTest();

        BatchPMWorkOrder mybatch = New BatchPMWorkOrder();
        Id myid = Database.executeBatch(mybatch);
        system.debug('myid is ' +myid);

        
    } 
}