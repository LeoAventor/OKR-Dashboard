@isTest
private class OkrControllerTest {
    
    // 1. Setup test data
    @testSetup
    static void setupTestData() {
        // Create a test user to test the dynamic dashboard filtering
        Profile p = [SELECT Id FROM Profile WHERE Name='System Administrator' LIMIT 1];
        User testUser = new User(
            Alias = 'okrtest', Email='okrtestuser@salesforce.com',
            EmailEncodingKey='UTF-8', LastName='Testing', LanguageLocaleKey='en_US',
            LocaleSidKey='en_US', ProfileId = p.Id,
            TimeZoneSidKey='America/Los_Angeles', UserName='okrtestuser@salesforcedashboard.com'
        );
        insert testUser;

        System.runAs(testUser) {
            // Pre-load data using the controller's own methods
            Objective__c obj = OkrController.createObjective('Q1 Sales Goal', testUser.Id, '2026');
            Key_Result__c kr = OkrController.createKeyResult('Increase Calls', obj.Id, '');
            Target__c tgt = OkrController.createTarget('Outgoing Calls', 50, 'Calls', kr.Id);
        }
    }

    // 2. Test data retrieval (The LWC Wire)
    @isTest
    static void testGetFullOkrData() {
        User testUser = [SELECT Id FROM User WHERE Alias = 'okrtest' LIMIT 1];
        
        Test.startTest();
        Map<String, List<SObject>> result = OkrController.getFullOkrData(testUser.Id, '2026');
        Test.stopTest();
        
        System.assertNotEquals(null, result, 'Result map should not be null');
        System.assertEquals(1, result.get('objectives').size(), 'Should find exactly 1 objective for 2026');
        System.assertEquals(1, result.get('keyResults').size(), 'Should find exactly 1 key result');
    }

    // 3.Test duplicate key results
    @isTest
    static void testDuplicateKeyResult() {
        User testUser = [SELECT Id FROM User WHERE Alias = 'okrtest' LIMIT 1];
        
        System.runAs(testUser) {
            Objective__c obj = [SELECT Id FROM Objective__c LIMIT 1];
            
            Test.startTest();
            try {
                // Attempt to create a KR with the exact same name as the setup KR
                OkrController.createKeyResult('Increase Calls', obj.Id, '');
                System.assert(false, 'Exception should have been thrown for duplicate name');
            } catch (AuraHandledException e) {
                System.assert(e != null, 'Successfully caught the duplicate blocker exception!');
            }
            Test.stopTest();
        }
    }

    // 4. test creating custom evaluation records
    @isTest
    static void testCreateEvaluationRecord() {
        Key_Result__c kr = [SELECT Id FROM Key_Result__c LIMIT 1];
        Target__c tgt = [SELECT Id FROM Target__c LIMIT 1];
        
        Test.startTest();
        // Test dynamically inserting a Google Review record
        OkrController.createEvaluationRecord('Google_Review__c', kr.Id, tgt.Id, '5 Star Review');
        Test.stopTest();
        
        List<Google_Review__c> reviews = [SELECT Id, Name FROM Google_Review__c WHERE Name = '5 Star Review'];
        System.assertEquals(1, reviews.size(), 'Evaluation record should be created');
    }

    // 5. test deletion logic
    @isTest
    static void testDeletions() {
        Objective__c obj = [SELECT Id FROM Objective__c LIMIT 1];
        Key_Result__c kr = [SELECT Id FROM Key_Result__c LIMIT 1];
        
        Test.startTest();
        OkrController.deleteKeyResults(new List<Id>{kr.Id});
        OkrController.deleteObjectives(new List<Id>{obj.Id});
        Test.stopTest();
        
        System.assertEquals(0, [SELECT COUNT() FROM Key_Result__c], 'Key Result should be deleted');
        System.assertEquals(0, [SELECT COUNT() FROM Objective__c], 'Objective should be deleted');
    }
}