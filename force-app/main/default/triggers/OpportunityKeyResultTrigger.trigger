trigger OpportunityKeyResultTrigger on Opportunity (after insert, after update, after delete, after undelete) {
    Set<Id> targetIds = new Set<Id>();

    // 1. Collect the Target IDs when Opportunities are created or updated
    if (Trigger.isInsert || Trigger.isUpdate || Trigger.isUndelete) {
        for (Opportunity o : Trigger.new) {
            if (o.Target__c != null) {
                targetIds.add(o.Target__c);
            }
        }
    }
    
    // 2. Collect the IDs when Opportunities are deleted or reparented
    if (Trigger.isDelete || Trigger.isUpdate) {
        for (Opportunity o : Trigger.old) {
            if (o.Target__c != null) {
                targetIds.add(o.Target__c);
            }
        }
    }

    // 3. Update the Completed count
    if (!targetIds.isEmpty()) {
        Map<Id, Target__c> targetsToUpdate = new Map<Id, Target__c>();
        for (Id tId : targetIds) {
            targetsToUpdate.put(tId, new Target__c(Id = tId, Completed__c = 0));
        }
        
        
        // Count the related Opportunities
        for (AggregateResult ar : [SELECT Target__c, COUNT(Id) OpportunityCount FROM Opportunity WHERE Target__c IN :targetIds GROUP BY Target__c]) {
            Id tId = (Id)ar.get('Target__c');
            targetsToUpdate.get(tId).Completed__c = (Integer)ar.get('OpportunityCount');
        }
        
        update targetsToUpdate.values();
    }
}