@IsTest
private class FormPartsInvoiceExtTest {
    @IsTest
    static void extensionInitializesWithoutInvoiceId() {
        ApexPages.StandardController controller = new ApexPages.StandardController(
            new dealer__Parts_Invoice__c()
        );

        Test.startTest();
        FormPartsInvoiceExt extension = new FormPartsInvoiceExt(controller);
        Test.stopTest();

        System.assertEquals(false, extension.hasLogo);
        System.assertEquals(null, extension.logoUrl);
        System.assertEquals(true, extension.isPdf);
        System.assertEquals('PDF', extension.renderAs);
        System.assertEquals(0, extension.invoiceLineItems.size());
        System.assertEquals(0, extension.cashLines.size());
        System.assertEquals(true, extension.isPreInvoice);
        System.assertEquals(true, String.isBlank(extension.userLoc.Name));
    }

    @IsTest
    static void renderFormatDefaultsToPdfWithoutParameter() {
        ApexPages.currentPage().getParameters().clear();

        FormPartsInvoiceExt extension = new FormPartsInvoiceExt(
            new ApexPages.StandardController(new dealer__Parts_Invoice__c())
        );

        System.assertEquals(true, extension.isPdf);
        System.assertEquals('PDF', extension.renderAs);
    }

    @IsTest
    static void renderFormatHonorsPdfParameter() {
        ApexPages.StandardController controller = new ApexPages.StandardController(
            new dealer__Parts_Invoice__c()
        );

        ApexPages.currentPage().getParameters().put('pdf', 'false');
        FormPartsInvoiceExt htmlExtension = new FormPartsInvoiceExt(controller);
        System.assertEquals(false, htmlExtension.isPdf);
        System.assertEquals(null, htmlExtension.renderAs);

        ApexPages.currentPage().getParameters().put('pdf', 'true');
        FormPartsInvoiceExt pdfExtension = new FormPartsInvoiceExt(controller);
        System.assertEquals(true, pdfExtension.isPdf);
        System.assertEquals('PDF', pdfExtension.renderAs);
    }

    @IsTest
    static void resolvePartsInvoiceIdUsesControllerRecordId() {
        Id fakeId = fakePartsInvoiceId();

        Id resolvedId = FormPartsInvoiceExt.resolvePartsInvoiceId(
            new ApexPages.StandardController(
                new dealer__Parts_Invoice__c(Id = fakeId)
            )
        );

        System.assertEquals(fakeId, resolvedId);
    }

    @IsTest
    static void resolvePartsInvoiceIdUsesPageParameter() {
        Id fakeId = fakePartsInvoiceId();
        ApexPages.currentPage().getParameters().put('id', fakeId);

        Id resolvedId = FormPartsInvoiceExt.resolvePartsInvoiceId(
            new ApexPages.StandardController(new dealer__Parts_Invoice__c())
        );

        System.assertEquals(fakeId, resolvedId);
    }

    @IsTest
    static void resolvePartsInvoiceIdReturnsNullWhenUnavailable() {
        ApexPages.currentPage().getParameters().clear();

        Id resolvedId = FormPartsInvoiceExt.resolvePartsInvoiceId(
            new ApexPages.StandardController(new dealer__Parts_Invoice__c())
        );

        System.assertEquals(null, resolvedId);
    }

    @IsTest
    static void constructorResolvesIdAndQueriesWithoutMatch() {
        Id fakeId = fakePartsInvoiceId();

        Test.startTest();
        FormPartsInvoiceExt extension = new FormPartsInvoiceExt(
            new ApexPages.StandardController(
                new dealer__Parts_Invoice__c(Id = fakeId)
            )
        );
        Test.stopTest();

        System.assertEquals(null, extension.invoice.Id);
        System.assertEquals(0, extension.invoiceLineItems.size());
        System.assertEquals(0, extension.cashLines.size());
    }

    @IsTest
    static void loadPartsInvoiceHandlesMissingRecord() {
        FormPartsInvoiceExt extension = new FormPartsInvoiceExt(
            new ApexPages.StandardController(new dealer__Parts_Invoice__c())
        );
        extension.loadPartsInvoice(fakePartsInvoiceId());

        System.assertEquals(null, extension.invoice.Id);
        System.assertEquals(0, extension.invoiceLineItems.size());
    }

    @IsTest
    static void resolveLinePartDescriptionPrefersLineAndReturnLineSources() {
        System.assertEquals(
            'Core charge',
            FormPartsInvoiceExt.resolveLinePartDescription(
                (dealer__Parts_Invoice_Line__c) JSON.deserialize(
                    '{"dealer__MiscellaneousChargeCode__c":"' +
                    fakeMiscChargeCodeId() +
                    '","dealer__Comment__c":"Core charge",' +
                    '"dealer__Part_Description__c":"Oil filter"}',
                    dealer__Parts_Invoice_Line__c.class
                )
            )
        );
        System.assertEquals(
            'Oil filter',
            FormPartsInvoiceExt.resolveLinePartDescription(
                (dealer__Parts_Invoice_Line__c) JSON.deserialize(
                    '{"dealer__Part_Description__c":"Oil filter",' +
                    '"dealer__Comment__c":"Received core"}',
                    dealer__Parts_Invoice_Line__c.class
                )
            )
        );
        System.assertEquals(
            'Front Brake Caliper 2018-2021 Ford Explorer',
            FormPartsInvoiceExt.resolveLinePartDescription(
                (dealer__Parts_Invoice_Line__c) JSON.deserialize(
                    '{"dealer__Part_Number__c":"RD1:OEM:N1040427506MTR",' +
                    '"dealer__Comment__c":"Received core",' +
                    '"dealer__PartsReturnLine__r":{' +
                    '"dealer__Part_Description__c":' +
                    '"Front Brake Caliper 2018-2021 Ford Explorer"}}',
                    dealer__Parts_Invoice_Line__c.class
                )
            )
        );
        System.assertEquals(
            'Battery Group 65',
            FormPartsInvoiceExt.resolveLinePartDescription(
                (dealer__Parts_Invoice_Line__c) JSON.deserialize(
                    '{"dealer__Part_Number__c":"BAT-65",' +
                    '"dealer__Part__r":{"dealer__Description__c":"Battery Group 65"}}',
                    dealer__Parts_Invoice_Line__c.class
                )
            )
        );
        System.assertEquals(
            'BAT-65',
            FormPartsInvoiceExt.resolveLinePartDescription(
                (dealer__Parts_Invoice_Line__c) JSON.deserialize(
                    '{"dealer__Part_Number__c":"BAT-65"}',
                    dealer__Parts_Invoice_Line__c.class
                )
            )
        );
    }

    @IsTest
    static void resolveBinDisplayPrefersBinLocationName() {
        System.assertEquals(
            'A-12',
            FormPartsInvoiceExt.resolveBinDisplay('A-12', 'BIN-1')
        );
        System.assertEquals(
            'BIN-1',
            FormPartsInvoiceExt.resolveBinDisplay(null, 'BIN-1')
        );
    }

    @IsTest
    static void buildPageBrokenLinesPaginatesInvoiceLines() {
        List<FormPartsInvoiceExt.InvoiceLineWrapper> lines =
            new List<FormPartsInvoiceExt.InvoiceLineWrapper>();
        for (Integer i = 0; i < 3; i++) {
            lines.add(buildLineWrapper('PART-' + i));
        }

        List<List<FormPartsInvoiceExt.InvoiceLineWrapper>> pages =
            FormPartsInvoiceExt.buildPageBrokenLines(lines, 2);

        System.assertEquals(2, pages.size());
        System.assertEquals(2, pages[0].size());
        System.assertEquals(1, pages[1].size());
        System.assertEquals('PART-0', pages[0][0].partNumber);
        System.assertEquals('PART-2', pages[1][0].partNumber);
    }

    @IsTest
    static void invoiceLineWrapperMapsFieldsAndSerialNumbers() {
        dealer__Parts_Invoice_Line__c line = (dealer__Parts_Invoice_Line__c) JSON.deserialize(
            '{' +
            '"dealer__Quantity_Sold__c":2,' +
            '"dealer__Part_Number__c":"BRK-1",' +
            '"dealer__Part_Description__c":"Brake pad",' +
            '"dealer__Bin__c":"BIN-A",' +
            '"dealer__Price__c":25.00,' +
            '"dealer__Core__c":12.50,' +
            '"dealer__TotalCore__c":25.00,' +
            '"dealer__Total_Price__c":50.00,' +
            '"dealer__Extended_Price__c":50.00,' +
            '"dealer__MiscellaneousChargeCode__c":null,' +
            '"dealer__Comment__c":"Defective part",' +
            '"dealer__QuantityReturned__c":1,' +
            '"dealer__Part__r":{"dealer__BinLocation__r":{"Name":"A-12"}},' +
            '"dealer__Parts_Ledgers__r":{"totalSize":1,"done":true,"records":[' +
            '{"dealer__SerialNumber__c":"SN-123"}' +
            ']}}',
            dealer__Parts_Invoice_Line__c.class
        );

        FormPartsInvoiceExt.InvoiceLineWrapper wrapper =
            new FormPartsInvoiceExt.InvoiceLineWrapper(line);

        System.assertEquals(2, wrapper.quantity);
        System.assertEquals('BRK-1', wrapper.partNumber);
        System.assertEquals('Brake pad', wrapper.displayDescription);
        System.assertEquals('A-12', wrapper.binDisplay);
        System.assertEquals(25.00, wrapper.unitPrice);
        System.assertEquals(12.50, wrapper.coreCharge);
        System.assertEquals(25.00, wrapper.totalCore);
        System.assertEquals(50.00, wrapper.totalPrice);
        System.assertEquals(true, wrapper.hasSerialNumbers);
        System.assertEquals(1, wrapper.serialNumbers.size());
        System.assertEquals('SN-123', wrapper.serialNumbers[0]);
        System.assertEquals('Defective part', wrapper.lineComment);
        System.assertEquals(true, wrapper.hasLineComment);
        System.assertEquals(1, wrapper.quantityReturned);
    }

    @IsTest
    static void buildCashLinesMapsPaymentRows() {
        dealer__Cashering__c cash = (dealer__Cashering__c) JSON.deserialize(
            '{"dealer__Payment_Method__c":"Visa","dealer__Payment_Type__c":"Payment","dealer__Deposit__c":true,"dealer__Close_Date__c":"2026-06-01","dealer__Amount__c":125.00,"dealer__ProcessingFee__c":3.50}',
            dealer__Cashering__c.class
        );

        List<FormPartsInvoiceExt.CashLineWrapper> lines =
            FormPartsInvoiceExt.buildCashLines(
                new List<dealer__Cashering__c>{ cash }
            );

        System.assertEquals(1, lines.size());
        System.assertEquals('Visa', lines[0].paymentMethod);
        System.assertEquals('Payment', lines[0].paymentType);
        System.assertEquals(true, lines[0].isDeposit);
        System.assertEquals(Date.newInstance(2026, 6, 1), lines[0].closeDate);
        System.assertEquals(125.00, lines[0].amount);
        System.assertEquals(3.50, lines[0].processingFee);
        System.assertEquals(128.50, lines[0].lineTotal);
        System.assertEquals(0, FormPartsInvoiceExt.buildCashLines(null).size());
    }

    @IsTest
    static void computePaymentTotalsSumsLineTotals() {
        FormPartsInvoiceExt extension = new FormPartsInvoiceExt(
            new ApexPages.StandardController(new dealer__Parts_Invoice__c())
        );
        extension.assignTestState(
            null,
            null,
            FormPartsInvoiceExt.buildCashLines(
                new List<dealer__Cashering__c>{
                    (dealer__Cashering__c) JSON.deserialize(
                        '{"dealer__Amount__c":90.00,"dealer__ProcessingFee__c":10.00}',
                        dealer__Cashering__c.class
                    )
                }
            ),
            null
        );

        System.assertEquals(100.00, extension.totalPaid);
        System.assertEquals(true, extension.hasPayments);
    }

    @IsTest
    static void applyShipToDetailsUsesStructuredAddressFields() {
        FormPartsInvoiceExt extension = new FormPartsInvoiceExt(
            new ApexPages.StandardController(new dealer__Parts_Invoice__c())
        );
        extension.assignTestState(
            new dealer__Parts_Invoice__c(
                dealer__Customer_ShipTo_Street__c = '9 Hamilton Avenue',
                dealer__Customer_ShipTo_City__c = 'Wauna',
                dealer__Customer_Shipto_State__c = 'WA',
                dealer__Customer_ShipTo_Zip__c = '98395'
            ),
            null,
            null,
            null
        );

        System.assertEquals(true, extension.hasStructuredShipTo);
        System.assertEquals(true, extension.showShipTo);
        System.assertEquals('9 Hamilton Avenue', extension.shipToStreet);
        System.assertEquals('Wauna', extension.shipToCity);
        System.assertEquals('WA', extension.shipToState);
        System.assertEquals('98395', extension.shipToPostalCode);
    }

    @IsTest
    static void buildInvoiceLineWrappersHandlesEmptyInput() {
        System.assertEquals(
            0,
            FormPartsInvoiceExt.buildInvoiceLineWrappers(null).size()
        );
        System.assertEquals(
            0,
            FormPartsInvoiceExt.buildInvoiceLineWrappers(
                new List<dealer__Parts_Invoice_Line__c>()
            ).size()
        );
    }

    @IsTest
    static void applyCustomerDetailsMapsFields() {
        FormPartsInvoiceExt extension = new FormPartsInvoiceExt(
            new ApexPages.StandardController(new dealer__Parts_Invoice__c())
        );
        FixedOpsFormUtil.CustomerDetails details = new FixedOpsFormUtil.CustomerDetails();
        details.name = 'Parts Customer';
        details.street = '123 Main';
        details.city = 'Denver';
        details.state = 'CO';
        details.postalCode = '80202';
        details.phone = '555-111-2222';
        details.mobile = '555-333-4444';
        details.email = 'parts@example.com';

        extension.applyCustomerDetails(details);

        System.assertEquals('Parts Customer', extension.customerName);
        System.assertEquals('123 Main', extension.customerStreet);
        System.assertEquals('Denver', extension.customerCity);
        System.assertEquals('CO', extension.customerState);
        System.assertEquals('80202', extension.customerPostalCode);
        System.assertEquals('555-111-2222', extension.customerPhone);
        System.assertEquals('555-333-4444', extension.customerMobile);
        System.assertEquals('parts@example.com', extension.customerEmail);
    }

    @IsTest
    static void repairOrderInvoiceFlagsHideTotals() {
        FormPartsInvoiceExt extension = new FormPartsInvoiceExt(
            new ApexPages.StandardController(new dealer__Parts_Invoice__c())
        );
        extension.assignTestState(
            new dealer__Parts_Invoice__c(
                RecordType = new RecordType(DeveloperName = 'Repair_Order'),
                dealer__Service_Repair_Order__r = new dealer__Service_Repair_Order__c(
                    Name = 'RO#RD1-1043',
                    dealer__RO_Number__c = '1043'
                )
            ),
            null,
            null,
            null
        );

        System.assertEquals(true, extension.isRepairOrderInvoice);
        System.assertEquals(false, extension.showInvoiceTotals);
        System.assertEquals('RO#RD1-1043', extension.repairOrderNumber);
    }

    @IsTest
    static void retailInvoiceShowsTotals() {
        FormPartsInvoiceExt extension = new FormPartsInvoiceExt(
            new ApexPages.StandardController(new dealer__Parts_Invoice__c())
        );
        extension.assignTestState(
            new dealer__Parts_Invoice__c(
                RecordType = new RecordType(DeveloperName = 'Retail_Sale')
            ),
            null,
            null,
            null
        );

        System.assertEquals(false, extension.isRepairOrderInvoice);
        System.assertEquals(true, extension.showInvoiceTotals);
    }

    @IsTest
    static void vendorReturnInvoiceUsesReturnLayoutFlags() {
        FormPartsInvoiceExt extension = new FormPartsInvoiceExt(
            new ApexPages.StandardController(new dealer__Parts_Invoice__c())
        );
        extension.assignTestState(
            new dealer__Parts_Invoice__c(
                RecordType = new RecordType(DeveloperName = 'Vendor_Return'),
                dealer__RMA_No__c = 'RMA-12345',
                dealer__Ship_To__c = '123 Ship Lane'
            ),
            null,
            FormPartsInvoiceExt.buildCashLines(
                new List<dealer__Cashering__c>{
                    (dealer__Cashering__c) JSON.deserialize(
                        '{"dealer__Payment_Method__c":"Cash","dealer__Amount__c":75}',
                        dealer__Cashering__c.class
                    )
                }
            ),
            null
        );

        System.assertEquals(true, extension.isVendorReturnInvoice);
        System.assertEquals(true, extension.isReturnInvoice);
        System.assertEquals('Vendor Return', extension.formTitle);
        System.assertEquals('Vendor', extension.partyPrimaryLabel);
        System.assertEquals('Qty Returned', extension.lineQuantityLabel);
        System.assertEquals(true, extension.showInvoiceTotals);
        System.assertEquals(false, extension.showPartyShipToColumn);
        System.assertEquals(false, extension.showShipTo);
        System.assertEquals(false, extension.showPaymentsSection);
        System.assertEquals(false, extension.showLineCoreColumn);
        System.assertEquals(true, extension.hasRmaNumber);
    }

    @IsTest
    static void counterReturnInvoiceUsesReturnLayoutFlags() {
        FormPartsInvoiceExt extension = new FormPartsInvoiceExt(
            new ApexPages.StandardController(new dealer__Parts_Invoice__c())
        );
        extension.assignTestState(
            new dealer__Parts_Invoice__c(
                RecordType = new RecordType(DeveloperName = 'Counter_Return'),
                dealer__Ship_To__c = '456 Twin Turbo Lane'
            ),
            null,
            FormPartsInvoiceExt.buildCashLines(
                new List<dealer__Cashering__c>{
                    (dealer__Cashering__c) JSON.deserialize(
                        '{"dealer__Payment_Method__c":"On Account","dealer__Amount__c":-206.18}',
                        dealer__Cashering__c.class
                    )
                }
            ),
            -156.75
        );

        System.assertEquals(true, extension.isCounterReturnInvoice);
        System.assertEquals(true, extension.isReturnInvoice);
        System.assertEquals(false, extension.isVendorReturnInvoice);
        System.assertEquals('Counter Return', extension.formTitle);
        System.assertEquals('Qty Returned', extension.lineQuantityLabel);
        System.assertEquals(true, extension.showInvoiceTotals);
        System.assertEquals(true, extension.showPartyShipToColumn);
        System.assertEquals(true, extension.showShipTo);
        System.assertEquals(true, extension.showPaymentsSection);
        System.assertEquals(false, extension.showLineCoreColumn);
        System.assertEquals('Total Credit', extension.totalDueLabel);
    }

    @IsTest
    static void coreReturnInvoiceUsesCoreReturnLayoutFlags() {
        FormPartsInvoiceExt extension = new FormPartsInvoiceExt(
            new ApexPages.StandardController(new dealer__Parts_Invoice__c())
        );
        extension.assignTestState(
            new dealer__Parts_Invoice__c(
                RecordType = new RecordType(DeveloperName = 'Core_Return'),
                dealer__Ship_To__c = '456 Twin Turbo Lane'
            ),
            null,
            null,
            -58.99
        );

        System.assertEquals(true, extension.isCoreReturnInvoice);
        System.assertEquals(true, extension.isReturnInvoice);
        System.assertEquals(false, extension.isCounterReturnInvoice);
        System.assertEquals('Core Return', extension.formTitle);
        System.assertEquals('Qty Returned', extension.lineQuantityLabel);
        System.assertEquals(true, extension.showInvoiceTotals);
        System.assertEquals(true, extension.showPartyShipToColumn);
        System.assertEquals(true, extension.showShipTo);
        System.assertEquals(true, extension.showLineCoreColumn);
        System.assertEquals('Total Credit', extension.totalDueLabel);
    }

    @IsTest
    static void resolveReturnReferenceInvoiceNameUsesOriginalInvoice() {
        dealer__Parts_Invoice_Line__c line = (dealer__Parts_Invoice_Line__c) JSON.deserialize(
            '{"dealer__ReturnReference__c":"REF-1",' +
            '"dealer__PartsReturnLine__r":{' +
            '"dealer__Parts_Invoice__r":{"Name":"INV#RD1-1019"}}}',
            dealer__Parts_Invoice_Line__c.class
        );

        System.assertEquals(
            'INV#RD1-1019',
            FormPartsInvoiceExt.resolveReturnReferenceInvoiceName(line)
        );
    }

    @IsTest
    static void resolveReturnReferenceInvoiceNameFallsBackToTextReference() {
        dealer__Parts_Invoice_Line__c line = (dealer__Parts_Invoice_Line__c) JSON.deserialize(
            '{"dealer__ReturnReference__c":"Manual Ref"}',
            dealer__Parts_Invoice_Line__c.class
        );

        System.assertEquals(
            'Manual Ref',
            FormPartsInvoiceExt.resolveReturnReferenceInvoiceName(line)
        );
    }

    @IsTest
    static void computedFlagsReflectInvoiceState() {
        FormPartsInvoiceExt extension = new FormPartsInvoiceExt(
            new ApexPages.StandardController(new dealer__Parts_Invoice__c())
        );
        extension.assignTestState(
            new dealer__Parts_Invoice__c(
                dealer__Status__c = 'Open',
                dealer__Comments__c = 'Rush order',
                dealer__Ship_To__c = '123 Ship Lane',
                dealer__PickupOrDelivery__c = 'Delivery',
                dealer__Deposit__c = 50
            ),
            null,
            FormPartsInvoiceExt.buildCashLines(
                new List<dealer__Cashering__c>{
                    (dealer__Cashering__c) JSON.deserialize(
                        '{"dealer__Payment_Method__c":"Cash","dealer__Amount__c":75}',
                        dealer__Cashering__c.class
                    )
                }
            ),
            125
        );

        System.assertEquals(true, extension.isPreInvoice);
        System.assertEquals(true, extension.hasComments);
        System.assertEquals(true, extension.showShipTo);
        System.assertEquals(true, extension.hasShipToAddress);
        System.assertEquals(true, extension.hasCashLines);
        System.assertEquals(true, extension.hasPayments);
        System.assertEquals(true, extension.hasDeposit);
        System.assertEquals(75, extension.totalPaid);
        System.assertEquals(125, extension.totalDue);

        extension.invoice.dealer__Status__c = 'Invoiced';
        System.assertEquals(false, extension.isPreInvoice);
        extension.invoice.dealer__Status__c = 'Posted';
        System.assertEquals(false, extension.isPreInvoice);
    }

    @IsTest
    static void pageBrokenInvoiceLinesUsesCachedPages() {
        FormPartsInvoiceExt extension = new FormPartsInvoiceExt(
            new ApexPages.StandardController(new dealer__Parts_Invoice__c())
        );
        extension.assignTestState(
            null,
            new List<FormPartsInvoiceExt.InvoiceLineWrapper>{
                buildLineWrapper('PART-1'),
                buildLineWrapper('PART-2')
            },
            null,
            null
        );

        List<List<FormPartsInvoiceExt.InvoiceLineWrapper>> pages =
            extension.pageBrokenInvoiceLines;

        System.assertEquals(1, pages.size());
        System.assertEquals(2, pages[0].size());
        System.assertEquals(1, extension.pageBrokenInvoiceLines.size());
    }

    @IsTest(SeeAllData=true)
    static void loadPartsInvoiceLoadsExistingRecordWhenAvailable() {
        List<dealer__Parts_Invoice__c> invoices = [
            SELECT Id
            FROM dealer__Parts_Invoice__c
            LIMIT 1
        ];
        if (invoices.isEmpty()) {
            return;
        }

        FormPartsInvoiceExt extension = new FormPartsInvoiceExt(
            new ApexPages.StandardController(new dealer__Parts_Invoice__c())
        );

        Test.startTest();
        extension.loadPartsInvoice(invoices[0].Id);
        Test.stopTest();

        System.assertEquals(invoices[0].Id, extension.invoice.Id);
        System.assertNotEquals(null, extension.invoiceLineItems);
        System.assertNotEquals(null, extension.cashLines);
        if (extension.invoice.dealer__Invoice_Date_Time__c != null) {
            System.assertNotEquals(null, extension.invoiceDateOnly);
        }
        System.assert(extension.totalDue >= 0);

        if (extension.invoice.dealer__Location__c != null) {
            System.assertNotEquals(null, extension.userLoc);
        }
    }

    @IsTest(SeeAllData=true)
    static void constructorLoadsExistingPartsInvoiceWhenAvailable() {
        List<dealer__Parts_Invoice__c> invoices = [
            SELECT Id
            FROM dealer__Parts_Invoice__c
            LIMIT 1
        ];
        if (invoices.isEmpty()) {
            return;
        }

        Test.startTest();
        FormPartsInvoiceExt extension = new FormPartsInvoiceExt(
            new ApexPages.StandardController(invoices[0])
        );
        Test.stopTest();

        System.assertEquals(invoices[0].Id, extension.invoice.Id);
        System.assertNotEquals(null, extension.printDateTime);
    }

    @IsTest
    static void sumTotalCoreAggregatesLineCoreAmounts() {
        List<FormPartsInvoiceExt.InvoiceLineWrapper> lines =
            new List<FormPartsInvoiceExt.InvoiceLineWrapper>{
                buildLineWrapper('PART-1', 55),
                buildLineWrapper('PART-2', 0)
            };

        System.assertEquals(55, FormPartsInvoiceExt.sumTotalCore(lines));
    }

    @IsTest(SeeAllData=true)
    static void loadPartsInvoiceComputesTotalCoreChargesWhenAvailable() {
        List<dealer__Parts_Invoice__c> invoices = [
            SELECT Id
            FROM dealer__Parts_Invoice__c
            WHERE Name = 'INV#RD1-1049'
            LIMIT 1
        ];
        if (invoices.isEmpty()) {
            return;
        }

        FormPartsInvoiceExt extension = new FormPartsInvoiceExt(
            new ApexPages.StandardController(new dealer__Parts_Invoice__c())
        );
        extension.loadPartsInvoice(invoices[0].Id);

        System.assertEquals(55, extension.totalCoreCharges);
        System.assertEquals(true, extension.hasCoreCharges);
        System.assertEquals(55, extension.invoiceLineItems[0].totalCore);
    }

    private static FormPartsInvoiceExt.InvoiceLineWrapper buildLineWrapper(
        String partNumber
    ) {
        return buildLineWrapper(partNumber, 0);
    }

    private static FormPartsInvoiceExt.InvoiceLineWrapper buildLineWrapper(
        String partNumber,
        Decimal totalCore
    ) {
        dealer__Parts_Invoice_Line__c line = (dealer__Parts_Invoice_Line__c) JSON.deserialize(
            '{"dealer__Part_Number__c":"' + partNumber + '","dealer__TotalCore__c":' + totalCore + '}',
            dealer__Parts_Invoice_Line__c.class
        );
        return new FormPartsInvoiceExt.InvoiceLineWrapper(line);
    }

    private static Id fakePartsInvoiceId() {
        String keyPrefix = dealer__Parts_Invoice__c.SObjectType.getDescribe()
            .getKeyPrefix();
        return Id.valueOf(keyPrefix + '000000000001');
    }

    private static Id fakeMiscChargeCodeId() {
        String keyPrefix = dealer__MiscChargeCode__c.SObjectType.getDescribe()
            .getKeyPrefix();
        return Id.valueOf(keyPrefix + '000000000001');
    }
}
