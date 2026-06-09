/**
 * Unmanaged extension for form_ServiceRepairOrderAuditCopy.
 *
 * Renders an internal "Audit Copy" of a Service Repair Order. Unlike the
 * customer copy, the audit copy is intended for dealership employees: it exposes
 * both cost and price for every line across all pay types (Customer / Warranty /
 * Internal), the full sublet purchase order detail tied to each job line, a gross
 * profit summary, and the posted General Ledger entries sourced from the
 * dealer__GLDetail__x external object.
 */
public with sharing class FormServiceRepairOrderAuditCopyExt {
    private static final String GL_JOURNAL_REPAIR_ORDERS = 'RepairOrders';

    public dealer__Service_Repair_Order__c ro { get; private set; }
    public List<JobWrapper> jobs { get; private set; }
    public List<CashLineWrapper> cashLines { get; private set; }
    public List<dealer__Service_Contract__c> serviceContracts { get; private set; }
    public List<GLLineWrapper> glLines { get; private set; }

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

    // Charges breakdown by pay type (sale amounts) sourced from RO rollups.
    public Decimal customerLabor { get; private set; }
    public Decimal warrantyLabor { get; private set; }
    public Decimal internalLabor { get; private set; }
    public Decimal customerParts { get; private set; }
    public Decimal warrantyParts { get; private set; }
    public Decimal internalParts { get; private set; }
    public Decimal customerMisc { get; private set; }
    public Decimal warrantyMisc { get; private set; }
    public Decimal internalMisc { get; private set; }
    public Decimal customerSublet { get; private set; }
    public Decimal warrantySublet { get; private set; }
    public Decimal internalSublet { get; private set; }
    public Decimal customerCharges { get; private set; }
    public Decimal warrantyCharges { get; private set; }
    public Decimal internalCharges { get; private set; }

    public Decimal totalLaborSale { get; private set; }
    public Decimal totalPartsSale { get; private set; }
    public Decimal totalMiscSale { get; private set; }
    public Decimal totalSubletSale { get; private set; }

    public Decimal discountTotal { get; private set; }
    public Decimal tax { get; private set; }
    public Decimal invoiceTotal { get; private set; }
    public Decimal customerInvoiceTotal { get; private set; }
    public Decimal deposit { get; private set; }
    public Decimal totalPayments { get; private set; }
    public Decimal totalDue { get; private set; }
    public Decimal totalPaid { get; private set; }

    // Gross profit summary (aggregated from job lines).
    public Decimal totalLaborCost { get; private set; }
    public Decimal totalPartsCost { get; private set; }
    public Decimal totalMiscCost { get; private set; }
    public Decimal totalSubletCost { get; private set; }
    public Decimal totalCost { get; private set; }
    public Decimal totalSale { get; private set; }
    public Decimal totalGross { get; private set; }

    // Gross profit broken out by pay type (Customer / Warranty / Internal).
    public List<GpTable> grossByPayType { get; private set; }

    public Decimal glTotal { get; private set; }

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
    public Boolean hasGlLines {
        get {
            return glLines != null && !glLines.isEmpty();
        }
    }
    public Decimal grossPercent {
        get {
            if (totalSale == null || totalSale == 0) {
                return 0;
            }
            return (totalGross / totalSale) * 100;
        }
    }

    private Decimal grossPct(Decimal sale, Decimal cost) {
        if (sale == null || sale == 0) {
            return 0;
        }
        Decimal c = (cost == null) ? 0 : cost;
        return ((sale - c) / sale) * 100;
    }
    public Decimal laborGrossPercent { get { return grossPct(totalLaborSale, totalLaborCost); } }
    public Decimal partsGrossPercent { get { return grossPct(totalPartsSale, totalPartsCost); } }
    public Decimal miscGrossPercent { get { return grossPct(totalMiscSale, totalMiscCost); } }
    public Decimal subletGrossPercent { get { return grossPct(totalSubletSale, totalSubletCost); } }

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

    public FormServiceRepairOrderAuditCopyExt(
        ApexPages.StandardController controller
    ) {
        jobs = new List<JobWrapper>();
        cashLines = new List<CashLineWrapper>();
        serviceContracts = new List<dealer__Service_Contract__c>();
        glLines = new List<GLLineWrapper>();

        customerLabor = 0;
        warrantyLabor = 0;
        internalLabor = 0;
        customerParts = 0;
        warrantyParts = 0;
        internalParts = 0;
        customerMisc = 0;
        warrantyMisc = 0;
        internalMisc = 0;
        customerSublet = 0;
        warrantySublet = 0;
        internalSublet = 0;
        customerCharges = 0;
        warrantyCharges = 0;
        internalCharges = 0;
        totalLaborSale = 0;
        totalPartsSale = 0;
        totalMiscSale = 0;
        totalSubletSale = 0;
        discountTotal = 0;
        tax = 0;
        invoiceTotal = 0;
        customerInvoiceTotal = 0;
        deposit = 0;
        totalPayments = 0;
        totalDue = 0;
        totalPaid = 0;
        totalLaborCost = 0;
        totalPartsCost = 0;
        totalMiscCost = 0;
        totalSubletCost = 0;
        totalCost = 0;
        totalSale = 0;
        totalGross = 0;
        grossByPayType = new List<GpTable>();
        glTotal = 0;
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
                dealer__Warranty_Labor_Charges__c,
                dealer__Internal_Labor_Charges__c,
                dealer__Customer_Parts_Charges__c,
                dealer__Warranty_Parts_Charges__c,
                dealer__Internal_Parts_Charges__c,
                dealer__Customer_Misc_Charges__c,
                dealer__Warranty_Misc_Charges__c,
                dealer__Internal_Misc_Charges__c,
                dealer__Total_Misc_Charges__c,
                dealer__Customer_Sublet_Charges__c,
                dealer__WarrantySubletCharges__c,
                dealer__Internal_Sublet_Charges__c,
                dealer__Customer_Charges__c,
                dealer__Warranty_Charges__c,
                dealer__Internal_Charges__c,
                dealer__Customer_Invoice_Total__c,
                dealer__Total_Repair_Order_Charges__c,
                dealer__Parts_Cost__c,
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
        computeTotals(ro, cashLines, jobs);
        glLines = loadGlLines(ro.dealer__RO_Number__c);
        glTotal = sumGlAmount(glLines);
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

    /**
     * Loads posted General Ledger detail for the repair order from the
     * dealer__GLDetail__x external object. Queried in system mode because the
     * external object is read through an OData connection and FLS does not apply.
     * Any callout failure (e.g. unreachable data source) is swallowed so the rest
     * of the document still renders.
     */
    @TestVisible
    private List<GLLineWrapper> loadGlLines(String roNumber) {
        List<GLLineWrapper> wrappers = new List<GLLineWrapper>();
        if (String.isBlank(roNumber) || Test.isRunningTest()) {
            return wrappers;
        }

        try {
            List<dealer__GLDetail__x> details = [
                SELECT Id,
                    dealer__Account__c,
                    dealer__AccountName__c,
                    dealer__Amount__c,
                    dealer__ControlNumber__c,
                    dealer__Journal__c,
                    dealer__PostingDescription__c,
                    dealer__PostingDate__c,
                    dealer__AccountingDate__c,
                    dealer__ReferenceDate__c,
                    dealer__ReversalDate__c,
                    dealer__Reference__c,
                    dealer__SaleType__c,
                    dealer__Tax__c,
                    dealer__CompanyNumber__c
                FROM dealer__GLDetail__x
                WHERE dealer__Journal__c = :GL_JOURNAL_REPAIR_ORDERS
                    AND dealer__Reference__c = :roNumber
                WITH SYSTEM_MODE
                ORDER BY dealer__Account__c ASC
            ];

            for (dealer__GLDetail__x detail : details) {
                wrappers.add(new GLLineWrapper(detail));
            }
        } catch (Exception e) {
            // External data source unavailable; render the rest of the page.
        }

        return wrappers;
    }

    @TestVisible
    private static Decimal sumGlAmount(List<GLLineWrapper> lines) {
        Decimal total = 0;
        if (lines == null) {
            return total;
        }
        for (GLLineWrapper line : lines) {
            total += zeroIfNull(line.amount);
        }
        return total;
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
        List<CashLineWrapper> lines,
        List<JobWrapper> jobWrappers
    ) {
        if (order != null) {
            customerLabor = zeroIfNull(order.dealer__Customer_Labor_Charges__c);
            warrantyLabor = zeroIfNull(order.dealer__Warranty_Labor_Charges__c);
            internalLabor = zeroIfNull(order.dealer__Internal_Labor_Charges__c);
            customerParts = zeroIfNull(order.dealer__Customer_Parts_Charges__c);
            warrantyParts = zeroIfNull(order.dealer__Warranty_Parts_Charges__c);
            internalParts = zeroIfNull(order.dealer__Internal_Parts_Charges__c);
            customerMisc = zeroIfNull(order.dealer__Customer_Misc_Charges__c);
            warrantyMisc = zeroIfNull(order.dealer__Warranty_Misc_Charges__c);
            internalMisc = zeroIfNull(order.dealer__Internal_Misc_Charges__c);
            customerSublet = zeroIfNull(order.dealer__Customer_Sublet_Charges__c);
            warrantySublet = zeroIfNull(order.dealer__WarrantySubletCharges__c);
            internalSublet = zeroIfNull(order.dealer__Internal_Sublet_Charges__c);
            customerCharges = zeroIfNull(order.dealer__Customer_Charges__c);
            warrantyCharges = zeroIfNull(order.dealer__Warranty_Charges__c);
            internalCharges = zeroIfNull(order.dealer__Internal_Charges__c);

            totalLaborSale = customerLabor + warrantyLabor + internalLabor;
            totalPartsSale = customerParts + warrantyParts + internalParts;
            totalMiscSale = zeroIfNull(order.dealer__Total_Misc_Charges__c);
            totalSubletSale = customerSublet + warrantySublet + internalSublet;

            discountTotal = zeroIfNull(order.dealer__Discount_Total__c);
            tax = zeroIfNull(order.dealer__Tax__c);
            invoiceTotal = zeroIfNull(order.dealer__Total_Repair_Order_Charges__c);
            customerInvoiceTotal = zeroIfNull(
                order.dealer__Customer_Invoice_Total__c
            );
            deposit = zeroIfNull(order.dealer__Deposit__c);
            totalPayments = zeroIfNull(order.dealer__Payments_Total__c);
            totalDue = customerInvoiceTotal - totalPayments - deposit;
        }

        totalPaid = 0;
        if (lines != null) {
            for (CashLineWrapper line : lines) {
                totalPaid += zeroIfNull(line.lineTotal);
            }
        }

        totalLaborCost = 0;
        totalPartsCost = 0;
        totalMiscCost = 0;
        totalSubletCost = 0;
        totalSale = 0;

        // Cost buckets by pay type. Labor / misc / sublet follow the job's
        // pay type; parts follow each part line's individual pay type.
        Map<String, Decimal> laborCostByPt = newPayTypeMap();
        Map<String, Decimal> partsCostByPt = newPayTypeMap();
        Map<String, Decimal> miscCostByPt = newPayTypeMap();
        Map<String, Decimal> subletCostByPt = newPayTypeMap();

        if (jobWrappers != null) {
            for (JobWrapper job : jobWrappers) {
                totalLaborCost += zeroIfNull(job.laborCost);
                totalPartsCost += zeroIfNull(job.partsCost);
                totalMiscCost += zeroIfNull(job.miscCost);
                totalSubletCost += zeroIfNull(job.subletCost);
                totalSale += zeroIfNull(job.lineSale);

                String jobPt = payTypeKey(job.laborType);
                if (jobPt != null) {
                    laborCostByPt.put(jobPt, laborCostByPt.get(jobPt) + zeroIfNull(job.laborCost));
                    miscCostByPt.put(jobPt, miscCostByPt.get(jobPt) + zeroIfNull(job.miscCost));
                    subletCostByPt.put(jobPt, subletCostByPt.get(jobPt) + zeroIfNull(job.subletCost));
                }

                Decimal allocatedParts = 0;
                if (job.parts != null) {
                    for (PartWrapper part : job.parts) {
                        String partPt = payTypeKey(part.payType);
                        if (partPt == null) {
                            partPt = jobPt;
                        }
                        if (partPt != null) {
                            partsCostByPt.put(partPt, partsCostByPt.get(partPt) + zeroIfNull(part.extendedCost));
                            allocatedParts += zeroIfNull(part.extendedCost);
                        }
                    }
                }
                // Reconcile any rounding gap against the job's pay type so
                // the buckets still sum to the job parts cost.
                if (jobPt != null) {
                    Decimal gap = zeroIfNull(job.partsCost) - allocatedParts;
                    if (gap != 0) {
                        partsCostByPt.put(jobPt, partsCostByPt.get(jobPt) + gap);
                    }
                }
            }
        }
        totalCost = totalLaborCost + totalPartsCost + totalMiscCost + totalSubletCost;
        totalGross = totalSale - totalCost;

        grossByPayType = new List<GpTable>();
        grossByPayType.add(new GpTable('Customer', new List<GpRow>{
            new GpRow('Labor', laborCostByPt.get('C'), customerLabor),
            new GpRow('Parts', partsCostByPt.get('C'), customerParts),
            new GpRow('Misc', miscCostByPt.get('C'), customerMisc),
            new GpRow('Sublet', subletCostByPt.get('C'), customerSublet)
        }));
        grossByPayType.add(new GpTable('Warranty', new List<GpRow>{
            new GpRow('Labor', laborCostByPt.get('W'), warrantyLabor),
            new GpRow('Parts', partsCostByPt.get('W'), warrantyParts),
            new GpRow('Misc', miscCostByPt.get('W'), warrantyMisc),
            new GpRow('Sublet', subletCostByPt.get('W'), warrantySublet)
        }));
        grossByPayType.add(new GpTable('Internal', new List<GpRow>{
            new GpRow('Labor', laborCostByPt.get('I'), internalLabor),
            new GpRow('Parts', partsCostByPt.get('I'), internalParts),
            new GpRow('Misc', miscCostByPt.get('I'), internalMisc),
            new GpRow('Sublet', subletCostByPt.get('I'), internalSublet)
        }));
    }

    private static Map<String, Decimal> newPayTypeMap() {
        return new Map<String, Decimal>{ 'C' => 0, 'W' => 0, 'I' => 0 };
    }

    private static String payTypeKey(String value) {
        if (String.isBlank(value)) {
            return null;
        }
        String c = value.trim().toUpperCase().substring(0, 1);
        if (c == 'C' || c == 'W' || c == 'I') {
            return c;
        }
        return null;
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

    public class GpRow {
        public String label { get; private set; }
        public Decimal cost { get; private set; }
        public Decimal sale { get; private set; }

        public GpRow(String label, Decimal cost, Decimal sale) {
            this.label = label;
            this.cost = zeroIfNull(cost);
            this.sale = zeroIfNull(sale);
        }

        public Decimal gross {
            get {
                return sale - cost;
            }
        }
        public Decimal grossPercent {
            get {
                return (sale == 0) ? 0 : (gross / sale) * 100;
            }
        }
    }

    public class GpTable {
        public String title { get; private set; }
        public List<GpRow> rows { get; private set; }

        public GpTable(String title, List<GpRow> rows) {
            this.title = title;
            this.rows = (rows == null) ? new List<GpRow>() : rows;
        }

        public Decimal totalCost {
            get {
                Decimal t = 0;
                for (GpRow r : rows) {
                    t += r.cost;
                }
                return t;
            }
        }
        public Decimal totalSale {
            get {
                Decimal t = 0;
                for (GpRow r : rows) {
                    t += r.sale;
                }
                return t;
            }
        }
        public Decimal totalGross {
            get {
                return totalSale - totalCost;
            }
        }
        public Decimal totalGrossPercent {
            get {
                return (totalSale == 0) ? 0 : (totalGross / totalSale) * 100;
            }
        }
        public Boolean hasData {
            get {
                return totalSale != 0 || totalCost != 0;
            }
        }
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
        public Decimal lineDiscount { get; private set; }
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

            parts = new List<PartWrapper>();
            serialNumbers = new List<String>();
            miscCharges = new List<MiscWrapper>();
            sublets = new List<SubletWrapper>();

            if (job.dealer__Parts_Lines__r != null) {
                for (dealer__Parts_Invoice_Line__c part : job.dealer__Parts_Lines__r) {
                    parts.add(new PartWrapper(part));
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
                    miscCharges.add(new MiscWrapper(misc));
                }
            }

            if (job.dealer__Purchase_Order_Line__r != null) {
                for (
                    dealer__Purchase_Order_Line__c sublet : job.dealer__Purchase_Order_Line__r
                ) {
                    sublets.add(new SubletWrapper(sublet));
                }
            }

            laborSale = zeroIfNull(job.dealer__Labor_Charges__c);
            laborCost = zeroIfNull(job.dealer__Technician_Cost__c);
            laborGross = laborSale - laborCost;
            partsSale = zeroIfNull(job.dealer__Parts_Total__c);
            partsCost = zeroIfNull(job.dealer__Parts_Cost__c);
            miscSale = zeroIfNull(job.dealer__Misc_Charges__c);
            miscCost = zeroIfNull(job.dealer__MiscChargeCost__c);
            subletSale = zeroIfNull(job.dealer__Sublet_Total__c);
            subletCost = zeroIfNull(job.dealer__Sublet_Cost__c);
            lineDiscount = zeroIfNull(job.dealer__LineDiscountAmount__c);
            lineSale = zeroIfNull(job.dealer__Line_Total__c);
            lineCost = laborCost + partsCost + miscCost + subletCost;
            lineGross = lineSale - lineCost;
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
        public Decimal unitCost { get; private set; }
        public Decimal extendedCost { get; private set; }
        public Decimal unitPrice { get; private set; }
        public Decimal extendedPrice { get; private set; }

        public PartWrapper(dealer__Parts_Invoice_Line__c part) {
            quantitySold = part.dealer__Quantity_Sold__c;
            partNumber = part.dealer__Part_Number__c;
            partDescription = part.dealer__Part_Description__c;
            payType = part.dealer__Pay_Type__c;
            unitCost = zeroIfNull(part.dealer__Cost__c);
            extendedCost = zeroIfNull(part.dealer__Extended_Cost__c);
            unitPrice = zeroIfNull(part.dealer__Price__c);
            extendedPrice = zeroIfNull(part.dealer__Extended_Price__c);
        }
    }

    public class MiscWrapper {
        public String code { get; private set; }
        public String description { get; private set; }
        public Decimal cost { get; private set; }
        public Decimal amount { get; private set; }

        public MiscWrapper(dealer__Service_Misc_Charge__c misc) {
            code = misc.dealer__MiscChargeCode__r == null
                ? null
                : misc.dealer__MiscChargeCode__r.Name;
            description = misc.dealer__Description__c;
            cost = zeroIfNull(misc.dealer__Cost__c);
            amount = zeroIfNull(misc.dealer__Amount__c);
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

        public SubletWrapper(dealer__Purchase_Order_Line__c sublet) {
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
            cost = zeroIfNull(sublet.dealer__Cost__c) != 0
                ? sublet.dealer__Cost__c
                : zeroIfNull(sublet.dealer__Amount__c);
            price = zeroIfNull(sublet.dealer__Customer_Total__c);
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

    public class GLLineWrapper {
        public String account { get; private set; }
        public String accountName { get; private set; }
        public String controlNumber { get; private set; }
        public String journal { get; private set; }
        public String postingDescription { get; private set; }
        public String saleType { get; private set; }
        public String reference { get; private set; }
        public String companyNumber { get; private set; }
        public Decimal amount { get; private set; }
        public Decimal taxAmount { get; private set; }
        public Datetime accountingDate { get; private set; }
        public Datetime postingDate { get; private set; }
        public Datetime referenceDate { get; private set; }
        public Datetime reversalDate { get; private set; }

        public GLLineWrapper(dealer__GLDetail__x detail) {
            account = detail.dealer__Account__c;
            accountName = detail.dealer__AccountName__c;
            controlNumber = detail.dealer__ControlNumber__c;
            journal = detail.dealer__Journal__c;
            postingDescription = detail.dealer__PostingDescription__c;
            saleType = detail.dealer__SaleType__c;
            reference = detail.dealer__Reference__c;
            companyNumber = detail.dealer__CompanyNumber__c;
            amount = detail.dealer__Amount__c == null
                ? 0
                : detail.dealer__Amount__c;
            taxAmount = detail.dealer__Tax__c == null ? 0 : detail.dealer__Tax__c;
            accountingDate = detail.dealer__AccountingDate__c;
            postingDate = detail.dealer__PostingDate__c;
            referenceDate = detail.dealer__ReferenceDate__c;
            reversalDate = detail.dealer__ReversalDate__c;
        }
    }
}
