trigger GoogleReviewKeyResultTrigger on Google_Review__c (after insert, after update, after delete, after undelete) {
    Set<Id> targetIds = new Set<Id>();

    // 1. Collect the Target IDs when Case_Study__c are created or updated
    if (Trigger.isInsert || Trigger.isUpdate || Trigger.isUndelete) {
        for (Google_Review__c gr : Trigger.new) {
            if (gr.Target__c != null) {
                targetIds.add(gr.Target__c);
            }
        }
    }
    
    // 2. Collect the IDs when Case_Study__c are deleted or reparented
    if (Trigger.isDelete || Trigger.isUpdate) {
        for (Google_Review__c gr : Trigger.old) {
            if (gr.Target__c != null) {
                targetIds.add(gr.Target__c);
            }
        }
    }

    // 3. Update the Completed count using an Aggregate Query
    if (!targetIds.isEmpty()) {
        // Default to 0 in case the last Case_Study__c is deleted
        Map<Id, Target__c> targetsToUpdate = new Map<Id, Target__c>();
        for (Id tId : targetIds) {
            targetsToUpdate.put(tId, new Target__c(Id = tId, Completed__c = 0));
        }
        
        // Count the related Case_Study__c
        for (AggregateResult ar : [SELECT Target__c, COUNT(Id) GoogleReviewCount FROM Google_Review__c WHERE Target__c IN :targetIds GROUP BY Target__c]) {
            Id tId = (Id)ar.get('Target__c');
            targetsToUpdate.get(tId).Completed__c = (Integer)ar.get('GoogleReviewCount');
        }
        
        update targetsToUpdate.values();
    }
}