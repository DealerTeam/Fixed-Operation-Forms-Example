@IsTest
private class FormPartsInvoiceAccountingCopyTest {
    @IsTest
    static void extensionInitializesWithoutInvoiceId() {
        ApexPages.StandardController controller = new ApexPages.StandardController(
            new dealer__Parts_Invoice__c()
        );

        Test.startTest();
        FormPartsInvoiceAccountingCopyExt extension = new FormPartsInvoiceAccountingCopyExt(
            controller
        );
        Test.stopTest();

        System.assertEquals(false, extension.hasLogo);
        System.assertEquals(null, extension.logoUrl);
        System.assertEquals(true, extension.isPdf);
        System.assertEquals('PDF', extension.renderAs);
        System.assertEquals(0, extension.invoiceLineItems.size());
        System.assertEquals(0, extension.cashLines.size());
        System.assertEquals(0, extension.glLines.size());
        System.assertEquals(false, extension.hasPayments);
        System.assertEquals(false, extension.hasGlLines);
        System.assertEquals(true, String.isBlank(extension.userLoc.Name));
        System.assertEquals('Parts Invoice - Accounting Copy', extension.formTitle);
    }

    @IsTest
    static void renderFormatHonorsPdfParameter() {
        ApexPages.StandardController controller = new ApexPages.StandardController(
            new dealer__Parts_Invoice__c()
        );

        ApexPages.currentPage().getParameters().put('pdf', 'false');
        FormPartsInvoiceAccountingCopyExt htmlExtension = new FormPartsInvoiceAccountingCopyExt(
            controller
        );
        System.assertEquals(false, htmlExtension.isPdf);
        System.assertEquals(null, htmlExtension.renderAs);

        ApexPages.currentPage().getParameters().put('pdf', 'true');
        FormPartsInvoiceAccountingCopyExt pdfExtension = new FormPartsInvoiceAccountingCopyExt(
            controller
        );
        System.assertEquals(true, pdfExtension.isPdf);
        System.assertEquals('PDF', pdfExtension.renderAs);
    }

    @IsTest
    static void resolvePartsInvoiceIdUsesControllerRecordId() {
        Id fakeId = fakePartsInvoiceId();

        Id resolvedId = FormPartsInvoiceAccountingCopyExt.resolvePartsInvoiceId(
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

        Id resolvedId = FormPartsInvoiceAccountingCopyExt.resolvePartsInvoiceId(
            new ApexPages.StandardController(new dealer__Parts_Invoice__c())
        );

        System.assertEquals(fakeId, resolvedId);
    }

    @IsTest
    static void resolvePartsInvoiceIdReturnsNullWhenUnavailable() {
        ApexPages.currentPage().getParameters().clear();

        Id resolvedId = FormPartsInvoiceAccountingCopyExt.resolvePartsInvoiceId(
            new ApexPages.StandardController(new dealer__Parts_Invoice__c())
        );

        System.assertEquals(null, resolvedId);
    }

    @IsTest
    static void constructorResolvesIdAndQueriesWithoutMatch() {
        Id fakeId = fakePartsInvoiceId();

        Test.startTest();
        FormPartsInvoiceAccountingCopyExt extension = new FormPartsInvoiceAccountingCopyExt(
            new ApexPages.StandardController(
                new dealer__Parts_Invoice__c(Id = fakeId)
            )
        );
        Test.stopTest();

        System.assertEquals(null, extension.invoice.Id);
        System.assertEquals(0, extension.invoiceLineItems.size());
        System.assertEquals(0, extension.cashLines.size());
        System.assertEquals(0, extension.glLines.size());
    }

    @IsTest
    static void loadPartsInvoiceHandlesMissingRecord() {
        FormPartsInvoiceAccountingCopyExt extension = new FormPartsInvoiceAccountingCopyExt(
            new ApexPages.StandardController(new dealer__Parts_Invoice__c())
        );
        extension.loadPartsInvoice(fakePartsInvoiceId());

        System.assertEquals(null, extension.invoice.Id);
        System.assertEquals(0, extension.invoiceLineItems.size());
    }

    @IsTest
    static void resolveGlReferenceBuildsPiReferenceFromInvoiceFields() {
        System.assertEquals(
            'PI1005',
            FormPartsInvoiceAccountingCopyExt.resolveGlReference(
                new dealer__Parts_Invoice__c(
                    Name = 'INV#RD1-1005',
                    dealer__Invoice_Number__c = 'PI1005'
                )
            )
        );
        System.assertEquals(
            'PI1005',
            FormPartsInvoiceAccountingCopyExt.resolveGlReference(
                new dealer__Parts_Invoice__c(Name = 'INV#RD1-1005')
            )
        );
        System.assertEquals(
            'PI1051',
            FormPartsInvoiceAccountingCopyExt.formatPartsInvoiceGlReference('1051')
        );
        System.assertEquals(
            'PI1051',
            FormPartsInvoiceAccountingCopyExt.formatPartsInvoiceGlReference('pi1051')
        );
        System.assertEquals(
            null,
            FormPartsInvoiceAccountingCopyExt.resolveGlReference(null)
        );
    }

    @IsTest
    static void extractInvoiceNumberParsesDisplayNameSuffix() {
        System.assertEquals(
            '1051',
            FormPartsInvoiceAccountingCopyExt.extractInvoiceNumber('INV#RD1-1051')
        );
        System.assertEquals(
            '1005',
            FormPartsInvoiceAccountingCopyExt.extractInvoiceNumber('INV#RD1-1005')
        );
        System.assertEquals(null, FormPartsInvoiceAccountingCopyExt.extractInvoiceNumber(null));
    }

    @IsTest
    static void buildAccountingLineWrappersMapsCostAndPriceFields() {
        dealer__Parts_Invoice_Line__c line = (dealer__Parts_Invoice_Line__c) JSON.deserialize(
            '{' +
            '"dealer__Quantity_Sold__c":2,' +
            '"dealer__Part_Number__c":"BRK-1",' +
            '"dealer__Part_Description__c":"Brake pad",' +
            '"dealer__Bin__c":"BIN-A",' +
            '"dealer__Cost__c":10.00,' +
            '"dealer__Extended_Cost__c":20.00,' +
            '"dealer__Price__c":25.00,' +
            '"dealer__Extended_Price__c":50.00,' +
            '"dealer__TotalCore__c":5.00,' +
            '"dealer__Total_Price__c":55.00,' +
            '"dealer__Comment__c":"Defective part",' +
            '"dealer__QuantityReturned__c":1,' +
            '"dealer__Part__r":{"dealer__BinLocation__r":{"Name":"A-12"}},' +
            '"dealer__Parts_Ledgers__r":{"totalSize":1,"done":true,"records":[' +
            '{"dealer__SerialNumber__c":"SN-123"}' +
            ']}}',
            dealer__Parts_Invoice_Line__c.class
        );

        List<FormPartsInvoiceAccountingCopyExt.AccountingLineWrapper> wrappers =
            FormPartsInvoiceAccountingCopyExt.buildAccountingLineWrappers(
                new List<dealer__Parts_Invoice_Line__c>{ line }
            );

        System.assertEquals(1, wrappers.size());
        FormPartsInvoiceAccountingCopyExt.AccountingLineWrapper wrapper = wrappers[0];
        System.assertEquals(2, wrapper.quantity);
        System.assertEquals('BRK-1', wrapper.partNumber);
        System.assertEquals('Brake pad', wrapper.displayDescription);
        System.assertEquals('A-12', wrapper.binDisplay);
        System.assertEquals(10.00, wrapper.unitCost);
        System.assertEquals(20.00, wrapper.extendedCost);
        System.assertEquals(25.00, wrapper.unitPrice);
        System.assertEquals(50.00, wrapper.extendedPrice);
        System.assertEquals(5.00, wrapper.totalCore);
        System.assertEquals(55.00, wrapper.totalPrice);
        System.assertEquals(1, wrapper.serialNumbers.size());
        System.assertEquals('SN-123', wrapper.serialNumbers[0]);
    }

    @IsTest
    static void buildAccountingLineWrappersHandlesNullAndEmpty() {
        System.assertEquals(
            0,
            FormPartsInvoiceAccountingCopyExt.buildAccountingLineWrappers(null).size()
        );
        System.assertEquals(
            0,
            FormPartsInvoiceAccountingCopyExt.buildAccountingLineWrappers(
                new List<dealer__Parts_Invoice_Line__c>()
            ).size()
        );
    }

    @IsTest
    static void buildCashLinesMapsPaymentRows() {
        dealer__Cashering__c cash = (dealer__Cashering__c) JSON.deserialize(
            '{"dealer__Payment_Method__c":"Visa","dealer__Deposit__c":true,"dealer__Close_Date__c":"2026-06-01","dealer__Amount__c":125.00,"dealer__ProcessingFee__c":3.50}',
            dealer__Cashering__c.class
        );

        List<FormPartsInvoiceAccountingCopyExt.CashLineWrapper> lines =
            FormPartsInvoiceAccountingCopyExt.buildCashLines(
                new List<dealer__Cashering__c>{ cash }
            );

        System.assertEquals(1, lines.size());
        System.assertEquals('Visa', lines[0].paymentMethod);
        System.assertEquals(true, lines[0].isDeposit);
        System.assertEquals(Date.newInstance(2026, 6, 1), lines[0].closeDate);
        System.assertEquals(125.00, lines[0].amount);
        System.assertEquals(3.50, lines[0].processingFee);
        System.assertEquals(128.50, lines[0].lineTotal);
        System.assertEquals(0, FormPartsInvoiceAccountingCopyExt.buildCashLines(null).size());
    }

    @IsTest
    static void computeFinancialTotalsRollsUpLineAmountsWhenHeaderFieldsNull() {
        FormPartsInvoiceAccountingCopyExt extension = new FormPartsInvoiceAccountingCopyExt(
            new ApexPages.StandardController(new dealer__Parts_Invoice__c())
        );

        List<FormPartsInvoiceAccountingCopyExt.AccountingLineWrapper> lines =
            FormPartsInvoiceAccountingCopyExt.buildAccountingLineWrappers(
                new List<dealer__Parts_Invoice_Line__c>{
                    (dealer__Parts_Invoice_Line__c) JSON.deserialize(
                        '{"dealer__Extended_Cost__c":50.00,"dealer__Total_Price__c":60.00,"dealer__TotalCore__c":8.00}',
                        dealer__Parts_Invoice_Line__c.class
                    )
                }
            );

        extension.assignTestState(new dealer__Parts_Invoice__c(), lines, null, null);

        System.assertEquals(50.00, extension.totalPartsCost);
        System.assertEquals(52.00, extension.totalPartsSale);
        System.assertEquals(0, extension.totalMiscCost);
        System.assertEquals(0, extension.totalMiscSale);
        System.assertEquals(50.00, extension.totalCost);
        System.assertEquals(60.00, extension.totalSale);
        System.assertEquals(10.00, extension.totalGross);
        System.assertEquals(8.00, extension.totalCoreCharges);
    }

    @IsTest
    static void computePaymentTotalsSumsLineTotals() {
        FormPartsInvoiceAccountingCopyExt extension = new FormPartsInvoiceAccountingCopyExt(
            new ApexPages.StandardController(new dealer__Parts_Invoice__c())
        );
        extension.assignTestState(
            null,
            null,
            FormPartsInvoiceAccountingCopyExt.buildCashLines(
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
        FormPartsInvoiceAccountingCopyExt extension = new FormPartsInvoiceAccountingCopyExt(
            new ApexPages.StandardController(new dealer__Parts_Invoice__c())
        );
        extension.assignTestState(
            new dealer__Parts_Invoice__c(
                dealer__Customer_ShipTo_Street__c = '9 Hamilton Avenue',
                dealer__Customer_ShipTo_City__c = 'Palo Alto',
                dealer__Customer_Shipto_State__c = 'CA',
                dealer__Customer_ShipTo_Zip__c = '94301'
            ),
            null,
            null,
            null
        );

        System.assertEquals(true, extension.hasStructuredShipTo);
        System.assertEquals(true, extension.hasShipToAddress);
        System.assertEquals(true, extension.showShipTo);
        System.assertEquals('9 Hamilton Avenue', extension.shipToStreet);
    }

    @IsTest
    static void percentCalculationsHandleZeroSale() {
        FormPartsInvoiceAccountingCopyExt extension = new FormPartsInvoiceAccountingCopyExt(
            new ApexPages.StandardController(new dealer__Parts_Invoice__c())
        );
        extension.assignTestState(
            new dealer__Parts_Invoice__c(),
            new List<FormPartsInvoiceAccountingCopyExt.AccountingLineWrapper>(),
            null,
            null
        );

        System.assertEquals(0, extension.grossPercent);
        System.assertEquals(0, extension.partsGrossPercent);
        System.assertEquals(0, extension.miscGrossPercent);
    }

    @IsTest
    static void recordTypeFlagsDriveFormTitleAndLayout() {
        FormPartsInvoiceAccountingCopyExt extension = new FormPartsInvoiceAccountingCopyExt(
            new ApexPages.StandardController(new dealer__Parts_Invoice__c())
        );

        extension.assignTestState(
            new dealer__Parts_Invoice__c(
                RecordType = new RecordType(DeveloperName = 'Vendor_Return')
            ),
            null,
            null,
            null
        );
        System.assertEquals(true, extension.isVendorReturnInvoice);
        System.assertEquals('Vendor Return - Accounting Copy', extension.formTitle);
        System.assertEquals(false, extension.showPartyShipToColumn);

        extension.assignTestState(
            new dealer__Parts_Invoice__c(
                RecordType = new RecordType(DeveloperName = 'Repair_Order')
            ),
            null,
            null,
            null
        );
        System.assertEquals(true, extension.isRepairOrderInvoice);
        System.assertEquals(false, extension.showInvoiceTotals);
        System.assertEquals(
            'Service Repair Order - Parts Invoice Accounting Copy',
            extension.formTitle
        );
    }

    @IsTest
    static void loadPartsInvoiceLoadsExistingRecordWhenAvailable() {
        List<dealer__Parts_Invoice__c> invoices = [
            SELECT Id
            FROM dealer__Parts_Invoice__c
            LIMIT 1
        ];
        if (invoices.isEmpty()) {
            return;
        }

        FormPartsInvoiceAccountingCopyExt extension = new FormPartsInvoiceAccountingCopyExt(
            new ApexPages.StandardController(new dealer__Parts_Invoice__c())
        );

        Test.startTest();
        extension.loadPartsInvoice(invoices[0].Id);
        Test.stopTest();

        System.assertEquals(invoices[0].Id, extension.invoice.Id);
    }

    @IsTest
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
        FormPartsInvoiceAccountingCopyExt extension = new FormPartsInvoiceAccountingCopyExt(
            new ApexPages.StandardController(
                new dealer__Parts_Invoice__c(Id = invoices[0].Id)
            )
        );
        Test.stopTest();

        System.assertEquals(invoices[0].Id, extension.invoice.Id);
    }

    @IsTest
    static void applyCustomerDetailsMapsFields() {
        FormPartsInvoiceAccountingCopyExt extension = new FormPartsInvoiceAccountingCopyExt(
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
    static void applyCustomerDetailsIgnoresNull() {
        FormPartsInvoiceAccountingCopyExt extension = new FormPartsInvoiceAccountingCopyExt(
            new ApexPages.StandardController(new dealer__Parts_Invoice__c())
        );
        extension.applyCustomerDetails(null);
        System.assertEquals(null, extension.customerName);
    }

    @IsTest
    static void commentDepositCoreAndDueFlags() {
        FormPartsInvoiceAccountingCopyExt extension = new FormPartsInvoiceAccountingCopyExt(
            new ApexPages.StandardController(new dealer__Parts_Invoice__c())
        );
        extension.assignTestState(
            new dealer__Parts_Invoice__c(
                dealer__Comments__c = 'Audit note',
                dealer__Deposit__c = 25.00,
                RecordType = new RecordType(DeveloperName = 'Counter_Return')
            ),
            FormPartsInvoiceAccountingCopyExt.buildAccountingLineWrappers(
                new List<dealer__Parts_Invoice_Line__c>{
                    (dealer__Parts_Invoice_Line__c) JSON.deserialize(
                        '{"dealer__TotalCore__c":12.00}',
                        dealer__Parts_Invoice_Line__c.class
                    )
                }
            ),
            null,
            -15.00
        );

        System.assertEquals(true, extension.hasComments);
        System.assertEquals(true, extension.hasDeposit);
        System.assertEquals(true, extension.hasCoreCharges);
        System.assertEquals(true, extension.isReturnInvoice);
        System.assertEquals('Total Credit', extension.totalDueLabel);
        System.assertEquals('Counter Return - Accounting Copy', extension.formTitle);
    }

    @IsTest
    static void auditLineWrapperResolvesReturnReferenceInvoiceName() {
        dealer__Parts_Invoice_Line__c line = (dealer__Parts_Invoice_Line__c) JSON.deserialize(
            '{"dealer__ReturnReference__c":"INV#RD1-9999",' +
            '"dealer__PartsReturnLine__r":{"dealer__Parts_Invoice__r":{"Name":"INV#RD1-1001"}}}',
            dealer__Parts_Invoice_Line__c.class
        );

        FormPartsInvoiceAccountingCopyExt.AccountingLineWrapper wrapper =
            new FormPartsInvoiceAccountingCopyExt.AccountingLineWrapper(line);

        System.assertEquals('INV#RD1-1001', wrapper.returnReferenceInvoiceName);
        System.assertEquals(true, wrapper.hasReturnReference);
    }

    @IsTest
    static void grossPercentCalculatesFromTotals() {
        FormPartsInvoiceAccountingCopyExt extension = new FormPartsInvoiceAccountingCopyExt(
            new ApexPages.StandardController(new dealer__Parts_Invoice__c())
        );
        extension.assignTestState(
            new dealer__Parts_Invoice__c(),
            FormPartsInvoiceAccountingCopyExt.buildAccountingLineWrappers(
                new List<dealer__Parts_Invoice_Line__c>{
                    (dealer__Parts_Invoice_Line__c) JSON.deserialize(
                        '{"dealer__Extended_Cost__c":40.00,"dealer__Total_Price__c":100.00,"dealer__TotalCore__c":0}',
                        dealer__Parts_Invoice_Line__c.class
                    )
                }
            ),
            null,
            null
        );

        System.assertEquals(60.00, extension.totalGross);
        System.assertEquals(60.0, extension.grossPercent);
        System.assertEquals(60.0, extension.partsGrossPercent);
    }

    @IsTest
    static void shipToFreeformUsedWhenStructuredAddressMissing() {
        FormPartsInvoiceAccountingCopyExt extension = new FormPartsInvoiceAccountingCopyExt(
            new ApexPages.StandardController(new dealer__Parts_Invoice__c())
        );
        extension.assignTestState(
            new dealer__Parts_Invoice__c(
                dealer__Ship_To__c = 'Dock 3\nWarehouse B'
            ),
            null,
            null,
            null
        );

        System.assertEquals(false, extension.hasStructuredShipTo);
        System.assertEquals(true, extension.hasShipToAddress);
        System.assertEquals('Dock 3\nWarehouse B', extension.shipToFreeform);
    }

    @IsTest
    static void loadPartsInvoiceUsesHeaderRollupsWhenAvailable() {
        List<dealer__Parts_Invoice__c> invoices = [
            SELECT Id,
                dealer__TotalPartsCost__c,
                dealer__Parts_Price__c,
                dealer__TotalOtherCost__c,
                dealer__TotalMiscCharges__c
            FROM dealer__Parts_Invoice__c
            WHERE dealer__TotalPartsCost__c != NULL
            LIMIT 1
        ];
        if (invoices.isEmpty()) {
            return;
        }

        FormPartsInvoiceAccountingCopyExt extension = new FormPartsInvoiceAccountingCopyExt(
            new ApexPages.StandardController(new dealer__Parts_Invoice__c())
        );

        Test.startTest();
        extension.loadPartsInvoice(invoices[0].Id);
        Test.stopTest();

        System.assertEquals(
            invoices[0].dealer__TotalPartsCost__c,
            extension.totalPartsCost
        );
        System.assertEquals(
            invoices[0].dealer__Parts_Price__c,
            extension.totalPartsSale
        );
    }

    @IsTest
    static void repairOrderNumberFallsBackToRoNumberField() {
        FormPartsInvoiceAccountingCopyExt extension = new FormPartsInvoiceAccountingCopyExt(
            new ApexPages.StandardController(new dealer__Parts_Invoice__c())
        );
        extension.assignTestState(
            new dealer__Parts_Invoice__c(
                dealer__Service_Repair_Order__r = new dealer__Service_Repair_Order__c(
                    Name = '1043'
                )
            ),
            null,
            null,
            null
        );

        System.assertEquals('1043', extension.repairOrderNumber);
    }

    @IsTest
    static void hasSalesTaxIdWhenFieldPresentOnLoadedInvoice() {
        List<dealer__Parts_Invoice__c> invoices = [
            SELECT Id, dealer__Sales_Tax_ID__c
            FROM dealer__Parts_Invoice__c
            WHERE dealer__Sales_Tax_ID__c != NULL
            LIMIT 1
        ];
        if (invoices.isEmpty()) {
            return;
        }

        FormPartsInvoiceAccountingCopyExt extension = new FormPartsInvoiceAccountingCopyExt(
            new ApexPages.StandardController(new dealer__Parts_Invoice__c())
        );
        extension.loadPartsInvoice(invoices[0].Id);

        System.assertEquals(true, extension.hasSalesTaxId);
    }

    private static Id fakePartsInvoiceId() {
        String keyPrefix = dealer__Parts_Invoice__c.SObjectType.getDescribe()
            .getKeyPrefix();
        return Id.valueOf(keyPrefix + '000000000001');
    }
}
