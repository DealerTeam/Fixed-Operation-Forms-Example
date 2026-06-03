/**
 * Unmanaged extension for form_ServiceRepairOrderCustomerCopy.
 *
 * Reproduces the managed Service Repair Order customer invoice without relying
 * on the managed dealer.SROPrint controller. All data is queried directly so
 * the page can render as a self-contained, unmanaged Visualforce form.
 */
public with sharing class FormServiceRepairOrderCustomerCopyExt {
    private static final String CUSTOMER_PAY_CODE = 'C';

    public dealer__Service_Repair_Order__c ro { get; private set; }
    public List<JobWrapper> jobs { get; private set; }
    public List<CashLineWrapper> cashLines { get; private set; }
    public List<dealer__Service_Contract__c> serviceContracts { get; private set; }

    public String logoUrl { get; private set; }
    public Boolean hasLogo { get; private set; }
    public String currencyCode { get; private set; }
    public String printedByName { get; private set; }
    public String renderAs { get; private set; }
    public Boolean isPdf { get; private set; }
    public String printDateTime { get; private set; }
    public String invoiceDateTime { get; private set; }
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

    public Decimal totalLabor { get; private set; }
    public Decimal totalParts { get; private set; }
    public Decimal totalMisc { get; private set; }
    public Decimal totalSublet { get; private set; }
    public Decimal customerCharges { get; private set; }
    public Decimal discountTotal { get; private set; }
    public Decimal tax { get; private set; }
    public Decimal invoiceTotal { get; private set; }
    public Decimal deposit { get; private set; }
    public Decimal totalPayments { get; private set; }
    public Decimal totalDue { get; private set; }
    public Decimal totalPaid { get; private set; }

    public Boolean hasPayments {
        get {
            return cashLines != null && !cashLines.isEmpty();
        }
    }
    public Boolean hasDiscount {
        get {
            return discountTotal != null && discountTotal != 0;
        }
    }
    public Boolean hasDeposit {
        get {
            return deposit != null && deposit != 0;
        }
    }
    public Boolean hasComments {
        get {
            return ro != null && String.isNotBlank(ro.dealer__Comments__c);
        }
    }
    public Boolean hasServiceContracts {
        get {
            return serviceContracts != null && !serviceContracts.isEmpty();
        }
    }

    public dealer__Dealer_Location__c userLoc {
        get {
            if (ro == null || ro.dealer__Company__c == null) {
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
                    dealer__Email__c,
                    dealer__BAR_Number__c,
                    dealer__EPA_Number__c,
                    dealer__Service_Hours__c,
                    dealer__Service_RO_Disclaimer__c
                FROM dealer__Dealer_Location__c
                WHERE Id = :ro.dealer__Company__c
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

    private Boolean serviceHoursLoaded = false;
    private List<String> serviceHoursLinesCache;

    public List<String> serviceHoursLines {
        get {
            if (!serviceHoursLoaded) {
                serviceHoursLinesCache = loadServiceHoursLines();
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

    public FormServiceRepairOrderCustomerCopyExt(
        ApexPages.StandardController controller
    ) {
        jobs = new List<JobWrapper>();
        cashLines = new List<CashLineWrapper>();
        serviceContracts = new List<dealer__Service_Contract__c>();
        totalLabor = 0;
        totalParts = 0;
        totalMisc = 0;
        totalSublet = 0;
        customerCharges = 0;
        discountTotal = 0;
        tax = 0;
        invoiceTotal = 0;
        deposit = 0;
        totalPayments = 0;
        totalDue = 0;
        totalPaid = 0;
        ro = new dealer__Service_Repair_Order__c();

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

        Id repairOrderId = resolveRepairOrderId(controller);
        if (repairOrderId == null) {
            return;
        }

        loadRepairOrder(repairOrderId);
        applyCustomerDetails(
            FixedOpsFormUtil.resolveCustomerDetails(repairOrderId)
        );
    }

    @TestVisible
    private static Id resolveRepairOrderId(ApexPages.StandardController controller) {
        Id recordId = controller.getRecord().Id;
        if (recordId != null) {
            return recordId;
        }

        String pageId = ApexPages.currentPage().getParameters().get('id');
        return String.isBlank(pageId) ? null : pageId;
    }

    @TestVisible
    private void loadRepairOrder(Id repairOrderId) {
        List<dealer__Service_Repair_Order__c> orders = [
            SELECT Id,
                Name,
                CreatedDate,
                dealer__RO_Number__c,
                dealer__Company__c,
                dealer__Customer__c,
                dealer__Customer__r.dealer__AccountNumberID__c,
                dealer__Invoiced_Date_Time__c,
                dealer__Posted_Date_Time__c,
                dealer__Status__c,
                dealer__Mileage_In__c,
                dealer__Mileage_Out__c,
                dealer__Comments__c,
                dealer__Vehicle__c,
                dealer__Customer_Labor_Charges__c,
                dealer__Customer_Parts_Charges__c,
                dealer__Customer_Misc_Charges__c,
                dealer__Customer_Sublet_Charges__c,
                dealer__Customer_Charges__c,
                dealer__Customer_Invoice_Total__c,
                dealer__Discount_Total__c,
                dealer__Tax__c,
                dealer__Deposit__c,
                dealer__Payments_Total__c,
                dealer__Service_Advisor__r.Name,
                dealer__Vehicle__r.dealer__VIN__c,
                dealer__Vehicle__r.dealer__Year__c,
                dealer__Vehicle__r.dealer__Make__c,
                dealer__Vehicle__r.dealer__Carline__c,
                dealer__Vehicle__r.dealer__Vehicle_Description__c,
                dealer__Vehicle__r.dealer__Licence__c,
                dealer__Vehicle__r.dealer__Sale_Date__c,
                (
                    SELECT dealer__Payment_Method__c,
                        dealer__Payment_Type__c,
                        dealer__Deposit__c,
                        dealer__Close_Date__c,
                        dealer__Amount__c,
                        dealer__ProcessingFee__c
                    FROM dealer__Cashiering__r
                    ORDER BY dealer__Close_Date__c ASC
                )
            FROM dealer__Service_Repair_Order__c
            WHERE Id = :repairOrderId
            WITH USER_MODE
            LIMIT 1
        ];

        if (orders.isEmpty()) {
            return;
        }

        ro = orders[0];
        customerAccountNumber = ro.dealer__Customer__r == null
            ? null
            : ro.dealer__Customer__r.dealer__AccountNumberID__c;
        invoiceDateTime = ro.dealer__Invoiced_Date_Time__c == null
            ? null
            : ro.dealer__Invoiced_Date_Time__c.format('MM/dd/yyyy HH:mm a');

        jobs = buildJobWrappers(loadJobLines(repairOrderId));
        cashLines = buildCashLines(ro.dealer__Cashiering__r);
        serviceContracts = loadServiceContracts(ro.dealer__Vehicle__c);
        computeTotals(ro, cashLines);
    }

    private List<String> loadServiceHoursLines() {
        List<String> lines = new List<String>();
        if (ro == null || ro.dealer__Company__c == null) {
            return lines;
        }

        List<dealer__Dealer_Location__c> locations = [
            SELECT dealer__Service_Hours__c
            FROM dealer__Dealer_Location__c
            WHERE Id = :ro.dealer__Company__c
            WITH USER_MODE
            LIMIT 1
        ];

        if (locations.isEmpty() || locations[0].dealer__Service_Hours__c == null) {
            return lines;
        }

        Id businessHoursId = locations[0].dealer__Service_Hours__c;
        List<BusinessHours> hours = [
            SELECT MondayStartTime, MondayEndTime,
                TuesdayStartTime, TuesdayEndTime,
                WednesdayStartTime, WednesdayEndTime,
                ThursdayStartTime, ThursdayEndTime,
                FridayStartTime, FridayEndTime,
                SaturdayStartTime, SaturdayEndTime,
                SundayStartTime, SundayEndTime
            FROM BusinessHours
            WHERE Id = :businessHoursId
            LIMIT 1
        ];

        if (hours.isEmpty()) {
            return lines;
        }

        return buildServiceHoursLines(hours[0]);
    }

    /**
     * Collapses a BusinessHours record into lines such as
     * "7:00 AM - 5:00 PM Monday - Friday" and "8:00 AM - 2:00 PM Saturday",
     * grouping consecutive days that share the same open/close times. Closed
     * days (null start or end) break a group.
     */
    @TestVisible
    private static List<String> buildServiceHoursLines(BusinessHours bh) {
        List<String> segments = new List<String>();
        if (bh == null) {
            return segments;
        }

        List<String> dayLabels = new List<String>{
            'Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday',
            'Saturday', 'Sunday'
        };
        List<Time> starts = new List<Time>{
            bh.MondayStartTime, bh.TuesdayStartTime, bh.WednesdayStartTime,
            bh.ThursdayStartTime, bh.FridayStartTime, bh.SaturdayStartTime,
            bh.SundayStartTime
        };
        List<Time> ends = new List<Time>{
            bh.MondayEndTime, bh.TuesdayEndTime, bh.WednesdayEndTime,
            bh.ThursdayEndTime, bh.FridayEndTime, bh.SaturdayEndTime,
            bh.SundayEndTime
        };

        List<String> hoursByDay = new List<String>();
        for (Integer i = 0; i < 7; i++) {
            if (starts[i] == null || ends[i] == null) {
                hoursByDay.add(null);
            } else {
                hoursByDay.add(
                    formatTimeCompact(starts[i]) + ' - ' + formatTimeCompact(ends[i])
                );
            }
        }

        Integer groupStart = -1;
        for (Integer i = 0; i < 7; i++) {
            Boolean isOpen = hoursByDay[i] != null;
            Boolean continuesGroup = isOpen &&
                groupStart != -1 &&
                hoursByDay[i] == hoursByDay[groupStart];
            if (continuesGroup) {
                continue;
            }

            if (groupStart != -1) {
                segments.add(
                    formatServiceHoursSegment(dayLabels, hoursByDay, groupStart, i - 1)
                );
            }
            groupStart = isOpen ? i : -1;
        }
        if (groupStart != -1) {
            segments.add(
                formatServiceHoursSegment(dayLabels, hoursByDay, groupStart, 6)
            );
        }

        return segments;
    }

    private static String formatServiceHoursSegment(
        List<String> dayLabels,
        List<String> hoursByDay,
        Integer startIdx,
        Integer endIdx
    ) {
        String dayRange = startIdx == endIdx
            ? dayLabels[startIdx]
            : dayLabels[startIdx] + ' - ' + dayLabels[endIdx];
        return hoursByDay[startIdx] + ' ' + dayRange;
    }

    @TestVisible
    private static String formatTimeCompact(Time value) {
        if (value == null) {
            return '';
        }

        Integer hour24 = value.hour();
        Integer minute = value.minute();
        Integer hour12 = Math.mod(hour24, 12);
        if (hour12 == 0) {
            hour12 = 12;
        }

        String meridiem = hour24 < 12 ? 'AM' : 'PM';
        String minuteText = minute < 10
            ? '0' + String.valueOf(minute)
            : String.valueOf(minute);
        return String.valueOf(hour12) + ':' + minuteText + ' ' + meridiem;
    }

    @TestVisible
    private List<dealer__Service_Contract__c> loadServiceContracts(Id vehicleId) {
        if (vehicleId == null) {
            return new List<dealer__Service_Contract__c>();
        }

        return [
            SELECT dealer__Description__c,
                dealer__Type__c,
                dealer__Deductable__c,
                dealer__Expiration_Months__c,
                dealer__Expiration_Mileage__c,
                dealer__End_Date__c
            FROM dealer__Service_Contract__c
            WHERE dealer__Service_Vehicle__c = :vehicleId
            WITH USER_MODE
            ORDER BY dealer__End_Date__c DESC NULLS LAST
        ];
    }

    @TestVisible
    private List<dealer__Service_Job__c> loadJobLines(Id repairOrderId) {
        return [
            SELECT Id,
                dealer__Line_Number__c,
                dealer__Op_Code__c,
                dealer__Labor_Type__c,
                dealer__CustomerConcern__c,
                dealer__CauseExtended__c,
                dealer__Correction__c,
                dealer__Labor_Charges__c,
                dealer__Parts_Total__c,
                dealer__Misc_Charges__c,
                dealer__Sublet_Total__c,
                dealer__Line_Total__c,
                (
                    SELECT dealer__Quantity_Sold__c,
                        dealer__Part_Number__c,
                        dealer__Part_Description__c,
                        dealer__Price__c,
                        dealer__Extended_Price__c,
                        dealer__Pay_Type__c
                    FROM dealer__Parts_Lines__r
                ),
                (
                    SELECT dealer__SerialNumber__c
                    FROM dealer__Parts_Ledger_Entries__r
                    WHERE dealer__SerialNumber__c != NULL
                ),
                (
                    SELECT dealer__Description__c,
                        dealer__Amount__c,
                        dealer__MiscChargeCode__r.Name
                    FROM dealer__Service_Misc_Charge__r
                ),
                (
                    SELECT dealer__Description__c,
                        dealer__Customer_Total__c,
                        dealer__Purchase_Order__r.Name,
                        dealer__Purchase_Order__r.dealer__Vendor_Name__c
                    FROM dealer__Purchase_Order_Line__r
                    WHERE dealer__Customer_Total__c != NULL
                        AND dealer__Part__c = NULL
                )
            FROM dealer__Service_Job__c
            WHERE dealer__Service_Repair_Order__c = :repairOrderId
            WITH USER_MODE
            ORDER BY dealer__Line_Number__c ASC
        ];
    }

    @TestVisible
    private static List<JobWrapper> buildJobWrappers(
        List<dealer__Service_Job__c> jobLines
    ) {
        List<JobWrapper> wrappers = new List<JobWrapper>();
        if (jobLines == null || jobLines.isEmpty()) {
            return wrappers;
        }

        for (dealer__Service_Job__c job : jobLines) {
            wrappers.add(new JobWrapper(job));
        }

        return wrappers;
    }

    @TestVisible
    private static List<CashLineWrapper> buildCashLines(
        List<dealer__Cashering__c> cashering
    ) {
        List<CashLineWrapper> wrappers = new List<CashLineWrapper>();
        if (cashering == null || cashering.isEmpty()) {
            return wrappers;
        }

        for (dealer__Cashering__c cash : cashering) {
            wrappers.add(new CashLineWrapper(cash));
        }

        return wrappers;
    }

    @TestVisible
    private void computeTotals(
        dealer__Service_Repair_Order__c order,
        List<CashLineWrapper> lines
    ) {
        if (order == null) {
            return;
        }

        totalLabor = zeroIfNull(order.dealer__Customer_Labor_Charges__c);
        totalParts = zeroIfNull(order.dealer__Customer_Parts_Charges__c);
        totalMisc = zeroIfNull(order.dealer__Customer_Misc_Charges__c);
        totalSublet = zeroIfNull(order.dealer__Customer_Sublet_Charges__c);
        customerCharges = zeroIfNull(order.dealer__Customer_Charges__c);
        discountTotal = zeroIfNull(order.dealer__Discount_Total__c);
        tax = zeroIfNull(order.dealer__Tax__c);
        invoiceTotal = zeroIfNull(order.dealer__Customer_Invoice_Total__c);
        deposit = zeroIfNull(order.dealer__Deposit__c);
        totalPayments = zeroIfNull(order.dealer__Payments_Total__c);
        totalDue = invoiceTotal - totalPayments - deposit;

        totalPaid = 0;
        if (lines != null) {
            for (CashLineWrapper line : lines) {
                totalPaid += zeroIfNull(line.lineTotal);
            }
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

    private static Decimal zeroIfNull(Decimal value) {
        return value == null ? 0 : value;
    }

    @TestVisible
    private static Boolean isCustomerPayCode(String payTypeCode) {
        return payTypeCode == CUSTOMER_PAY_CODE;
    }

    public class JobWrapper {
        public Decimal lineNumber { get; private set; }
        public String opCode { get; private set; }
        public String laborType { get; private set; }
        public String customerConcern { get; private set; }
        public String causeExtended { get; private set; }
        public String correction { get; private set; }
        public Boolean isCustomerPay { get; private set; }

        public List<PartWrapper> parts { get; private set; }
        public List<String> serialNumbers { get; private set; }
        public List<MiscWrapper> miscCharges { get; private set; }
        public List<SubletWrapper> sublets { get; private set; }

        public Decimal laborDisplay { get; private set; }
        public Decimal partsSum { get; private set; }
        public Decimal miscDisplay { get; private set; }
        public Decimal subletDisplay { get; private set; }
        public Decimal lineTotalDisplay { get; private set; }

        public JobWrapper(dealer__Service_Job__c job) {
            lineNumber = job.dealer__Line_Number__c;
            opCode = job.dealer__Op_Code__c;
            laborType = job.dealer__Labor_Type__c;
            customerConcern = job.dealer__CustomerConcern__c;
            causeExtended = job.dealer__CauseExtended__c;
            correction = job.dealer__Correction__c;
            isCustomerPay = isCustomerPayCode(job.dealer__Labor_Type__c);

            parts = new List<PartWrapper>();
            serialNumbers = new List<String>();
            miscCharges = new List<MiscWrapper>();
            sublets = new List<SubletWrapper>();

            partsSum = 0;
            if (job.dealer__Parts_Lines__r != null) {
                for (dealer__Parts_Invoice_Line__c part : job.dealer__Parts_Lines__r) {
                    PartWrapper partWrapper = new PartWrapper(part, isCustomerPay);
                    parts.add(partWrapper);
                    partsSum += partWrapper.extendedDisplay;
                }
            }

            if (job.dealer__Parts_Ledger_Entries__r != null) {
                for (
                    dealer__Parts_Ledger__c ledger : job.dealer__Parts_Ledger_Entries__r
                ) {
                    if (String.isNotBlank(ledger.dealer__SerialNumber__c)) {
                        serialNumbers.add(ledger.dealer__SerialNumber__c);
                    }
                }
            }

            if (job.dealer__Service_Misc_Charge__r != null) {
                for (
                    dealer__Service_Misc_Charge__c misc : job.dealer__Service_Misc_Charge__r
                ) {
                    miscCharges.add(new MiscWrapper(misc, isCustomerPay));
                }
            }

            if (job.dealer__Purchase_Order_Line__r != null) {
                for (
                    dealer__Purchase_Order_Line__c sublet : job.dealer__Purchase_Order_Line__r
                ) {
                    sublets.add(new SubletWrapper(sublet, isCustomerPay));
                }
            }

            laborDisplay = customerPayValue(job.dealer__Labor_Charges__c);
            miscDisplay = customerPayValue(job.dealer__Misc_Charges__c);
            subletDisplay = customerPayValue(job.dealer__Sublet_Total__c);
            lineTotalDisplay = customerPayValue(job.dealer__Line_Total__c);
        }

        private Decimal customerPayValue(Decimal value) {
            if (!isCustomerPay || value == null) {
                return 0;
            }
            return value;
        }

        public Boolean hasParts {
            get {
                return !parts.isEmpty();
            }
        }
        public Boolean hasSerialNumbers {
            get {
                return !serialNumbers.isEmpty();
            }
        }
        public Boolean hasMisc {
            get {
                return !miscCharges.isEmpty();
            }
        }
        public Boolean hasSublet {
            get {
                return !sublets.isEmpty();
            }
        }
        public Boolean hasCause {
            get {
                return String.isNotBlank(causeExtended);
            }
        }
        public Boolean hasCorrection {
            get {
                return String.isNotBlank(correction);
            }
        }
    }

    public class PartWrapper {
        public Decimal quantitySold { get; private set; }
        public String partNumber { get; private set; }
        public String partDescription { get; private set; }
        public Decimal priceDisplay { get; private set; }
        public Decimal extendedDisplay { get; private set; }
        public Boolean isCustomerPay { get; private set; }

        public PartWrapper(
            dealer__Parts_Invoice_Line__c part,
            Boolean jobIsCustomerPay
        ) {
            quantitySold = part.dealer__Quantity_Sold__c;
            partNumber = part.dealer__Part_Number__c;
            partDescription = part.dealer__Part_Description__c;
            isCustomerPay = isCustomerPayCode(part.dealer__Pay_Type__c);

            priceDisplay = (jobIsCustomerPay && part.dealer__Price__c != null)
                ? part.dealer__Price__c
                : 0;
            extendedDisplay = (isCustomerPay && part.dealer__Extended_Price__c != null)
                ? part.dealer__Extended_Price__c
                : 0;
        }
    }

    public class MiscWrapper {
        public String code { get; private set; }
        public String description { get; private set; }
        public Decimal amountDisplay { get; private set; }

        public MiscWrapper(
            dealer__Service_Misc_Charge__c misc,
            Boolean jobIsCustomerPay
        ) {
            code = misc.dealer__MiscChargeCode__r == null
                ? null
                : misc.dealer__MiscChargeCode__r.Name;
            description = misc.dealer__Description__c;
            amountDisplay = (jobIsCustomerPay && misc.dealer__Amount__c != null)
                ? misc.dealer__Amount__c
                : 0;
        }
    }

    public class SubletWrapper {
        public String poNumber { get; private set; }
        public String vendorName { get; private set; }
        public String description { get; private set; }
        public Decimal customerTotalDisplay { get; private set; }

        public SubletWrapper(
            dealer__Purchase_Order_Line__c sublet,
            Boolean jobIsCustomerPay
        ) {
            poNumber = sublet.dealer__Purchase_Order__r == null
                ? null
                : sublet.dealer__Purchase_Order__r.Name;
            vendorName = sublet.dealer__Purchase_Order__r == null
                ? null
                : sublet.dealer__Purchase_Order__r.dealer__Vendor_Name__c;
            description = sublet.dealer__Description__c;
            customerTotalDisplay = (jobIsCustomerPay &&
                sublet.dealer__Customer_Total__c != null)
                ? sublet.dealer__Customer_Total__c
                : 0;
        }
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
