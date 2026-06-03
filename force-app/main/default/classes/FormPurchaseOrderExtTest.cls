@IsTest
private class FormPurchaseOrderExtTest {
    @IsTest
    static void extensionInitializesWithoutPurchaseOrderId() {
        ApexPages.StandardController controller = new ApexPages.StandardController(
            new dealer__Purchase_Order__c()
        );

        Test.startTest();
        FormPurchaseOrderExt extension = new FormPurchaseOrderExt(controller);
        Test.stopTest();

        System.assertEquals(false, extension.hasLogo);
        System.assertEquals(null, extension.logoUrl);
        System.assertEquals(true, extension.isPdf);
        System.assertEquals('PDF', extension.renderAs);
        System.assertEquals(false, extension.hasReceivingLines);
        System.assertEquals(0, extension.purchaseLineList.size());
        System.assertEquals(0, extension.miscLines.size());
        System.assertEquals(0, extension.partTotal);
        System.assertEquals(true, String.isBlank(extension.dlr.Name));
    }

    @IsTest
    static void renderFormatDefaultsToPdfWithoutParameter() {
        ApexPages.currentPage().getParameters().clear();

        FormPurchaseOrderExt extension = new FormPurchaseOrderExt(
            new ApexPages.StandardController(new dealer__Purchase_Order__c())
        );

        System.assertEquals(true, extension.isPdf);
        System.assertEquals('PDF', extension.renderAs);
    }

    @IsTest
    static void renderFormatHonorsPdfParameter() {
        ApexPages.StandardController controller = new ApexPages.StandardController(
            new dealer__Purchase_Order__c()
        );

        ApexPages.currentPage().getParameters().put('pdf', 'false');
        FormPurchaseOrderExt htmlExtension = new FormPurchaseOrderExt(controller);
        System.assertEquals(false, htmlExtension.isPdf);
        System.assertEquals(null, htmlExtension.renderAs);

        ApexPages.currentPage().getParameters().put('pdf', 'true');
        FormPurchaseOrderExt pdfExtension = new FormPurchaseOrderExt(controller);
        System.assertEquals(true, pdfExtension.isPdf);
        System.assertEquals('PDF', pdfExtension.renderAs);
    }

    @IsTest
    static void resolvePurchaseOrderIdUsesControllerRecordId() {
        dealer__Purchase_Order__c purchaseOrder = createPurchaseOrder();

        Id resolvedId = FormPurchaseOrderExt.resolvePurchaseOrderId(
            new ApexPages.StandardController(purchaseOrder)
        );

        System.assertEquals(purchaseOrder.Id, resolvedId);
    }

    @IsTest
    static void resolvePurchaseOrderIdUsesPageParameter() {
        dealer__Purchase_Order__c purchaseOrder = createPurchaseOrder();
        ApexPages.currentPage().getParameters().put('id', purchaseOrder.Id);

        Id resolvedId = FormPurchaseOrderExt.resolvePurchaseOrderId(
            new ApexPages.StandardController(new dealer__Purchase_Order__c())
        );

        System.assertEquals(purchaseOrder.Id, resolvedId);
    }

    @IsTest
    static void resolvePurchaseOrderIdReturnsNullWhenUnavailable() {
        ApexPages.currentPage().getParameters().clear();

        Id resolvedId = FormPurchaseOrderExt.resolvePurchaseOrderId(
            new ApexPages.StandardController(new dealer__Purchase_Order__c())
        );

        System.assertEquals(null, resolvedId);
    }

    @IsTest
    static void extensionLoadsPurchaseOrderFromRecordId() {
        dealer__Purchase_Order__c purchaseOrder = createPurchaseOrder();
        insertPurchaseOrderLine(
            purchaseOrder.Id,
            'Part',
            'Brake pads',
            25,
            12.5
        );
        insertPurchaseOrderLine(
            purchaseOrder.Id,
            'Miscellaneous',
            'Freight',
            5,
            null
        );

        FormPurchaseOrderExt extension = new FormPurchaseOrderExt(
            new ApexPages.StandardController(purchaseOrder)
        );

        System.assertEquals(purchaseOrder.Id, extension.po.Id);
        System.assertNotEquals(null, extension.poDateOnly);
        System.assertEquals(1, extension.purchaseLineList.size());
        System.assertEquals(1, extension.miscLines.size());
        System.assertEquals(25, extension.partTotal);
        System.assertEquals('Brake pads', extension.purchaseLineList[0].firstLine);
        System.assertEquals(false, extension.hasReceivingLines);
    }

    @IsTest
    static void extensionLoadsPurchaseOrderFromPageIdParameter() {
        dealer__Purchase_Order__c purchaseOrder = createPurchaseOrder();
        insertPurchaseOrderLine(
            purchaseOrder.Id,
            'Part',
            'Air filter',
            10,
            4
        );
        ApexPages.currentPage().getParameters().put('id', purchaseOrder.Id);

        FormPurchaseOrderExt extension = new FormPurchaseOrderExt(
            new ApexPages.StandardController(new dealer__Purchase_Order__c())
        );

        System.assertEquals(purchaseOrder.Id, extension.po.Id);
        System.assertEquals(1, extension.purchaseLineList.size());
        System.assertEquals(10, extension.partTotal);
    }

    @IsTest
    static void loadPurchaseOrderHandlesMissingRecord() {
        dealer__Purchase_Order__c purchaseOrder = createPurchaseOrder();
        Id deletedPurchaseOrderId = purchaseOrder.Id;
        delete purchaseOrder;

        FormPurchaseOrderExt extension = new FormPurchaseOrderExt(
            new ApexPages.StandardController(new dealer__Purchase_Order__c())
        );
        extension.loadPurchaseOrder(deletedPurchaseOrderId);

        System.assertEquals(null, extension.po.Id);
        System.assertEquals(0, extension.purchaseLineList.size());
    }

    @IsTest
    static void dealerLocationGetterReturnsLocationWhenCompanyIsSet() {
        dealer__Dealer_Location__c location = createDealerLocation(
            'Main Store',
            '1 Main St'
        );

        dealer__Purchase_Order__c purchaseOrder = createPurchaseOrder(location.Id);

        FormPurchaseOrderExt extension = new FormPurchaseOrderExt(
            new ApexPages.StandardController(purchaseOrder)
        );

        System.assertEquals('Main Store', extension.dlr.Name);
        System.assertEquals('1 Main St', extension.dlr.dealer__Street__c);
    }

    @IsTest
    static void resolveDealerDomainUsesWebsiteHost() {
        dealer__Dealer_Location__c location = new dealer__Dealer_Location__c(
            dealer__Website__c = 'https://www.unitedaccess.com/about'
        );

        System.assertEquals(
            'unitedaccess.com',
            FormPurchaseOrderExt.resolveDealerDomain(location)
        );
        System.assertEquals(
            'ap@unitedaccess.com',
            FormPurchaseOrderExt.resolveApInboxEmail(location)
        );
    }

    @IsTest
    static void resolveDealerDomainFallsBackToEmailWhenWebsiteMissing() {
        dealer__Dealer_Location__c location = new dealer__Dealer_Location__c(
            dealer__Email__c = 'billing@example.org'
        );

        System.assertEquals(
            'example.org',
            FormPurchaseOrderExt.resolveDealerDomain(location)
        );
    }

    @IsTest
    static void extensionSetsApInboxEmailFromDealerWebsite() {
        dealer__Dealer_Location__c location = createDealerLocation(
            'Main Store',
            '1 Main St'
        );
        location.dealer__Website__c = 'https://unitedaccess.com';
        update location;

        dealer__Purchase_Order__c purchaseOrder = createPurchaseOrder(location.Id);

        FormPurchaseOrderExt extension = new FormPurchaseOrderExt(
            new ApexPages.StandardController(purchaseOrder)
        );

        System.assertEquals('ap@unitedaccess.com', extension.apInboxEmail);
    }

    @IsTest
    static void dealerLocationGetterReturnsEmptyWhenCompanyIsInvalid() {
        dealer__Dealer_Location__c location = createDealerLocation(
            'Temp Location',
            '99 Side St'
        );

        dealer__Purchase_Order__c purchaseOrder = createPurchaseOrder(location.Id);
        delete location;

        FormPurchaseOrderExt extension = new FormPurchaseOrderExt(
            new ApexPages.StandardController(purchaseOrder)
        );

        System.assertEquals(true, String.isBlank(extension.dlr.Name));
    }

    @IsTest
    static void loadReceivingLinesSetsFlagWhenReceivingDataExists() {
        dealer__Purchase_Order__c purchaseOrder = createPurchaseOrder();
        dealer__Purchase_Order_Line__c poLine = insertPurchaseOrderLine(
            purchaseOrder.Id,
            'Part',
            'Wiper blade',
            8,
            2
        );

        dealer__Purchase_Order_Receiving__c receivingHeader =
            new dealer__Purchase_Order_Receiving__c(
                dealer__Purchase_Order__c = purchaseOrder.Id
            );
        insert receivingHeader;

        dealer__Purchase_Order_Receiving_Line__c receivingLine =
            new dealer__Purchase_Order_Receiving_Line__c(
                dealer__PurchaseOrderReceivingHeader__c = receivingHeader.Id,
                dealer__PurchaseOrderLine__c = poLine.Id,
                dealer__QuantityReceived__c = 1,
                dealer__Amount__c = 8
            );
        insert receivingLine;

        FormPurchaseOrderExt extension = new FormPurchaseOrderExt(
            new ApexPages.StandardController(new dealer__Purchase_Order__c())
        );
        extension.loadReceivingLines(purchaseOrder.Id);
        purchaseOrder = queryPurchaseOrderDisplayFields(purchaseOrder.Id);
        receivingHeader = queryReceivingHeaderName(receivingHeader.Id);

        System.assertEquals(true, extension.hasReceivingLines);
        System.assertEquals(1, extension.receivedEventLine.size());
        System.assertEquals(1, extension.receivingEventGroups.size());
        System.assertEquals(
            FormPurchaseOrderExt.formatReceivingEventTitle(
                FormPurchaseOrderExt.resolvePurchaseOrderDisplayName(purchaseOrder),
                receivingHeader.Name
            ),
            extension.receivingEventGroups[0].eventTitle
        );
        System.assertEquals(1, extension.receivingEventGroups[0].lines.size());
        System.assertEquals(
            'Wiper blade',
            extension.receivingEventGroups[0].lines[0].partDescription
        );
    }

    @IsTest
    static void formatReceivingEventTitleCombinesPoNameAndReceivingEvent() {
        System.assertEquals(
            'RD1-000057-26.06.02.50',
            FormPurchaseOrderExt.formatReceivingEventTitle(
                'RD1-000057',
                '26.06.02.50'
            )
        );
    }

    @IsTest
    static void loadReceivingLinesGroupsLinesByReceivingEvent() {
        dealer__Purchase_Order__c purchaseOrder = createPurchaseOrder();
        dealer__Purchase_Order_Line__c firstLine = insertPurchaseOrderLine(
            purchaseOrder.Id,
            'Part',
            'First part description',
            10,
            1
        );
        dealer__Purchase_Order_Line__c secondLine = insertPurchaseOrderLine(
            purchaseOrder.Id,
            'Part',
            'Second part description',
            5,
            1
        );

        dealer__Purchase_Order_Receiving__c receivingHeader =
            new dealer__Purchase_Order_Receiving__c(
                dealer__Purchase_Order__c = purchaseOrder.Id
            );
        insert receivingHeader;

        insert new dealer__Purchase_Order_Receiving_Line__c(
            dealer__PurchaseOrderReceivingHeader__c = receivingHeader.Id,
            dealer__PurchaseOrderLine__c = firstLine.Id,
            dealer__QuantityReceived__c = 1,
            dealer__Amount__c = 10
        );
        insert new dealer__Purchase_Order_Receiving_Line__c(
            dealer__PurchaseOrderReceivingHeader__c = receivingHeader.Id,
            dealer__PurchaseOrderLine__c = secondLine.Id,
            dealer__QuantityReceived__c = 2,
            dealer__Amount__c = 5
        );

        FormPurchaseOrderExt extension = new FormPurchaseOrderExt(
            new ApexPages.StandardController(new dealer__Purchase_Order__c())
        );
        extension.loadReceivingLines(purchaseOrder.Id);
        purchaseOrder = queryPurchaseOrderDisplayFields(purchaseOrder.Id);
        receivingHeader = queryReceivingHeaderName(receivingHeader.Id);

        System.assertEquals(1, extension.receivingEventGroups.size());
        System.assertEquals(2, extension.receivingEventGroups[0].lines.size());
        System.assertEquals(
            FormPurchaseOrderExt.formatReceivingEventTitle(
                FormPurchaseOrderExt.resolvePurchaseOrderDisplayName(purchaseOrder),
                receivingHeader.Name
            ),
            extension.receivingEventGroups[0].eventTitle
        );
        System.assertEquals(
            'First part description',
            extension.receivingEventGroups[0].lines[0].partDescription
        );
        System.assertEquals(
            'Second part description',
            extension.receivingEventGroups[0].lines[1].partDescription
        );
    }

    @IsTest
    static void isMiscOrSubletPurchaseOrderTrueForSubletAndMiscRecordTypes() {
        dealer__Purchase_Order__c subletOrder = new dealer__Purchase_Order__c(
            RecordType = new RecordType(DeveloperName = 'Sublet')
        );
        dealer__Purchase_Order__c miscOrder = new dealer__Purchase_Order__c(
            RecordType = new RecordType(DeveloperName = 'Misc')
        );

        System.assertEquals(
            true,
            FormPurchaseOrderExt.isMiscOrSubletPurchaseOrder(subletOrder)
        );
        System.assertEquals(
            true,
            FormPurchaseOrderExt.isMiscOrSubletPurchaseOrder(miscOrder)
        );
    }

    @IsTest
    static void isMiscOrSubletPurchaseOrderFalseForPartsPurchaseRecordType() {
        dealer__Purchase_Order__c purchaseOrder = new dealer__Purchase_Order__c(
            RecordType = new RecordType(DeveloperName = 'Parts_Purchase')
        );

        System.assertEquals(
            false,
            FormPurchaseOrderExt.isMiscOrSubletPurchaseOrder(purchaseOrder)
        );
    }

    @IsTest
    static void subletPurchaseOrderUsesLineQuantityAndDescriptionColumns() {
        dealer__Purchase_Order__c purchaseOrder = createPurchaseOrder(
            null,
            getPurchaseOrderRecordTypeId('Sublet')
        );
        dealer__Purchase_Order_Line__c poLine = insertPurchaseOrderLine(
            purchaseOrder.Id,
            'Part',
            'Sublet labor description',
            100,
            100
        );
        poLine.dealer__Quantity__c = 3;
        update poLine;

        FormPurchaseOrderExt extension = new FormPurchaseOrderExt(
            new ApexPages.StandardController(purchaseOrder)
        );

        System.assertEquals(false, extension.showPartLineColumns);
        System.assertEquals(false, extension.showPartsTotal);
        System.assertEquals(0, extension.partTotal);
        System.assertEquals(1, extension.purchaseLineList.size());
        System.assertEquals(3, extension.purchaseLineList[0].lineQuantity);
        System.assertEquals(
            'Sublet labor description',
            extension.purchaseLineList[0].lineDescription
        );
    }

    @IsTest
    static void miscPurchaseOrderUsesLineFieldsAndHidesPartsTotal() {
        dealer__Purchase_Order__c purchaseOrder = createPurchaseOrder(
            null,
            getPurchaseOrderRecordTypeId('Misc')
        );
        dealer__Purchase_Order_Line__c poLine = insertPurchaseOrderLine(
            purchaseOrder.Id,
            'Miscellaneous',
            'Freight charge',
            50,
            50
        );
        poLine.dealer__Quantity__c = 1;
        update poLine;

        FormPurchaseOrderExt extension = new FormPurchaseOrderExt(
            new ApexPages.StandardController(purchaseOrder)
        );

        System.assertEquals(false, extension.showPartLineColumns);
        System.assertEquals(false, extension.showPartsTotal);
        System.assertEquals(1, extension.purchaseLineList.size());
        System.assertEquals(0, extension.miscLines.size());
        System.assertEquals(
            'Freight charge',
            extension.purchaseLineList[0].lineDescription
        );
    }

    @IsTest
    static void resolvePoLinePartDescriptionUsesLineDescriptionWhenPartMissing() {
        dealer__Purchase_Order_Line__c poLine = new dealer__Purchase_Order_Line__c(
            dealer__Description__c = 'Line only description'
        );

        System.assertEquals(
            'Line only description',
            FormPurchaseOrderExt.resolvePoLinePartDescription(poLine)
        );
    }

    @IsTest
    static void resolveReceivingLineDescriptionUsesPoLineDescription() {
        dealer__Purchase_Order_Line__c poLine = new dealer__Purchase_Order_Line__c(
            dealer__Description__c = 'Receiving line description'
        );

        System.assertEquals(
            'Receiving line description',
            FormPurchaseOrderExt.resolveReceivingLineDescription(poLine)
        );
    }

    @IsTest
    static void subletReceivingDisplayUsesLineDescription() {
        dealer__Purchase_Order__c purchaseOrder = createPurchaseOrder(
            null,
            getPurchaseOrderRecordTypeId('Sublet')
        );
        dealer__Purchase_Order_Line__c poLine = insertPurchaseOrderLine(
            purchaseOrder.Id,
            'Part',
            'Sublet received work',
            75,
            75
        );

        dealer__Purchase_Order_Receiving__c receivingHeader =
            new dealer__Purchase_Order_Receiving__c(
                dealer__Purchase_Order__c = purchaseOrder.Id
            );
        insert receivingHeader;

        insert new dealer__Purchase_Order_Receiving_Line__c(
            dealer__PurchaseOrderReceivingHeader__c = receivingHeader.Id,
            dealer__PurchaseOrderLine__c = poLine.Id,
            dealer__QuantityReceived__c = 1,
            dealer__Amount__c = 75
        );

        FormPurchaseOrderExt extension = new FormPurchaseOrderExt(
            new ApexPages.StandardController(purchaseOrder)
        );

        System.assertEquals(false, extension.showPartLineColumns);
        System.assertEquals(1, extension.receivingEventGroups.size());
        System.assertEquals(
            'Sublet received work',
            extension.receivingEventGroups[0].lines[0].lineDescription
        );
        System.assertEquals(
            null,
            extension.receivingEventGroups[0].lines[0].partNumber
        );
    }

    @IsTest
    static void initializePurchaseOrderLinesSplitsPartAndMiscLines() {
        FormPurchaseOrderExt extension = new FormPurchaseOrderExt(
            new ApexPages.StandardController(new dealer__Purchase_Order__c())
        );

        dealer__Purchase_Order_Line__c partLine = new dealer__Purchase_Order_Line__c(
            dealer__LineType__c = 'Part',
            dealer__Part_Quantity__c = 2,
            dealer__Cost__c = 10,
            dealer__Amount__c = 20,
            dealer__Description__c = 'Oil filter assembly',
            dealer__Special_Instructions__c = 'Rush order'
        );
        dealer__Purchase_Order_Line__c miscLine = new dealer__Purchase_Order_Line__c(
            dealer__LineType__c = 'Miscellaneous',
            dealer__Description__c = 'Freight',
            dealer__Amount__c = 5
        );

        extension.initializePurchaseOrderLines(
            new List<dealer__Purchase_Order_Line__c>{ partLine, miscLine }
        );

        System.assertEquals(1, extension.purchaseLineList.size());
        System.assertEquals(1, extension.miscLines.size());
        System.assertEquals(20, extension.partTotal);
        System.assertEquals(
            'Oil filter assembly',
            extension.purchaseLineList[0].firstLine
        );
        System.assertEquals(
            'Rush order',
            extension.purchaseLineList[0].specialInstructions
        );
    }

    @IsTest
    static void initializePurchaseOrderLinesIgnoresNullAndEmptyInput() {
        FormPurchaseOrderExt extension = new FormPurchaseOrderExt(
            new ApexPages.StandardController(new dealer__Purchase_Order__c())
        );

        extension.initializePurchaseOrderLines(null);
        extension.initializePurchaseOrderLines(
            new List<dealer__Purchase_Order_Line__c>()
        );

        System.assertEquals(0, extension.purchaseLineList.size());
        System.assertEquals(0, extension.miscLines.size());
    }

    @IsTest
    static void applyDescriptionLinesSplitsLongDescriptions() {
        FormPurchaseOrderExt.PurchaseOrderLineWrapper lineWrapper =
            new FormPurchaseOrderExt.PurchaseOrderLineWrapper();
        String longDescription = 'A'.repeat(85);

        FormPurchaseOrderExt.applyDescriptionLines(lineWrapper, longDescription);

        System.assertEquals(40, lineWrapper.firstLine.length());
        System.assertEquals(40, lineWrapper.secondLine.length());
    }

    @IsTest
    static void applyDescriptionLinesHandlesShortAndBlankDescriptions() {
        FormPurchaseOrderExt.PurchaseOrderLineWrapper shortWrapper =
            new FormPurchaseOrderExt.PurchaseOrderLineWrapper();
        FormPurchaseOrderExt.applyDescriptionLines(shortWrapper, 'Short part');
        System.assertEquals('Short part', shortWrapper.firstLine);
        System.assertEquals('', shortWrapper.secondLine);

        FormPurchaseOrderExt.PurchaseOrderLineWrapper blankWrapper =
            new FormPurchaseOrderExt.PurchaseOrderLineWrapper();
        FormPurchaseOrderExt.applyDescriptionLines(blankWrapper, null);
        System.assertEquals(null, blankWrapper.firstLine);
        System.assertEquals(null, blankWrapper.secondLine);
    }

    @IsTest
    static void getSerialNumberByPartReturnsEmptyMapWithoutPartIds() {
        dealer__Purchase_Order_Line__c lineWithoutPart =
            new dealer__Purchase_Order_Line__c(dealer__LineType__c = 'Part');

        Map<Id, String> serialNumbers = FormPurchaseOrderExt.getSerialNumberByPart(
            new List<dealer__Purchase_Order_Line__c>{ lineWithoutPart }
        );

        System.assertEquals(true, serialNumbers.isEmpty());
    }

    @IsTest
    static void getSerialNumberByPartQueriesWhenPartIdsArePresent() {
        dealer__Purchase_Order_Line__c lineWithPart = new dealer__Purchase_Order_Line__c(
            dealer__LineType__c = 'Part',
            dealer__Part__c = UserInfo.getUserId()
        );

        Map<Id, String> serialNumbers = FormPurchaseOrderExt.getSerialNumberByPart(
            new List<dealer__Purchase_Order_Line__c>{ lineWithPart }
        );

        System.assertNotEquals(null, serialNumbers);
    }

    @IsTest
    static void printedByAndDateFieldsInitializeFromUtil() {
        FormPurchaseOrderExt extension = new FormPurchaseOrderExt(
            new ApexPages.StandardController(new dealer__Purchase_Order__c())
        );

        System.assertEquals(
            FixedOpsFormUtil.resolvePrintedByName(),
            extension.printedByName
        );
        System.assertEquals(
            FixedOpsFormUtil.formatTodayDateOnly(),
            extension.todayDateOnly
        );
        System.assertEquals(
            FixedOpsFormUtil.resolveCurrencySymbol(),
            extension.currencyCode
        );
    }

    @IsTest
    static void isPartsPurchasePurchaseOrderRecognizesRecordType() {
        dealer__Purchase_Order__c partsOrder = new dealer__Purchase_Order__c(
            RecordType = new RecordType(DeveloperName = 'Parts_Purchase')
        );
        dealer__Purchase_Order__c subletOrder = new dealer__Purchase_Order__c(
            RecordType = new RecordType(DeveloperName = 'Sublet')
        );

        System.assertEquals(
            true,
            FormPurchaseOrderExt.isPartsPurchasePurchaseOrder(partsOrder)
        );
        System.assertEquals(
            false,
            FormPurchaseOrderExt.isPartsPurchasePurchaseOrder(subletOrder)
        );
        System.assertEquals(
            false,
            FormPurchaseOrderExt.isPartsPurchasePurchaseOrder(null)
        );
    }

    @IsTest
    static void extensionFlagsPartPurchaseRecordType() {
        dealer__Purchase_Order__c partsOrder = createPurchaseOrder();
        FormPurchaseOrderExt partsExtension = new FormPurchaseOrderExt(
            new ApexPages.StandardController(partsOrder)
        );
        System.assertEquals(true, partsExtension.isPartPurchase);

        dealer__Purchase_Order__c subletOrder = createPurchaseOrder(
            null,
            getPurchaseOrderRecordTypeId('Sublet')
        );
        FormPurchaseOrderExt subletExtension = new FormPurchaseOrderExt(
            new ApexPages.StandardController(subletOrder)
        );
        System.assertEquals(false, subletExtension.isPartPurchase);
    }

    @IsTest
    static void formatDetailValueNormalizesByType() {
        System.assertEquals(null, FormPurchaseOrderExt.formatDetailValue(null));
        System.assertEquals('Yes', FormPurchaseOrderExt.formatDetailValue(true));
        System.assertEquals(null, FormPurchaseOrderExt.formatDetailValue(false));
        System.assertEquals(null, FormPurchaseOrderExt.formatDetailValue(''));
        System.assertEquals(
            'Override label',
            FormPurchaseOrderExt.formatDetailValue('Override label')
        );
        System.assertEquals('12', FormPurchaseOrderExt.formatDetailValue(12));
    }

    @IsTest
    static void applyDetailSubRowFieldsSetsPackQuantityDisplay() {
        FormPurchaseOrderExt.PurchaseOrderLineWrapper lineWrapper =
            new FormPurchaseOrderExt.PurchaseOrderLineWrapper();
        dealer__Purchase_Order_Line__c poLine = (dealer__Purchase_Order_Line__c) JSON.deserialize(
            '{"dealer__LineType__c":"Part","dealer__Pack_Quantity__c":6}',
            dealer__Purchase_Order_Line__c.class
        );

        FormPurchaseOrderExt.applyDetailSubRowFields(lineWrapper, poLine);

        System.assertEquals(6, lineWrapper.packQuantity);
        System.assertEquals(true, lineWrapper.showPackQuantity);
        System.assertEquals(false, lineWrapper.showPackPartOverride);
        System.assertEquals(false, lineWrapper.showReturnedToVendor);
        System.assertEquals(true, lineWrapper.hasDetailSubRow);
    }

    @IsTest
    static void applyDetailSubRowFieldsHidesPackQuantityOfOne() {
        FormPurchaseOrderExt.PurchaseOrderLineWrapper lineWrapper =
            new FormPurchaseOrderExt.PurchaseOrderLineWrapper();
        dealer__Purchase_Order_Line__c poLine = (dealer__Purchase_Order_Line__c) JSON.deserialize(
            '{"dealer__LineType__c":"Part","dealer__Pack_Quantity__c":1}',
            dealer__Purchase_Order_Line__c.class
        );

        FormPurchaseOrderExt.applyDetailSubRowFields(lineWrapper, poLine);

        System.assertEquals(false, lineWrapper.showPackQuantity);
        System.assertEquals(false, lineWrapper.hasDetailSubRow);
    }

    private static Account createVendorAccount() {
        Account vendor = new Account(
            RecordTypeId = getAccountRecordTypeId('Business_Account'),
            Name = 'Test PO Vendor',
            dealer__Vendor__c = true
        );
        insert vendor;
        return vendor;
    }

    private static dealer__Dealer_Location__c createDealerLocation(
        String locationName,
        String street
    ) {
        dealer__Dealer_Location__c location = new dealer__Dealer_Location__c(
            Name = locationName,
            dealer__Company_Number__c = String.valueOf(
                Math.mod(Math.abs(Crypto.getRandomInteger()), 90000) + 10000
            ),
            dealer__Street__c = street,
            dealer__City__c = 'Denver',
            dealer__State__c = 'CO',
            dealer__Postal_Code__c = '80202'
        );
        insert location;
        return location;
    }

    private static dealer__Purchase_Order__c createPurchaseOrder() {
        return createPurchaseOrder(null);
    }

    private static dealer__Purchase_Order__c createPurchaseOrder(Id dealerCompanyId) {
        return createPurchaseOrder(dealerCompanyId, null);
    }

    private static dealer__Purchase_Order__c createPurchaseOrder(
        Id dealerCompanyId,
        Id recordTypeId
    ) {
        Account vendor = createVendorAccount();
        dealer__Purchase_Order__c purchaseOrder = new dealer__Purchase_Order__c(
            dealer__Vendor__c = vendor.Id,
            dealer__Vendor_Name__c = vendor.Name,
            dealer__Company__c = dealerCompanyId,
            RecordTypeId = recordTypeId != null
                ? recordTypeId
                : getPurchaseOrderRecordTypeId('Parts_Purchase')
        );
        insert purchaseOrder;
        return purchaseOrder;
    }

    private static Id getPurchaseOrderRecordTypeId(String developerName) {
        return Schema.SObjectType.dealer__Purchase_Order__c
            .getRecordTypeInfosByDeveloperName()
            .get(developerName)
            .getRecordTypeId();
    }

    private static dealer__Purchase_Order__c queryPurchaseOrderDisplayFields(
        Id purchaseOrderId
    ) {
        return [
            SELECT Name, dealer__PO_Number__c
            FROM dealer__Purchase_Order__c
            WHERE Id = :purchaseOrderId
            LIMIT 1
        ];
    }

    private static dealer__Purchase_Order_Receiving__c queryReceivingHeaderName(
        Id receivingHeaderId
    ) {
        return [
            SELECT Name
            FROM dealer__Purchase_Order_Receiving__c
            WHERE Id = :receivingHeaderId
            LIMIT 1
        ];
    }

    private static Id getAccountRecordTypeId(String developerName) {
        return Schema.SObjectType.Account.getRecordTypeInfosByDeveloperName()
            .get(developerName)
            .getRecordTypeId();
    }

    private static dealer__Purchase_Order_Line__c insertPurchaseOrderLine(
        Id purchaseOrderId,
        String lineType,
        String description,
        Decimal amount,
        Decimal cost
    ) {
        dealer__Purchase_Order_Line__c purchaseOrderLine =
            new dealer__Purchase_Order_Line__c(
                dealer__Purchase_Order__c = purchaseOrderId,
                dealer__LineType__c = lineType,
                dealer__Description__c = description,
                dealer__Amount__c = amount,
                dealer__Cost__c = cost
            );
        insert purchaseOrderLine;
        return purchaseOrderLine;
    }
}
