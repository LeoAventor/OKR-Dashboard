trigger ReviewKeyResultTrigger on Review__c (after insert, after update, after delete, after undelete) {
    Set<Id> targetIds = new Set<Id>();

    // 1. Collect the Target IDs when Reviews are created or updated
    if (Trigger.isInsert || Trigger.isUpdate || Trigger.isUndelete) {
        for (Review__c r : Trigger.new) {
            if (r.Target__c != null) {
                targetIds.add(r.Target__c);
            }
        }
    }
    
    // 2. Collect the IDs when Reviews are deleted or reparented
    if (Trigger.isDelete || Trigger.isUpdate) {
        for (Review__c r : Trigger.old) {
            if (r.Target__c != null) {
                targetIds.add(r.Target__c);
            }
        }
    }

    // 3. Update the Completed count using an Aggregate Query
    if (!targetIds.isEmpty()) {
        // Default to 0 in case the last Review is deleted
        Map<Id, Target__c> targetsToUpdate = new Map<Id, Target__c>();
        for (Id tId : targetIds) {
            targetsToUpdate.put(tId, new Target__c(Id = tId, Completed__c = 0));
        }
        
        // Count the related Reviews
        for (AggregateResult ar : [SELECT Target__c, COUNT(Id) ReviewCount FROM Review__c WHERE Target__c IN :targetIds GROUP BY Target__c]) {
            Id tId = (Id)ar.get('Target__c');
            targetsToUpdate.get(tId).Completed__c = (Integer)ar.get('ReviewCount');
        }
        
        update targetsToUpdate.values();
    }
}