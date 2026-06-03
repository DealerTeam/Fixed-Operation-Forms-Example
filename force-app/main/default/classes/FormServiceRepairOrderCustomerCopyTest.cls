@IsTest
private class FormServiceRepairOrderCustomerCopyTest {
    @IsTest
    static void extensionInitializesWithoutRepairOrder() {
        ApexPages.StandardController controller = new ApexPages.StandardController(
            new dealer__Service_Repair_Order__c()
        );

        Test.startTest();
        FormServiceRepairOrderCustomerCopyExt extension = new FormServiceRepairOrderCustomerCopyExt(
            controller
        );
        Test.stopTest();

        System.assertEquals(false, extension.hasLogo);
        System.assertEquals(null, extension.logoUrl);
        System.assertEquals(true, extension.isPdf);
        System.assertEquals('PDF', extension.renderAs);
        System.assertEquals(0, extension.jobs.size());
        System.assertEquals(0, extension.cashLines.size());
        System.assertEquals(false, extension.hasPayments);
        System.assertEquals(0, extension.invoiceTotal);
        System.assertEquals(true, String.isBlank(extension.userLoc.Name));
    }

    @IsTest
    static void renderFormatDefaultsToPdfWithoutParameter() {
        ApexPages.currentPage().getParameters().clear();

        FormServiceRepairOrderCustomerCopyExt extension = new FormServiceRepairOrderCustomerCopyExt(
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
        FormServiceRepairOrderCustomerCopyExt htmlExtension = new FormServiceRepairOrderCustomerCopyExt(
            controller
        );
        System.assertEquals(false, htmlExtension.isPdf);
        System.assertEquals(null, htmlExtension.renderAs);

        ApexPages.currentPage().getParameters().put('pdf', 'true');
        FormServiceRepairOrderCustomerCopyExt pdfExtension = new FormServiceRepairOrderCustomerCopyExt(
            controller
        );
        System.assertEquals(true, pdfExtension.isPdf);
        System.assertEquals('PDF', pdfExtension.renderAs);
    }

    @IsTest
    static void resolveRepairOrderIdUsesControllerRecordId() {
        Id fakeId = fakeRepairOrderId();

        Id resolvedId = FormServiceRepairOrderCustomerCopyExt.resolveRepairOrderId(
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

        Id resolvedId = FormServiceRepairOrderCustomerCopyExt.resolveRepairOrderId(
            new ApexPages.StandardController(new dealer__Service_Repair_Order__c())
        );

        System.assertEquals(fakeId, resolvedId);
    }

    @IsTest
    static void resolveRepairOrderIdReturnsNullWhenUnavailable() {
        ApexPages.currentPage().getParameters().clear();

        Id resolvedId = FormServiceRepairOrderCustomerCopyExt.resolveRepairOrderId(
            new ApexPages.StandardController(new dealer__Service_Repair_Order__c())
        );

        System.assertEquals(null, resolvedId);
    }

    @IsTest
    static void constructorResolvesIdAndQueriesWithoutMatch() {
        // A correctly formatted but non-existent Id exercises the id resolution
        // and SOQL query paths without depending on managed SRO insert triggers
        // (which require a dealership-configured running user).
        Id fakeId = fakeRepairOrderId();

        Test.startTest();
        FormServiceRepairOrderCustomerCopyExt extension = new FormServiceRepairOrderCustomerCopyExt(
            new ApexPages.StandardController(
                new dealer__Service_Repair_Order__c(Id = fakeId)
            )
        );
        Test.stopTest();

        System.assertEquals(null, extension.ro.Id);
        System.assertEquals(0, extension.jobs.size());
        System.assertEquals(0, extension.cashLines.size());
    }

    @IsTest
    static void loadRepairOrderHandlesMissingRecord() {
        FormServiceRepairOrderCustomerCopyExt extension = new FormServiceRepairOrderCustomerCopyExt(
            new ApexPages.StandardController(new dealer__Service_Repair_Order__c())
        );
        extension.loadRepairOrder(fakeRepairOrderId());

        System.assertEquals(null, extension.ro.Id);
        System.assertEquals(0, extension.jobs.size());
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

        FormServiceRepairOrderCustomerCopyExt extension = new FormServiceRepairOrderCustomerCopyExt(
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
        FormServiceRepairOrderCustomerCopyExt extension = new FormServiceRepairOrderCustomerCopyExt(
            new ApexPages.StandardController(new dealer__Service_Repair_Order__c())
        );
        extension.applyCustomerDetails(null);

        System.assertEquals(null, extension.customerName);
        System.assertEquals(null, extension.customerEmail);
    }

    @IsTest
    static void isCustomerPayCodeRecognizesCustomerCode() {
        System.assertEquals(
            true,
            FormServiceRepairOrderCustomerCopyExt.isCustomerPayCode('C')
        );
        System.assertEquals(
            false,
            FormServiceRepairOrderCustomerCopyExt.isCustomerPayCode('W')
        );
        System.assertEquals(
            false,
            FormServiceRepairOrderCustomerCopyExt.isCustomerPayCode(null)
        );
    }

    @IsTest
    static void buildJobWrappersHandlesNullAndEmpty() {
        System.assertEquals(
            0,
            FormServiceRepairOrderCustomerCopyExt.buildJobWrappers(null).size()
        );
        System.assertEquals(
            0,
            FormServiceRepairOrderCustomerCopyExt.buildJobWrappers(
                new List<dealer__Service_Job__c>()
            )
            .size()
        );
    }

    @IsTest
    static void buildJobWrappersDisplaysCustomerPayCharges() {
        String jobJson =
            '{' +
            '"dealer__Line_Number__c":1,' +
            '"dealer__Op_Code__c":"OILCHG",' +
            '"dealer__Labor_Type__c":"C",' +
            '"dealer__CustomerConcern__c":"Noise when braking",' +
            '"dealer__CauseExtended__c":"Worn pads",' +
            '"dealer__Correction__c":"Replaced pads",' +
            '"dealer__Labor_Charges__c":120.00,' +
            '"dealer__Misc_Charges__c":15.00,' +
            '"dealer__Sublet_Total__c":40.00,' +
            '"dealer__Line_Total__c":250.00,' +
            '"dealer__Parts_Lines__r":{"totalSize":2,"done":true,"records":[' +
            '{"attributes":{"type":"dealer__Parts_Invoice_Line__c"},"dealer__Quantity_Sold__c":2,"dealer__Part_Number__c":"BRK-1","dealer__Part_Description__c":"Brake pad","dealer__Price__c":25.00,"dealer__Extended_Price__c":50.00,"dealer__Pay_Type__c":"C"},' +
            '{"attributes":{"type":"dealer__Parts_Invoice_Line__c"},"dealer__Quantity_Sold__c":1,"dealer__Part_Number__c":"WAR-1","dealer__Part_Description__c":"Warranty part","dealer__Price__c":10.00,"dealer__Extended_Price__c":10.00,"dealer__Pay_Type__c":"W"}' +
            ']},' +
            '"dealer__Parts_Ledger_Entries__r":{"totalSize":1,"done":true,"records":[' +
            '{"attributes":{"type":"dealer__Parts_Ledger__c"},"dealer__SerialNumber__c":"SN-123"}' +
            ']},' +
            '"dealer__Service_Misc_Charge__r":{"totalSize":1,"done":true,"records":[' +
            '{"attributes":{"type":"dealer__Service_Misc_Charge__c"},"dealer__Description__c":"Shop supplies","dealer__Amount__c":15.00,"dealer__MiscChargeCode__r":{"attributes":{"type":"dealer__MiscChargeCode__c"},"Name":"SUPPLY"}}' +
            ']},' +
            '"dealer__Purchase_Order_Line__r":{"totalSize":1,"done":true,"records":[' +
            '{"attributes":{"type":"dealer__Purchase_Order_Line__c"},"dealer__Description__c":"Alignment","dealer__Customer_Total__c":40.00,"dealer__Purchase_Order__r":{"attributes":{"type":"dealer__Purchase_Order__c"},"Name":"PO-100","dealer__Vendor_Name__c":"Align Co"}}' +
            ']}' +
            '}';
        dealer__Service_Job__c job = (dealer__Service_Job__c) JSON.deserialize(
            jobJson,
            dealer__Service_Job__c.class
        );

        List<FormServiceRepairOrderCustomerCopyExt.JobWrapper> wrappers =
            FormServiceRepairOrderCustomerCopyExt.buildJobWrappers(
                new List<dealer__Service_Job__c>{ job }
            );

        System.assertEquals(1, wrappers.size());
        FormServiceRepairOrderCustomerCopyExt.JobWrapper w = wrappers[0];
        System.assertEquals(true, w.isCustomerPay);
        System.assertEquals('OILCHG', w.opCode);
        System.assertEquals(true, w.hasCause);
        System.assertEquals(true, w.hasCorrection);
        System.assertEquals(120.00, w.laborDisplay);
        System.assertEquals(15.00, w.miscDisplay);
        System.assertEquals(40.00, w.subletDisplay);
        System.assertEquals(250.00, w.lineTotalDisplay);

        System.assertEquals(2, w.parts.size());
        // Only the customer-pay part contributes to the parts sum.
        System.assertEquals(50.00, w.partsSum);
        System.assertEquals(25.00, w.parts[0].priceDisplay);
        System.assertEquals(50.00, w.parts[0].extendedDisplay);
        System.assertEquals(0, w.parts[1].extendedDisplay);

        System.assertEquals(true, w.hasSerialNumbers);
        System.assertEquals('SN-123', w.serialNumbers[0]);

        System.assertEquals(true, w.hasMisc);
        System.assertEquals('SUPPLY', w.miscCharges[0].code);
        System.assertEquals(15.00, w.miscCharges[0].amountDisplay);

        System.assertEquals(true, w.hasSublet);
        System.assertEquals('PO-100', w.sublets[0].poNumber);
        System.assertEquals('Align Co', w.sublets[0].vendorName);
        System.assertEquals(40.00, w.sublets[0].customerTotalDisplay);
    }

    @IsTest
    static void buildJobWrappersZeroesOutNonCustomerPayCharges() {
        String jobJson =
            '{' +
            '"dealer__Line_Number__c":2,' +
            '"dealer__Labor_Type__c":"W",' +
            '"dealer__Labor_Charges__c":99.00,' +
            '"dealer__Misc_Charges__c":10.00,' +
            '"dealer__Sublet_Total__c":20.00,' +
            '"dealer__Line_Total__c":150.00,' +
            '"dealer__Parts_Lines__r":{"totalSize":1,"done":true,"records":[' +
            '{"attributes":{"type":"dealer__Parts_Invoice_Line__c"},"dealer__Quantity_Sold__c":1,"dealer__Part_Number__c":"WAR-2","dealer__Part_Description__c":"Covered part","dealer__Price__c":30.00,"dealer__Extended_Price__c":30.00,"dealer__Pay_Type__c":"W"}' +
            ']}' +
            '}';
        dealer__Service_Job__c job = (dealer__Service_Job__c) JSON.deserialize(
            jobJson,
            dealer__Service_Job__c.class
        );

        FormServiceRepairOrderCustomerCopyExt.JobWrapper w =
            FormServiceRepairOrderCustomerCopyExt.buildJobWrappers(
                new List<dealer__Service_Job__c>{ job }
            )[0];

        System.assertEquals(false, w.isCustomerPay);
        System.assertEquals(0, w.laborDisplay);
        System.assertEquals(0, w.miscDisplay);
        System.assertEquals(0, w.subletDisplay);
        System.assertEquals(0, w.lineTotalDisplay);
        System.assertEquals(0, w.partsSum);
        System.assertEquals(0, w.parts[0].priceDisplay);
        System.assertEquals(0, w.parts[0].extendedDisplay);
        System.assertEquals(false, w.hasCause);
        System.assertEquals(false, w.hasCorrection);
        System.assertEquals(false, w.hasMisc);
        System.assertEquals(false, w.hasSublet);
    }

    @IsTest
    static void buildCashLinesSummarizesPayments() {
        List<dealer__Cashering__c> cashering = (List<dealer__Cashering__c>) JSON.deserialize(
            '[' +
            '{"attributes":{"type":"dealer__Cashering__c"},"dealer__Payment_Method__c":"Cash","dealer__Deposit__c":true,"dealer__Amount__c":100.00,"dealer__ProcessingFee__c":0.00},' +
            '{"attributes":{"type":"dealer__Cashering__c"},"dealer__Payment_Method__c":"Visa","dealer__Amount__c":50.00,"dealer__ProcessingFee__c":1.50}' +
            ']',
            List<dealer__Cashering__c>.class
        );

        List<FormServiceRepairOrderCustomerCopyExt.CashLineWrapper> lines =
            FormServiceRepairOrderCustomerCopyExt.buildCashLines(cashering);

        System.assertEquals(2, lines.size());
        System.assertEquals('Visa', lines[1].paymentMethod);
        System.assertEquals(51.50, lines[1].lineTotal);
        System.assertEquals(true, lines[0].isDeposit);
        System.assertEquals(false, lines[1].isDeposit);
        System.assertEquals(
            0,
            FormServiceRepairOrderCustomerCopyExt.buildCashLines(null).size()
        );
    }

    @IsTest
    static void computeTotalsDerivesTotalsFromRepairOrder() {
        dealer__Service_Repair_Order__c order = (dealer__Service_Repair_Order__c) JSON.deserialize(
            '{' +
            '"dealer__Customer_Labor_Charges__c":120.00,' +
            '"dealer__Customer_Parts_Charges__c":60.00,' +
            '"dealer__Customer_Misc_Charges__c":15.00,' +
            '"dealer__Customer_Sublet_Charges__c":40.00,' +
            '"dealer__Customer_Charges__c":235.00,' +
            '"dealer__Discount_Total__c":10.00,' +
            '"dealer__Tax__c":18.00,' +
            '"dealer__Customer_Invoice_Total__c":243.00,' +
            '"dealer__Deposit__c":50.00,' +
            '"dealer__Payments_Total__c":100.00' +
            '}',
            dealer__Service_Repair_Order__c.class
        );

        FormServiceRepairOrderCustomerCopyExt extension = new FormServiceRepairOrderCustomerCopyExt(
            new ApexPages.StandardController(new dealer__Service_Repair_Order__c())
        );

        List<FormServiceRepairOrderCustomerCopyExt.CashLineWrapper> lines =
            FormServiceRepairOrderCustomerCopyExt.buildCashLines(
                (List<dealer__Cashering__c>) JSON.deserialize(
                    '[{"attributes":{"type":"dealer__Cashering__c"},"dealer__Amount__c":90.00,"dealer__ProcessingFee__c":10.00}]',
                    List<dealer__Cashering__c>.class
                )
            );

        extension.computeTotals(order, lines);

        System.assertEquals(120.00, extension.totalLabor);
        System.assertEquals(60.00, extension.totalParts);
        System.assertEquals(15.00, extension.totalMisc);
        System.assertEquals(40.00, extension.totalSublet);
        System.assertEquals(235.00, extension.customerCharges);
        System.assertEquals(10.00, extension.discountTotal);
        System.assertEquals(true, extension.hasDiscount);
        System.assertEquals(18.00, extension.tax);
        System.assertEquals(243.00, extension.invoiceTotal);
        System.assertEquals(50.00, extension.deposit);
        System.assertEquals(true, extension.hasDeposit);
        System.assertEquals(100.00, extension.totalPayments);
        // 243 - 100 payments - 50 deposit
        System.assertEquals(93.00, extension.totalDue);
        System.assertEquals(100.00, extension.totalPaid);
    }

    @IsTest
    static void computeTotalsHandlesNullOrder() {
        FormServiceRepairOrderCustomerCopyExt extension = new FormServiceRepairOrderCustomerCopyExt(
            new ApexPages.StandardController(new dealer__Service_Repair_Order__c())
        );

        extension.computeTotals(null, null);

        System.assertEquals(0, extension.invoiceTotal);
        System.assertEquals(0, extension.totalDue);
    }

    @IsTest
    static void buildServiceHoursLinesReturnsEmptyForNull() {
        System.assertEquals(
            0,
            FormServiceRepairOrderCustomerCopyExt.buildServiceHoursLines(null).size()
        );
    }

    @IsTest
    static void buildServiceHoursLinesGroupsConsecutiveDays() {
        // Mon-Tue share hours (group), Wed closed (break), Thu noon w/ minutes
        // (single-day group + hour12==0 + minute padding), Fri closed,
        // Sat-Sun share hours and run to the final day (trailing flush).
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

        List<String> segments = FormServiceRepairOrderCustomerCopyExt.buildServiceHoursLines(
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
            FormServiceRepairOrderCustomerCopyExt.formatTimeCompact(null)
        );
        System.assertEquals(
            '12:00 AM',
            FormServiceRepairOrderCustomerCopyExt.formatTimeCompact(
                Time.newInstance(0, 0, 0, 0)
            )
        );
    }

    @IsTest
    static void loadJobLinesQueriesByRepairOrderWithoutMatch() {
        FormServiceRepairOrderCustomerCopyExt extension = new FormServiceRepairOrderCustomerCopyExt(
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
        FormServiceRepairOrderCustomerCopyExt extension = new FormServiceRepairOrderCustomerCopyExt(
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
        FormServiceRepairOrderCustomerCopyExt extension = new FormServiceRepairOrderCustomerCopyExt(
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
}
