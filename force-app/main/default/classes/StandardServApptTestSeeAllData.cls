@isTest (SeeAllData=true)
public with sharing class StandardServApptTestSeeAllData {

    //jjackson 10/1/2019  This test class was created to use SeeAllData because certain things can't be done to 
    //service appointments programatically such as changing the status of the service appointment.  In order to get
    //trigger code coverage to test code that changes an appointment status, you must use a real appointment in the org
    //and change the status of it with code.  Doing this within a test does not actually save the test change in the org.

    static testmethod void testCreateFollowUp()
    {
        List<ServiceAppointment> lstsa = New List<ServiceAppointment>();
        lstsa = [Select Id, account_name__c, case__c, schedstarttime, schedendtime, technician_Assigned__c, field_work_order__c,
                status, cannot_complete_reason__c, create_follow_up__c, follow_up_appointment_time__c, appointmentnumber  from ServiceAppointment 
                where case__c != null AND schedstarttime != null AND schedendtime != null AND 
                technician_assigned__c != null AND status not in ('On-Site Completed', 'Remote Completed', 'Canceled', 'None', 'Cannot Complete') LIMIT 1 ];

        system.debug('appointment number returned is ' +lstsa[0].appointmentnumber);

        lstsa[0].status = 'Cannot Complete';
        lstsa[0].cannot_complete_reason__c = 'Access To Rooms';
        update lstsa[0];

        ServiceAppointment sa = [Select id, appointmentnumber, status, cannot_complete_reason__c, create_follow_up__c,
                              follow_up_appointment_time__c from ServiceAppointment where appointmentnumber = :lstsa[0].appointmentnumber LIMIT 1];

        sa.create_follow_up__c = true;
        sa.follow_up_appointment_time__c = lstsa[0].schedendtime.adddays(2);
        update sa;

    }
}