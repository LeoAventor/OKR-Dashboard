trigger EventKeyResultTrigger on Event (after insert, after update, after delete, after undelete) {
    Set<Id> targetIds = new Set<Id>();

    // Define the specific Event Types to track in a Set
    Set<String> trackedTypes = new Set<String>{'Email', 'Call', 'Meeting', 'Other'};


    // 1. Collect the Target IDs when Events are created or updated
    if (Trigger.isInsert || Trigger.isUpdate || Trigger.isUndelete) {
        for (Event e : Trigger.new) {
            if (e.WhatId != null && e.WhatId.getSObjectType().getDescribe().getName() == 'Target__c' && trackedTypes.contains(e.Type)) {
                targetIds.add(e.WhatId);
            }
        }
    }
    
    // 2. Collect the IDs when Events are deleted or reparented
    if (Trigger.isDelete || Trigger.isUpdate) {
        for (Event e : Trigger.old) {
            if (e.WhatId != null && e.WhatId.getSObjectType().getDescribe().getName() == 'Target__c' && trackedTypes.contains(e.Type)) {
                targetIds.add(e.WhatId);
            }
        }
    }

    // 3. Update the Completed count using an Aggregate Query
    if (!targetIds.isEmpty()) {
        // Default to 0 in case the last Event is deleted
        Map<Id, Target__c> targetsToUpdate = new Map<Id, Target__c>();
        for (Id tId : targetIds) {
            targetsToUpdate.put(tId, new Target__c(Id = tId, Completed__c = 0));
        }
        
        // Count the related Events 
        for (AggregateResult ar : [SELECT WhatId, COUNT(Id) eventCount 
                                   FROM Event 
                                   WHERE WhatId IN :targetIds 
                                   AND Type IN :trackedTypes
                                   GROUP BY WhatId]) {
            Id tId = (Id)ar.get('WhatId');
            targetsToUpdate.get(tId).Completed__c = (Integer)ar.get('eventCount');
        }
        
        update targetsToUpdate.values();
    }
}