@IsTest
private class FormServiceRepairOrderAuditCopyTest {
    @IsTest
    static void extensionInitializesWithoutRepairOrder() {
        ApexPages.StandardController controller = new ApexPages.StandardController(
            new dealer__Service_Repair_Order__c()
        );

        Test.startTest();
        FormServiceRepairOrderAuditCopyExt extension = new FormServiceRepairOrderAuditCopyExt(
            controller
        );
        Test.stopTest();

        System.assertEquals(false, extension.hasLogo);
        System.assertEquals(null, extension.logoUrl);
        System.assertEquals(true, extension.isPdf);
        System.assertEquals('PDF', extension.renderAs);
        System.assertEquals(0, extension.jobs.size());
        System.assertEquals(0, extension.cashLines.size());
        System.assertEquals(0, extension.glLines.size());
        System.assertEquals(false, extension.hasPayments);
        System.assertEquals(false, extension.hasGlLines);
        System.assertEquals(0, extension.invoiceTotal);
        System.assertEquals(true, String.isBlank(extension.userLoc.Name));
    }

    @IsTest
    static void renderFormatHonorsPdfParameter() {
        ApexPages.StandardController controller = new ApexPages.StandardController(
            new dealer__Service_Repair_Order__c()
        );

        ApexPages.currentPage().getParameters().put('pdf', 'false');
        FormServiceRepairOrderAuditCopyExt htmlExtension = new FormServiceRepairOrderAuditCopyExt(
            controller
        );
        System.assertEquals(false, htmlExtension.isPdf);
        System.assertEquals(null, htmlExtension.renderAs);

        ApexPages.currentPage().getParameters().put('pdf', 'true');
        FormServiceRepairOrderAuditCopyExt pdfExtension = new FormServiceRepairOrderAuditCopyExt(
            controller
        );
        System.assertEquals(true, pdfExtension.isPdf);
        System.assertEquals('PDF', pdfExtension.renderAs);
    }

    @IsTest
    static void resolveRepairOrderIdUsesControllerRecordId() {
        Id fakeId = fakeRepairOrderId();

        Id resolvedId = FormServiceRepairOrderAuditCopyExt.resolveRepairOrderId(
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

        Id resolvedId = FormServiceRepairOrderAuditCopyExt.resolveRepairOrderId(
            new ApexPages.StandardController(new dealer__Service_Repair_Order__c())
        );

        System.assertEquals(fakeId, resolvedId);
    }

    @IsTest
    static void resolveRepairOrderIdReturnsNullWhenUnavailable() {
        ApexPages.currentPage().getParameters().clear();

        Id resolvedId = FormServiceRepairOrderAuditCopyExt.resolveRepairOrderId(
            new ApexPages.StandardController(new dealer__Service_Repair_Order__c())
        );

        System.assertEquals(null, resolvedId);
    }

    @IsTest
    static void constructorResolvesIdAndQueriesWithoutMatch() {
        Id fakeId = fakeRepairOrderId();

        Test.startTest();
        FormServiceRepairOrderAuditCopyExt extension = new FormServiceRepairOrderAuditCopyExt(
            new ApexPages.StandardController(
                new dealer__Service_Repair_Order__c(Id = fakeId)
            )
        );
        Test.stopTest();

        System.assertEquals(null, extension.ro.Id);
        System.assertEquals(0, extension.jobs.size());
        System.assertEquals(0, extension.cashLines.size());
        System.assertEquals(0, extension.glLines.size());
    }

    @IsTest
    static void loadRepairOrderHandlesMissingRecord() {
        FormServiceRepairOrderAuditCopyExt extension = new FormServiceRepairOrderAuditCopyExt(
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

        FormServiceRepairOrderAuditCopyExt extension = new FormServiceRepairOrderAuditCopyExt(
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
        FormServiceRepairOrderAuditCopyExt extension = new FormServiceRepairOrderAuditCopyExt(
            new ApexPages.StandardController(new dealer__Service_Repair_Order__c())
        );
        extension.applyCustomerDetails(null);

        System.assertEquals(null, extension.customerName);
        System.assertEquals(null, extension.customerEmail);
    }

    @IsTest
    static void buildJobWrappersHandlesNullAndEmpty() {
        System.assertEquals(
            0,
            FormServiceRepairOrderAuditCopyExt.buildJobWrappers(null).size()
        );
        System.assertEquals(
            0,
            FormServiceRepairOrderAuditCopyExt.buildJobWrappers(
                new List<dealer__Service_Job__c>()
            )
            .size()
        );
    }

    @IsTest
    static void buildJobWrappersExposesCostAndPriceForAllPayTypes() {
        String jobJson =
            '{' +
            '"dealer__Line_Number__c":1,' +
            '"dealer__Op_Code__c":"OILCHG",' +
            '"dealer__Labor_Type__c":"W",' +
            '"dealer__Service_Type__c":"Maintenance",' +
            '"dealer__CustomerConcern__c":"Noise when braking",' +
            '"dealer__CauseExtended__c":"Worn pads",' +
            '"dealer__Correction__c":"Replaced pads",' +
            '"dealer__Technician__r":{"attributes":{"type":"dealer__Service_Technician__c"},"Name":"Sam Tech"},' +
            '"dealer__Labor_Charges__c":120.00,' +
            '"dealer__Technician_Cost__c":48.00,' +
            '"dealer__Parts_Total__c":60.00,' +
            '"dealer__Parts_Cost__c":36.00,' +
            '"dealer__Misc_Charges__c":15.00,' +
            '"dealer__MiscChargeCost__c":5.00,' +
            '"dealer__Sublet_Total__c":40.00,' +
            '"dealer__Sublet_Cost__c":30.00,' +
            '"dealer__LineDiscountAmount__c":0.00,' +
            '"dealer__Line_Total__c":235.00,' +
            '"dealer__Parts_Lines__r":{"totalSize":2,"done":true,"records":[' +
            '{"attributes":{"type":"dealer__Parts_Invoice_Line__c"},"dealer__Quantity_Sold__c":2,"dealer__Part_Number__c":"BRK-1","dealer__Part_Description__c":"Brake pad","dealer__Cost__c":15.00,"dealer__Extended_Cost__c":30.00,"dealer__Price__c":25.00,"dealer__Extended_Price__c":50.00,"dealer__Pay_Type__c":"C"},' +
            '{"attributes":{"type":"dealer__Parts_Invoice_Line__c"},"dealer__Quantity_Sold__c":1,"dealer__Part_Number__c":"WAR-1","dealer__Part_Description__c":"Warranty part","dealer__Cost__c":6.00,"dealer__Extended_Cost__c":6.00,"dealer__Price__c":10.00,"dealer__Extended_Price__c":10.00,"dealer__Pay_Type__c":"W"}' +
            ']},' +
            '"dealer__Parts_Ledger_Entries__r":{"totalSize":1,"done":true,"records":[' +
            '{"attributes":{"type":"dealer__Parts_Ledger__c"},"dealer__SerialNumber__c":"SN-123"}' +
            ']},' +
            '"dealer__Service_Misc_Charge__r":{"totalSize":1,"done":true,"records":[' +
            '{"attributes":{"type":"dealer__Service_Misc_Charge__c"},"dealer__Description__c":"Shop supplies","dealer__Amount__c":15.00,"dealer__Cost__c":5.00,"dealer__MiscChargeCode__r":{"attributes":{"type":"dealer__MiscChargeCode__c"},"Name":"SUPPLY"}}' +
            ']},' +
            '"dealer__Purchase_Order_Line__r":{"totalSize":1,"done":true,"records":[' +
            '{"attributes":{"type":"dealer__Purchase_Order_Line__c"},"dealer__Description__c":"Alignment","dealer__Customer_Total__c":40.00,"dealer__Cost__c":30.00,"dealer__Purchase_Order__r":{"attributes":{"type":"dealer__Purchase_Order__c"},"Name":"PO-100","dealer__PO_Number__c":"PO-100","dealer__Vendor_Name__c":"Align Co","dealer__Status__c":"Posted","dealer__Invoice_Number__c":"INV-9"}}' +
            ']}' +
            '}';
        dealer__Service_Job__c job = (dealer__Service_Job__c) JSON.deserialize(
            jobJson,
            dealer__Service_Job__c.class
        );

        List<FormServiceRepairOrderAuditCopyExt.JobWrapper> wrappers =
            FormServiceRepairOrderAuditCopyExt.buildJobWrappers(
                new List<dealer__Service_Job__c>{ job }
            );

        System.assertEquals(1, wrappers.size());
        FormServiceRepairOrderAuditCopyExt.JobWrapper w = wrappers[0];
        System.assertEquals('OILCHG', w.opCode);
        System.assertEquals('Sam Tech', w.technicianName);
        System.assertEquals(true, w.hasCause);
        System.assertEquals(true, w.hasCorrection);

        // Warranty labor still shows cost and price (no customer-pay gating).
        System.assertEquals(48.00, w.laborCost);
        System.assertEquals(120.00, w.laborSale);
        System.assertEquals(72.00, w.laborGross);
        System.assertEquals(36.00, w.partsCost);
        System.assertEquals(60.00, w.partsSale);
        System.assertEquals(5.00, w.miscCost);
        System.assertEquals(15.00, w.miscSale);
        System.assertEquals(30.00, w.subletCost);
        System.assertEquals(40.00, w.subletSale);
        System.assertEquals(119.00, w.lineCost);
        System.assertEquals(235.00, w.lineSale);
        System.assertEquals(116.00, w.lineGross);

        System.assertEquals(2, w.parts.size());
        System.assertEquals('C', w.parts[0].payType);
        System.assertEquals(15.00, w.parts[0].unitCost);
        System.assertEquals(30.00, w.parts[0].extendedCost);
        System.assertEquals(25.00, w.parts[0].unitPrice);
        System.assertEquals(50.00, w.parts[0].extendedPrice);
        // Warranty part is still rendered with real numbers.
        System.assertEquals('W', w.parts[1].payType);
        System.assertEquals(10.00, w.parts[1].extendedPrice);

        System.assertEquals(true, w.hasSerialNumbers);
        System.assertEquals('SN-123', w.serialNumbers[0]);

        System.assertEquals(true, w.hasMisc);
        System.assertEquals('SUPPLY', w.miscCharges[0].code);
        System.assertEquals(5.00, w.miscCharges[0].cost);
        System.assertEquals(15.00, w.miscCharges[0].amount);

        System.assertEquals(true, w.hasSublet);
        System.assertEquals('PO-100', w.sublets[0].poNumber);
        System.assertEquals('Align Co', w.sublets[0].vendorName);
        System.assertEquals('Posted', w.sublets[0].poStatus);
        System.assertEquals('INV-9', w.sublets[0].invoiceNumber);
        System.assertEquals(30.00, w.sublets[0].cost);
        System.assertEquals(40.00, w.sublets[0].price);
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

        List<FormServiceRepairOrderAuditCopyExt.CashLineWrapper> lines =
            FormServiceRepairOrderAuditCopyExt.buildCashLines(cashering);

        System.assertEquals(2, lines.size());
        System.assertEquals('Visa', lines[1].paymentMethod);
        System.assertEquals(51.50, lines[1].lineTotal);
        System.assertEquals(true, lines[0].isDeposit);
        System.assertEquals(false, lines[1].isDeposit);
        System.assertEquals(
            0,
            FormServiceRepairOrderAuditCopyExt.buildCashLines(null).size()
        );
    }

    @IsTest
    static void computeTotalsDerivesPayTypeAndGrossTotals() {
        dealer__Service_Repair_Order__c order = (dealer__Service_Repair_Order__c) JSON.deserialize(
            '{' +
            '"dealer__Customer_Labor_Charges__c":120.00,' +
            '"dealer__Warranty_Labor_Charges__c":30.00,' +
            '"dealer__Internal_Labor_Charges__c":10.00,' +
            '"dealer__Customer_Parts_Charges__c":60.00,' +
            '"dealer__Warranty_Parts_Charges__c":20.00,' +
            '"dealer__Internal_Parts_Charges__c":5.00,' +
            '"dealer__Customer_Misc_Charges__c":15.00,' +
            '"dealer__Warranty_Misc_Charges__c":2.00,' +
            '"dealer__Internal_Misc_Charges__c":1.00,' +
            '"dealer__Total_Misc_Charges__c":18.00,' +
            '"dealer__Customer_Sublet_Charges__c":40.00,' +
            '"dealer__WarrantySubletCharges__c":4.00,' +
            '"dealer__Internal_Sublet_Charges__c":2.00,' +
            '"dealer__Customer_Charges__c":235.00,' +
            '"dealer__Warranty_Charges__c":56.00,' +
            '"dealer__Internal_Charges__c":18.00,' +
            '"dealer__Discount_Total__c":10.00,' +
            '"dealer__Tax__c":18.00,' +
            '"dealer__Customer_Invoice_Total__c":243.00,' +
            '"dealer__Total_Repair_Order_Charges__c":309.00,' +
            '"dealer__Deposit__c":50.00,' +
            '"dealer__Payments_Total__c":100.00' +
            '}',
            dealer__Service_Repair_Order__c.class
        );

        FormServiceRepairOrderAuditCopyExt extension = new FormServiceRepairOrderAuditCopyExt(
            new ApexPages.StandardController(new dealer__Service_Repair_Order__c())
        );

        FormServiceRepairOrderAuditCopyExt.JobWrapper jobWrapper =
            FormServiceRepairOrderAuditCopyExt.buildJobWrappers(
                new List<dealer__Service_Job__c>{
                    (dealer__Service_Job__c) JSON.deserialize(
                        '{"dealer__Technician_Cost__c":48.00,"dealer__Parts_Cost__c":36.00,"dealer__MiscChargeCost__c":5.00,"dealer__Sublet_Cost__c":30.00,"dealer__Line_Total__c":235.00}',
                        dealer__Service_Job__c.class
                    )
                }
            )[0];

        List<FormServiceRepairOrderAuditCopyExt.CashLineWrapper> lines =
            FormServiceRepairOrderAuditCopyExt.buildCashLines(
                (List<dealer__Cashering__c>) JSON.deserialize(
                    '[{"attributes":{"type":"dealer__Cashering__c"},"dealer__Amount__c":90.00,"dealer__ProcessingFee__c":10.00}]',
                    List<dealer__Cashering__c>.class
                )
            );

        extension.computeTotals(
            order,
            lines,
            new List<FormServiceRepairOrderAuditCopyExt.JobWrapper>{ jobWrapper }
        );

        System.assertEquals(120.00, extension.customerLabor);
        System.assertEquals(30.00, extension.warrantyLabor);
        System.assertEquals(10.00, extension.internalLabor);
        System.assertEquals(160.00, extension.totalLaborSale);
        System.assertEquals(85.00, extension.totalPartsSale);
        System.assertEquals(18.00, extension.totalMiscSale);
        System.assertEquals(46.00, extension.totalSubletSale);
        System.assertEquals(235.00, extension.customerCharges);
        System.assertEquals(56.00, extension.warrantyCharges);
        System.assertEquals(18.00, extension.internalCharges);
        System.assertEquals(10.00, extension.discountTotal);
        System.assertEquals(true, extension.hasDiscount);
        System.assertEquals(18.00, extension.tax);
        System.assertEquals(309.00, extension.invoiceTotal);
        System.assertEquals(243.00, extension.customerInvoiceTotal);
        System.assertEquals(50.00, extension.deposit);
        System.assertEquals(true, extension.hasDeposit);
        System.assertEquals(100.00, extension.totalPayments);
        // 243 - 100 payments - 50 deposit
        System.assertEquals(93.00, extension.totalDue);
        System.assertEquals(100.00, extension.totalPaid);

        // Gross summary aggregated from job wrappers.
        System.assertEquals(48.00, extension.totalLaborCost);
        System.assertEquals(36.00, extension.totalPartsCost);
        System.assertEquals(5.00, extension.totalMiscCost);
        System.assertEquals(30.00, extension.totalSubletCost);
        System.assertEquals(119.00, extension.totalCost);
        System.assertEquals(235.00, extension.totalSale);
        System.assertEquals(116.00, extension.totalGross);
        System.assert(extension.grossPercent > 0);
    }

    @IsTest
    static void computeTotalsHandlesNullOrder() {
        FormServiceRepairOrderAuditCopyExt extension = new FormServiceRepairOrderAuditCopyExt(
            new ApexPages.StandardController(new dealer__Service_Repair_Order__c())
        );

        extension.computeTotals(null, null, null);

        System.assertEquals(0, extension.invoiceTotal);
        System.assertEquals(0, extension.totalDue);
        System.assertEquals(0, extension.totalGross);
        System.assertEquals(0, extension.grossPercent);
    }

    @IsTest
    static void glWrapperMapsExternalObjectFields() {
        dealer__GLDetail__x detail = (dealer__GLDetail__x) JSON.deserialize(
            '{' +
            '"dealer__Account__c":"4000-01",' +
            '"dealer__AccountName__c":"Labor Sales",' +
            '"dealer__Amount__c":120.00,' +
            '"dealer__ControlNumber__c":"CTRL-1",' +
            '"dealer__Journal__c":"RepairOrders",' +
            '"dealer__PostingDescription__c":"RO labor",' +
            '"dealer__SaleType__c":"C",' +
            '"dealer__Reference__c":"RO-1001",' +
            '"dealer__Tax__c":0.00' +
            '}',
            dealer__GLDetail__x.class
        );

        FormServiceRepairOrderAuditCopyExt.GLLineWrapper w =
            new FormServiceRepairOrderAuditCopyExt.GLLineWrapper(detail);

        System.assertEquals('4000-01', w.account);
        System.assertEquals('Labor Sales', w.accountName);
        System.assertEquals('CTRL-1', w.controlNumber);
        System.assertEquals('RepairOrders', w.journal);
        System.assertEquals('RO labor', w.postingDescription);
        System.assertEquals('C', w.saleType);
        System.assertEquals('RO-1001', w.reference);
        System.assertEquals(120.00, w.amount);

        List<FormServiceRepairOrderAuditCopyExt.GLLineWrapper> lines =
            new List<FormServiceRepairOrderAuditCopyExt.GLLineWrapper>{ w, w };
        System.assertEquals(240.00, FormServiceRepairOrderAuditCopyExt.sumGlAmount(lines));
        System.assertEquals(0, FormServiceRepairOrderAuditCopyExt.sumGlAmount(null));
    }

    @IsTest
    static void loadGlLinesReturnsEmptyDuringTestAndForBlankReference() {
        FormServiceRepairOrderAuditCopyExt extension = new FormServiceRepairOrderAuditCopyExt(
            new ApexPages.StandardController(new dealer__Service_Repair_Order__c())
        );

        System.assertEquals(0, extension.loadGlLines(null).size());
        System.assertEquals(0, extension.loadGlLines('RO-1001').size());
    }

    @IsTest
    static void buildServiceHoursLinesReturnsEmptyForNull() {
        System.assertEquals(
            0,
            FormServiceRepairOrderAuditCopyExt.buildServiceHoursLines(null).size()
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

        List<String> segments = FormServiceRepairOrderAuditCopyExt.buildServiceHoursLines(
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
            FormServiceRepairOrderAuditCopyExt.formatTimeCompact(null)
        );
        System.assertEquals(
            '12:00 AM',
            FormServiceRepairOrderAuditCopyExt.formatTimeCompact(
                Time.newInstance(0, 0, 0, 0)
            )
        );
    }

    @IsTest
    static void loadJobLinesQueriesByRepairOrderWithoutMatch() {
        FormServiceRepairOrderAuditCopyExt extension = new FormServiceRepairOrderAuditCopyExt(
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
        FormServiceRepairOrderAuditCopyExt extension = new FormServiceRepairOrderAuditCopyExt(
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
        FormServiceRepairOrderAuditCopyExt extension = new FormServiceRepairOrderAuditCopyExt(
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
