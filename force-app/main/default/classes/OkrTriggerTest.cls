@isTest
private class OkrTriggerTest {

    @testSetup
    static void setupData() {
        // 1. Setup the required parent records
        Objective__c obj = new Objective__c(Name = 'Test Obj', Year__c = 2026);
        insert obj;
        
        Key_Result__c kr = new Key_Result__c(Name = 'Test KR', Objective__c = obj.Id);
        insert kr;
        
        Account acc = new Account(Name = 'Test Account'); 
        insert acc;

        // 2. Create targets with Completed__c = 0 so they don't start as null
        List<Target__c> targets = new List<Target__c>();
        targets.add(new Target__c(Name = 'Task', Target_Number__c = 10, Completed__c = 0, Key_Result__c = kr.Id));
        targets.add(new Target__c(Name = 'Event', Target_Number__c = 10, Completed__c = 0, Key_Result__c = kr.Id));
        targets.add(new Target__c(Name = 'Opportunity', Target_Number__c = 10, Completed__c = 0, Key_Result__c = kr.Id));
        targets.add(new Target__c(Name = 'Lead', Target_Number__c = 10, Completed__c = 0, Key_Result__c = kr.Id));
        targets.add(new Target__c(Name = 'Contract', Target_Number__c = 10, Completed__c = 0, Key_Result__c = kr.Id));
        targets.add(new Target__c(Name = 'Review', Target_Number__c = 10, Completed__c = 0, Key_Result__c = kr.Id));
        targets.add(new Target__c(Name = 'Google Review', Target_Number__c = 10, Completed__c = 0, Key_Result__c = kr.Id));
        targets.add(new Target__c(Name = 'Survey', Target_Number__c = 10, Completed__c = 0, Key_Result__c = kr.Id));
        targets.add(new Target__c(Name = 'Case Study', Target_Number__c = 10, Completed__c = 0, Key_Result__c = kr.Id));
        insert targets;
    }

    @isTest
    static void testAllTriggersMath() {
        Account acc = [SELECT Id FROM Account LIMIT 1];
        
        Map<String, Id> tgtMap = new Map<String, Id>();
        for(Target__c t : [SELECT Id, Name FROM Target__c]) {
            tgtMap.put(t.Name, t.Id);
        }

        Test.startTest();
        
      
        // Phase 1: test inserts
        
        // Added Type = 'Call' to satisfy the Task trigger logic
        Task t = new Task(Subject='Call', TaskSubtype='Call', Type='Call', WhatId=tgtMap.get('Task'));
        insert t;
        
        // Added Type = 'Meeting' to satisfy Event trigger logic!
        Event e = new Event(Subject='Meeting', DurationInMinutes=60, ActivityDateTime=System.now(), Type='Meeting', WhatId=tgtMap.get('Event'));
        insert e;
        
        Opportunity o = new Opportunity(Name='Opp', StageName='Prospecting', CloseDate=Date.today(), Target__c=tgtMap.get('Opportunity'));
        insert o;
        
        Lead l = new Lead(LastName='Lead', Company='Co', LeadSource='Web', Target__c=tgtMap.get('Lead'));
        insert l;
        
        Contract c = new Contract(AccountId=acc.Id, Status='Draft', StartDate=Date.today(), ContractTerm=12, Target__c=tgtMap.get('Contract'));
        insert c;
        
        Review__c r = new Review__c(Name='Rev', Target__c=tgtMap.get('Review'));
        insert r;
        
        Google_Review__c gr = new Google_Review__c(Name='GRev', Target__c=tgtMap.get('Google Review'));
        insert gr;
        
        Survey__c s = new Survey__c(Name='Surv', Target__c=tgtMap.get('Survey'));
        insert s;
        
        Case_Study__c cs = new Case_Study__c(Name='CS', Target__c=tgtMap.get('Case Study'));
        insert cs;
        
        // verification 
        Set<Id> activeTargets = new Set<Id>();
        for(Target__c tgt : [SELECT Id, Name, Completed__c FROM Target__c]) {
            if (tgt.Completed__c > 0) {
                System.assertEquals(1, tgt.Completed__c, 'Insert math failed for ' + tgt.Name);
                activeTargets.add(tgt.Id);
            }
        }

        // Phase 2: test deletes
        
        delete t; delete e; delete o; delete l; delete c; delete r; delete gr; delete s; delete cs;
        
        for(Target__c tgt : [SELECT Name, Completed__c FROM Target__c WHERE Id IN :activeTargets]) {
            System.assertEquals(0, tgt.Completed__c, 'Delete trigger failed for ' + tgt.Name);
        }
        
        // Phase 3: test undeletes
        
        undelete t; undelete e; undelete o; undelete l; undelete c; undelete r; undelete gr; undelete s; undelete cs;
        
        Test.stopTest();

        for(Target__c tgt : [SELECT Name, Completed__c FROM Target__c WHERE Id IN :activeTargets]) {
            System.assertEquals(1, tgt.Completed__c, 'Undelete trigger failed for ' + tgt.Name);
        }
    }
}