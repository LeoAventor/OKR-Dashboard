trigger CallsKeyResultTrigger on Task (after insert, after update, after delete, after undelete) {
    Set<Id> targetIds = new Set<Id>();

    // Calls Types to track in a Set
    Set<String> trackedTypes = new Set<String>{'Incoming', 'Outgoing', 'Missed'};


    // 1. Target IDs when Calls are created or updated
    if (Trigger.isInsert || Trigger.isUpdate || Trigger.isUndelete) {
        for (Task t : Trigger.new) {
            if (t.WhatId != null && t.WhatId.getSObjectType().getDescribe().getName() == 'Target__c' && t.TaskSubtype == 'Call' && trackedTypes.contains(t.Type)) {
                targetIds.add(t.WhatId);
            }
        }
    }
    
    // 2. IDs when Calls are deleted or reparented
    if (Trigger.isDelete || Trigger.isUpdate) {
        for (Task t : Trigger.old) {
            if (t.WhatId != null && t.WhatId.getSObjectType().getDescribe().getName() == 'Target__c' && t.TaskSubtype == 'Call' && trackedTypes.contains(t.Type)) {
                targetIds.add(t.WhatId);
            }
        }
    }

    // 3. Completed count using an Aggregate Query
    if (!targetIds.isEmpty()) {
        // Default to 0 in case the last Event is deleted
        Map<Id, Target__c> targetsToUpdate = new Map<Id, Target__c>();
        for (Id tId : targetIds) {
            targetsToUpdate.put(tId, new Target__c(Id = tId, Completed__c = 0));
        }
        
        // Count the related Events 
        for (AggregateResult ar : [SELECT WhatId, COUNT(Id) taskCount 
                                   FROM Task 
                                   WHERE WhatId IN :targetIds
                                   AND TaskSubtype = 'Call' 
                                   AND Type IN :trackedTypes
                                   GROUP BY WhatId]) {
            Id tId = (Id)ar.get('WhatId');
            targetsToUpdate.get(tId).Completed__c = (Integer)ar.get('taskCount');
        }
        
        update targetsToUpdate.values();
    }
}