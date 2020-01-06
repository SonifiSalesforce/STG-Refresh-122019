/*  
    shawks 11/2019  BUG-00984 - Do not update FWO or Case ownership when ownership is changed on a Tech Assist SA;
                              - Update SurveyAppointmentCompleted and ChangeFWOOwnershiptoQueue to exclude Tech Assist SAs
    jjackson 9/2019 BUG-01007 Add trigger code to create a follow-up appointment after Cannot Complete instead of 
       relying on the automated flow.  The flow doesn't seem to work when people are creating follow-ups from a phone.
    jjackson 9/2019 added PopulateSiteSurveyScheduleDate as part of the site survey appointment functionality
    jjackson 9/2019 added method PopulateGanttLabel to show more info on the appointment label on the Gantt chart
    jjackson 8/2019 Added method TechnicianAssignedUpdatesOwnership.  When the Technician Assigned field is
       populated or changed, update the ownership to that person on the service appointment, the related FWO,
       and the site survey (if the parent fwo is for a site survey).
    jjackson 8/2019 BUG-00916 Change SA scheduled end time to the actual end time (check-out date/time)
    jjackson 8/2019 BUG-00905 Post-FSL update FWO date from related Service Appointment
    
    Joan Jackson
    Sonifi Solutions
    8/13/2019
*/
public with sharing class StandardServiceAppointmentTriggerLogic {

    //jjackson 9/19--Create a follow-up appointment when the original goes to Cannot Complete
    public static void CreateFollowUpAppointment(List<ServiceAppointment> lsttrigger)
    {
        system.debug('**********BEGIN CreateFollowUpAppointment*********');

        Boolean noerrorsflag = true;
        List<ServiceAppointment> lstcreatenewsa = New List<ServiceAppointment>();
        Set<Id> setapptid = New Set<Id>();
        

        //first check to make sure the new appointment has the correct info
        for(ServiceAppointment sa :lsttrigger)
        {

            setapptid.add(sa.id); //add all sa id's to a set for querying the assigned resource on each appointment

            if(sa.create_follow_up__c == true)
            {
                if(sa.status != 'Cannot Complete')
                {
                    lsttrigger[0].status.addError('Status must be Cannot Complete to create a follow up. ');
                    noerrorsflag = false;
                }

                if(sa.status == 'Cannot Complete' && sa.Cannot_Complete_Reason__c == '' )
                {
                    lsttrigger[0].Cannot_Complete_Reason__c.addError('Add a Cannot Complete Reason.');
                    noerrorsflag = false;
                }

                if(sa.Follow_Up_Appointment_Time__c == null)
                {   lsttrigger[0].Follow_Up_Appointment_Time__c.addError('You must enter a Follow Up Appointment Time. '); 
                    noerrorsflag = false;
                }

                if(sa.Follow_Up_Appointment_Time__c != null && sa.Follow_Up_Appointment_Time__c < sa.SchedEndTime)
                {
                    lsttrigger[0].Follow_Up_Appointment_Time__c.AddError('Follow Up Appointment Time must be later than Scheduled End Time. ');
                    noerrorsflag = false;
                }

                if(noerrorsflag == true)
                { lstcreatenewsa.add(sa); }
            }

        }//end first for loop

        if(lstcreatenewsa.size() > 0)
        {
            //query for the original assigned resources and add to map for assigned to the new appointment
            List<AssignedResource> lstresource = New List<AssignedResource>();
            lstresource = [Select serviceappointmentid, serviceresourceid from AssignedResource where Serviceappointmentid
                           in :setapptid];

            system.debug('lstresource size is ' +lstresource.size());

            Map<Id,Id> mapapptidtoar = New Map<Id,Id>(); //map storing appointmentid (key), assigned resource id (value)
            for(AssignedResource a :lstresource)
            {  mapapptidtoar.put(a.serviceappointmentid, a.serviceresourceid); }

 
            List<ServiceAppointment> lstnewsa = New List<ServiceAppointment>();


            for(ServiceAppointment s :lstcreatenewsa)
            {
                ServiceAppointment appt = New ServiceAppointment();
                appt.parentrecordid = s.parentrecordid;
                appt.field_work_order__c = s.parentrecordid;
                appt.arrivalwindowstarttime = s.arrivalwindowstarttime;
                appt.duedate = system.now().addDays(14);
                appt.Duration = s.duration;
                appt.schedstarttime = s.follow_up_appointment_time__c;

                if(s.follow_up_appointment_time__c != null)
                { appt.schedendtime = s.follow_up_appointment_time__c.addHours(integer.valueof(s.duration)); }

                appt.durationType = s.durationtype;
                appt.EarliestStartTime = s.earlieststarttime;
                //appt.recordtypeid = s.recordtypeid;
                appt.serviceterritoryid = s.serviceterritoryid;
                appt.status = 'None';
                appt.subject = s.subject;
                appt.account_name__c = s.account_name__c;
                appt.case__c = s.case__c;
                appt.case_milestone_synopsis_SA__c = s.case_milestone_synopsis_SA__c;
                appt.FSL__GanttLabel__c = s.FSL__GanttLabel__c;
                appt.sonifi_work_order__c = s.sonifi_work_order__c;
                appt.site_survey__c = s.site_survey__c;
                appt.street = s.street;
                appt.city = s.city;
                appt.state = s.state;
                appt.postalcode = s.postalcode;
                appt.country = s.country;
                appt.FSL__Related_Service__c = s.id;
                appt.FSL__Time_Dependency__c = 'Start After Finish'; //this value is enforced in this field for a follow up appt
                lstnewsa.add(appt);


            }//end for loop

            if(lstnewsa.size() > 0 )
            {
                try{ insert lstnewsa; }
                catch(Exception e)
                {  System.debug('Error creating follow up appointments: ' + e.getMessage()); }

 
            }
            
            //the new service appointments are created.  Now create the assigned resource and link to the new appointment.
            List<AssignedResource> lstar = New List<AssignedResource>();
            List<ServiceAppointment> lstnewappt = New List<ServiceAppointment>();

            //query for the new appointments to get the new appointment ids for the assigned resource records
            lstnewappt = [Select id, FSL__Related_Service__c, schedendtime, schedstarttime from ServiceAppointment 
                            where FSL__Related_Service__c in :mapapptidtoar.keyset() ];
            
            system.debug('lstnewappt size is ' +lstnewappt.size());
            
            if(lstnewappt.size() > 0)
            {
                for(ServiceAppointment sa :lstnewappt)
                {
                    if(sa.schedstarttime != null && sa.schedendtime != null && mapapptidtoar.containskey(sa.FSL__Related_Service__c))
                    {
                        AssignedResource ar = New AssignedResource();
                        ar.serviceappointmentid = sa.id;
                        ar.serviceresourceid = mapapptidtoar.get(sa.FSL__Related_Service__c);
                        lstar.add(ar);

                    }
                    else {
                        system.debug('Could not create Assigned Resource for ' +sa.id +' because a value is missing on the new appointment. ');
                    }
                }
            }

            if(lstar.size() > 0 ) 
            {
                    try{ insert lstar; }
                    catch(Exception ex)
                    { System.debug('Error creating assigned resource ' +ex.getMessage()); }
            }
        }//end if lstcreatenewsa size > 0

        system.debug('********** END CreateFollowUpAppointment ***********');
    }



    //jjackson when the site survey appointment is complete, change the ownership of the site survey back to the install manager
    //also change the parent FWO status to Work Completed and change the fwo ownership to the Work Completed queue
    public static void SurveyAppointmentCompleted(List<ServiceAppointment> lstnewtrig, Map<Id,ServiceAppointment> trigoldmap)
    {     
          Set<Id> ssid = New Set<Id>();
          List<Site_survey__c> lstupdss = new List<Site_Survey__c>();
          List<WorkOrder> lstclosefwo = New List<WorkOrder>();
          List<WorkOrder> lstupdclosefwo = New List<WorkOrder>();

          //get queue id for Field Work Order Complete queue for fwo ownership change
          Group closedgroup = [Select Id, Name from Group where Name = 'Field Work Order Completed' LIMIT 1];


          for(ServiceAppointment s :lstnewtrig)
          {
              //shawks BUG-00984: Should exclude Tech Assist Service Appointments
              if(s.site_survey__c != null && !s.Tech_Assist__c && (s.status == 'On-Site Completed' && trigoldmap.get(s.id).status != 'On-Site Completed' ))
              { 
                ssid.add(s.site_survey__c);
                WorkOrder wo = New WorkOrder(); //create a "blank" workorder record with only the id
                wo.id = s.parentrecordid;
                lstclosefwo.add(wo);  //add the "blank" workorder to the list for update later
              }
          }

          if(ssid.size() > 0)
          {
            Map<Id,Site_Survey__c> mapss = New Map<Id,Site_Survey__c>([Select Id, ownerid, install_manager__c from site_survey__c where
                                                                     id in :ssid ]);

            if(mapss.size() > 0)
            {
                for(Site_Survey__c ss :mapss.values())
                {   
                    if(ss.install_manager__c != null)
                    {
                        ss.ownerid = ss.install_manager__c;
                        lstupdss.add(ss);
                    }
                }
            }

          }

          if(lstclosefwo.size() > 0)
          {
              for(WorkOrder w :lstclosefwo)
              {
                  w.status = 'Work Completed';
                  w.ownerid = closedgroup.id;
                  lstupdclosefwo.add(w);
              }
          }

          if(lstupdss.size() > 0)
          {  update lstupdss; }

          if(lstupdclosefwo.size() > 0)
          {  update lstupdclosefwo; }

    }//end SurveyAppointmentCompleted


    public static void ChangeFWOOwnershiptoQueue(List<ServiceAppointment> lsttriggernew)
    {
        Set<Id> parentid = New Set<Id>();
        Group leadgroup = [Select Id, Name from Group where Name = 'Assign Site Survey FWO' LIMIT 1];
        List<WorkOrder> lstssfwo = New List<WorkOrder>();
        List<WorkOrder> lstupdssfwo = New List<WorkOrder>();

        for(ServiceAppointment sa :lsttriggernew)
        {
            //shawks BUG-00984: Do not change to queue if SA is a Tech Assist SA
            if(sa.site_survey__c != null && sa.FSL__related_service__c == null && !sa.tech_assist__c)//if the sa is linked to a site survey and it not a follow up
            { parentid.add(sa.parentrecordid ); } //separate the fwo id into a set for querying the fwo's

        }

        if(parentid.size() > 0 )
        {
            lstssfwo = [Select Id, ownerid from WorkOrder where id in :parentid ];
        }

        if(lstssfwo.size() > 0)
        {
            for(WorkOrder w :lstssfwo)
            {
                w.ownerid = leadgroup.id;
                lstupdssfwo.add(w);
            }
        }

        if(lstupdssfwo.size() > 0)
        {  update lstupdssfwo; }
    }

    //jjackson--also change site survey status to In Progress when status changes on service appointment
    public static void PopulateSiteSurveyScheduleDate(List<ServiceAppointment> lsttrigger, Map<Id,ServiceAppointment> trigoldmap)
    {
            system.debug('************BEGIN PopulateSiteSurveyScheduleDate****************');

            Map<Id, ServiceAppointment> mapssappt = New Map<Id, ServiceAppointment>();
            List<Site_Survey__c> lstss = new List<Site_Survey__c>();
            List<Site_Survey__c> lstupdss = new List<Site_Survey__c>();

            for(ServiceAppointment sa :lsttrigger)
            {
                if(sa.site_survey__c != null)
                {
                    mapssappt.put(sa.site_survey__c, sa);
                }
            }

            if(mapssappt.size() > 0)
            {
                lstss = [Select Id, status__c, survey_schedule_date__c from Site_Survey__c where id in :mapssappt.keyset() ];
            }

            if(lstss.size() > 0)
            {
                for(Site_Survey__c ss :lstss)
                {

                    Boolean updateflag = false;
                    ServiceAppointment s = New ServiceAppointment();
                    s = mapssappt.get(ss.id);

                    if(s.schedstarttime != null && s.schedstarttime != trigoldmap.get(s.id).schedstarttime)
                    {
                        Date start = date.valueof(s.schedstarttime);
                        ss.survey_schedule_date__c = start;
                        updateflag = true;
                    }

                    if(ss.status__c != null && ss.status__c != 'In Progress' && (s.status == 'In Progress' && trigoldmap.get(s.id).status != 'In Progress'))
                    {
                        ss.status__c = 'In Progress';
                        updateflag = true;
                        system.debug('update flag = ' +updateflag);
                    }

                    if(updateflag == true)
                    {
                        lstupdss.add(ss);
                    }
                }
            }

            if(lstupdss.size() > 0 )
            {  update lstupdss; }

            system.debug('*************END PopulateSiteSurveyScheduleDate****************');

    }//end PopulateSiteSurveyScheduleDate
    
    public static void PopulateGanttLabel(List<ServiceAppointment> lsttrigger)
    {
        Set<Id> setfwoid = New Set<Id>();
        List<WorkOrder> lstwo = New List<WorkOrder>();
        Map<Id,WorkOrder> mpwo = New Map<Id,WorkOrder>();
        
        for(ServiceAppointment s :lsttrigger)
        {
            if(s.ParentRecordId != null && string.valueof(s.ParentRecordId).startsWith('0WO'))
            {  setfwoid.add(s.parentrecordid); }
        }

        if(!setfwoid.IsEmpty())
        { 
            lstwo = [Select Id, Subject, Case.casenumber, priority from WorkOrder where Id in :setfwoid  ]; 
            
            for(WorkOrder wo :lstwo)
            { mpwo.put(wo.id, wo); }
            
        }

        for(ServiceAppointment sa :lsttrigger)
        {
            String label;

            if(mpwo.containskey(sa.parentrecordid))
            {
                WorkOrder getwo = mpwo.get(sa.parentrecordid);
                //shawks BUG-00984: Include "Tech Assist" in label if appropriate
                if(sa.Tech_Assist__c) { label = 'Tech Assist '+ sa.appointmentnumber; }
                else { label = sa.appointmentnumber; }

                if(sa.case__c != null)
                //{ label = sa.appointmentnumber +':  ' +getwo.case.casenumber +'  ' +getwo.priority; }
                { label = label +':  ' +getwo.case.casenumber +'  ' +getwo.priority; }
                else {
                  //label = sa.appointmentnumber +':  ' +getwo.subject; }
                  label = label +':  ' +getwo.subject; }
                //system.debug('gantt label value is ' +label);
            }
            sa.FSL__GanttLabel__c = label;
        }
    }
 
    public static void PopulateFWODatefromSA(List<ServiceAppointment> lsttriggersa, Map<Id,ServiceAppointment> trigoldmap)
    {
        system.debug('*************BEGIN Populate FWODatefromSA**************');

        Map<Id,WorkOrder> mpfwo = New Map<Id,WorkOrder>();
        List<WorkOrder> lstupdfwo = New List<WorkOrder>();
        Set<Id> setfwoid = New Set<Id>();

        for(ServiceAppointment s  :lsttriggersa)
        {
                if(s.ParentRecordId != null && string.valueof(s.ParentRecordId).startsWith('0WO'))
                {  setfwoid.add(s.parentrecordid); }
        }

        for(WorkOrder w : [Select Id, Date__c from WorkOrder where id in :setfwoid])
        {   mpfwo.put(w.id, w); }


        if(trigoldmap != null)
        {
            for(ServiceAppointment sa :lsttriggersa)
            {
                
                {
                    if(trigoldmap.get(sa.id).actualstarttime == null && sa.actualstarttime != null ||
                       trigoldmap.get(sa.id).actualstarttime != sa.actualstarttime)
                    {
                        if(mpfwo.containskey(sa.parentrecordid))
                        {
                            WorkOrder wo = new WorkOrder();
                            wo = mpfwo.get(sa.parentrecordid);
                            wo.date__c = sa.actualstarttime;
                            lstupdfwo.add(wo);
                        }
                    }
                }
            }

            if(lstupdfwo.size() > 0)
            {
                try{ update lstupdfwo; }
                catch(Exception e)
                {
                    system.debug('ERROR updating FWO Date from SA actualstarttime: ' +e.getmessage());
                }
            }
        }

        system.debug('***************END PopulateFWODatefromSA**************** ');

    }//end PopulateFWODatefromSA

    public static void ChangeScheduledEndDatetoActual(List<ServiceAppointment> lsttriggernew, Map<Id,ServiceAppointment> trigoldmap)
    {
        for(ServiceAppointment s :lsttriggernew)
        {
            if(s.actualendtime != null && s.sonifi_work_order__c == null)
            {
                if(s.actualendtime != trigoldmap.get(s.id).actualendtime)
                {
                    s.schedendtime = s.actualendtime;
                }

            }
        }
    }

    public static void PopulateAccountandSiteSurveyInfo(List<ServiceAppointment> triggernewlist)
    {
        system.debug('*************BEGIN PopulateAccountandSiteSurveyInfo**************');

        List<WorkType> lstwt = New List<WorkType>();
        List<ServiceAppointment> lstsa = New List<ServiceAppointment>();
        Map<String,WorkType> wtmap = New Map<String,WorkType>();
        Set<Id> setfwoid = New Set<Id>();
        Id rectypeid = Utilities.RecordTypeNametoId('WorkOrder', 'Site Survey Work Order');
        lstwt = [Select Id, Name, estimatedduration from WorkType];

        FSL__Scheduling_Policy__c policy = New FSL__Scheduling_Policy__c();

        if(!test.isRunningTest())
        {  policy = [ Select Id, Name from FSL__Scheduling_Policy__c where Name = 'Site Survey' LIMIT 1]; }

        for(WorkType w :lstwt)
        {
            wtmap.put(w.name,w);
        }

        //get the site survey scheduling policy


        for(ServiceAppointment sa :triggernewlist)
        {   
            setfwoid.add(sa.parentrecordid); 
        }

        Map<Id,WorkOrder> mpfwo = New Map<Id,WorkOrder>([Select Id, site_survey__c, due_date__c, accountid, worktypeid, recordtype.Name, Duration,
                                  DurationType from WorkOrder
                                  where Id in :setfwoid AND recordtype.Name = 'Site Survey Work Order']);

        for(ServiceAppointment s :triggernewlist)
        {
            if(mpfwo.containskey(s.parentrecordid))
            {
                WorkOrder fwo = New WorkOrder();
                fwo = mpfwo.get(s.parentrecordid);
                s.Site_Survey__c = fwo.site_survey__c;
                s.Account_Name__c = fwo.AccountId;
                if(fwo.Due_Date__c != null)
                { s.duedate = fwo.due_date__c; }
                s.Duration = fwo.duration;
                s.DurationType = fwo.durationtype;
                s.Field_Work_Order__c = fwo.id;
                s.SA_Type__c = 'Survey';
                s.earlieststarttime = system.now().adddays(-3);

                if(!test.isRunningTest())
                {
                    if(policy != null)
                    { s.FSL__Scheduling_Policy_Used__c = policy.id; }
                }
                                     

            }
        }//end for loop triggernewlist

        system.debug('*****************END PopulateAccountandsiteSurveyInfo****************');

    }//end populate account and sitesurvey method

    public static void UpdateScheduledEndfromDuration(List<ServiceAppointment> lstsatrigger, Map<Id,ServiceAppointment> trigoldmap)
    {
        for(ServiceAppointment sa :lstsatrigger)
        {
            if(sa.Duration != null && sa.Duration != trigoldmap.get(sa.id).Duration)
            {
                if(sa.SchedEndTime != null)
                {
                    Datetime newend = sa.SchedStartTime.addHours(Integer.valueof(sa.Duration));
                    sa.schedendtime = newend;
                }
            }
        }
    }

//jjackson 8/2019 upon insert or update, change the sa ownership, parent record ownership and site survey ownership
//to whoever the Technician Assigned is on the service appointment
//jjackson--at business request, added code that will update the site survey status to In Progress when the service appointment
//status changes to In Progress
public static void TechnicianAssignedUpdatesOwnership(List<ServiceAppointment> lstsa, String triggertype, Map<Id,ServiceAppointment> trigoldmap)
{
    Set<Id> parentfwoid = New Set<Id>();
    Set<Id> srid = New Set<Id>();
    List<WorkOrder> lstparents = New List<WorkOrder>();
    List<WorkOrder> lstupdfwo = New List<WorkOrder>();
    List<ServiceResource> lstsr = New List<ServiceResource>();
    List<Site_Survey__c> lstupdss = New List<Site_Survey__c>();
    Map<Id,ServiceResource> mpsr = New Map<Id,ServiceResource>();
    Map<Id,WorkOrder> mpfwo = New Map<Id,WorkOrder>();
    List<ServiceAppointment> lstinsertsa = New List<ServiceAppointment>();
    List<ServiceAppointment> lstupdatesa = new List<ServiceAppointment>();

    //FYI this code will sometimes fail if someone is attempting to assign a new appointment to someone and
    //the parent field work order is in a queue.  If the person attempting to assign the appointment is not in 
    //the queue that owns the FWO, this code will fail.  We can't tweak this code to ignore changing the fwo
    //ownership if the fwo is in a queue.  The reason is because if the fwo is in the Assign Site Survey FWO
    //queue, we want the fwo ownership to change when a Lead Tech (who is a member of that queue) assigns a
    //site survey FWO to a tech.  Also, if the parent FWO is already going through the billing process and is in
    //an approver queue, there shouldn't be any new appointments being created/assigned for that FWO.

    for(ServiceAppointment sa :lstsa)
    {
        if(String.valueof(sa.parentrecordid).left(3) == '0WO')
        {  parentfwoid.add(sa.parentrecordid); 
           
           if(sa.Technician_Assigned__c != null)
           {  srid.add(sa.Technician_Assigned__c); }
        }
    }

    if(parentfwoid.size() > 0 )
    {
        lstparents = [Select Id, Ownerid, site_survey__c, site_survey__r.id, site_survey__r.ownerid from WorkOrder where Id in :parentfwoid ];
        for(WorkOrder w :lstparents)
        {
            mpfwo.put(w.id,w);
        }
    }

    if(srid.size() > 0)
    {
        lstsr = [ Select Id, userinfo__c from ServiceResource where Id in :srid ];
        for(ServiceResource sr :lstsr)
        {
            mpsr.put(sr.id,sr);
        }

    }

        for(ServiceAppointment sa :lstsa)
        {
            Id userid; 

            if(triggertype == 'Insert' && sa.Technician_Assigned__c != null)
            {
                if(mpsr.containskey(sa.Technician_Assigned__c))
                {  userid = mpsr.get(sa.technician_assigned__c).userinfo__c; 

                    sa.ownerid = userid;
                    //shawks BUG-00984: Do not change FWO or Site Survey Ownership if SA is a Tech Assist
                    if(mpfwo.containskey(sa.ParentRecordId) && !sa.Tech_Assist__c)
                    {
                        WorkOrder fwo = mpfwo.get(sa.parentrecordid);
                        {fwo.ownerid = userid;}
                        

                        if(fwo.Site_Survey__c != null)
                        {  
                            Site_Survey__c ss = New Site_Survey__c();
                            ss.id = fwo.Site_Survey__r.id;
                            ss.ownerid = userid;
                            ss.status__c = 'Scheduled';
                            lstupdss.add(ss);
                        }

                        lstupdfwo.add(fwo);
                    }
                }
            }

            if(triggertype == 'Update' && sa.Technician_Assigned__c != null)
            {
                    if(sa.Technician_Assigned__c != trigoldmap.get(sa.id).Technician_Assigned__c)
                    {
                        if(mpsr.containskey(sa.Technician_Assigned__c))
                        {
                            userid = mpsr.get(sa.technician_assigned__c).userinfo__c; 

                            sa.ownerid = userid;
                            //shawks BUG-00984: Do not change FWO or Site Survey Ownership if SA is a Tech Assist
                            if(mpfwo.containskey(sa.ParentRecordId) && !sa.Tech_Assist__c)
                            {
                                WorkOrder fwo = mpfwo.get(sa.parentrecordid);
                                fwo.ownerid = userid;

                                if(fwo.Site_Survey__c != null)
                                {  
                                    Site_Survey__c ss = New Site_Survey__c();
                                    ss.id = fwo.Site_Survey__r.id;
                                    ss.ownerid = userid;
                                    ss.Status__c = 'Scheduled';

    
                                    lstupdss.add(ss);
                                }

                                lstupdfwo.add(fwo);
                            }
                        }
                    }
                }//end if trigger = update
        }//end for loop service appointment

        if(lstupdfwo.size() > 0)
        {
            update lstupdfwo;
        }

        if(lstupdss.size() > 0)
        {  update lstupdss; }

}//end TechnicianAssignedUpdatesOwnership method

}//end standardserviceappointmenttriggerlogic.cls