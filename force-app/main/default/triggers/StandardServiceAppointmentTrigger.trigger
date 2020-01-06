trigger StandardServiceAppointmentTrigger on ServiceAppointment (before insert, before update, after insert, after update) {

    //jjackson--check to see if trigger is turned off via the custom setting
    try{ 
    	if(AppConfig__c.getValues('Global').BlockTriggerProcessing__c) {
    		return;
    	} else if(ServiceAppointmentTriggerConfig__c.getValues('Global').BlockTriggerProcessing__c) {
			return; 
		}
    }
    catch (Exception e) {}

if(trigger.isBefore)
{   
 
    if(trigger.isInsert)
    {  StandardServiceAppointmentTriggerLogic.PopulateAccountandSiteSurveyInfo(trigger.new); 
       StandardServiceAppointmentTriggerLogic.TechnicianAssignedUpdatesOwnership(trigger.new, 'Insert', trigger.oldmap);
    }

    if(trigger.isUpdate)
    {
        StandardServiceAppointmentTriggerLogic.PopulateGanttLabel(trigger.new);
        StandardServiceAppointmentTriggerLogic.TechnicianAssignedUpdatesOwnership(trigger.new, 'Update', trigger.oldmap);
        StandardServiceAppointmentTriggerLogic.UpdateScheduledEndfromDuration(trigger.new, trigger.oldmap);
        StandardServiceAppointmentTriggerLogic.ChangeScheduledEndDatetoActual(trigger.new, trigger.oldMap);
    }
}

if(trigger.isAfter)
{
    
    if(trigger.isInsert)
    {
        List<ServiceAppointment> lstsa = New List<ServiceAppointment>();
        for(ServiceAppointment s :trigger.new)
        { 
            if(s.case__c != null && s.technician_assigned__c != null && s.case_severity__c != null &&
            (s.case_severity__c == 'Critical' || s.case_severity__c == 'Catastrophic' || s.case_severity__c == 'High'))
            { 
                lstsa.add(s); 
                system.debug('case severity is ' +s.case_severity__c +' for case number ' +s.case__c);
            }
        }
    

        system.debug('lstsa size is ' +lstsa.size());
         
        StandardServiceAppointmentTriggerLogic.ChangeFWOOwnershiptoQueue(trigger.new);

    }

    if(trigger.isUpdate)
    {   

        List<ServiceAppointment> lstcriticalapp = New List<ServiceAppointment>();
        String prioritynotice = 'High|Critical|Catastrophic';
        for(ServiceAppointment s :trigger.new)
        { 
            if(s.case__c != null && s.case_severity__c != null && prioritynotice.contains(s.case_severity__c))
            {   
                Id oldtechassigned = trigger.oldmap.get(s.id).technician_assigned__c;
                system.debug('oldtechassigned is ' +oldtechassigned);
                if(s.technician_assigned__c != null && oldtechassigned == null)
                {
                    lstcriticalapp.add(s); 
                    system.debug('case severity is ' +s.case_severity__c +' for case number ' +s.case__c);
                }
            }
        }
    

        system.debug('lstcriticalapp size is ' +lstcriticalapp.size());

        //if there are critical cases in the trigger, call the method that sends out
        //a critical email notification.  The call is in the recursion block so the email
        //will only get sent one time
        if(lstcriticalapp.size() > 0 && triggerRecursionBlock.flag == true) 
        {
            	 EmailUtilities.EmailWhenServiceAppointmentisCritical(lstcriticalapp);
          	     triggerRecursionBlock.flag = false;
        }


        List<ServiceAppointment> lstsa = New List<ServiceAppointment>();
        for(ServiceAppointment s :trigger.new)
        {
            if(s.create_follow_up__c == true && trigger.oldMap.get(s.id).create_follow_up__c == false)
            {
                lstsa.add(s);
            }
        }
        StandardServiceAppointmentTriggerLogic.PopulateFWODatefromSA(trigger.new, trigger.oldMap);
        StandardServiceAppointmentTriggerLogic.PopulateSiteSurveyScheduleDate(trigger.new, trigger.oldMap);
        StandardServiceAppointmentTriggerLogic.SurveyAppointmentCompleted(trigger.new, trigger.oldMap);
        StandardServiceAppointmentTriggerLogic.CreateFollowUpAppointment(lstsa);


    }
}

}