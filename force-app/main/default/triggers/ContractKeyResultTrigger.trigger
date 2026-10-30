trigger ContractKeyResultTrigger on Contract (after insert, after update, after delete, after undelete) {
    Set<Id> targetIds = new Set<Id>();
    
    // Define the specific Contract Types to track in a Set
    Set<String> trackedTypes = new Set<String>{'Monthly', 'Annual', 'Renewal'};

    // 1. Collect IDs ONLY for the specific Contract Types
    if (Trigger.isInsert || Trigger.isUpdate || Trigger.isUndelete) {
        for (Contract c : Trigger.new) {
            // Check if the picklist value is inside our trackedTypes list
            if (c.Target__c != null && trackedTypes.contains(c.Contract_types__c)) {
                targetIds.add(c.Target__c);
            }
        }
    }
    
    // 2. Collect IDs when specific Contracts are deleted or reparented
    if (Trigger.isDelete || Trigger.isUpdate) {
        for (Contract c : Trigger.old) {
            if (c.Target__c != null && trackedTypes.contains(c.Contract_types__c)) {
                targetIds.add(c.Target__c);
            }
        }
    }

    // 3. Update the Completed count using an Aggregate Query
    if (!targetIds.isEmpty()) {
        Map<Id, Target__c> targetsToUpdate = new Map<Id, Target__c>();
        for (Id tId : targetIds) {
            targetsToUpdate.put(tId, new Target__c(Id = tId, Completed__c = 0));
        }
        
        // Filter the SOQL query 
        for (AggregateResult ar : [SELECT Target__c, COUNT(Id) ContractCount 
                                   FROM Contract 
                                   WHERE Target__c IN :targetIds 
                                   AND Contract_types__c IN :trackedTypes 
                                   GROUP BY Target__c]) {
            Id tId = (Id)ar.get('Target__c');
            targetsToUpdate.get(tId).Completed__c = (Integer)ar.get('ContractCount');
        }
        
        update targetsToUpdate.values();
    }
}