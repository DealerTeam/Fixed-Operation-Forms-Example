/**
 * Unmanaged extension for form_PartsInvoiceAuditCopy.
 *
 * Renders an internal audit copy of a Parts Invoice with cost and sale detail
 * on every line, a gross-profit summary, cashiering, and posted General Ledger
 * entries from dealer__GLDetail__x.
 */
public with sharing class FormPartsInvoiceAuditCopyExt {
    public dealer__Parts_Invoice__c invoice { get; private set; }
    public List<AuditLineWrapper> invoiceLineItems { get; private set; }
    public List<CashLineWrapper> cashLines { get; private set; }
    public List<FixedOpsFormUtil.GlDetailLine> glLines { get; private set; }

    public String logoUrl { get; private set; }
    public Boolean hasLogo { get; private set; }
    public String currencyCode { get; private set; }
    public String printedByName { get; private set; }
    public String renderAs { get; private set; }
    public Boolean isPdf { get; private set; }
    public String printDateTime { get; private set; }
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

    public Decimal totalDue { get; private set; }
    public Decimal totalPaid { get; private set; }
    public Decimal totalCoreCharges { get; private set; }
    public Decimal totalPartsCost { get; private set; }
    public Decimal totalPartsSale { get; private set; }
    public Decimal totalMiscCost { get; private set; }
    public Decimal totalMiscSale { get; private set; }
    public Decimal totalCost { get; private set; }
    public Decimal totalSale { get; private set; }
    public Decimal totalGross { get; private set; }
    public Decimal glTotal { get; private set; }

    public Boolean hasPayments {
        get {
            return cashLines != null && !cashLines.isEmpty();
        }
    }
    public Boolean hasGlLines {
        get {
            return glLines != null && !glLines.isEmpty();
        }
    }
    public Boolean hasComments {
        get {
            return invoice != null &&
                String.isNotBlank(invoice.dealer__Comments__c);
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
    public Boolean hasCoreCharges {
        get {
            return totalCoreCharges != null && totalCoreCharges != 0;
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
    public Boolean isVendorReturnInvoice {
        get {
            return invoice != null &&
                invoice.RecordType != null &&
                invoice.RecordType.DeveloperName == 'Vendor_Return';
        }
    }
    public Boolean isCounterReturnInvoice {
        get {
            return invoice != null &&
                invoice.RecordType != null &&
                invoice.RecordType.DeveloperName == 'Counter_Return';
        }
    }
    public Boolean isCoreReturnInvoice {
        get {
            return invoice != null &&
                invoice.RecordType != null &&
                (invoice.RecordType.DeveloperName == 'Core_Return' ||
                    invoice.RecordType.DeveloperName == 'Vendor_Core_Return');
        }
    }
    public Boolean showPartyShipToColumn {
        get {
            return !isVendorReturnInvoice;
        }
    }
    public Boolean showInvoiceTotals {
        get {
            return !isRepairOrderInvoice;
        }
    }
    public Boolean hasRmaNumber {
        get {
            return invoice != null &&
                String.isNotBlank(invoice.dealer__RMA_No__c);
        }
    }
    public String formTitle {
        get {
            if (isRepairOrderInvoice) {
                return 'Service Repair Order - Parts Invoice Audit Copy';
            }
            if (isVendorReturnInvoice) {
                return 'Vendor Return - Audit Copy';
            }
            if (isCounterReturnInvoice) {
                return 'Counter Return - Audit Copy';
            }
            if (isCoreReturnInvoice) {
                return 'Core Return - Audit Copy';
            }
            return 'Parts Invoice - Audit Copy';
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
    public Decimal partsGrossPercent {
        get {
            return percentOfSale(totalPartsSale, totalPartsSale - totalPartsCost);
        }
    }
    public Decimal miscGrossPercent {
        get {
            return percentOfSale(totalMiscSale, totalMiscSale - totalMiscCost);
        }
    }
    public Boolean isReturnInvoice {
        get {
            if (invoice == null || invoice.RecordType == null) {
                return false;
            }
            String developerName = invoice.RecordType.DeveloperName;
            return developerName == 'Vendor_Return' ||
                developerName == 'Counter_Return' ||
                developerName == 'Core_Return' ||
                developerName == 'Vendor_Core_Return';
        }
    }
    public Boolean showLineCoreColumn {
        get {
            return !isReturnInvoice ||
                (invoice != null &&
                    invoice.RecordType != null &&
                    (invoice.RecordType.DeveloperName == 'Core_Return' ||
                        invoice.RecordType.DeveloperName == 'Vendor_Core_Return'));
        }
    }
    public String lineQuantityLabel {
        get {
            return isReturnInvoice ? 'Qty Returned' : null;
        }
    }
    public String partyPrimaryLabel {
        get {
            return isVendorReturnInvoice ? 'Vendor' : null;
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
    public Boolean isRepairOrderInvoice {
        get {
            return invoice != null &&
                invoice.RecordType != null &&
                invoice.RecordType.DeveloperName == 'Repair_Order';
        }
    }
    public Decimal grossPercent {
        get {
            return percentOfSale(totalSale, totalGross);
        }
    }

    public List<String> serviceHoursLines {
        get {
            if (serviceHoursLoaded) {
                return serviceHoursLinesCache;
            }
            serviceHoursLinesCache = invoice == null ||
                invoice.dealer__Location__c == null
                ? new List<String>()
                : FixedOpsFormUtil.resolveServiceHoursLines(
                    invoice.dealer__Location__c
                );
            serviceHoursLoaded = true;
            return serviceHoursLinesCache;
        }
        private set;
    }
    public Boolean hasServiceHours {
        get {
            return serviceHoursLines != null && !serviceHoursLines.isEmpty();
        }
    }

    private Boolean serviceHoursLoaded = false;
    private List<String> serviceHoursLinesCache;

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
                    dealer__EPA_Number__c
                FROM dealer__Dealer_Location__c
                WHERE Id = :invoice.dealer__Location__c
                WITH USER_MODE
                LIMIT 1
            ];

            return locations.isEmpty()
                ? new dealer__Dealer_Location__c()
                : locations[0];
        }
        private set;
    }

    public FormPartsInvoiceAuditCopyExt(ApexPages.StandardController controller) {
        invoiceLineItems = new List<AuditLineWrapper>();
        cashLines = new List<CashLineWrapper>();
        glLines = new List<FixedOpsFormUtil.GlDetailLine>();
        invoice = new dealer__Parts_Invoice__c();
        totalDue = 0;
        totalPaid = 0;
        totalCoreCharges = 0;
        totalPartsCost = 0;
        totalPartsSale = 0;
        totalMiscCost = 0;
        totalMiscSale = 0;
        totalCost = 0;
        totalSale = 0;
        totalGross = 0;
        glTotal = 0;
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
                RecordType.Name,
                RecordType.DeveloperName,
                dealer__Invoice_Number__c,
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
                dealer__Parts_Price__c,
                dealer__TotalMiscCharges__c,
                dealer__Total_Tax__c,
                dealer__Sales_Tax_ID__c,
                dealer__TotalPayments__c,
                dealer__Deposit__c,
                dealer__Total_Invoice__c,
                dealer__TotalPartsCost__c,
                dealer__TotalOtherCost__c,
                dealer__Location__c,
                dealer__Service_Repair_Order__c,
                dealer__Service_Repair_Order__r.Name,
                dealer__Service_Repair_Order__r.dealer__RO_Number__c,
                dealer__Customer__c,
                dealer__Customer__r.IsPersonAccount,
                dealer__Customer__r.dealer__AccountNumberID__c,
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
        cashLines = buildCashLines(invoice.dealer__Cashiering__r);
        computePaymentTotals();
        invoiceLineItems = buildAuditLineWrappers(loadInvoiceLines(invoiceId));
        computeFinancialTotals(invoice, invoiceLineItems);
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

        glLines = FixedOpsFormUtil.resolveGlDetailLines(
            null,
            resolveGlReference(invoice)
        );
        glTotal = FixedOpsFormUtil.sumGlDetailAmounts(glLines);
    }

    /**
     * GL detail in DMS is keyed by Reference = PI&lt;Invoice#&gt; (e.g. PI1051).
     */
    @TestVisible
    private static String resolveGlReference(dealer__Parts_Invoice__c inv) {
        if (inv == null) {
            return null;
        }

        if (String.isNotBlank(inv.dealer__Invoice_Number__c)) {
            return formatPartsInvoiceGlReference(inv.dealer__Invoice_Number__c);
        }

        return formatPartsInvoiceGlReference(inv.Name);
    }

    @TestVisible
    private static String formatPartsInvoiceGlReference(String value) {
        if (String.isBlank(value)) {
            return null;
        }

        String trimmed = value.trim();
        if (trimmed.startsWithIgnoreCase('PI')) {
            return trimmed.toUpperCase();
        }

        String invoiceNumber = extractInvoiceNumber(trimmed);
        return String.isBlank(invoiceNumber) ? null : 'PI' + invoiceNumber;
    }

    @TestVisible
    private static String extractInvoiceNumber(String value) {
        if (String.isBlank(value)) {
            return null;
        }

        Integer lastHyphen = value.lastIndexOf('-');
        if (lastHyphen >= 0 && lastHyphen < value.length() - 1) {
            String suffix = value.substring(lastHyphen + 1).trim();
            if (suffix.isNumeric()) {
                return suffix;
            }
        }

        String digits = '';
        for (Integer i = value.length() - 1; i >= 0; i--) {
            String ch = value.substring(i, i + 1);
            if (ch.isNumeric()) {
                digits = ch + digits;
            } else if (String.isNotBlank(digits)) {
                break;
            }
        }

        return String.isBlank(digits) ? null : digits;
    }

    @TestVisible
    private List<dealer__Parts_Invoice_Line__c> loadInvoiceLines(Id invoiceId) {
        return [
            SELECT dealer__Quantity_Sold__c,
                dealer__QuantityReturned__c,
                dealer__Part_Number__c,
                dealer__Part_Description__c,
                dealer__Bin__c,
                dealer__Cost__c,
                dealer__Extended_Cost__c,
                dealer__Price__c,
                dealer__Extended_Price__c,
                dealer__Core__c,
                dealer__TotalCore__c,
                dealer__Total_Price__c,
                dealer__MiscellaneousChargeCode__c,
                dealer__Comment__c,
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
    private static List<AuditLineWrapper> buildAuditLineWrappers(
        List<dealer__Parts_Invoice_Line__c> lines
    ) {
        List<AuditLineWrapper> wrappers = new List<AuditLineWrapper>();
        if (lines == null || lines.isEmpty()) {
            return wrappers;
        }

        for (dealer__Parts_Invoice_Line__c line : lines) {
            wrappers.add(new AuditLineWrapper(line));
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
    private void computeFinancialTotals(
        dealer__Parts_Invoice__c inv,
        List<AuditLineWrapper> lines
    ) {
        Decimal lineCost = 0;
        Decimal lineSale = 0;
        Decimal lineCore = 0;

        if (lines != null) {
            for (AuditLineWrapper line : lines) {
                lineCost += zeroIfNull(line.extendedCost);
                lineSale += zeroIfNull(line.totalPrice);
                lineCore += zeroIfNull(line.totalCore);
            }
        }

        totalCoreCharges = lineCore;
        totalPartsCost = inv == null || inv.dealer__TotalPartsCost__c == null
            ? lineCost
            : inv.dealer__TotalPartsCost__c;
        totalPartsSale = inv == null || inv.dealer__Parts_Price__c == null
            ? lineSale - lineCore
            : inv.dealer__Parts_Price__c;
        totalMiscCost = inv == null ? 0 : zeroIfNull(inv.dealer__TotalOtherCost__c);
        totalMiscSale = inv == null ? 0 : zeroIfNull(inv.dealer__TotalMiscCharges__c);
        totalCost = totalPartsCost + totalMiscCost;
        totalSale = totalPartsSale + totalMiscSale + lineCore;
        totalGross = totalSale - totalCost;
    }

    @TestVisible
    private static Decimal percentOfSale(Decimal sale, Decimal gross) {
        if (sale == null || sale == 0) {
            return 0;
        }
        return (gross / sale) * 100;
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
    private void assignTestState(
        dealer__Parts_Invoice__c testInvoice,
        List<AuditLineWrapper> lines,
        List<CashLineWrapper> cash,
        Decimal due
    ) {
        invoice = testInvoice;
        invoiceLineItems = lines == null ? new List<AuditLineWrapper>() : lines;
        cashLines = cash == null ? new List<CashLineWrapper>() : cash;
        totalDue = due == null ? 0 : due;
        computePaymentTotals();
        computeFinancialTotals(testInvoice, invoiceLineItems);
        if (testInvoice != null) {
            applyShipToDetails();
        }
    }

    private static Decimal zeroIfNull(Decimal value) {
        return value == null ? 0 : value;
    }

    public class AuditLineWrapper {
        public Decimal quantity { get; private set; }
        public Decimal quantityReturned { get; private set; }
        public String partNumber { get; private set; }
        public String displayDescription { get; private set; }
        public String binDisplay { get; private set; }
        public Decimal unitCost { get; private set; }
        public Decimal extendedCost { get; private set; }
        public Decimal unitPrice { get; private set; }
        public Decimal extendedPrice { get; private set; }
        public Decimal totalCore { get; private set; }
        public Decimal totalPrice { get; private set; }
        public String lineComment { get; private set; }
        public String returnReferenceInvoiceName { get; private set; }
        public Boolean hasReturnReference { get; private set; }
        public List<String> serialNumbers { get; private set; }

        public AuditLineWrapper(dealer__Parts_Invoice_Line__c line) {
            quantity = line.dealer__Quantity_Sold__c;
            quantityReturned = line.dealer__QuantityReturned__c;
            partNumber = line.dealer__Part_Number__c;
            unitCost = line.dealer__Cost__c;
            extendedCost = line.dealer__Extended_Cost__c;
            unitPrice = line.dealer__Price__c;
            extendedPrice = line.dealer__Extended_Price__c;
            totalCore = zeroIfNull(line.dealer__TotalCore__c);
            totalPrice = line.dealer__Total_Price__c;
            lineComment = line.dealer__Comment__c;
            serialNumbers = new List<String>();

            displayDescription = FormPartsInvoiceExt.resolveLinePartDescription(line);
            binDisplay = resolveBinDisplay(
                line.dealer__Part__r == null ||
                    line.dealer__Part__r.dealer__BinLocation__r == null
                    ? null
                    : line.dealer__Part__r.dealer__BinLocation__r.Name,
                line.dealer__Bin__c
            );
            returnReferenceInvoiceName = resolveReturnReferenceInvoiceName(line);
            hasReturnReference = String.isNotBlank(returnReferenceInvoiceName);

            if (line.dealer__Parts_Ledgers__r != null) {
                for (
                    dealer__Parts_Ledger__c ledger : line.dealer__Parts_Ledgers__r
                ) {
                    if (String.isNotBlank(ledger.dealer__SerialNumber__c)) {
                        serialNumbers.add(ledger.dealer__SerialNumber__c);
                    }
                }
            }
        }

        private String resolveReturnReferenceInvoiceName(
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

        private String resolveBinDisplay(
            String binLocationName,
            String binField
        ) {
            if (String.isNotBlank(binLocationName)) {
                return binLocationName;
            }
            return binField;
        }
    }

    public class CashLineWrapper {
        public String paymentMethod { get; private set; }
        public Boolean isDeposit { get; private set; }
        public Date closeDate { get; private set; }
        public Decimal amount { get; private set; }
        public Decimal processingFee { get; private set; }
        public Decimal lineTotal { get; private set; }

        public CashLineWrapper(dealer__Cashering__c cash) {
            paymentMethod = cash.dealer__Payment_Method__c;
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
