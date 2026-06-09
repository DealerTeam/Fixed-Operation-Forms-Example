/**
 * Unmanaged extension for form_PartsInvoiceCopy and form_PartsPickTicketCopy.
 *
 * Reproduces the managed Parts Invoice and Pick Ticket print forms without
 * relying on the managed PartsInvoice_Printing controller.
 */
public with sharing class FormPartsInvoiceExt {
    private static final Integer PICK_TICKET_PAGE_SIZE = 25;
    private static final String STATUS_INVOICED = 'Invoiced';
    private static final String STATUS_POSTED = 'Posted';
    private static final String REPAIR_ORDER_RECORD_TYPE = 'Repair_Order';
    private static final String VENDOR_RETURN_RECORD_TYPE = 'Vendor_Return';
    private static final String COUNTER_RETURN_RECORD_TYPE = 'Counter_Return';
    private static final String CORE_RETURN_RECORD_TYPE = 'Core_Return';

    public dealer__Parts_Invoice__c invoice { get; private set; }
    public List<InvoiceLineWrapper> invoiceLineItems { get; private set; }

    public String logoUrl { get; private set; }
    public Boolean hasLogo { get; private set; }
    public String currencyCode { get; private set; }
    public String printedByName { get; private set; }
    public String renderAs { get; private set; }
    public Boolean isPdf { get; private set; }
    public String printDateTime { get; private set; }
    public String invoiceDateOnly { get; private set; }
    public String todayDateOnly { get; private set; }

    public String customerName { get; private set; }
    public String customerStreet { get; private set; }
    public String customerCity { get; private set; }
    public String customerState { get; private set; }
    public String customerPostalCode { get; private set; }
    public String customerPhone { get; private set; }
    public String customerMobile { get; private set; }
    public String customerEmail { get; private set; }
    public String customerAccountNumber { get; private set; }
    public String customerContactName { get; private set; }
    public Boolean customerIsPersonAccount { get; private set; }

    public String shipToStreet { get; private set; }
    public String shipToCity { get; private set; }
    public String shipToState { get; private set; }
    public String shipToPostalCode { get; private set; }
    public String shipToFreeform { get; private set; }
    public Boolean hasStructuredShipTo { get; private set; }

    public List<CashLineWrapper> cashLines { get; private set; }
    public Decimal totalDue { get; private set; }
    public Decimal totalPaid { get; private set; }
    public Decimal totalCoreCharges { get; private set; }

    public Boolean hasCoreCharges {
        get {
            return totalCoreCharges != null && totalCoreCharges != 0;
        }
    }

    public Boolean hasComments {
        get {
            return invoice != null &&
                String.isNotBlank(invoice.dealer__Comments__c);
        }
    }
    public Boolean isPreInvoice {
        get {
            if (invoice == null || String.isBlank(invoice.dealer__Status__c)) {
                return true;
            }
            String status = invoice.dealer__Status__c;
            return status != STATUS_INVOICED && status != STATUS_POSTED;
        }
    }
    public Boolean showShipTo {
        get {
            return hasShipToAddress && !isVendorReturnInvoice;
        }
    }
    public Boolean hasShipToAddress {
        get {
            return hasStructuredShipTo ||
                (invoice != null &&
                    String.isNotBlank(invoice.dealer__Ship_To__c));
        }
    }
    public Boolean hasCashLines {
        get {
            return cashLines != null && !cashLines.isEmpty();
        }
    }
    public Boolean hasPayments {
        get {
            return hasCashLines;
        }
    }
    public Boolean hasDeposit {
        get {
            return invoice != null &&
                invoice.dealer__Deposit__c != null &&
                invoice.dealer__Deposit__c != 0;
        }
    }
    public Boolean hasSalesTaxId {
        get {
            return invoice != null &&
                String.isNotBlank(invoice.dealer__Sales_Tax_ID__c);
        }
    }

    public Boolean isRepairOrderInvoice {
        get {
            return invoice != null &&
                invoice.RecordType != null &&
                invoice.RecordType.DeveloperName == REPAIR_ORDER_RECORD_TYPE;
        }
    }

    public Boolean isVendorReturnInvoice {
        get {
            return invoice != null &&
                invoice.RecordType != null &&
                invoice.RecordType.DeveloperName == VENDOR_RETURN_RECORD_TYPE;
        }
    }

    public Boolean isCounterReturnInvoice {
        get {
            return invoice != null &&
                invoice.RecordType != null &&
                invoice.RecordType.DeveloperName == COUNTER_RETURN_RECORD_TYPE;
        }
    }

    public Boolean isCoreReturnInvoice {
        get {
            return invoice != null &&
                invoice.RecordType != null &&
                invoice.RecordType.DeveloperName == CORE_RETURN_RECORD_TYPE;
        }
    }

    public Boolean isReturnInvoice {
        get {
            return isVendorReturnInvoice ||
                isCounterReturnInvoice ||
                isCoreReturnInvoice;
        }
    }

    public Boolean showLineCoreColumn {
        get {
            return !isReturnInvoice || isCoreReturnInvoice;
        }
    }

    public Boolean showInvoiceTotals {
        get {
            return !isRepairOrderInvoice;
        }
    }

    public Boolean showPaymentsSection {
        get {
            return hasPayments && showInvoiceTotals && !isVendorReturnInvoice;
        }
    }

    public Boolean showPartyShipToColumn {
        get {
            return !isVendorReturnInvoice;
        }
    }

    public String formTitle {
        get {
            if (isRepairOrderInvoice) {
                return 'Service Repair Order - Parts Invoice';
            }
            if (isVendorReturnInvoice) {
                return 'Vendor Return';
            }
            if (isCounterReturnInvoice) {
                return 'Counter Return';
            }
            if (isCoreReturnInvoice) {
                return 'Core Return';
            }
            return 'Parts Invoice';
        }
    }

    public String partyPrimaryLabel {
        get {
            return isVendorReturnInvoice ? 'Vendor' : null;
        }
    }

    public String lineQuantityLabel {
        get {
            return isReturnInvoice ? 'Qty Returned' : null;
        }
    }

    public String totalDueLabel {
        get {
            if (isReturnInvoice && totalDue != null && totalDue < 0) {
                return 'Total Credit';
            }
            return 'Total Due';
        }
    }

    public Boolean hasRmaNumber {
        get {
            return invoice != null &&
                String.isNotBlank(invoice.dealer__RMA_No__c);
        }
    }

    public String repairOrderNumber {
        get {
            if (invoice == null || invoice.dealer__Service_Repair_Order__r == null) {
                return null;
            }

            if (String.isNotBlank(invoice.dealer__Service_Repair_Order__r.Name)) {
                return invoice.dealer__Service_Repair_Order__r.Name;
            }

            return invoice.dealer__Service_Repair_Order__r.dealer__RO_Number__c == null
                ? null
                : String.valueOf(
                    invoice.dealer__Service_Repair_Order__r.dealer__RO_Number__c
                );
        }
    }

    private List<List<InvoiceLineWrapper>> pageBrokenInvoiceLinesCache;

    public List<List<InvoiceLineWrapper>> pageBrokenInvoiceLines {
        get {
            if (pageBrokenInvoiceLinesCache == null) {
                pageBrokenInvoiceLinesCache = buildPageBrokenLines(
                    invoiceLineItems,
                    PICK_TICKET_PAGE_SIZE
                );
            }
            return pageBrokenInvoiceLinesCache;
        }
        private set;
    }

    private Boolean serviceHoursLoaded = false;
    private List<String> serviceHoursLinesCache;

    public List<String> serviceHoursLines {
        get {
            if (!serviceHoursLoaded) {
                serviceHoursLinesCache = invoice == null ||
                    invoice.dealer__Location__c == null
                    ? new List<String>()
                    : FixedOpsFormUtil.resolveServiceHoursLines(
                        invoice.dealer__Location__c
                    );
                serviceHoursLoaded = true;
            }
            return serviceHoursLinesCache;
        }
        private set;
    }

    public Boolean hasServiceHours {
        get {
            return serviceHoursLines != null && !serviceHoursLines.isEmpty();
        }
    }

    public dealer__Dealer_Location__c userLoc {
        get {
            if (invoice == null || invoice.dealer__Location__c == null) {
                return new dealer__Dealer_Location__c();
            }

            List<dealer__Dealer_Location__c> locations = [
                SELECT Name,
                    dealer__Company_Contracting_Name__c,
                    dealer__Street__c,
                    dealer__City__c,
                    dealer__State__c,
                    dealer__Postal_Code__c,
                    dealer__Main_Phone__c,
                    dealer__Website__c,
                    dealer__Email__c,
                    dealer__BAR_Number__c,
                    dealer__EPA_Number__c,
                    dealer__Parts_Invoice_Disclaimer__c
                FROM dealer__Dealer_Location__c
                WHERE Id = :invoice.dealer__Location__c
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

    public FormPartsInvoiceExt(ApexPages.StandardController controller) {
        invoiceLineItems = new List<InvoiceLineWrapper>();
        cashLines = new List<CashLineWrapper>();
        invoice = new dealer__Parts_Invoice__c();
        totalDue = 0;
        totalPaid = 0;
        totalCoreCharges = 0;
        hasStructuredShipTo = false;

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
        printDateTime = FixedOpsFormUtil.formatNowDateTime('MM/dd/yyyy HH:mm a');

        Id invoiceId = resolvePartsInvoiceId(controller);
        if (invoiceId == null) {
            return;
        }

        loadPartsInvoice(invoiceId);
    }

    @TestVisible
    private static Id resolvePartsInvoiceId(ApexPages.StandardController controller) {
        Id recordId = controller.getRecord().Id;
        if (recordId != null) {
            return recordId;
        }

        String pageId = ApexPages.currentPage().getParameters().get('id');
        return String.isBlank(pageId) ? null : pageId;
    }

    @TestVisible
    private void loadPartsInvoice(Id invoiceId) {
        List<dealer__Parts_Invoice__c> invoices = [
            SELECT Id,
                Name,
                CreatedDate,
                RecordType.DeveloperName,
                RecordType.Name,
                dealer__Invoice_Date_Time__c,
                dealer__Post_Date_Time__c,
                dealer__Status__c,
                dealer__Customer_Purchase_Order__c,
                dealer__RMA_No__c,
                dealer__Ship_To__c,
                dealer__Customer_ShipTo_Street__c,
                dealer__Customer_ShipTo_City__c,
                dealer__Customer_Shipto_State__c,
                dealer__Customer_ShipTo_Zip__c,
                dealer__Ship_Via__c,
                dealer__Shipping_Tracking_No__c,
                dealer__Comments__c,
                dealer__PickupOrDelivery__c,
                dealer__Parts_Price__c,
                dealer__TotalMiscCharges__c,
                dealer__Misc_Fee__c,
                dealer__Shipping_Charges__c,
                dealer__Deposit__c,
                dealer__Total_Tax__c,
                dealer__Sales_Tax_ID__c,
                dealer__TotalPayments__c,
                dealer__Total_Invoice__c,
                dealer__Location__c,
                dealer__Service_Repair_Order__c,
                dealer__Service_Repair_Order__r.Name,
                dealer__Service_Repair_Order__r.dealer__RO_Number__c,
                dealer__Customer__c,
                dealer__Customer__r.Name,
                dealer__Customer__r.IsPersonAccount,
                dealer__Customer__r.dealer__AccountNumberID__c,
                dealer__Customer__r.ShippingCity,
                dealer__Customer__r.ShippingState,
                dealer__Customer__r.ShippingPostalCode,
                dealer__Customer_Contact__r.Name,
                dealer__Counterman__r.Name,
                (
                    SELECT dealer__Payment_Method__c,
                        dealer__Payment_Type__c,
                        dealer__Deposit__c,
                        dealer__Close_Date__c,
                        dealer__Amount__c,
                        dealer__ProcessingFee__c
                    FROM dealer__Cashiering__r
                    ORDER BY dealer__Close_Date__c ASC NULLS LAST
                )
            FROM dealer__Parts_Invoice__c
            WHERE Id = :invoiceId
            WITH USER_MODE
            LIMIT 1
        ];

        if (invoices.isEmpty()) {
            return;
        }

        invoice = invoices[0];
        invoiceDateOnly = FixedOpsFormUtil.formatDateOnly(
            invoice.dealer__Invoice_Date_Time__c
        );
        cashLines = buildCashLines(invoice.dealer__Cashiering__r);
        computePaymentTotals();
        invoiceLineItems = buildInvoiceLineWrappers(loadInvoiceLines(invoiceId));
        totalCoreCharges = sumTotalCore(invoiceLineItems);
        applyCustomerDetails(
            FixedOpsFormUtil.resolveCustomerDetailsByAccountId(
                invoice.dealer__Customer__c
            )
        );
        applyShipToDetails();
        customerContactName = invoice.dealer__Customer_Contact__r == null
            ? null
            : invoice.dealer__Customer_Contact__r.Name;
        customerIsPersonAccount = invoice.dealer__Customer__r != null &&
            invoice.dealer__Customer__r.IsPersonAccount == true;
        customerAccountNumber = invoice.dealer__Customer__r == null
            ? null
            : invoice.dealer__Customer__r.dealer__AccountNumberID__c;
        totalDue = zeroIfNull(invoice.dealer__Total_Invoice__c) -
            zeroIfNull(invoice.dealer__TotalPayments__c);
    }

    @TestVisible
    private List<dealer__Parts_Invoice_Line__c> loadInvoiceLines(Id invoiceId) {
        return [
            SELECT dealer__Quantity_Sold__c,
                dealer__Part_Number__c,
                dealer__Part_Description__c,
                dealer__Bin__c,
                dealer__Price__c,
                dealer__Core__c,
                dealer__TotalCore__c,
                dealer__Total_Price__c,
                dealer__Extended_Price__c,
                dealer__MiscellaneousChargeCode__c,
                dealer__Comment__c,
                dealer__QuantityReturned__c,
                dealer__ReturnReference__c,
                dealer__PartsReturnLine__r.dealer__Part_Description__c,
                dealer__PartsReturnLine__r.dealer__Parts_Invoice__r.Name,
                dealer__Part__r.dealer__Description__c,
                dealer__Part__r.dealer__BinLocation__r.Name,
                (
                    SELECT dealer__SerialNumber__c
                    FROM dealer__Parts_Ledgers__r
                    WHERE dealer__SerialNumber__c != NULL
                )
            FROM dealer__Parts_Invoice_Line__c
            WHERE dealer__Parts_Invoice__c = :invoiceId
            WITH USER_MODE
            ORDER BY dealer__Sequence__c ASC NULLS LAST
        ];
    }

    @TestVisible
    private static List<InvoiceLineWrapper> buildInvoiceLineWrappers(
        List<dealer__Parts_Invoice_Line__c> lines
    ) {
        List<InvoiceLineWrapper> wrappers = new List<InvoiceLineWrapper>();
        if (lines == null || lines.isEmpty()) {
            return wrappers;
        }

        for (dealer__Parts_Invoice_Line__c line : lines) {
            wrappers.add(new InvoiceLineWrapper(line));
        }

        return wrappers;
    }

    @TestVisible
    private static List<CashLineWrapper> buildCashLines(
        List<dealer__Cashering__c> cashiering
    ) {
        List<CashLineWrapper> wrappers = new List<CashLineWrapper>();
        if (cashiering == null || cashiering.isEmpty()) {
            return wrappers;
        }

        for (dealer__Cashering__c cash : cashiering) {
            wrappers.add(new CashLineWrapper(cash));
        }

        return wrappers;
    }

    @TestVisible
    private static List<List<InvoiceLineWrapper>> buildPageBrokenLines(
        List<InvoiceLineWrapper> lines,
        Integer pageSize
    ) {
        List<List<InvoiceLineWrapper>> pages = new List<List<InvoiceLineWrapper>>();
        if (lines == null || lines.isEmpty()) {
            return pages;
        }

        List<Object> flat = new List<Object>();
        for (InvoiceLineWrapper line : lines) {
            flat.add(line);
        }

        for (List<Object> chunk : FixedOpsFormUtil.chunkList(flat, pageSize)) {
            List<InvoiceLineWrapper> page = new List<InvoiceLineWrapper>();
            for (Object item : chunk) {
                page.add((InvoiceLineWrapper) item);
            }
            pages.add(page);
        }

        return pages;
    }

    @TestVisible
    private void applyShipToDetails() {
        if (invoice == null) {
            return;
        }

        shipToStreet = invoice.dealer__Customer_ShipTo_Street__c;
        shipToCity = invoice.dealer__Customer_ShipTo_City__c;
        shipToState = invoice.dealer__Customer_Shipto_State__c;
        shipToPostalCode = invoice.dealer__Customer_ShipTo_Zip__c;
        shipToFreeform = invoice.dealer__Ship_To__c;
        hasStructuredShipTo = String.isNotBlank(shipToStreet) ||
            String.isNotBlank(shipToCity) ||
            String.isNotBlank(shipToState) ||
            String.isNotBlank(shipToPostalCode);
    }

    @TestVisible
    private void computePaymentTotals() {
        totalPaid = 0;
        if (cashLines == null) {
            return;
        }

        for (CashLineWrapper line : cashLines) {
            totalPaid += zeroIfNull(line.lineTotal);
        }
    }

    @TestVisible
    private void applyCustomerDetails(FixedOpsFormUtil.CustomerDetails details) {
        if (details == null) {
            return;
        }

        customerName = details.name;
        customerStreet = details.street;
        customerCity = details.city;
        customerState = details.state;
        customerPostalCode = details.postalCode;
        customerPhone = details.phone;
        customerMobile = details.mobile;
        customerEmail = details.email;
    }

    @TestVisible
    private void assignTestState(
        dealer__Parts_Invoice__c testInvoice,
        List<InvoiceLineWrapper> lines,
        List<CashLineWrapper> cash,
        Decimal due
    ) {
        invoice = testInvoice;
        invoiceLineItems = lines == null
            ? new List<InvoiceLineWrapper>()
            : lines;
        cashLines = cash == null ? new List<CashLineWrapper>() : cash;
        totalDue = due == null ? 0 : due;
        totalCoreCharges = sumTotalCore(invoiceLineItems);
        computePaymentTotals();
        if (testInvoice != null) {
            applyShipToDetails();
        }
    }

    @TestVisible
    private static Decimal sumTotalCore(List<InvoiceLineWrapper> lines) {
        Decimal total = 0;
        if (lines == null) {
            return total;
        }

        for (InvoiceLineWrapper line : lines) {
            total += zeroIfNull(line.totalCore);
        }

        return total;
    }

    private static Decimal zeroIfNull(Decimal value) {
        return value == null ? 0 : value;
    }

    public class InvoiceLineWrapper {
        public Decimal quantity { get; private set; }
        public String partNumber { get; private set; }
        public String partDescription { get; private set; }
        public String displayDescription { get; private set; }
        public String binDisplay { get; private set; }
        public Decimal unitPrice { get; private set; }
        public Decimal coreCharge { get; private set; }
        public Decimal totalCore { get; private set; }
        public Decimal totalPrice { get; private set; }
        public Decimal extendedPrice { get; private set; }
        public Decimal quantityReturned { get; private set; }
        public String lineComment { get; private set; }
        public Boolean hasLineComment { get; private set; }
        public String returnReferenceInvoiceName { get; private set; }
        public Boolean hasReturnReference { get; private set; }
        public List<String> serialNumbers { get; private set; }
        public Boolean hasSerialNumbers { get; private set; }

        public InvoiceLineWrapper(dealer__Parts_Invoice_Line__c line) {
            quantity = line.dealer__Quantity_Sold__c;
            quantityReturned = line.dealer__QuantityReturned__c;
            partNumber = line.dealer__Part_Number__c;
            partDescription = line.dealer__Part_Description__c;
            unitPrice = line.dealer__Price__c;
            coreCharge = zeroIfNull(line.dealer__Core__c);
            totalCore = zeroIfNull(line.dealer__TotalCore__c);
            totalPrice = line.dealer__Total_Price__c;
            extendedPrice = line.dealer__Extended_Price__c;
            lineComment = line.dealer__Comment__c;
            hasLineComment = String.isNotBlank(lineComment);
            returnReferenceInvoiceName = resolveReturnReferenceInvoiceName(line);
            hasReturnReference = String.isNotBlank(returnReferenceInvoiceName);
            serialNumbers = new List<String>();

            displayDescription = resolveLinePartDescription(line);
            binDisplay = resolveBinDisplay(
                line.dealer__Part__r == null ||
                    line.dealer__Part__r.dealer__BinLocation__r == null
                    ? null
                    : line.dealer__Part__r.dealer__BinLocation__r.Name,
                line.dealer__Bin__c
            );

            if (line.dealer__Parts_Ledgers__r != null) {
                for (
                    dealer__Parts_Ledger__c ledger : line.dealer__Parts_Ledgers__r
                ) {
                    if (String.isNotBlank(ledger.dealer__SerialNumber__c)) {
                        serialNumbers.add(ledger.dealer__SerialNumber__c);
                    }
                }
            }

            hasSerialNumbers = !serialNumbers.isEmpty();
        }
    }

    @TestVisible
    private static String resolveReturnReferenceInvoiceName(
        dealer__Parts_Invoice_Line__c line
    ) {
        if (line == null) {
            return null;
        }

        if (line.dealer__PartsReturnLine__r != null &&
            line.dealer__PartsReturnLine__r.dealer__Parts_Invoice__r != null &&
            String.isNotBlank(
                line.dealer__PartsReturnLine__r.dealer__Parts_Invoice__r.Name
            )) {
            return line.dealer__PartsReturnLine__r.dealer__Parts_Invoice__r.Name;
        }

        return line.dealer__ReturnReference__c;
    }

    @TestVisible
    public static String resolveLinePartDescription(
        dealer__Parts_Invoice_Line__c line
    ) {
        if (line == null) {
            return null;
        }

        if (line.dealer__MiscellaneousChargeCode__c != null &&
            String.isNotBlank(line.dealer__Comment__c)) {
            return line.dealer__Comment__c;
        }
        if (String.isNotBlank(line.dealer__Part_Description__c)) {
            return line.dealer__Part_Description__c;
        }
        if (line.dealer__PartsReturnLine__r != null &&
            String.isNotBlank(
                line.dealer__PartsReturnLine__r.dealer__Part_Description__c
            )) {
            return line.dealer__PartsReturnLine__r.dealer__Part_Description__c;
        }
        if (line.dealer__Part__r != null &&
            String.isNotBlank(line.dealer__Part__r.dealer__Description__c)) {
            return line.dealer__Part__r.dealer__Description__c;
        }
        return line.dealer__Part_Number__c;
    }

    @TestVisible
    private static String resolveBinDisplay(
        String binLocationName,
        String binField
    ) {
        if (String.isNotBlank(binLocationName)) {
            return binLocationName;
        }
        return binField;
    }

    public class CashLineWrapper {
        public String paymentMethod { get; private set; }
        public String paymentType { get; private set; }
        public Boolean isDeposit { get; private set; }
        public Date closeDate { get; private set; }
        public Decimal amount { get; private set; }
        public Decimal processingFee { get; private set; }
        public Decimal lineTotal { get; private set; }

        public CashLineWrapper(dealer__Cashering__c cash) {
            paymentMethod = cash.dealer__Payment_Method__c;
            paymentType = cash.dealer__Payment_Type__c;
            isDeposit = cash.dealer__Deposit__c == true;
            closeDate = cash.dealer__Close_Date__c;
            amount = cash.dealer__Amount__c == null ? 0 : cash.dealer__Amount__c;
            processingFee = cash.dealer__ProcessingFee__c == null
                ? 0
                : cash.dealer__ProcessingFee__c;
            lineTotal = amount + processingFee;
        }
    }
}
