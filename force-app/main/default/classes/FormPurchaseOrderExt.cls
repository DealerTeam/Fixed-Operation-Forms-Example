/**
 * Unmanaged extension for form_PurchaseOrderVendorCopy and form_PurchaseOrderAccountingCopy.
 */
public with sharing class FormPurchaseOrderExt {
    private static final Integer DESC_SIZE = 40;
    private static final Integer PART_NAME_WRAP_SIZE = 12;
    // The PDF renderer cannot break long unbroken strings (e.g. part numbers),
    // so break opportunities are inserted manually as zero-width spaces.
    private static final String ZERO_WIDTH_SPACE = String.fromCharArray(
        new List<Integer>{ 8203 }
    );

    public dealer__Purchase_Order__c po { get; private set; }
    public List<PurchaseOrderLineWrapper> purchaseLineList { get; private set; }
    public List<dealer__Purchase_Order_Line__c> miscLines { get; private set; }
    public List<dealer__Purchase_Order_Receiving_Line__c> receivedEventLine {
        get;
        private set;
    }
    public List<ReceivingEventDisplayWrapper> receivingEventGroups {
        get;
        private set;
    }
    public Decimal partTotal { get; private set; }
    public Decimal miscTotal { get; private set; }
    public String currencyCode { get; private set; }
    public String printedByName { get; private set; }
    public String createdByName { get; private set; }
    public String poDateOnly { get; private set; }
    public String todayDateOnly { get; private set; }
    public String logoUrl { get; private set; }
    public Boolean hasLogo { get; private set; }
    public Boolean hasReceivingLines { get; private set; }
    public Boolean showPartLineColumns { get; private set; }
    public Boolean showPartsTotal { get; private set; }
    public Boolean isPartPurchase { get; private set; }
    public String apInboxEmail { get; private set; }
    public String renderAs { get; private set; }
    public Boolean isPdf { get; private set; }

    public String vendorStreet { get; private set; }
    public String vendorCity { get; private set; }
    public String vendorState { get; private set; }
    public String vendorPostalCode { get; private set; }

    public dealer__Dealer_Location__c dlr {
        get {
            if (po == null || po.dealer__Company__c == null) {
                return new dealer__Dealer_Location__c();
            }

            List<dealer__Dealer_Location__c> locations = [
                SELECT Name,
                    dealer__Street__c,
                    dealer__City__c,
                    dealer__State__c,
                    dealer__Postal_Code__c,
                    dealer__Main_Phone__c,
                    dealer__Website__c,
                    dealer__Email__c
                FROM dealer__Dealer_Location__c
                WHERE Id = :po.dealer__Company__c
                WITH USER_MODE
                LIMIT 1
            ];

            if (locations.isEmpty()) {
                return new dealer__Dealer_Location__c();
            }

            return locations[0];
        }
        private set;
    }

    public FormPurchaseOrderExt(ApexPages.StandardController controller) {
        partTotal = 0;
        miscTotal = 0;
        purchaseLineList = new List<PurchaseOrderLineWrapper>();
        miscLines = new List<dealer__Purchase_Order_Line__c>();
        receivedEventLine = new List<dealer__Purchase_Order_Receiving_Line__c>();
        receivingEventGroups = new List<ReceivingEventDisplayWrapper>();
        hasReceivingLines = false;
        showPartLineColumns = true;
        showPartsTotal = true;
        isPartPurchase = false;
        po = new dealer__Purchase_Order__c();

        FixedOpsFormUtil.RenderFormat renderFormat = new FixedOpsFormUtil.RenderFormat(
            true
        );
        isPdf = renderFormat.isPdf;
        renderAs = renderFormat.renderAs;

        logoUrl = FixedOpsFormUtil.resolveLogoUrl(
            FixedOpsFormUtil.DEFAULT_LOGO_ASSET_DEVELOPER_NAME
        );
        hasLogo = String.isNotBlank(logoUrl);

        currencyCode = FixedOpsFormUtil.resolveCurrencySymbol();
        printedByName = FixedOpsFormUtil.resolvePrintedByName();
        todayDateOnly = FixedOpsFormUtil.formatTodayDateOnly();

        Id purchaseOrderId = resolvePurchaseOrderId(controller);
        if (purchaseOrderId == null) {
            return;
        }

        loadPurchaseOrder(purchaseOrderId);
    }

    @TestVisible
    private static Id resolvePurchaseOrderId(ApexPages.StandardController controller) {
        Id recordId = controller.getRecord().Id;
        if (recordId != null) {
            return recordId;
        }

        String pageId = ApexPages.currentPage().getParameters().get('id');
        return String.isBlank(pageId) ? null : pageId;
    }

    @TestVisible
    private void loadPurchaseOrder(Id purchaseOrderId) {
        List<dealer__Purchase_Order__c> orders = [
            SELECT dealer__Carrier__c,
                dealer__TotalMiscellaneousCost__c,
                dealer__Status__c,
                dealer__VIN__c,
                dealer__Shipping_Method__c,
                dealer__Tracking__c,
                dealer__Vendor__c,
                dealer__Vendor__r.Fax,
                dealer__Vendor_Street__c,
                dealer__Vendor_State__c,
                dealer__Vendor_Postal_Code__c,
                dealer__AccountNumber__c,
                dealer__Vendor_Phone__c,
                dealer__Vendor_Name__c,
                dealer__Vendor_City__c,
                dealer__Service_Repair_Order__c,
                dealer__Service_Repair_Order__r.Name,
                dealer__TotalOrder__c,
                Name,
                Id,
                RecordType.DeveloperName,
                dealer__Type__c,
                CreatedDate,
                CreatedBy.Name,
                dealer__PO_Number__c,
                dealer__Company__c,
                dealer__Comments__c,
                dealer__RequestedBy__c,
                dealer__RequestedBy__r.Name,
                dealer__RequestedBy__r.Phone,
                (
                    SELECT Name,
                        dealer__LineType__c,
                        dealer__Amount__c,
                        dealer__Cost__c,
                        dealer__Part__c,
                        dealer__Description__c,
                        dealer__Quantity__c,
                        dealer__Part_Quantity__c,
                        dealer__Pack_Quantity__c,
                        dealer__Pack_Part_Override__c,
                        dealer__Returned_to_Vendor__c,
                        dealer__Special_Instructions__c,
                        dealer__Part__r.Name,
                        dealer__Part__r.dealer__Description__c
                    FROM dealer__Purchase_Order_Line__r
                    ORDER BY Name ASC
                )
            FROM dealer__Purchase_Order__c
            WHERE Id = :purchaseOrderId
            WITH USER_MODE
            LIMIT 1
        ];

        if (orders.isEmpty()) {
            return;
        }

        po = orders[0];
        showPartLineColumns = !isMiscOrSubletPurchaseOrder(po);
        showPartsTotal = showPartLineColumns;
        isPartPurchase = isPartsPurchasePurchaseOrder(po);
        createdByName = po.CreatedBy != null ? po.CreatedBy.Name : null;
        poDateOnly = FixedOpsFormUtil.formatDateOnly(po.CreatedDate);
        miscTotal = po.dealer__TotalMiscellaneousCost__c;
        initializePurchaseOrderLines(po.dealer__Purchase_Order_Line__r);
        loadReceivingLines(purchaseOrderId);
        apInboxEmail = resolveApInboxEmail(dlr);
        applyVendorAddress(po);
    }

    /**
     * Vendor address is sourced from the vendor Account; the PO header copy
     * is only used as a fallback when the Account has no address on file.
     */
    @TestVisible
    private void applyVendorAddress(dealer__Purchase_Order__c order) {
        if (order == null) {
            return;
        }

        vendorStreet = order.dealer__Vendor_Street__c;
        vendorCity = order.dealer__Vendor_City__c;
        vendorState = order.dealer__Vendor_State__c;
        vendorPostalCode = order.dealer__Vendor_Postal_Code__c;

        FixedOpsFormUtil.CustomerDetails details =
            FixedOpsFormUtil.resolveCustomerDetailsByAccountId(
                order.dealer__Vendor__c
            );
        if (details == null) {
            return;
        }

        Boolean accountHasAddress = String.isNotBlank(details.street) ||
            String.isNotBlank(details.city) ||
            String.isNotBlank(details.state) ||
            String.isNotBlank(details.postalCode);
        if (!accountHasAddress) {
            return;
        }

        vendorStreet = details.street;
        vendorCity = details.city;
        vendorState = details.state;
        vendorPostalCode = details.postalCode;
    }

    @TestVisible
    private static Boolean isMiscOrSubletPurchaseOrder(dealer__Purchase_Order__c order) {
        if (order == null || order.RecordType == null) {
            return false;
        }

        String recordTypeDeveloperName = order.RecordType.DeveloperName;
        return recordTypeDeveloperName == 'Sublet' ||
            recordTypeDeveloperName == 'Misc';
    }

    @TestVisible
    private static Boolean isPartsPurchasePurchaseOrder(dealer__Purchase_Order__c order) {
        if (order == null || order.RecordType == null) {
            return false;
        }

        return order.RecordType.DeveloperName == 'Parts_Purchase';
    }

    @TestVisible
    private static String resolveApInboxEmail(dealer__Dealer_Location__c location) {
        String domain = resolveDealerDomain(location);
        return String.isBlank(domain) ? null : 'ap@' + domain;
    }

    @TestVisible
    private static String resolveDealerDomain(dealer__Dealer_Location__c location) {
        if (location == null) {
            return null;
        }

        if (String.isNotBlank(location.dealer__Website__c)) {
            String host = location.dealer__Website__c.trim().toLowerCase();
            if (host.startsWith('https://')) {
                host = host.substring(8);
            } else if (host.startsWith('http://')) {
                host = host.substring(7);
            }
            if (host.startsWith('www.')) {
                host = host.substring(4);
            }
            Integer slashIndex = host.indexOf('/');
            if (slashIndex >= 0) {
                host = host.substring(0, slashIndex);
            }
            return String.isBlank(host) ? null : host;
        }

        if (
            String.isNotBlank(location.dealer__Email__c) &&
            location.dealer__Email__c.contains('@')
        ) {
            return location.dealer__Email__c.substringAfter('@').trim().toLowerCase();
        }

        return null;
    }

    @TestVisible
    private void loadReceivingLines(Id purchaseOrderId) {
        List<dealer__Purchase_Order_Receiving__c> headers = [
            SELECT Id
            FROM dealer__Purchase_Order_Receiving__c
            WHERE dealer__Purchase_Order__c = :purchaseOrderId
            WITH USER_MODE
        ];

        if (headers.isEmpty()) {
            hasReceivingLines = false;
            return;
        }

        Set<Id> headerIds = new Map<Id, dealer__Purchase_Order_Receiving__c>(
            headers
        ).keySet();

        receivedEventLine = [
            SELECT Id,
                Name,
                dealer__PurchaseOrderReceivingHeader__c,
                dealer__PurchaseOrderReceivingHeader__r.Name,
                dealer__PurchaseOrderLine__r.Name,
                dealer__PurchaseOrderLine__r.dealer__Description__c,
                dealer__PurchaseOrderLine__r.dealer__Part__c,
                dealer__PurchaseOrderLine__r.dealer__Part__r.Name,
                dealer__PurchaseOrderLine__r.dealer__Part__r.dealer__Description__c,
                dealer__QuantityReceived__c,
                dealer__Amount__c
            FROM dealer__Purchase_Order_Receiving_Line__c
            WHERE dealer__PurchaseOrderReceivingHeader__c IN :headerIds
            WITH USER_MODE
            ORDER BY dealer__PurchaseOrderReceivingHeader__r.Name DESC,
                dealer__PurchaseOrderLine__r.Name ASC
        ];

        hasReceivingLines = !receivedEventLine.isEmpty();
        List<dealer__Purchase_Order__c> ordersForTitle = [
            SELECT Name, dealer__PO_Number__c
            FROM dealer__Purchase_Order__c
            WHERE Id = :purchaseOrderId
            WITH USER_MODE
            LIMIT 1
        ];
        String purchaseOrderDisplayName = ordersForTitle.isEmpty()
            ? null
            : resolvePurchaseOrderDisplayName(ordersForTitle[0]);
        receivingEventGroups = buildReceivingEventGroups(
            purchaseOrderDisplayName,
            receivedEventLine,
            showPartLineColumns
        );
    }

    @TestVisible
    private static String resolvePurchaseOrderDisplayName(
        dealer__Purchase_Order__c order
    ) {
        if (order == null) {
            return null;
        }

        if (String.isNotBlank(order.dealer__PO_Number__c)) {
            return order.dealer__PO_Number__c;
        }

        return order.Name;
    }

    @TestVisible
    private static String formatReceivingEventTitle(
        String purchaseOrderName,
        String receivingEventName
    ) {
        if (String.isBlank(receivingEventName)) {
            return purchaseOrderName;
        }

        if (String.isBlank(purchaseOrderName)) {
            return receivingEventName;
        }

        return purchaseOrderName + '-' + receivingEventName;
    }

    @TestVisible
    private static List<ReceivingEventDisplayWrapper> buildReceivingEventGroups(
        String purchaseOrderName,
        List<dealer__Purchase_Order_Receiving_Line__c> receivingLines,
        Boolean usePartReceivingFields
    ) {
        List<ReceivingEventDisplayWrapper> eventGroups = new List<ReceivingEventDisplayWrapper>();
        if (receivingLines == null || receivingLines.isEmpty()) {
            return eventGroups;
        }

        Id currentHeaderId = null;
        ReceivingEventDisplayWrapper currentEvent = null;
        for (dealer__Purchase_Order_Receiving_Line__c receivingLine : receivingLines) {
            Id headerId = receivingLine.dealer__PurchaseOrderReceivingHeader__c;
            if (headerId != currentHeaderId) {
                currentEvent = new ReceivingEventDisplayWrapper();
                currentEvent.eventTitle = formatReceivingEventTitle(
                    purchaseOrderName,
                    receivingLine.dealer__PurchaseOrderReceivingHeader__r.Name
                );
                currentEvent.lines = new List<ReceivingLineDisplayWrapper>();
                eventGroups.add(currentEvent);
                currentHeaderId = headerId;
            }

            ReceivingLineDisplayWrapper displayLine = new ReceivingLineDisplayWrapper();
            dealer__Purchase_Order_Line__c poLine = receivingLine.dealer__PurchaseOrderLine__r;
            if (usePartReceivingFields == true) {
                displayLine.partNumber = resolvePoLinePartNumber(poLine);
                displayLine.partDescription = resolvePoLinePartDescription(poLine);
            } else {
                displayLine.lineDescription = resolveReceivingLineDescription(poLine);
            }
            displayLine.quantityReceived = receivingLine.dealer__QuantityReceived__c;
            displayLine.amount = receivingLine.dealer__Amount__c;
            currentEvent.lines.add(displayLine);
        }

        return eventGroups;
    }

    @TestVisible
    private static String resolvePoLinePartNumber(
        dealer__Purchase_Order_Line__c poLine
    ) {
        if (poLine == null || poLine.dealer__Part__r == null) {
            return null;
        }

        return poLine.dealer__Part__r.Name;
    }

    @TestVisible
    private static String resolvePoLinePartDescription(
        dealer__Purchase_Order_Line__c poLine
    ) {
        if (poLine == null) {
            return null;
        }

        String partDescription = poLine.dealer__Part__r == null
            ? null
            : poLine.dealer__Part__r.dealer__Description__c;
        if (String.isBlank(partDescription)) {
            partDescription = poLine.dealer__Description__c;
        }

        return partDescription;
    }

    @TestVisible
    private static String resolveReceivingLineDescription(
        dealer__Purchase_Order_Line__c poLine
    ) {
        if (poLine == null) {
            return null;
        }

        return poLine.dealer__Description__c;
    }

    @TestVisible
    private void initializePurchaseOrderLines(
        List<dealer__Purchase_Order_Line__c> poLines
    ) {
        if (poLines == null || poLines.isEmpty()) {
            return;
        }

        Boolean useStandardLineFields = !showPartLineColumns;
        Map<Id, String> serialNumbersByPart = useStandardLineFields
            ? new Map<Id, String>()
            : getSerialNumberByPart(poLines);

        for (dealer__Purchase_Order_Line__c poLine : poLines) {
            if (
                !useStandardLineFields &&
                poLine.dealer__LineType__c == 'Miscellaneous'
            ) {
                miscLines.add(poLine);
                continue;
            }

            PurchaseOrderLineWrapper lineWrapper = new PurchaseOrderLineWrapper();
            if (useStandardLineFields) {
                lineWrapper.lineQuantity = poLine.dealer__Quantity__c;
                lineWrapper.lineDescription = poLine.dealer__Description__c;
            } else {
                lineWrapper.partQuantity = poLine.dealer__Part_Quantity__c;
                if (poLine.dealer__Part__r != null) {
                    lineWrapper.partName = poLine.dealer__Part__r.Name;
                }

                String partDescription = poLine.dealer__Part__r == null
                    ? null
                    : poLine.dealer__Part__r.dealer__Description__c;
                if (String.isBlank(partDescription)) {
                    partDescription = poLine.dealer__Description__c;
                }
                applyDescriptionLines(lineWrapper, partDescription);
                lineWrapper.partDescription = partDescription;
                lineWrapper.serialNumber = serialNumbersByPart.get(
                    poLine.dealer__Part__c
                );
            }

            lineWrapper.partCost = poLine.dealer__Cost__c;
            lineWrapper.partAmount = poLine.dealer__Amount__c;
            lineWrapper.specialInstructions = poLine.dealer__Special_Instructions__c;
            applyDetailSubRowFields(lineWrapper, poLine);
            purchaseLineList.add(lineWrapper);

            if (
                showPartsTotal &&
                poLine.dealer__Amount__c != null
            ) {
                partTotal += poLine.dealer__Amount__c;
            }
        }
    }

    @TestVisible
    private static void applyDescriptionLines(
        PurchaseOrderLineWrapper lineWrapper,
        String partDescription
    ) {
        if (String.isBlank(partDescription)) {
            return;
        }

        lineWrapper.firstLine = partDescription.substring(
            0,
            Math.min(partDescription.length(), DESC_SIZE)
        );

        if (partDescription.length() < DESC_SIZE * 2) {
            lineWrapper.secondLine = partDescription.substring(
                partDescription.length()
            );
        } else {
            lineWrapper.secondLine = partDescription.substring(
                DESC_SIZE,
                Math.min(partDescription.length(), DESC_SIZE * 2)
            );
        }
    }

    @TestVisible
    private static void applyDetailSubRowFields(
        PurchaseOrderLineWrapper lineWrapper,
        dealer__Purchase_Order_Line__c poLine
    ) {
        Decimal packQuantity = poLine.dealer__Pack_Quantity__c;
        lineWrapper.packQuantity = packQuantity;
        lineWrapper.showPackQuantity = packQuantity != null && packQuantity != 1;

        String packPartOverride = formatDetailValue(
            poLine.get('dealer__Pack_Part_Override__c')
        );
        lineWrapper.packPartOverride = packPartOverride;
        lineWrapper.showPackPartOverride = packPartOverride != null;

        String returnedToVendor = formatDetailValue(
            poLine.get('dealer__Returned_to_Vendor__c')
        );
        lineWrapper.returnedToVendor = returnedToVendor;
        lineWrapper.showReturnedToVendor = returnedToVendor != null;
    }

    @TestVisible
    private static String softWrap(String value, Integer chunkSize) {
        if (value == null || chunkSize == null || chunkSize <= 0 ||
            value.length() <= chunkSize) {
            return value;
        }

        List<String> chunks = new List<String>();
        Integer index = 0;
        while (index < value.length()) {
            chunks.add(
                value.substring(index, Math.min(index + chunkSize, value.length()))
            );
            index += chunkSize;
        }

        return String.join(chunks, ZERO_WIDTH_SPACE);
    }

    @TestVisible
    private static String formatDetailValue(Object value) {
        if (value == null) {
            return null;
        }

        if (value instanceof Boolean) {
            return ((Boolean) value) ? 'Yes' : null;
        }

        if (value instanceof String) {
            String stringValue = (String) value;
            return String.isBlank(stringValue) ? null : stringValue;
        }

        return String.valueOf(value);
    }

    @TestVisible
    private static Map<Id, String> getSerialNumberByPart(
        List<dealer__Purchase_Order_Line__c> poLines
    ) {
        Map<Id, String> serialNumberByPart = new Map<Id, String>();
        Set<Id> partIds = new Set<Id>();

        for (dealer__Purchase_Order_Line__c poLine : poLines) {
            if (poLine.dealer__Part__c != null) {
                partIds.add(poLine.dealer__Part__c);
            }
        }

        if (partIds.isEmpty()) {
            return serialNumberByPart;
        }

        for (dealer__Parts_Ledger__c ledger : [
            SELECT dealer__Part__c, dealer__SerialNumber__c
            FROM dealer__Parts_Ledger__c
            WHERE dealer__Part__c IN :partIds
                AND dealer__SerialNumber__c != NULL
            WITH USER_MODE
            ORDER BY CreatedDate DESC
        ]) {
            if (!serialNumberByPart.containsKey(ledger.dealer__Part__c)) {
                serialNumberByPart.put(
                    ledger.dealer__Part__c,
                    ledger.dealer__SerialNumber__c
                );
            }
        }

        return serialNumberByPart;
    }

    public class ReceivingEventDisplayWrapper {
        public String eventTitle { get; set; }
        public List<ReceivingLineDisplayWrapper> lines { get; set; }
    }

    public class ReceivingLineDisplayWrapper {
        public String partNumber { get; set; }
        public String partDescription { get; set; }
        public String lineDescription { get; set; }
        public Decimal quantityReceived { get; set; }
        public Decimal amount { get; set; }
    }

    public class PurchaseOrderLineWrapper {
        public Decimal lineQuantity { get; set; }
        public String lineDescription { get; set; }
        public Decimal partQuantity { get; set; }
        public String partName { get; set; }
        public String partNameDisplay {
            get {
                return softWrap(partName, PART_NAME_WRAP_SIZE);
            }
        }
        public String partDescription { get; set; }
        public Decimal partCost { get; set; }
        public Decimal partAmount { get; set; }
        public String serialNumber { get; set; }
        public String firstLine { get; set; }
        public String secondLine { get; set; }
        public String specialInstructions { get; set; }
        public Decimal packQuantity { get; set; }
        public Boolean showPackQuantity { get; set; }
        public String packPartOverride { get; set; }
        public Boolean showPackPartOverride { get; set; }
        public String returnedToVendor { get; set; }
        public Boolean showReturnedToVendor { get; set; }
        public Boolean hasDetailSubRow {
            get {
                return showPackQuantity == true ||
                    showPackPartOverride == true ||
                    showReturnedToVendor == true;
            }
        }
    }
}
