global class BatchPMWorkOrderScheduler implements schedulable {
    
    global void execute(SchedulableContext context) {

        BatchPMWorkOrder b = New BatchPMWorkOrder();
        database.executeBatch(b);

    }
}

/*  run the below code in Execute Anonymous to add the job to the cron

BatchPMWorkOrderScheduler b = new BatchPMWorkOrderScheduler();
String sch = '0 0 1 1 * ? *';
system.schedule('PMWorkOrderBatchMonthly', sch, b);


*/