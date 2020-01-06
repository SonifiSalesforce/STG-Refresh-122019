import { LightningElement, api, track, wire  } from 'lwc';
import { getRecord, createRecord } from 'lightning/uiRecordApi';
import { NavigationMixin } from 'lightning/navigation';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';

import SA_OBJECT from '@salesforce/schema/ServiceAppointment';
import ACCOUNT_ID_FIELD from '@salesforce/schema/ServiceAppointment.AccountId';
import STREET_FIELD from '@salesforce/schema/ServiceAppointment.Street';
import CITY_FIELD from '@salesforce/schema/ServiceAppointment.City';
import STATE_FIELD from '@salesforce/schema/ServiceAppointment.State';
import POSTALCODE_FIELD from '@salesforce/schema/ServiceAppointment.PostalCode';
import COUNTRY_FIELD from '@salesforce/schema/ServiceAppointment.Country';
import CASE_FIELD from '@salesforce/schema/ServiceAppointment.Case__c';
import DESCRIPTION_FIELD from '@salesforce/schema/ServiceAppointment.Description';
import DUEDATE_FIELD from '@salesforce/schema/ServiceAppointment.DueDate';
import DURATION_FIELD from '@salesforce/schema/ServiceAppointment.Duration';
import DURATION_TYPE_FIELD from '@salesforce/schema/ServiceAppointment.DurationType';
import EARLIEST_STATEDATE_FIELD from '@salesforce/schema/ServiceAppointment.EarliestStartTime';
import FIELD_WO_FIELD from '@salesforce/schema/ServiceAppointment.Field_Work_Order__c';
import GANTT_LABEL_FIELD from '@salesforce/schema/ServiceAppointment.FSL__GanttLabel__c';
import PARENTID_FIELD from '@salesforce/schema/ServiceAppointment.ParentRecordId';
import PARENT_RECORDTYPE_FIELD from '@salesforce/schema/ServiceAppointment.ParentRecordType';
import RECORDTYPE_FIELD from '@salesforce/schema/ServiceAppointment.RecordTypeId';
import SA_TYPE_FIELD from '@salesforce/schema/ServiceAppointment.SA_Type__c';
import SCHED_ENDTIME_FIELD from '@salesforce/schema/ServiceAppointment.SchedEndTime';
import SCHED_STARTTIME_FIELD from '@salesforce/schema/ServiceAppointment.SchedStartTime';
import SCHED_POLICY_USED_FIELD from '@salesforce/schema/ServiceAppointment.FSL__Scheduling_Policy_Used__c';
import SERVICE_TERR_ID_FIELD from '@salesforce/schema/ServiceAppointment.ServiceTerritoryId';
import SONIFI_WO_FIELD from '@salesforce/schema/ServiceAppointment.Sonifi_Work_Order__c';
import STATUS_CAT_FIELD from '@salesforce/schema/ServiceAppointment.StatusCategory';
import SUBJECT_FIELD from '@salesforce/schema/ServiceAppointment.Subject';
import WORKTYPE_ID_FIELD from '@salesforce/schema/ServiceAppointment.WorkTypeId';
import TECH_ASSIST_FIELD from '@salesforce/schema/ServiceAppointment.Tech_Assist__c'
import APPNUM_FIELD from '@salesforce/schema/ServiceAppointment.AppointmentNumber';

const nameFields = [
    ACCOUNT_ID_FIELD,
    STREET_FIELD,
    CITY_FIELD,
    STATE_FIELD,
    POSTALCODE_FIELD,
    COUNTRY_FIELD,
    CASE_FIELD,
    DESCRIPTION_FIELD,
    DUEDATE_FIELD,
    DURATION_FIELD,
    DURATION_TYPE_FIELD,
    EARLIEST_STATEDATE_FIELD,
    FIELD_WO_FIELD,
    GANTT_LABEL_FIELD,
    PARENTID_FIELD,
    PARENT_RECORDTYPE_FIELD,
    RECORDTYPE_FIELD,
    SA_TYPE_FIELD,
    SCHED_ENDTIME_FIELD,
    SCHED_STARTTIME_FIELD,
    SCHED_POLICY_USED_FIELD,
    SERVICE_TERR_ID_FIELD,
    SONIFI_WO_FIELD,
    STATUS_CAT_FIELD,
    SUBJECT_FIELD,
    WORKTYPE_ID_FIELD,
    APPNUM_FIELD
];

export default class TechAssist_LWC extends NavigationMixin(LightningElement) {
    @api recordId;
    @api greeting;
    @track isSelected = false;
    @track showTAButton = false;
    @track recordPageUrl;

    @wire(getRecord, { recordId: '$recordId', fields: nameFields }) SA_record;

    //Opens the created SA (compatible with VF and LE)
    openTAClick() {
        const SA_Link = '/' + this.SA_TA_Id;
        window.open(SA_Link);
    }

    //Create Tech Assist SA
    create_TA() {
        if (!this.isSelected){
            this.isSelected = true;  //Change button so cannot click more than once
            const SA_fields = {};
            SA_fields[TECH_ASSIST_FIELD.fieldApiName] =  true;  //If true then do not update Case and FWO ownership (trigger and process builder)
            SA_fields[DUEDATE_FIELD.fieldApiName] = this.SA_record.data.fields.DueDate.value;
            SA_fields[DURATION_FIELD.fieldApiName] = this.SA_record.data.fields.Duration.value;
            SA_fields[DURATION_TYPE_FIELD.fieldApiName] = this.SA_record.data.fields.DurationType.value;
            SA_fields[EARLIEST_STATEDATE_FIELD.fieldApiName] = this.SA_record.data.fields.EarliestStartTime.value;
            SA_fields[PARENTID_FIELD.fieldApiName] = this.SA_record.data.fields.ParentRecordId.value;
            SA_fields[SCHED_ENDTIME_FIELD.fieldApiName] = this.SA_record.data.fields.SchedEndTime.value;
            SA_fields[SCHED_STARTTIME_FIELD.fieldApiName] = this.SA_record.data.fields.SchedStartTime.value;
            SA_fields[SCHED_POLICY_USED_FIELD.fieldApiName] = this.SA_record.data.fields.FSL__Scheduling_Policy_Used__c.value;

            const SA_RecordInput = { apiName: SA_OBJECT.objectApiName, fields: SA_fields };
            createRecord(SA_RecordInput)  //Create new SA record
            .then(serviceappointment => {
                this.SA_TA_Id = serviceappointment.id;  //Will be used to open new SA

                //Make link button visible
                this.showTAButton = true;
            }) 
            .catch(error => {
                this.dispatchEvent(
                    new ShowToastEvent({
                        title: 'Error creating Tech Assist',
                        message: error.body.message,
                        variant: 'error',
                    }),
                );
            });
        }
    }
}