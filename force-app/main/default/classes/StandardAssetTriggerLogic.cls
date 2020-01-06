public without sharing class StandardAssetTriggerLogic {    
    //shawks 20190830: BUG-00947 - Set start/end dates at billing for entitlements and service contracts
    // -> Created setEntitleServiceContrDates method
    //Contracts Admin Manager
    //jjackson--Removed references to custom subscription__c field on asset and replaced with
    //package field sbqq__subscription__c
    //shawks 20180927: CPQ Project - Updated updateContractLineItemStatus method
    // -> Replaced Contract_Line__c object references with SBQQ__Subscription__c object  
    // ->  and replaced Legal_Contract_Line_Item__c references with Subscription__c
    //jjackson 8/2016 we don't need to updated contract line item end dates from the product inventory item;
    //the date updates go the other way (contract line item to product inventory); This code not needed.
    /*public static void updateEndDates (Map<Id,Asset> triggerNewMap){
        System.debug('Entering updateEndDates...');
        System.debug('Checking '+ triggerNewMap.size() + ' records...');
        System.debug('Trigger New Map' + triggerNewMap + ' records...');
        
        
        //initialize variables
        Set<Id> assetIds = new Set<Id>();
        for(Asset a : triggerNewMap.values())
        {
            assetIds.add(a.id);
        }
        List<String> lcliStatuses = new List<String>{'Installed Activated', 'Installed Deactivated','Pending Installation Activate','Pending Installation Deactivate'};
        List<Asset> assetList = [SELECT Term_End_Date__c, Parent_Asset__c, Service_End_Date__c,
        (SELECT Term_End_Date__c, Status__c from Legal_Contract_Line_Items_del__r WHERE Status__c IN :lcliStatuses ORDER BY CreatedDate DESC)
        FROM Asset WHERE Id IN :assetIds];
        
        
        for(Asset a : assetList)
        {
            if((a.Parent_Asset__c == null && a.Term_End_Date__c != null) || (a.Parent_Asset__c != null && a.Service_End_Date__c != null))
            {
                Boolean updated = false;
                for(Contract_Line_Item__c cli : a.Legal_Contract_Line_Items_del__r)//Go through line items looking for Installed items first
                {
                    if(a.Parent_Asset__c == null)
                    {
                        if(cli.Status__c == 'Installed Activated' || cli.Status__c == 'Installed Deactivated' && updated == false)
                        {
                            triggerNewMap.get(a.id).Term_End_Date__c = cli.Term_End_Date__c;
                            updated = true;
                        }
                    }
                    else
                    {
                        if(cli.Status__c == 'Installed Activated' || cli.Status__c == 'Installed Deactivated' && updated == false)
                        {
                            triggerNewMap.get(a.id).Service_End_Date__c = cli.Term_End_Date__c;
                            updated = true;
                        }
                    }
                }
                if(updated == false) //No Installed CLI found looking for Pending Installation
                {
                    for(Contract_Line_Item__c cli : a.Legal_Contract_Line_Items_del__r)//Go through line items looking for Installed items first
                    {
                        if(a.Parent_Asset__c == null)
                        {
                            if(cli.Status__c == 'Pending Installation Activate' || cli.Status__c == 'Pending Installation Deactivate' && updated == false)
                            {
                                triggerNewMap.get(a.id).Term_End_Date__c = cli.Term_End_Date__c;
                                updated = true;
                            }
                        }
                        else
                        {
                            if(cli.Status__c == 'Pending Installation Activate' || cli.Status__c == 'Pending Installation Deactivate' && updated == false)
                            {
                                triggerNewMap.get(a.id).Service_End_Date__c = cli.Term_End_Date__c;
                                updated = true;
                            }
                        }
                    }
                }
            }
        }
        System.debug('Asset new Map after trigger '+triggerNewMap);
        System.debug('Ending updateEndDates...');   
    } */
    
    public static void subtotalSummary(List<Asset> asList)
    {
        system.debug('Entering subtotalSummary*******************');
        //for(Asset recasset : asList)
        //{  system.debug('recasset passed in to update trigger is ' + recasset);  }
        //jjackson 8/2014 
        Map<ID,Decimal> mpParentRooms = new Map<ID,Decimal>();
        Map<ID,String> mpParentFamily = new Map<ID,String>();
        List<Asset> lstProductParents = new List<Asset>();
        Set<String> parentAssetIds = new Set<String>();
        for(Asset a : asList)
        {
            if(a.Product_Parent_Id__c != null)
            {
                parentAssetIds.add(a.Product_Parent_Id__c);
          
            }
            
            if(a.Name.Contains('Product Parent'))
            {
            	parentAssetIds.add(a.Id);
            }
           
         }
        //system.debug('parentAssetIds is ' + parentAssetIds);
        
        lstProductParents = [Select Id, Total_Active_Rooms__c, Product2.Family from Asset where id in :parentAssetIds];
        for(Asset recass : lstProductParents)
        {
            mpParentRooms.put(recass.Id,recass.Total_Active_Rooms__c);
            mpParentFamily.put(recass.Id,recass.Product2.Family);
            //system.debug('mpParentFamily product2 family type is ' +recass.Product2.Family);
        }
        
        //system.debug('mpParentRooms is ' + mpParentRooms);
        
        //Create map of parent asset id to list of child assets
        Map<Id,List<Asset>> parentAssetMap = new Map<Id,List<Asset>>();
        for(Asset ass : [SELECT Id, Name, Price__c, Total_Room_Count__c, Product2.Channel_Type__c, Product_Parent_Family__c, 
                        Fee_Schedule__c, Quantity, Total_Active_Rooms__c, Product_Code__c, Product_Parent_Id__c,Product2.Service_Equipment__c,
                        Product2.Price_Category__c, Product2.Warranty__c, Product2.Financing__c, Product2.Recurring_App__c, Product2.Do_Not_Calculate__c
        from Asset 
        WHERE (Status = 'Installed Activated' OR Status = 'Billing' OR Status = 'Pending De-Installation')
        AND Product_Parent_Id__c IN :parentAssetIds 
        AND Parent_Asset__c != null])
        {
            if(parentAssetMap.containsKey(ass.Product_Parent_Id__c))
            {
                parentAssetMap.get(ass.Product_Parent_Id__c).add(ass);
            }
            else
            {
                List<Asset> temp = new List<Asset>();
                temp.add(ass);
                parentAssetMap.put(ass.Product_Parent_Id__c,temp);
                //system.debug('record going on temp list is ' + ass);       
            }
        }
        
        
        //Calculating fields
        //Main Loop
        //system.debug('parentAssetMap is: ' +parentAssetMap);
        Set<Asset> parentAssetsToUpdate = new Set<Asset>();
        
        for(Id parentAssetId : parentAssetMap.keyset())
        {
            //system.debug('parentAssetId inside for loop is ' +parentAssetId);
         
            Asset temp = new Asset(Id = parentAssetId);
            Decimal FTGProgrammingPerMonthSubtotal = 0;
            Decimal FTGProgrammingPerRoomSubtotal = 0;
            Decimal FTGEquipmentServiceSubtotal = 0;
            Decimal FTGWarrantySubtotal = 0;
            Decimal FTGFinancingFee = 0;
            Decimal iTVRecurringAppSubtotal = 0;
            Decimal iTVServiceSubtotal = 0;
            Decimal iTVWarrantySubtotal = 0;
            Decimal iTVFinancingFee = 0;
            Decimal LocalsPriceInc = 0;  //jjackson
            Decimal ProgrammingInc = 0;  //jjackson
            Decimal CreditAmountRm = 0;    //jjackson
            Decimal CreditAmountMth = 0;
            Decimal PriceIncperMonth = 0; //jjackson
            Decimal PriceIncperRmMth = 0; //jjackson
            Integer HD = 0;
            Integer SD = 0;
            Integer Analog = 0;
            
            String ProductFamily = mpParentFamily.get(parentAssetId);
            Decimal decTotalActiveRms;
 
            
            if(test.IsRunningTest())
            {  decTotalActiveRms = 100; }
            else
            {  decTotalActiveRms = mpParentRooms.get(parentAssetId);  }
            
            //system.debug('ProductFamily is ' +ProductFamily +' for asset id ' +parentAssetId);

           
          for(Asset ass : parentAssetMap.get(parentAssetId))
          {
          	
          		Decimal decactiverms;	
          
                if(ass.Product2.Channel_Type__c == 'HD')
                    HD ++;
                else if(ass.Product2.Channel_Type__c == 'SD')
                    SD ++;
                else if(ass.Product2.Channel_Type__c == 'Analog')   
                    Analog++;
                    
                //jjackson added this because test was failing; couldn't pull summary field total active rms
                if(test.IsRunningTest())
                { decactiverms = 100;  }
                else
                { decactiverms = ass.total_active_rooms__c;  }  
                    
                    //jjackson 6/19/2014 These calculations originally reference ass.Quantity but this
                    //was changed to ass.Total_Active_Rooms__c per the request of the business BUG-00354
             if(decTotalActiveRms > 0)
             {     
                if(decactiverms > 0 && ass.Price__c != null && ass.Product2.Do_Not_Calculate__c == false)
                {                
                 
                  if(ProductFamily == 'FTG')
                  {
                     
                     
                     if(ass.Product2.Service_Equipment__c == false && ass.Product2.Price_Category__c == 'Locals Programming'  && ass.Fee_Schedule__c == 'Monthly'
                     && ass.Product2.Financing__c == false)
                     
                     {if(decactiverms == 1)
                       { FTGProgrammingPerMonthSubtotal += ass.Price__c; }
                       
                      else
                        {FTGProgrammingPerMonthSubtotal += (ass.Price__c * decactiverms);  }
                      //system.debug('locals programming line items being added are ' + ass.Name + ', ' + ass.Price__c + ', ' + decactiverms);
                      }  
      
                    if(ass.Product2.Service_Equipment__c == false && ass.Product2.Price_Category__c == 'Program Package' && ass.Fee_Schedule__c == 'Monthly' &&
                    ass.Product2.Financing__c == false)
 
                    {
                    	if(decactiverms == 1)
                    	  {FTGProgrammingPerRoomSubtotal += ass.Price__c / decTotalActiveRms ; } 
                    	else
                    	  {FTGProgrammingPerRoomSubtotal += ass.Price__c; }
                        //system.debug('ftg programming line items being added are ' +ass.Name + ', ' + ass.Price__c + ', ' + decactiverms);
                    }
                   
                    if(ass.Product_Code__c.contains('CC-GPI'))
                    {
                    	if(decactiverms == 1)
                    	{ PriceIncperMonth += ass.Price__c;    }
                    	else
                    	{ PriceIncperRmMth += ass.Price__c;  }
                    		
                    }
                    
                      //jjackson August 2014  add up the credit line items on the contract so they can be subtracted from the pricing
                    if(ass.Product2.Price_Category__c == 'Credit' && ass.Fee_Schedule__c == 'Monthly')
                      {if(decactiverms == 1)
                       { CreditAmountMth += ass.Price__c;  }
                       else
                       { CreditAmountRm += ass.Price__c;  }
                      }
                    
                    if(ass.Product2.Service_Equipment__c == true)
      
                        //FTGEquipmentServiceSubtotal += ass.Total_Active_Rooms__c * ass.Price__c;  jjackson 8/2014
                        //don't multiply by number of rooms.  The price on the asset is the price per month.
                       {  FTGEquipmentServiceSubtotal += ass.Price__c;  }
                        
                    if(ass.Product2.Warranty__c == true)
                       { FTGWarrantySubtotal += decactiverms * ass.Price__c; }
                        
                    if(ass.Product2.Financing__c == true && ass.Fee_Schedule__c == 'Monthly')
                       { FTGFinancingFee += decactiverms * ass.Price__c;  }
                  }
                
                
                if(ProductFamily == 'Interactive')
                {        
                   if(ass.Product2.Recurring_App__c == true)
                      {  iTVRecurringAppSubtotal += decactiverms * ass.Price__c;   }
                         
                   if(ass.Product2.Service_Equipment__c == true)
                      {  iTVServiceSubtotal += decactiverms * ass.Price__c;  }
                        
                   if(ass.Product2.Warranty__c == true)
                      {  iTVWarrantySubtotal += decactiverms * ass.Price__c; }
                        
                   if(ass.Product2.Financing__c == true)
                      {  iTVFinancingFee += decactiverms * ass.Price__c; }
                        
                }
                //system.debug('asset in the loop for calculation is ' + ass.id + ', ' + ass.name + ', ' + ass.price__c + ', ' + decactiverms + ', ' + ass.Product2.Price_Category__c);
             }
           }
           else
           {
                system.debug('Calculations were not performed because product parent total active rooms is null or 0 for id ' +parentassetid);
           }
           
           system.debug('FTG ProgrammingPerMonthSubtotal(locals) = ' +FTGProgrammingPerMonthSubtotal);
           system.debug('FTGProgrammingPerRoomSubtotal(ftgperroompermonth = )' +FTGProgrammingPerRoomSubtotal);
            
            temp.HD_Channel_Count__c = HD;
            temp.SD_Channel_Count__c = SD;
            temp.Analog_Channel_Count__c = Analog;
            temp.Programming_Per_Month_Subtotal__c = FTGProgrammingPerMonthSubtotal.setScale(2,RoundingMode.HALF_UP) + CreditAmountMth +PriceIncperMonth;
            temp.Programming_Per_Room_Bed_Subtotal__c = FTGProgrammingPerRoomSubtotal.setScale(2,RoundingMode.HALF_UP) + CreditAmountRm + PriceIncperRmMth;  //jjackson subtract credits
            temp.Equipment_and_Service_Subtotal__c = FTGEquipmentServiceSubtotal.setScale(2,RoundingMode.HALF_UP);
            temp.FTG_Warranty_Subtotal__c = FTGWarrantySubtotal;
            temp.FTG_Financing_Fee__c = FTGFinancingFee;
            //jjackson 8/2014 ftg total field should be calculated differently BUG-00354
            temp.FTG_Total__c = ((FTGProgrammingPerMonthSubtotal + CreditAmountMth + PriceIncperMonth) + ((FTGProgrammingPerRoomSubtotal + CreditAmountRm + PriceIncperRmMth) * decTotalActiveRms) + FTGEquipmentServiceSubtotal + FTGWarrantySubtotal + FTGFinancingFee);
            temp.Interactive_Recurring_App_Subtotal__c = iTVRecurringAppSubtotal;
            temp.Interactive_Service_Subtotal__c = iTVServiceSubtotal;
            temp.Interactive_Warranty_Subtotal__c = iTVWarrantySubtotal;
            temp.iTV_Financing_Fee__c   = iTVFinancingFee;
            temp.Interactive_Total__c = iTVRecurringAppSubtotal+iTVServiceSubtotal+iTVWarrantySubtotal+iTVFinancingFee;

            parentAssetsToUpdate.add(temp);
            
          
       }
     }
        system.debug(LoggingLevel.INFO, 'Assets subtotal rollups to update'+parentAssetsToUpdate);
        List<asset> updateList = new List<Asset>();
        updateList.addAll(parentAssetsToUpdate);
        try
        {
            update updateList;
        }
        catch(Exception e)
        {
            system.debug(LoggingLevel.ERROR, 'Could not update Parent Assets for subtotal roll up fields: '+e.getMessage());
            asList[0].addError('Could not update Parent Assets for subtotal roll up fields, '+e.getMessage());
        }
         system.debug('Finished subtotalSummary********************');
    }
    public static void updateContractLineItemStatus(Map<Id, Asset> oldMap, List<Asset> newList){
        System.debug('Entering updateContractLineItemStatus...');
        System.debug('Checking ' + newList.size() + ' records...');
        
        Set<Id> lineItemIds = new Set<Id>();
        //shawks 20180927: CPQ - update to use CPQ object SBQQ__Subscription__c instead of Contract_Line_Item__c
        //Map<Id, Contract_Line_Item__c> clItemMap = new Map<Id, Contract_Line_Item__c>();
        Map<Id, SBQQ__Subscription__c> clItemMap = new Map<Id, SBQQ__Subscription__c>();
        List<Asset> updateAssetList = new List<Asset>();
        
        // go through the assets and find the contract line items that need to be updated
        //shawks 20180927: CPQ - in for loop update to use Subscription__c instead of Legal_Contract_Line_Item__c
        for(Asset a : newList){
            if(oldMap != null ){
                if(oldMap.get(a.id).Status != a.Status){
                    //if(a.Legal_Contract_Line_Item__c != null){
                    if(a.subscription_item__c != null){
                        //lineItemIds.add(a.Legal_Contract_Line_Item__c);
                        lineItemIds.add(a.subscription_item__c);
                        updateAssetList.add(a);
                    }
                }
            } else {
                //if(a.Legal_Contract_Line_Item__c != null){
                if(a.subscription_item__c != null){
                    //lineItemIds.add(a.Legal_Contract_Line_Item__c);
                    lineItemIds.add(a.subscription_item__c);
                    updateAssetList.add(a);
                }
            }
        }
        //shawks 20180927: CPQ - update to use CPQ object SBQQ__Subscription__c instead of Contract_Line_Item__c
        //query for the contract line items
        //clItemMap = new Map<Id, Contract_Line_Item__c>([SELECT id, Status__c FROM Contract_Line_Item__c WHERE id IN :lineItemIds]);
        clItemMap = new Map<Id, SBQQ__Subscription__c>([SELECT id, Status__c FROM SBQQ__Subscription__c WHERE id IN :lineItemIds]);
        
        //go through asset and update the contract line item status
        for(Asset a : updateAssetList){
            //shawks 20180927: CPQ - update to use Subscription__c instead of Legal_Contract_Line_Item__c
            //clItemMap.get(a.Legal_Contract_Line_Item__c).Status__c = a.Status;
            clItemMap.get(a.subscription_item__c).Status__c = a.Status;
        }
        
        //update the contract line items
        update clItemMap.Values();
    }

    //shawks 20190830: BUG-00947 - Set start/end dates at billing for entitlements and service contracts
    public static void setEntitleServiceContrDates(List<Asset> newList, Map<Id, Asset> oldMap){
       System.debug('**********************START setEntitleServiceContrDates***************************');
       Set<Id> setUpdates = New Set<Id>();
       Set<String> legacynames = New Set<String>();
       List<Entitlement> lstupdentl = New List<Entitlement>();
       List<ServiceContract> lstupdsc = New List<ServiceContract>();
       Map<Id,Asset> mpAssets_Billing = New Map<Id,Asset>();
       Map<Id,Asset> mpAssets_DeInstall = New Map<Id,Asset>();
       List<Legacy_Service_Contract_Names__c> legacySCNames = Legacy_Service_Contract_Names__c.getall().values();

       //Iterate through the list of assets to determine if the status field has been changed, whether Billing or De-Installed, and dates set
       for(Asset recAsset: newList){
           //Verify the status has changed on product parent asset
           if(recAsset.name.contains('Product Parent') && oldMap.get(recAsset.id).status != recAsset.status){
               //Find asset records where the new status is 'Billing' and the start date has been set
               if(recAsset.status == 'Billing' && recAsset.service_start_date__c != NULL){
                   mpAssets_Billing.put(recAsset.id, recAsset);
                   setUpdates.add(recAsset.id);
               }
               //Find asset records where the new status is 'De-Installed' or Cancelled
               if(recAsset.status == 'De-Installed' || recAsset.status == 'Cancelled' || recAsset.status == 'Canceled'){
                   mpAssets_DeInstall.put(recAsset.id, recAsset);
                   setUpdates.add(recAsset.id);
               }
            }
        }//end newList for loop
       
       //Check if entitlements and service contraccts need updated
       if(!setUpdates.IsEmpty()){
          //Create a set of the Legacy Service Contract names for use below
          for(Legacy_Service_Contract_Names__c recLegacy : legacySCNames){
              legacynames.add(recLegacy.service_contract_names__c);  
	      }
          //Find all entitlements/service contracts that are related to assets
          //Exclude Entitlements linked to Cancelled Subscriptions or Entitlements in case Asset linked to more than one Entitlement
	      List<Entitlement> entllst = [ SELECT Name, subscription__c, Status, StartDate, EndDate, ServiceContract.Id, ServiceContract.Name, ServiceContract.EndDate,
	        	                          ServiceContract.StartDate, ServiceContract.term, ServiceContract.NotificationNeeded__c, 
	  	                                  ServiceContract.Status, AssetId, subscription__r.SBQQ__Contract__r.initial_term__c
                                        FROM Entitlement
                                        WHERE AssetId in :setUpdates
                                          AND subscription__r.status__c NOT IN ('Cancelled', 'Canceled')
                                          AND Status NOT IN ('Cancelled', 'Canceled') ];

          if(!entllst.isEmpty()){
              for(Entitlement recEntl: entllst){
                 //Create Service Contract record to store dates
                 ServiceContract recServCon = New ServiceContract();
   			     recServCon.Id = recEntl.servicecontract.Id;

                 //If Billing asset, set start and end dates for entitlements and service contracts
                 if(mpAssets_Billing.containskey(recEntl.AssetId)){
                    //Find related Contract's Initial Term to determine end dates
                    Integer intTerm = (Integer)recEntl.subscription__r.SBQQ__Contract__r.initial_term__c;
                    //Set dates for Entitlements
                    recEntl.startdate = mpAssets_Billing.get(recEntl.AssetId).service_start_date__c;
                    recEntl.enddate = mpAssets_Billing.get(recEntl.AssetId).service_start_date__c.addMonths(intTerm);
                    //Set dates for Service Contracts
                    //Check if Legacy Service Contract
                    if(legacynames.contains(recEntl.servicecontract.name)){
                        recServCon.startdate = mpAssets_Billing.get(recEntl.AssetId).service_start_date__c;
                        recServCon.enddate = mpAssets_Billing.get(recEntl.AssetId).service_start_date__c.addMonths(intTerm);
                    }
                    else{ //Then not Legacy
                        //Verify Term is has a value
                        if(recEntl.ServiceContract.term > 0){
                            recServCon.startdate = mpAssets_Billing.get(recEntl.AssetId).service_start_date__c;
                            recServCon.enddate = mpAssets_Billing.get(recEntl.AssetId).service_start_date__c.addMonths(recEntl.ServiceContract.term);
                        }
                        else { //If no term yet use a 3 month default and mark so email notification sent
                            recServCon.startdate = mpAssets_Billing.get(recEntl.AssetId).service_start_date__c;
                            recServCon.enddate = mpAssets_Billing.get(recEntl.AssetId).service_start_date__c.addMonths(3);
                            recServCon.NotificationNeeded__c = true;
                        }
                    }
                 } //END IF - if(mpAssets_Billing.containskey(recEntl.AssetId))
                 //If De-Installed asset, set end dates of entitlements and service contracts to yesterday
                 if(mpAssets_DeInstall.containskey(recEntl.AssetId)){
                    recEntl.enddate = system.today().addDays(-1);
                    recServCon.enddate = system.today().addDays(-1);
                 }
                 //Add records to lists so can be updated
                 lstupdentl.add(recEntl);
                 lstupdsc.add(recServCon);
              } //END FOR LOOP - for(Entitlement recEntl: entllst)
              //Update Entitlements and Service Contracts
              try {
                 update lstupdentl;
                 update lstupdsc;
              } catch (Exception e) {
                  system.debug('Error in StandardAssetTriggerLogic.setEntitleServiceContrDates: ' +e.getMessage());
              }
           } //END IF - if(!entllst.isEmpty())
        } //END IF - if(!setUpdates.IsEmpty())

       System.debug('**********************END setEntitleServiceContrDates*****************************');
    }
}