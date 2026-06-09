@IsTest
private class FormServiceRepairOrderWarrantyCopyTest {
    @IsTest
    static void extensionInitializesWithoutRepairOrder() {
        ApexPages.StandardController controller = new ApexPages.StandardController(
            new dealer__Service_Repair_Order__c()
        );

        Test.startTest();
        FormServiceRepairOrderWarrantyCopyExt extension = new FormServiceRepairOrderWarrantyCopyExt(
            controller
        );
        Test.stopTest();

        System.assertEquals(false, extension.hasLogo);
        System.assertEquals(null, extension.logoUrl);
        System.assertEquals(true, extension.isPdf);
        System.assertEquals('PDF', extension.renderAs);
        System.assertEquals(0, extension.jobs.size());
        System.assertEquals(0, extension.warrantyCharges);
        System.assertEquals(false, extension.hasWarrantyAccount);
        System.assertEquals(false, extension.hasWarrantyComments);
        System.assertEquals(true, String.isBlank(extension.userLoc.Name));
    }

    @IsTest
    static void renderFormatDefaultsToPdfWithoutParameter() {
        ApexPages.currentPage().getParameters().clear();

        FormServiceRepairOrderWarrantyCopyExt extension = new FormServiceRepairOrderWarrantyCopyExt(
            new ApexPages.StandardController(new dealer__Service_Repair_Order__c())
        );

        System.assertEquals(true, extension.isPdf);
        System.assertEquals('PDF', extension.renderAs);
    }

    @IsTest
    static void renderFormatHonorsPdfParameter() {
        ApexPages.StandardController controller = new ApexPages.StandardController(
            new dealer__Service_Repair_Order__c()
        );

        ApexPages.currentPage().getParameters().put('pdf', 'false');
        FormServiceRepairOrderWarrantyCopyExt htmlExtension = new FormServiceRepairOrderWarrantyCopyExt(
            controller
        );
        System.assertEquals(false, htmlExtension.isPdf);
        System.assertEquals(null, htmlExtension.renderAs);

        ApexPages.currentPage().getParameters().put('pdf', 'true');
        FormServiceRepairOrderWarrantyCopyExt pdfExtension = new FormServiceRepairOrderWarrantyCopyExt(
            controller
        );
        System.assertEquals(true, pdfExtension.isPdf);
        System.assertEquals('PDF', pdfExtension.renderAs);
    }

    @IsTest
    static void resolveRepairOrderIdUsesControllerRecordId() {
        Id fakeId = fakeRepairOrderId();

        Id resolvedId = FormServiceRepairOrderWarrantyCopyExt.resolveRepairOrderId(
            new ApexPages.StandardController(
                new dealer__Service_Repair_Order__c(Id = fakeId)
            )
        );

        System.assertEquals(fakeId, resolvedId);
    }

    @IsTest
    static void resolveRepairOrderIdUsesPageParameter() {
        Id fakeId = fakeRepairOrderId();
        ApexPages.currentPage().getParameters().put('id', fakeId);

        Id resolvedId = FormServiceRepairOrderWarrantyCopyExt.resolveRepairOrderId(
            new ApexPages.StandardController(new dealer__Service_Repair_Order__c())
        );

        System.assertEquals(fakeId, resolvedId);
    }

    @IsTest
    static void resolveRepairOrderIdReturnsNullWhenUnavailable() {
        ApexPages.currentPage().getParameters().clear();

        Id resolvedId = FormServiceRepairOrderWarrantyCopyExt.resolveRepairOrderId(
            new ApexPages.StandardController(new dealer__Service_Repair_Order__c())
        );

        System.assertEquals(null, resolvedId);
    }

    @IsTest
    static void constructorResolvesIdAndQueriesWithoutMatch() {
        Id fakeId = fakeRepairOrderId();

        Test.startTest();
        FormServiceRepairOrderWarrantyCopyExt extension = new FormServiceRepairOrderWarrantyCopyExt(
            new ApexPages.StandardController(
                new dealer__Service_Repair_Order__c(Id = fakeId)
            )
        );
        Test.stopTest();

        System.assertEquals(null, extension.ro.Id);
        System.assertEquals(0, extension.jobs.size());
    }

    @IsTest
    static void loadRepairOrderHandlesMissingRecord() {
        FormServiceRepairOrderWarrantyCopyExt extension = new FormServiceRepairOrderWarrantyCopyExt(
            new ApexPages.StandardController(new dealer__Service_Repair_Order__c())
        );
        extension.loadRepairOrder(fakeRepairOrderId());

        System.assertEquals(null, extension.ro.Id);
        System.assertEquals(0, extension.jobs.size());
    }

    @IsTest
    static void loadWarrantyAccountReturnsNullForNullId() {
        FormServiceRepairOrderWarrantyCopyExt extension = new FormServiceRepairOrderWarrantyCopyExt(
            new ApexPages.StandardController(new dealer__Service_Repair_Order__c())
        );

        System.assertEquals(null, extension.loadWarrantyAccount(null));
    }

    @IsTest
    static void loadWarrantyAccountQueriesByIdWithoutMatch() {
        FormServiceRepairOrderWarrantyCopyExt extension = new FormServiceRepairOrderWarrantyCopyExt(
            new ApexPages.StandardController(new dealer__Service_Repair_Order__c())
        );

        Test.startTest();
        Account warrantyAccount = extension.loadWarrantyAccount(fakeAccountId());
        Test.stopTest();

        System.assertEquals(null, warrantyAccount);
    }

    @IsTest
    static void applyWarrantyAccountPopulatesHeader() {
        Account warrantyAccount = new Account(
            Name = 'Acme Warranty Co',
            Phone = '555-0900',
            AccountNumber = 'WAR-001',
            BillingStreet = '1 Claims Way',
            BillingCity = 'Denver',
            BillingState = 'CO',
            BillingPostalCode = '80202'
        );
        insert warrantyAccount;

        Account inserted = [
            SELECT Name,
                Phone,
                AccountNumber,
                BillingStreet,
                BillingCity,
                BillingState,
                BillingPostalCode
            FROM Account
            WHERE Id = :warrantyAccount.Id
            LIMIT 1
        ];

        FormServiceRepairOrderWarrantyCopyExt extension = new FormServiceRepairOrderWarrantyCopyExt(
            new ApexPages.StandardController(new dealer__Service_Repair_Order__c())
        );
        extension.applyWarrantyAccount(inserted);

        System.assertEquals('Acme Warranty Co', extension.warrantyCompanyName);
        System.assertEquals('555-0900', extension.warrantyCompanyPhone);
        System.assertEquals('WAR-001', extension.warrantyAccountNumber);
        System.assertEquals('1 Claims Way', extension.warrantyCompanyStreet);
        System.assertEquals('Denver', extension.warrantyCompanyCity);
        System.assertEquals('CO', extension.warrantyCompanyState);
        System.assertEquals('80202', extension.warrantyCompanyPostalCode);
        System.assertEquals(true, extension.hasWarrantyAccount);
    }

    @IsTest
    static void applyWarrantyAccountIgnoresNull() {
        FormServiceRepairOrderWarrantyCopyExt extension = new FormServiceRepairOrderWarrantyCopyExt(
            new ApexPages.StandardController(new dealer__Service_Repair_Order__c())
        );
        extension.applyWarrantyAccount(null);

        System.assertEquals(null, extension.warrantyCompanyName);
        System.assertEquals(false, extension.hasWarrantyAccount);
    }

    @IsTest
    static void extensionAppliesCustomerDetailsFromUtil() {
        Account personAccount = new Account(
            RecordTypeId = Schema.SObjectType.Account.getRecordTypeInfosByDeveloperName()
                .get('PersonAccount')
                .getRecordTypeId(),
            FirstName = 'Pat',
            LastName = 'Owner',
            Phone = '555-0300',
            PersonEmail = 'pat@example.com',
            PersonMobilePhone = '555-0400',
            PersonMailingStreet = '200 Service Rd',
            PersonMailingCity = 'Boulder',
            PersonMailingState = 'CO',
            PersonMailingPostalCode = '80301'
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

        FormServiceRepairOrderWarrantyCopyExt extension = new FormServiceRepairOrderWarrantyCopyExt(
            new ApexPages.StandardController(new dealer__Service_Repair_Order__c())
        );
        extension.applyCustomerDetails(
            FixedOpsFormUtil.buildCustomerDetails(insertedAccount)
        );

        System.assertEquals('Pat Owner', extension.customerName);
        System.assertEquals('200 Service Rd', extension.customerStreet);
        System.assertEquals('Boulder', extension.customerCity);
        System.assertEquals('CO', extension.customerState);
        System.assertEquals('80301', extension.customerPostalCode);
        System.assertEquals('555-0300', extension.customerPhone);
        System.assertEquals('555-0400', extension.customerMobile);
        System.assertEquals('pat@example.com', extension.customerEmail);
    }

    @IsTest
    static void extensionIgnoresNullCustomerDetails() {
        FormServiceRepairOrderWarrantyCopyExt extension = new FormServiceRepairOrderWarrantyCopyExt(
            new ApexPages.StandardController(new dealer__Service_Repair_Order__c())
        );
        extension.applyCustomerDetails(null);

        System.assertEquals(null, extension.customerName);
        System.assertEquals(null, extension.customerEmail);
    }

    @IsTest
    static void isWarrantyPayCodeRecognizesWarrantyCode() {
        System.assertEquals(
            true,
            FormServiceRepairOrderWarrantyCopyExt.isWarrantyPayCode('W')
        );
        System.assertEquals(
            false,
            FormServiceRepairOrderWarrantyCopyExt.isWarrantyPayCode('C')
        );
        System.assertEquals(
            false,
            FormServiceRepairOrderWarrantyCopyExt.isWarrantyPayCode(null)
        );
    }

    @IsTest
    static void buildJobWrappersHandlesNullAndEmpty() {
        System.assertEquals(
            0,
            FormServiceRepairOrderWarrantyCopyExt.buildJobWrappers(null).size()
        );
        System.assertEquals(
            0,
            FormServiceRepairOrderWarrantyCopyExt.buildJobWrappers(
                new List<dealer__Service_Job__c>()
            )
            .size()
        );
    }

    @IsTest
    static void buildJobWrappersDisplaysWarrantyPayCostAndPrice() {
        String jobJson =
            '{' +
            '"dealer__Line_Number__c":1,' +
            '"dealer__Op_Code__c":"WARREP",' +
            '"dealer__Labor_Type__c":"W",' +
            '"dealer__CustomerConcern__c":"Engine noise",' +
            '"dealer__CauseExtended__c":"Failed component",' +
            '"dealer__Correction__c":"Replaced under warranty",' +
            '"dealer__Labor_Charges__c":120.00,' +
            '"dealer__Technician_Cost__c":48.00,' +
            '"dealer__Misc_Charges__c":15.00,' +
            '"dealer__MiscChargeCost__c":6.00,' +
            '"dealer__Sublet_Total__c":40.00,' +
            '"dealer__Sublet_Cost__c":30.00,' +
            '"dealer__Line_Total__c":250.00,' +
            '"dealer__Parts_Lines__r":{"totalSize":2,"done":true,"records":[' +
            '{"attributes":{"type":"dealer__Parts_Invoice_Line__c"},"dealer__Quantity_Sold__c":2,"dealer__Part_Number__c":"WAR-1","dealer__Part_Description__c":"Covered part","dealer__Cost__c":12.00,"dealer__Extended_Cost__c":24.00,"dealer__Price__c":25.00,"dealer__Extended_Price__c":50.00,"dealer__Pay_Type__c":"W"},' +
            '{"attributes":{"type":"dealer__Parts_Invoice_Line__c"},"dealer__Quantity_Sold__c":1,"dealer__Part_Number__c":"CUS-1","dealer__Part_Description__c":"Customer part","dealer__Cost__c":5.00,"dealer__Extended_Cost__c":5.00,"dealer__Price__c":10.00,"dealer__Extended_Price__c":10.00,"dealer__Pay_Type__c":"C"}' +
            ']},' +
            '"dealer__Parts_Ledger_Entries__r":{"totalSize":1,"done":true,"records":[' +
            '{"attributes":{"type":"dealer__Parts_Ledger__c"},"dealer__SerialNumber__c":"SN-123"}' +
            ']},' +
            '"dealer__Service_Misc_Charge__r":{"totalSize":1,"done":true,"records":[' +
            '{"attributes":{"type":"dealer__Service_Misc_Charge__c"},"dealer__Description__c":"Shop supplies","dealer__Amount__c":15.00,"dealer__Cost__c":6.00,"dealer__MiscChargeCode__r":{"attributes":{"type":"dealer__MiscChargeCode__c"},"Name":"SUPPLY"}}' +
            ']},' +
            '"dealer__Purchase_Order_Line__r":{"totalSize":1,"done":true,"records":[' +
            '{"attributes":{"type":"dealer__Purchase_Order_Line__c"},"dealer__Description__c":"Alignment","dealer__Customer_Total__c":40.00,"dealer__Cost__c":30.00,"dealer__Purchase_Order__r":{"attributes":{"type":"dealer__Purchase_Order__c"},"Name":"PO-100","dealer__Vendor_Name__c":"Align Co"}}' +
            ']}' +
            '}';
        dealer__Service_Job__c job = (dealer__Service_Job__c) JSON.deserialize(
            jobJson,
            dealer__Service_Job__c.class
        );

        FormServiceRepairOrderWarrantyCopyExt.JobWrapper w =
            FormServiceRepairOrderWarrantyCopyExt.buildJobWrappers(
                new List<dealer__Service_Job__c>{ job }
            )[0];

        System.assertEquals(true, w.isWarrantyPay);
        System.assertEquals('WARREP', w.opCode);
        System.assertEquals(true, w.hasCause);
        System.assertEquals(true, w.hasCorrection);
        System.assertEquals(120.00, w.laborSale);
        System.assertEquals(48.00, w.laborCost);
        System.assertEquals(15.00, w.miscSale);
        System.assertEquals(6.00, w.miscCost);
        System.assertEquals(40.00, w.subletSale);
        System.assertEquals(30.00, w.subletCost);

        // Only the warranty-pay part contributes to the parts sums.
        System.assertEquals(2, w.parts.size());
        System.assertEquals(50.00, w.partsSale);
        System.assertEquals(24.00, w.partsCost);
        System.assertEquals(25.00, w.parts[0].unitPrice);
        System.assertEquals(12.00, w.parts[0].unitCost);
        System.assertEquals(50.00, w.parts[0].extendedPrice);
        System.assertEquals(24.00, w.parts[0].extendedCost);
        // Customer-pay part is zeroed out.
        System.assertEquals(0, w.parts[1].unitPrice);
        System.assertEquals(0, w.parts[1].unitCost);
        System.assertEquals(0, w.parts[1].extendedPrice);
        System.assertEquals(0, w.parts[1].extendedCost);

        // Line totals are derived from the warranty-gated components.
        System.assertEquals(225.00, w.lineSale);
        System.assertEquals(108.00, w.lineCost);
        System.assertEquals(117.00, w.lineGross);

        System.assertEquals(true, w.hasSerialNumbers);
        System.assertEquals('SN-123', w.serialNumbers[0]);
        System.assertEquals(true, w.hasMisc);
        System.assertEquals('SUPPLY', w.miscCharges[0].code);
        System.assertEquals(true, w.hasSublet);
        System.assertEquals('PO-100', w.sublets[0].poNumber);
        System.assertEquals('Align Co', w.sublets[0].vendorName);
        System.assertEquals(40.00, w.sublets[0].price);
        System.assertEquals(30.00, w.sublets[0].cost);
    }

    @IsTest
    static void buildJobWrappersZeroesOutNonWarrantyPayCharges() {
        String jobJson =
            '{' +
            '"dealer__Line_Number__c":2,' +
            '"dealer__Labor_Type__c":"C",' +
            '"dealer__Labor_Charges__c":99.00,' +
            '"dealer__Technician_Cost__c":40.00,' +
            '"dealer__Misc_Charges__c":10.00,' +
            '"dealer__MiscChargeCost__c":4.00,' +
            '"dealer__Sublet_Total__c":20.00,' +
            '"dealer__Sublet_Cost__c":12.00,' +
            '"dealer__Line_Total__c":150.00,' +
            '"dealer__Parts_Lines__r":{"totalSize":1,"done":true,"records":[' +
            '{"attributes":{"type":"dealer__Parts_Invoice_Line__c"},"dealer__Quantity_Sold__c":1,"dealer__Part_Number__c":"CUS-2","dealer__Part_Description__c":"Customer part","dealer__Cost__c":15.00,"dealer__Extended_Cost__c":15.00,"dealer__Price__c":30.00,"dealer__Extended_Price__c":30.00,"dealer__Pay_Type__c":"C"}' +
            ']},' +
            '"dealer__Service_Misc_Charge__r":{"totalSize":1,"done":true,"records":[' +
            '{"attributes":{"type":"dealer__Service_Misc_Charge__c"},"dealer__Description__c":"Supplies","dealer__Amount__c":10.00,"dealer__Cost__c":4.00,"dealer__MiscChargeCode__r":{"attributes":{"type":"dealer__MiscChargeCode__c"},"Name":"SUPPLY"}}' +
            ']},' +
            '"dealer__Purchase_Order_Line__r":{"totalSize":1,"done":true,"records":[' +
            '{"attributes":{"type":"dealer__Purchase_Order_Line__c"},"dealer__Description__c":"Sublet","dealer__Customer_Total__c":20.00,"dealer__Cost__c":12.00,"dealer__Purchase_Order__r":{"attributes":{"type":"dealer__Purchase_Order__c"},"Name":"PO-200","dealer__Vendor_Name__c":"Vendor Co"}}' +
            ']}' +
            '}';
        dealer__Service_Job__c job = (dealer__Service_Job__c) JSON.deserialize(
            jobJson,
            dealer__Service_Job__c.class
        );

        FormServiceRepairOrderWarrantyCopyExt.JobWrapper w =
            FormServiceRepairOrderWarrantyCopyExt.buildJobWrappers(
                new List<dealer__Service_Job__c>{ job }
            )[0];

        System.assertEquals(false, w.isWarrantyPay);
        System.assertEquals(0, w.laborSale);
        System.assertEquals(0, w.laborCost);
        System.assertEquals(0, w.miscSale);
        System.assertEquals(0, w.miscCost);
        System.assertEquals(0, w.subletSale);
        System.assertEquals(0, w.subletCost);
        System.assertEquals(0, w.partsSale);
        System.assertEquals(0, w.partsCost);
        System.assertEquals(0, w.parts[0].unitPrice);
        System.assertEquals(0, w.parts[0].unitCost);
        System.assertEquals(0, w.parts[0].extendedPrice);
        System.assertEquals(0, w.parts[0].extendedCost);
        System.assertEquals(0, w.miscCharges[0].cost);
        System.assertEquals(0, w.miscCharges[0].amount);
        System.assertEquals(0, w.sublets[0].cost);
        System.assertEquals(0, w.sublets[0].price);
        System.assertEquals(0, w.lineSale);
        System.assertEquals(0, w.lineCost);
        System.assertEquals(0, w.lineGross);
    }

    @IsTest
    static void computeTotalsDerivesWarrantyTotals() {
        dealer__Service_Repair_Order__c order = (dealer__Service_Repair_Order__c) JSON.deserialize(
            '{' +
            '"dealer__Warranty_Labor_Charges__c":120.00,' +
            '"dealer__Warranty_Parts_Charges__c":50.00,' +
            '"dealer__Warranty_Misc_Charges__c":15.00,' +
            '"dealer__WarrantySubletCharges__c":40.00,' +
            '"dealer__Warranty_Charges__c":225.00' +
            '}',
            dealer__Service_Repair_Order__c.class
        );

        FormServiceRepairOrderWarrantyCopyExt extension = new FormServiceRepairOrderWarrantyCopyExt(
            new ApexPages.StandardController(new dealer__Service_Repair_Order__c())
        );
        extension.computeTotals(order);

        System.assertEquals(120.00, extension.totalLabor);
        System.assertEquals(50.00, extension.totalParts);
        System.assertEquals(15.00, extension.totalMisc);
        System.assertEquals(40.00, extension.totalSublet);
        System.assertEquals(225.00, extension.warrantyCharges);
    }

    @IsTest
    static void computeTotalsHandlesNullOrder() {
        FormServiceRepairOrderWarrantyCopyExt extension = new FormServiceRepairOrderWarrantyCopyExt(
            new ApexPages.StandardController(new dealer__Service_Repair_Order__c())
        );

        extension.computeTotals(null);

        System.assertEquals(0, extension.warrantyCharges);
        System.assertEquals(0, extension.totalLabor);
    }

    @IsTest
    static void buildServiceHoursLinesReturnsEmptyForNull() {
        System.assertEquals(
            0,
            FormServiceRepairOrderWarrantyCopyExt.buildServiceHoursLines(null).size()
        );
    }

    @IsTest
    static void buildServiceHoursLinesGroupsConsecutiveDays() {
        BusinessHours bh = new BusinessHours(
            MondayStartTime = Time.newInstance(7, 0, 0, 0),
            MondayEndTime = Time.newInstance(17, 0, 0, 0),
            TuesdayStartTime = Time.newInstance(7, 0, 0, 0),
            TuesdayEndTime = Time.newInstance(17, 0, 0, 0),
            ThursdayStartTime = Time.newInstance(12, 5, 0, 0),
            ThursdayEndTime = Time.newInstance(13, 0, 0, 0),
            SaturdayStartTime = Time.newInstance(8, 0, 0, 0),
            SaturdayEndTime = Time.newInstance(14, 0, 0, 0),
            SundayStartTime = Time.newInstance(8, 0, 0, 0),
            SundayEndTime = Time.newInstance(14, 0, 0, 0)
        );

        List<String> segments = FormServiceRepairOrderWarrantyCopyExt.buildServiceHoursLines(
            bh
        );

        System.assertEquals(3, segments.size());
        System.assertEquals('7:00 AM - 5:00 PM Monday - Tuesday', segments[0]);
        System.assertEquals('12:05 PM - 1:00 PM Thursday', segments[1]);
        System.assertEquals('8:00 AM - 2:00 PM Saturday - Sunday', segments[2]);
    }

    @IsTest
    static void formatTimeCompactHandlesNullAndMidnight() {
        System.assertEquals(
            '',
            FormServiceRepairOrderWarrantyCopyExt.formatTimeCompact(null)
        );
        System.assertEquals(
            '12:00 AM',
            FormServiceRepairOrderWarrantyCopyExt.formatTimeCompact(
                Time.newInstance(0, 0, 0, 0)
            )
        );
    }

    @IsTest
    static void loadJobLinesQueriesByRepairOrderWithoutMatch() {
        FormServiceRepairOrderWarrantyCopyExt extension = new FormServiceRepairOrderWarrantyCopyExt(
            new ApexPages.StandardController(new dealer__Service_Repair_Order__c())
        );

        Test.startTest();
        List<dealer__Service_Job__c> jobLines = extension.loadJobLines(
            fakeRepairOrderId()
        );
        Test.stopTest();

        System.assertEquals(0, jobLines.size());
    }

    @IsTest
    static void loadServiceContractsReturnsEmptyForNullVehicle() {
        FormServiceRepairOrderWarrantyCopyExt extension = new FormServiceRepairOrderWarrantyCopyExt(
            new ApexPages.StandardController(new dealer__Service_Repair_Order__c())
        );

        List<dealer__Service_Contract__c> contracts = extension.loadServiceContracts(
            null
        );

        System.assertEquals(0, contracts.size());
        System.assertEquals(false, extension.hasServiceContracts);
    }

    @IsTest
    static void loadServiceContractsQueriesByVehicleWithoutMatch() {
        FormServiceRepairOrderWarrantyCopyExt extension = new FormServiceRepairOrderWarrantyCopyExt(
            new ApexPages.StandardController(new dealer__Service_Repair_Order__c())
        );

        Test.startTest();
        List<dealer__Service_Contract__c> contracts = extension.loadServiceContracts(
            fakeVehicleId()
        );
        Test.stopTest();

        System.assertEquals(0, contracts.size());
    }

    private static Id fakeRepairOrderId() {
        String keyPrefix = dealer__Service_Repair_Order__c.SObjectType.getDescribe()
            .getKeyPrefix();
        return Id.valueOf(keyPrefix + '000000000001');
    }

    private static Id fakeVehicleId() {
        String keyPrefix = dealer__Service_Vehicle__c.SObjectType.getDescribe()
            .getKeyPrefix();
        return Id.valueOf(keyPrefix + '000000000001');
    }

    private static Id fakeAccountId() {
        String keyPrefix = Account.SObjectType.getDescribe().getKeyPrefix();
        return Id.valueOf(keyPrefix + '000000000001');
    }
}
