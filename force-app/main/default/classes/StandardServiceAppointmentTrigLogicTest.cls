@isTest
public without sharing class StandardServiceAppointmentTrigLogicTest {
    
    
    static testmethod void PopulateFWODateTest() 
    {
		//Sample code create service appointment with work type, etc.

        Case newcase = CreateTestRecords.DefaultSupportCase();
		
        Id accid = newcase.accountid;
        WorkOrder testwo = CreateTestRecords.DefaultFieldServiceWO(accid,newcase.id);
		


        //jjackson now create all the data that is needed for a service appointment
        Profile proid = [Select id, name from Profile where name = 'System Administrator' LIMIT 1];
		User u = New User(alias='jblow', firstname='Joe', lastname='Blow', email='testemail@invalid.com',
		                  username='testemail@invalid.com', profileid = proid.id, timezonesidkey='America/Chicago', isActive=true,
						  localesidkey='en_US', languagelocalekey='en_US', emailencodingkey='ISO-8859-1', currencyisocode='USD',
						  defaultcurrencyisocode='USD');
		insert u;



		ServiceResource sr = New ServiceResource(Name='Joe Blow', relatedrecordid=u.id, 
		                     isActive = true, resourcetype='T');
		insert sr;

		OperatingHours oh = New OperatingHours(Name='Regular Time = Central Time - US', Timezone='America/Chicago');
		insert oh;

		ServiceTerritory st = New ServiceTerritory(Name='Test Territory', City = 'Sioux Falls', CurrencyIsoCode = 'USD', GeocodeAccuracy='Zip', IsActive=True,
							  postalcode = '57106', State='SD', operatinghoursid=oh.id);
		insert st;

		WorkType wt = New WorkType(Name='Interactive', durationtype='Hours', estimatedduration=2,
		                           work_type_category__c = 'Dispatch', ownerid=u.id);
		insert wt;

		newcase.Target_Date_Time__c = system.now().addDays(4);
		newcase.Work_Type__c = wt.id;
		newcase.Service_Territory__c = st.id;
		update newcase;

		testwo.WorkTypeId = wt.id;
		testwo.ServiceTerritoryId = st.id;
		update testwo;

		DateTime setactual = system.now().addminutes(30);

		ServiceAppointment svcapp = New ServiceAppointment(case__c = newcase.id, schedstarttime=system.now().addminutes(-60), 
                                    schedendtime=system.now().addminutes(90), technician_assigned__c = sr.id, duration=3,
									sa_type__c = 'Dispatch', field_work_order__c = testwo.id, subject = 'test',
									serviceterritoryid=st.id, parentrecordid=testwo.id, status = 'Scheduled',
                                    account_name__c = newcase.accountid, duedate = system.now().adddays(3));
		insert svcapp;

        test.startTest();

        ServiceAppointment sa = [ Select Id, duration, schedendtime, actualstarttime, actualendtime from ServiceAppointment LIMIT 1 ];
		system.debug('sa schedendtime is ' +sa.schedendtime);

        sa.Duration = 2; //should cover UpdateScheduledEndfromDuration
		update sa;

		ServiceAppointment sap = [ Select Id, duration, schedendtime, actualstarttime, actualendtime from ServiceAppointment LIMIT 1 ];

		system.debug('sap schedendtime is ' +sap.SchedEndTime);
		
		sap.actualstarttime = setactual;
        update sap;

        WorkOrder wo = [ Select Id, Date__c from WorkOrder where id = :testwo.id];
		system.assert(wo.date__c != null);


		DateTime setactualend = system.now().addminutes(60);
		sap.actualendtime = setactualend;  //should cover ChangeScheduledEndDatetoActual
		update sap;

		ServiceAppointment updsa = [Select id, status, schedendtime, actualendtime, create_follow_up__c,
		                            follow_up_Appointment_time__c, cannot_complete_reason__c  from ServiceAppointment LIMIT 1];

		system.assert(sa.schedendtime != updsa.schedendtime);

		

        test.stopTest();

    }

	public static testmethod void testSiteSurveyAppointment()
	{
		system.debug(' BEGIN testSiteSurveyAppointment');

		Id userid = UserInfo.GetUserId();

		Account hospacct = CreateTestRecords.DefaultHospitalityAccount();

		Opportunity opp = CreateTestRecords.DefaultHospitalityOpportunity(hospacct.id);

		//Insert custom setting record for FSL_RecordType_WorkType__c
		FSL_RecordType_WorkType__c rec_rtwt = new FSL_RecordType_WorkType__c();
		rec_rtwt.name = 'Site Survey';
		rec_rtwt.WorkTypeName__c = 'Site Survey';
		insert rec_rtwt;

		//must create a contact record for use with the email notification
		Contact con = New Contact(firstname = 'Test', lastname = 'Contact', accountid = hospacct.id, email = 'testemail@invalid.com');
		insert con;

        //Find Id for Site Survey record type
		Id recordTypeId_ss = Utilities.RecordTypeNametoId('Site_Survey__c', 'Site Survey');
		//when creating a site survey for a test, it must be linked to an opportunity.  Otherwise code that runs in the
		//site survey trigger logic will fail.
		Site_Survey__c ss = New Site_Survey__c(opportunity__c = opp.id, Site__c = hospacct.id, Status__c = 'Not Started',
		                                       install_manager__c = userid, recordtypeid = recordTypeId_ss);
		insert ss;

		WorkType wt = New WorkType(Name='Site Survey', durationtype='Hours', estimatedduration=7, FSL__Due_Date_Offset__c = 10080,
		                           work_type_category__c = 'Dispatch', ShouldAutoCreateSvcAppt = true);
		insert wt;

		Date due = system.today().adddays(5);

		Id surveyrecid = Utilities.RecordTypeNametoId('WorkOrder', 'Site Survey Work Order');

		//WorkOrder fwosurvey = New WorkOrder(Duration = 7, DurationType = 'Hours', Site_Survey__c = ss.id, accountid = hospacct.id,
		//           Due_Date__c = due, recordtypeid = surveyrecid, worktypeid = wt.id, status = 'New' );
		WorkOrder fwosurvey = New WorkOrder(Site_Survey__c = ss.id, accountid = hospacct.id, 
		           							Due_Date__c = due, status = 'New' );
		insert fwosurvey;

		Datetime startdate = system.now().addhours(-1);
		Datetime enddate = system.now().addhours(2);
		DateTime earlieststart = system.now().adddays(-3);

	

		system.debug('test startdate is ' +startdate);
		system.debug('test enddate is ' +enddate);

		ServiceAppointment sa = New ServiceAppointment(parentrecordid = fwosurvey.id, account_name__c = hospacct.id, duedate = due,
		                        schedstarttime = startdate, schedendtime = enddate, earlieststarttime = earlieststart, field_work_order__c = fwosurvey.id, site_survey__c = ss.id);
		insert sa;

		test.startTest();

		
		ServiceAppointment appt = [Select Id, schedstarttime, schedendtime, status, Subject from ServiceAppointment where parentrecordid = :fwosurvey.id LIMIT 1];
		system.assert(appt.subject.contains('Site Survey'));

		Profile proid = [Select id, name from Profile where name = 'System Administrator' LIMIT 1];
		User u = New User(alias='jblow', firstname='Joe', lastname='Blow', email='testemail@invalid.com',
		                  username='testemail@invalid.com', profileid = proid.id, timezonesidkey='America/Chicago', isActive=true,
						  localesidkey='en_US', languagelocalekey='en_US', emailencodingkey='ISO-8859-1', currencyisocode='USD',
						  defaultcurrencyisocode='USD');
		insert u;



		ServiceResource sr = New ServiceResource(Name='Joe Blow', relatedrecordid=u.id,
		                     isActive = true, UserInfo__c = u.id);
		insert sr;

		sa.technician_assigned__c = sr.id;
		update sa;

		ServiceAppointment serv = [Select Id, site_survey__c, ownerid, technician_assigned__c, status from ServiceAppointment where id = :sa.id ];
		system.debug('technician assigned is ' +serv.technician_assigned__c);
		system.debug('ownerid is ' +serv.ownerid);

		serv.status = 'Scheduled';
		update serv;
		
		//jjackson -- the test code above hits part of the code in method SurveyAppointmentCompleted.  I am unable to change a service
		//appointment in this test to On-Site Completed even if I update the service appointment to each status value
		//that comes before On-Site Completed.  I keep getting errors that I am not allow to change from one status to the
		//next so I am going to leave the test here.  About half the code in the method gets hit.

		test.stopTest();

	}

}