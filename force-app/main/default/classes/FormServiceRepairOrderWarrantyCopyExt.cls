/**
 * Unmanaged extension for form_ServiceRepairOrderWarrantyCopy.
 *
 * Renders a "Warranty Copy" of a Service Repair Order for submission to the
 * warranty company. Like the Audit copy it exposes both cost and price for the
 * line detail, but values are only populated for Warranty (pay type "W") lines;
 * any Customer or Internal line is shown at $0 (mirroring how the Customer copy
 * zeroes out non-Customer lines). The General Ledger detail shown on the Audit
 * copy is intentionally omitted, and the header surfaces the Warranty Account
 * company information (sourced from dealer__Warranty_Account__c) along with the
 * warranty authorization, deductible, and comments.
 */
public with sharing class FormServiceRepairOrderWarrantyCopyExt {
    private static final String WARRANTY_PAY_CODE = 'W';

    public dealer__Service_Repair_Order__c ro { get; private set; }
    public List<JobWrapper> jobs { get; private set; }
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

    // Warranty company header (sourced from dealer__Warranty_Account__c).
    public String warrantyCompanyName { get; private set; }
    public String warrantyCompanyStreet { get; private set; }
    public String warrantyCompanyCity { get; private set; }
    public String warrantyCompanyState { get; private set; }
    public String warrantyCompanyPostalCode { get; private set; }
    public String warrantyCompanyPhone { get; private set; }
    public String warrantyAccountNumber { get; private set; }
    public String warrantyAuth { get; private set; }
    public Decimal warrantyDeductible { get; private set; }
    public String warrantyComments { get; private set; }

    // Warranty-only charge rollups sourced from the RO.
    public Decimal totalLabor { get; private set; }
    public Decimal totalParts { get; private set; }
    public Decimal totalMisc { get; private set; }
    public Decimal totalSublet { get; private set; }
    public Decimal warrantyCharges { get; private set; }

    public Boolean hasWarrantyAccount {
        get {
            return String.isNotBlank(warrantyCompanyName);
        }
    }
    public Boolean hasWarrantyComments {
        get {
            return String.isNotBlank(warrantyComments);
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

    public FormServiceRepairOrderWarrantyCopyExt(
        ApexPages.StandardController controller
    ) {
        jobs = new List<JobWrapper>();
        serviceContracts = new List<dealer__Service_Contract__c>();

        totalLabor = 0;
        totalParts = 0;
        totalMisc = 0;
        totalSublet = 0;
        warrantyCharges = 0;
        warrantyDeductible = 0;
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
                dealer__Warranty_Account__c,
                dealer__Warranty_Auth__c,
                dealer__Warranty_Deductible__c,
                dealer__Warranty_Comments__c,
                dealer__Warranty_Labor_Charges__c,
                dealer__Warranty_Parts_Charges__c,
                dealer__Warranty_Misc_Charges__c,
                dealer__WarrantySubletCharges__c,
                dealer__Warranty_Charges__c,
                dealer__Service_Advisor__r.Name,
                dealer__Vehicle__r.dealer__VIN__c,
                dealer__Vehicle__r.dealer__Year__c,
                dealer__Vehicle__r.dealer__Make__c,
                dealer__Vehicle__r.dealer__Carline__c,
                dealer__Vehicle__r.dealer__Vehicle_Description__c,
                dealer__Vehicle__r.dealer__Licence__c,
                dealer__Vehicle__r.dealer__Sale_Date__c
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

        warrantyAuth = ro.dealer__Warranty_Auth__c;
        warrantyComments = ro.dealer__Warranty_Comments__c;
        warrantyDeductible = zeroIfNull(ro.dealer__Warranty_Deductible__c);

        applyWarrantyAccount(loadWarrantyAccount(ro.dealer__Warranty_Account__c));

        jobs = buildJobWrappers(loadJobLines(repairOrderId));
        serviceContracts = loadServiceContracts(ro.dealer__Vehicle__c);
        computeTotals(ro);
    }

    @TestVisible
    private Account loadWarrantyAccount(Id warrantyAccountId) {
        if (warrantyAccountId == null) {
            return null;
        }

        List<Account> accounts = [
            SELECT Name,
                Phone,
                AccountNumber,
                BillingStreet,
                BillingCity,
                BillingState,
                BillingPostalCode
            FROM Account
            WHERE Id = :warrantyAccountId
            WITH USER_MODE
            LIMIT 1
        ];

        return accounts.isEmpty() ? null : accounts[0];
    }

    @TestVisible
    private void applyWarrantyAccount(Account warrantyAccount) {
        if (warrantyAccount == null) {
            return;
        }

        warrantyCompanyName = warrantyAccount.Name;
        warrantyCompanyPhone = warrantyAccount.Phone;
        warrantyAccountNumber = warrantyAccount.AccountNumber;
        warrantyCompanyStreet = warrantyAccount.BillingStreet;
        warrantyCompanyCity = warrantyAccount.BillingCity;
        warrantyCompanyState = warrantyAccount.BillingState;
        warrantyCompanyPostalCode = warrantyAccount.BillingPostalCode;
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
                dealer__Service_Type__c,
                dealer__CustomerConcern__c,
                dealer__CauseExtended__c,
                dealer__Correction__c,
                dealer__Technician__r.Name,
                dealer__Labor_Charges__c,
                dealer__Technician_Cost__c,
                dealer__Labor_Gross__c,
                dealer__Parts_Total__c,
                dealer__Parts_Cost__c,
                dealer__Misc_Charges__c,
                dealer__MiscChargeCost__c,
                dealer__Sublet_Total__c,
                dealer__Sublet_Cost__c,
                dealer__LineDiscountAmount__c,
                dealer__Line_Total__c,
                (
                    SELECT dealer__Quantity_Sold__c,
                        dealer__Part_Number__c,
                        dealer__Part_Description__c,
                        dealer__Cost__c,
                        dealer__Extended_Cost__c,
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
                        dealer__Cost__c,
                        dealer__MiscChargeCode__r.Name
                    FROM dealer__Service_Misc_Charge__r
                ),
                (
                    SELECT dealer__Description__c,
                        dealer__Customer_Total__c,
                        dealer__Cost__c,
                        dealer__Amount__c,
                        dealer__Purchase_Order__r.Name,
                        dealer__Purchase_Order__r.dealer__PO_Number__c,
                        dealer__Purchase_Order__r.dealer__Vendor_Name__c,
                        dealer__Purchase_Order__r.dealer__Status__c,
                        dealer__Purchase_Order__r.dealer__Invoice_Number__c,
                        dealer__Purchase_Order__r.dealer__Post_Date_Time__c
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
    private void computeTotals(dealer__Service_Repair_Order__c order) {
        if (order == null) {
            return;
        }

        totalLabor = zeroIfNull(order.dealer__Warranty_Labor_Charges__c);
        totalParts = zeroIfNull(order.dealer__Warranty_Parts_Charges__c);
        totalMisc = zeroIfNull(order.dealer__Warranty_Misc_Charges__c);
        totalSublet = zeroIfNull(order.dealer__WarrantySubletCharges__c);
        warrantyCharges = zeroIfNull(order.dealer__Warranty_Charges__c);
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
    private static Boolean isWarrantyPayCode(String payTypeCode) {
        return payTypeCode == WARRANTY_PAY_CODE;
    }

    public class JobWrapper {
        public Decimal lineNumber { get; private set; }
        public String opCode { get; private set; }
        public String laborType { get; private set; }
        public String serviceType { get; private set; }
        public String technicianName { get; private set; }
        public String customerConcern { get; private set; }
        public String causeExtended { get; private set; }
        public String correction { get; private set; }
        public Boolean isWarrantyPay { get; private set; }

        public List<PartWrapper> parts { get; private set; }
        public List<String> serialNumbers { get; private set; }
        public List<MiscWrapper> miscCharges { get; private set; }
        public List<SubletWrapper> sublets { get; private set; }

        public Decimal laborSale { get; private set; }
        public Decimal laborCost { get; private set; }
        public Decimal laborGross { get; private set; }
        public Decimal partsSale { get; private set; }
        public Decimal partsCost { get; private set; }
        public Decimal miscSale { get; private set; }
        public Decimal miscCost { get; private set; }
        public Decimal subletSale { get; private set; }
        public Decimal subletCost { get; private set; }
        public Decimal lineSale { get; private set; }
        public Decimal lineCost { get; private set; }
        public Decimal lineGross { get; private set; }

        public JobWrapper(dealer__Service_Job__c job) {
            lineNumber = job.dealer__Line_Number__c;
            opCode = job.dealer__Op_Code__c;
            laborType = job.dealer__Labor_Type__c;
            serviceType = job.dealer__Service_Type__c;
            technicianName = job.dealer__Technician__r == null
                ? null
                : job.dealer__Technician__r.Name;
            customerConcern = job.dealer__CustomerConcern__c;
            causeExtended = job.dealer__CauseExtended__c;
            correction = job.dealer__Correction__c;
            isWarrantyPay = isWarrantyPayCode(job.dealer__Labor_Type__c);

            parts = new List<PartWrapper>();
            serialNumbers = new List<String>();
            miscCharges = new List<MiscWrapper>();
            sublets = new List<SubletWrapper>();

            partsSale = 0;
            partsCost = 0;
            if (job.dealer__Parts_Lines__r != null) {
                for (dealer__Parts_Invoice_Line__c part : job.dealer__Parts_Lines__r) {
                    PartWrapper partWrapper = new PartWrapper(part);
                    parts.add(partWrapper);
                    partsSale += partWrapper.extendedPrice;
                    partsCost += partWrapper.extendedCost;
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
                    miscCharges.add(new MiscWrapper(misc, isWarrantyPay));
                }
            }

            if (job.dealer__Purchase_Order_Line__r != null) {
                for (
                    dealer__Purchase_Order_Line__c sublet : job.dealer__Purchase_Order_Line__r
                ) {
                    sublets.add(new SubletWrapper(sublet, isWarrantyPay));
                }
            }

            laborSale = warrantyValue(job.dealer__Labor_Charges__c);
            laborCost = warrantyValue(job.dealer__Technician_Cost__c);
            laborGross = laborSale - laborCost;
            miscSale = warrantyValue(job.dealer__Misc_Charges__c);
            miscCost = warrantyValue(job.dealer__MiscChargeCost__c);
            subletSale = warrantyValue(job.dealer__Sublet_Total__c);
            subletCost = warrantyValue(job.dealer__Sublet_Cost__c);
            lineSale = laborSale + partsSale + miscSale + subletSale;
            lineCost = laborCost + partsCost + miscCost + subletCost;
            lineGross = lineSale - lineCost;
        }

        private Decimal warrantyValue(Decimal value) {
            if (!isWarrantyPay || value == null) {
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
        public String payType { get; private set; }
        public Boolean isWarrantyPay { get; private set; }
        public Decimal unitCost { get; private set; }
        public Decimal extendedCost { get; private set; }
        public Decimal unitPrice { get; private set; }
        public Decimal extendedPrice { get; private set; }

        public PartWrapper(dealer__Parts_Invoice_Line__c part) {
            quantitySold = part.dealer__Quantity_Sold__c;
            partNumber = part.dealer__Part_Number__c;
            partDescription = part.dealer__Part_Description__c;
            payType = part.dealer__Pay_Type__c;
            isWarrantyPay = isWarrantyPayCode(part.dealer__Pay_Type__c);

            unitCost = warrantyValue(part.dealer__Cost__c);
            extendedCost = warrantyValue(part.dealer__Extended_Cost__c);
            unitPrice = warrantyValue(part.dealer__Price__c);
            extendedPrice = warrantyValue(part.dealer__Extended_Price__c);
        }

        private Decimal warrantyValue(Decimal value) {
            if (!isWarrantyPay || value == null) {
                return 0;
            }
            return value;
        }
    }

    public class MiscWrapper {
        public String code { get; private set; }
        public String description { get; private set; }
        public Decimal cost { get; private set; }
        public Decimal amount { get; private set; }

        public MiscWrapper(
            dealer__Service_Misc_Charge__c misc,
            Boolean jobIsWarrantyPay
        ) {
            code = misc.dealer__MiscChargeCode__r == null
                ? null
                : misc.dealer__MiscChargeCode__r.Name;
            description = misc.dealer__Description__c;
            cost = (jobIsWarrantyPay && misc.dealer__Cost__c != null)
                ? misc.dealer__Cost__c
                : 0;
            amount = (jobIsWarrantyPay && misc.dealer__Amount__c != null)
                ? misc.dealer__Amount__c
                : 0;
        }
    }

    public class SubletWrapper {
        public String poNumber { get; private set; }
        public String vendorName { get; private set; }
        public String description { get; private set; }
        public String poStatus { get; private set; }
        public String invoiceNumber { get; private set; }
        public Datetime postDateTime { get; private set; }
        public Decimal cost { get; private set; }
        public Decimal price { get; private set; }

        public SubletWrapper(
            dealer__Purchase_Order_Line__c sublet,
            Boolean jobIsWarrantyPay
        ) {
            dealer__Purchase_Order__c po = sublet.dealer__Purchase_Order__r;
            if (po != null) {
                poNumber = String.isNotBlank(po.dealer__PO_Number__c)
                    ? po.dealer__PO_Number__c
                    : po.Name;
                vendorName = po.dealer__Vendor_Name__c;
                poStatus = po.dealer__Status__c;
                invoiceNumber = po.dealer__Invoice_Number__c;
                postDateTime = po.dealer__Post_Date_Time__c;
            }
            description = sublet.dealer__Description__c;

            Decimal rawCost = zeroIfNull(sublet.dealer__Cost__c) != 0
                ? sublet.dealer__Cost__c
                : zeroIfNull(sublet.dealer__Amount__c);
            cost = jobIsWarrantyPay ? zeroIfNull(rawCost) : 0;
            price = (jobIsWarrantyPay && sublet.dealer__Customer_Total__c != null)
                ? sublet.dealer__Customer_Total__c
                : 0;
        }
    }
}
