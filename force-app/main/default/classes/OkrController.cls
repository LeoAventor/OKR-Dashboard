public with sharing class OkrController {
    
    // Query from Key Result to access both Parent (Objective) and Children (Targets)
   @AuraEnabled(cacheable=true)
public static Map<String, List<SObject>> getFullOkrData(Id userId, String year) {
    Map<String, List<SObject>> result = new Map<String, List<SObject>>();
    Integer yearNumber = Integer.valueOf(year);
    
    // 1. Fetch strictly the filtered Objectives
    List<Objective__c> userObjectives = [
        SELECT Id, Name, Year__c, OwnerId, Sort_Order__c 
        FROM Objective__c 
        WHERE OwnerId = :userId AND Year__c = :yearNumber
        ORDER BY Sort_Order__c ASC NULLS LAST, CreatedDate ASC
    ];
    result.put('objectives', userObjectives);
    
    // 2. fetch Key Results if they belong to the Objectives just found!
    if (!userObjectives.isEmpty()) {
        result.put('keyResults', [
            SELECT Id, Name, Objective__c, Sort_Order__c,  
                (SELECT Id, Name, Target_Number__c, Target_Object__c, Completed__c FROM Targets__r) 
            FROM Key_Result__c
            WHERE Objective__c IN :userObjectives
            ORDER BY Sort_Order__c ASC NULLS LAST, CreatedDate ASC
        ]);
    } else {
        // If no objectives, send an empty list so the dashboard goes blank
        result.put('keyResults', new List<Key_Result__c>());
    }
    
    return result;
}

    // 1. Create Objective 
    @AuraEnabled
    public static Objective__c createObjective(String name, Id userId, String objectiveYear) {
        Objective__c newObj = new Objective__c (
            Name = name,
            OwnerId = userId,
            Year__c = Integer.valueOf(objectiveYear)     
        );
        insert newObj;
        return newObj;
    }

    // 2. Create Key Result 
    @AuraEnabled
    public static Key_Result__c createKeyResult(String name, Id objectiveId) {

    // 1. Check for duplicate Key Result names under the same Objective    
        List<Key_Result__c> existingKrs = [
            SELECT Id FROM Key_Result__c
            WHERE Name = :name AND Objective__c = :objectiveId
            LIMIT 1
        ];

        if (!existingKrs.isEmpty()) {
            throw new AuraHandledException('A Key Result named "'+ name + '"already exists in this Objective.');
        }

        // 2. If no duplicate is found, proceed with creation
        Key_Result__c newKr = new Key_Result__c(
            Name = name,
            Objective__c = objectiveId
        );
        insert newKr;
        return newKr;
    } 

    // 3. Create Target (Holds the actual math and picklist)
    // 3. Create Target (Holds the actual math and picklist)
    @AuraEnabled
    public static Target__c createTarget(String name, Decimal targetNumber, String targetObject, Id keyResultId) {
        
        // Check for duplicate Targets of the same Object Type under this specific Key Result
        List<Target__c> existingTargets = [
            SELECT Id FROM Target__c
            WHERE Target_Object__c = :targetObject AND Key_Result__c = :keyResultId
            LIMIT 1
        ];

        if (!existingTargets.isEmpty()) {
            throw new AuraHandledException('A Target for "' + targetObject + '" already exists in this Key Result.');
        }

        Target__c newTgt = new Target__c(
            Name = name,
            Target_Number__c = targetNumber,
            Target_Object__c = targetObject,
            Completed__c = 0, // Default to 0 on creation
            Key_Result__c = keyResultId // Link to parent Key Result
        );
        insert newTgt;
        return newTgt;
    }

    // 4. Create Custom Evaluation Records 
    @AuraEnabled
    public static void createEvaluationRecord(String objectType, Id keyResultId, Id targetId, String recordName) {
        SObject newRecord = Schema.getGlobalDescribe().get(objectType).newSObject();
        newRecord.put('Name', recordName);
        newRecord.put('Key_Result__c', keyResultId);
        newRecord.put('Target__c', targetId);
        insert newRecord;
    }

    @AuraEnabled
        public static void deleteObjectives(List<Id> objectiveIds) {
        List<Objective__c> objsToDelete = new List<Objective__c>();
        for(Id i : objectiveIds) objsToDelete.add(new Objective__c(Id = i));
        Database.delete(objsToDelete, false); // false allows partial success without crashing
    }

    @AuraEnabled
    public static void deleteKeyResults(List<Id> keyResultIds) {
        List<Key_Result__c> krsToDelete = new List<Key_Result__c>();
        for(Id i : keyResultIds) krsToDelete.add(new Key_Result__c(Id = i));
        Database.delete(krsToDelete, false);

    }

    // Methods for drag and drop reordering (Objectives, KeyResults) 
    @AuraEnabled
    public static void updateObjectiveOrder(List<Id> orderedIds) {
        List<Objective__c> objsToUpdate = new List<Objective__c>();
        for (Integer i = 0; i < orderedIds.size(); i++) {
            objsToUpdate.add(new Objective__c(Id = orderedIds[i], Sort_Order__c = i));
        }
        update objsToUpdate;
    }

    @AuraEnabled
    public static void updateKeyResultOrder(List<Id> orderedIds) {
        List<Key_Result__c> krsToUpdate = new List<Key_Result__c>();
        for (Integer i = 0; i < orderedIds.size(); i++) {
            krsToUpdate.add(new Key_Result__c(Id = orderedIds[i], Sort_Order__c = i));
        }
        update krsToUpdate;
    }
}