//jjackson 11/2019: This test supplies code coverage for both SupportTeamAccountExtension.cls and
//SupportTeamCaseExtenion.cls

@isTest(seealldata=true)
public with sharing class SupportTeamAccountExtTest {
    
    static testmethod void testSupportTeamAcctExtension()
    {
        Account acc = [Select id, site_id__c from Account where site_id__c = '0030577'];
		

		ApexPages.StandardController sc = new ApexPages.StandardController(acc);
        SupportTeamAccountExtension testacc = New SupportTeamAccountExtension(sc);
   		PageReference pageRef = Page.SupportTeamAccountFSL;
   		pageRef.getParameters().put('Id', String.valueOf(acc.id));
   		Test.setCurrentPage(pageRef);

        
    }

    static testmethod void testSupportTeamCaseExt()
    {
        
        Case c = [Select id, casenumber, accountid from Case where casenumber = '02392673'];
		

		ApexPages.StandardController sc = new ApexPages.StandardController(c);
        SupportTeamCaseExtension testc = New SupportTeamCaseExtension(sc);
   		PageReference pageRef = Page.SupportTeamCaseFSLPage;
   		pageRef.getParameters().put('Id', String.valueOf(c.id));
   		Test.setCurrentPage(pageRef);
    }

}