@IsTest
private class FormServiceTechnicianHardCardExtTest {
    @IsTest
    static void extensionInitializesWithoutLogoAsset() {
        ApexPages.StandardController controller = new ApexPages.StandardController(
            new dealer__Service_Repair_Order__c()
        );

        Test.startTest();
        FormServiceTechnicianHardCardExt extension = new FormServiceTechnicianHardCardExt(controller);
        Test.stopTest();

        System.assertEquals(false, extension.hasLogo, 'Expected no logo when asset is absent.');
        System.assertEquals(null, extension.logoUrl, 'Expected blank logo URL.');
        System.assertNotEquals(null, extension.getRepairOrder(), 'Repair order reference should be available.');
        System.assertEquals(true, extension.isPdf, 'Expected PDF by default.');
        System.assertEquals('PDF', extension.renderAs, 'Expected PDF render format by default.');
    }

    @IsTest
    static void renderFormatDefaultsToPdfWithoutParameter() {
        ApexPages.currentPage().getParameters().clear();

        ApexPages.StandardController controller = new ApexPages.StandardController(
            new dealer__Service_Repair_Order__c()
        );
        FormServiceTechnicianHardCardExt extension = new FormServiceTechnicianHardCardExt(controller);

        System.assertEquals(true, extension.isPdf);
        System.assertEquals('PDF', extension.renderAs);
    }

    @IsTest
    static void renderFormatHonorsPdfParameter() {
        ApexPages.StandardController controller = new ApexPages.StandardController(
            new dealer__Service_Repair_Order__c()
        );

        ApexPages.currentPage().getParameters().put('pdf', 'false');
        FormServiceTechnicianHardCardExt htmlExtension = new FormServiceTechnicianHardCardExt(controller);
        System.assertEquals(false, htmlExtension.isPdf);
        System.assertEquals(null, htmlExtension.renderAs);

        ApexPages.currentPage().getParameters().put('pdf', 'true');
        FormServiceTechnicianHardCardExt pdfExtension = new FormServiceTechnicianHardCardExt(controller);
        System.assertEquals(true, pdfExtension.isPdf);
        System.assertEquals('PDF', pdfExtension.renderAs);
    }

    @IsTest
    static void extensionAppliesCustomerDetailsFromUtil() {
        Account personAccount = new Account(
            RecordTypeId = Schema.SObjectType.Account.getRecordTypeInfosByDeveloperName()
                .get('PersonAccount')
                .getRecordTypeId(),
            FirstName = 'Sam',
            LastName = 'Driver',
            Phone = '555-0100',
            PersonEmail = 'sam@example.com',
            PersonMobilePhone = '555-0200',
            PersonMailingStreet = '100 Test Lane',
            PersonMailingCity = 'Denver',
            PersonMailingState = 'CO',
            PersonMailingPostalCode = '80203'
        );
        insert personAccount;

        Account insertedAccount = [
            SELECT Name,
                IsPersonAccount,
                Phone,
                PersonEmail,
                PersonMobilePhone,
                PersonMailingStreet,
                PersonMailingCity,
                PersonMailingState,
                PersonMailingPostalCode,
                BillingStreet,
                BillingCity,
                BillingState,
                BillingPostalCode
            FROM Account
            WHERE Id = :personAccount.Id
            LIMIT 1
        ];

        FormServiceTechnicianHardCardExt extension = new FormServiceTechnicianHardCardExt(
            new ApexPages.StandardController(new dealer__Service_Repair_Order__c())
        );
        extension.applyCustomerDetails(FixedOpsFormUtil.buildCustomerDetails(insertedAccount));

        System.assertEquals('Sam Driver', extension.customerName);
        System.assertEquals('100 Test Lane', extension.customerStreet);
        System.assertEquals('Denver', extension.customerCity);
        System.assertEquals('CO', extension.customerState);
        System.assertEquals('80203', extension.customerPostalCode);
        System.assertEquals('555-0100', extension.customerPhone);
        System.assertEquals('555-0200', extension.customerMobile);
        System.assertEquals('sam@example.com', extension.customerEmail);
    }

    @IsTest
    static void extensionIgnoresNullCustomerDetails() {
        FormServiceTechnicianHardCardExt extension = new FormServiceTechnicianHardCardExt(
            new ApexPages.StandardController(new dealer__Service_Repair_Order__c())
        );
        extension.applyCustomerDetails(null);

        System.assertEquals(null, extension.customerName);
        System.assertEquals(null, extension.customerEmail);
    }
}
