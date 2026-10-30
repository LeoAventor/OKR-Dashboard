trigger LeadKeyResultTrigger on Lead (after insert, after update, after delete, after undelete) {
    Set<Id> targetIds = new Set<Id>();

    // 1. Collect Target IDs only for Web Leads
    if (Trigger.isInsert || Trigger.isUpdate || Trigger.isUndelete) {
        for (Lead l : Trigger.new) {
            if (l.Target__c != null && l.LeadSource == 'Web') {
                targetIds.add(l.Target__c);
            }
        }
    }
    
    // 2. Collect Target IDs when Web Leads are deleted or changed
    if (Trigger.isDelete || Trigger.isUpdate) {
        for (Lead l : Trigger.old) {
            if (l.Target__c != null && l.LeadSource == 'Web') {
                targetIds.add(l.Target__c);
            }
        }
    }

    // 3. Update the Completed count
    if (!targetIds.isEmpty()) {
        Map<Id, Target__c> targetsToUpdate = new Map<Id, Target__c>();
        for (Id tId : targetIds) {
            targetsToUpdate.put(tId, new Target__c(Id = tId, Completed__c = 0));
        }
        
        // Count the related Leads where LeadSource is 'Web'
        for (AggregateResult ar : [SELECT Target__c, COUNT(Id) leadCount FROM Lead WHERE Target__c IN :targetIds AND LeadSource = 'Web' GROUP BY Target__c]) {
            Id tId = (Id)ar.get('Target__c');
            targetsToUpdate.get(tId).Completed__c = (Integer)ar.get('leadCount');
        }
        
        update targetsToUpdate.values();
    }
}