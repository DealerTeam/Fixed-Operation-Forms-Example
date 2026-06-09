/**
 * Shared helpers for unmanaged fixed-ops Visualforce form extensions.
 */
public with sharing class FixedOpsFormUtil {
    public static final String DEFAULT_LOGO_ASSET_DEVELOPER_NAME = 'FormCompanyLogo';

    public class CustomerDetails {
        public String name;
        public String street;
        public String city;
        public String state;
        public String postalCode;
        public String phone;
        public String mobile;
        public String email;
    }

    public class RenderFormat {
        public String renderAs { get; private set; }
        public Boolean isPdf { get; private set; }

        public RenderFormat(Boolean defaultToPdf) {
            isPdf = parsePdfParameter(
                ApexPages.currentPage().getParameters().get('pdf'),
                defaultToPdf
            );
            renderAs = isPdf ? 'PDF' : null;
        }
    }

    public static CustomerDetails resolveCustomerDetails(Id repairOrderId) {
        if (repairOrderId == null) {
            return null;
        }

        List<dealer__Service_Repair_Order__c> orders = [
            SELECT dealer__Customer__r.Name,
                dealer__Customer__r.IsPersonAccount,
                dealer__Customer__r.Phone,
                dealer__Customer__r.PersonEmail,
                dealer__Customer__r.PersonMobilePhone,
                dealer__Customer__r.PersonMailingStreet,
                dealer__Customer__r.PersonMailingCity,
                dealer__Customer__r.PersonMailingState,
                dealer__Customer__r.PersonMailingPostalCode,
                dealer__Customer__r.BillingStreet,
                dealer__Customer__r.BillingCity,
                dealer__Customer__r.BillingState,
                dealer__Customer__r.BillingPostalCode
            FROM dealer__Service_Repair_Order__c
            WHERE Id = :repairOrderId
            WITH USER_MODE
            LIMIT 1
        ];

        if (orders.isEmpty() || orders[0].dealer__Customer__r == null) {
            return null;
        }

        return buildCustomerDetails(orders[0].dealer__Customer__r);
    }

    public static CustomerDetails resolveCustomerDetailsByAccountId(Id accountId) {
        if (accountId == null) {
            return null;
        }

        List<Account> accounts = [
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
            WHERE Id = :accountId
            WITH USER_MODE
            LIMIT 1
        ];

        if (accounts.isEmpty()) {
            return null;
        }

        return buildCustomerDetails(accounts[0]);
    }

    /**
     * Splits a list into fixed-size pages. Returns an empty list when source is
     * null/empty. When pageSize is null or non-positive, all items land on one page.
     */
    public static List<List<Object>> chunkList(List<Object> source, Integer pageSize) {
        List<List<Object>> pages = new List<List<Object>>();
        if (source == null || source.isEmpty()) {
            return pages;
        }

        Integer resolvedSize = (pageSize == null || pageSize <= 0)
            ? source.size()
            : pageSize;
        List<Object> currentPage = new List<Object>();

        for (Object item : source) {
            currentPage.add(item);
            if (currentPage.size() == resolvedSize) {
                pages.add(currentPage);
                currentPage = new List<Object>();
            }
        }

        if (!currentPage.isEmpty()) {
            pages.add(currentPage);
        }

        return pages;
    }

    public static String resolveLogoUrl(String assetDeveloperName) {
        if (String.isBlank(assetDeveloperName)) {
            return null;
        }

        List<ContentAsset> assets = [
            SELECT ContentDocumentId
            FROM ContentAsset
            WHERE DeveloperName = :assetDeveloperName
            WITH USER_MODE
            LIMIT 1
        ];

        if (assets.isEmpty()) {
            return null;
        }

        List<ContentVersion> versions = [
            SELECT Id
            FROM ContentVersion
            WHERE ContentDocumentId = :assets[0].ContentDocumentId
                AND IsLatest = true
            WITH USER_MODE
            LIMIT 1
        ];

        if (versions.isEmpty()) {
            return null;
        }

        return URL.getOrgDomainUrl().toExternalForm()
            + '/sfc/servlet.shepherd/version/download/'
            + versions[0].Id;
    }

    public static CustomerDetails buildCustomerDetails(Account customer) {
        CustomerDetails details = new CustomerDetails();
        details.name = customer.Name;
        details.phone = formatPhone(customer.Phone);

        if (customer.IsPersonAccount) {
            details.street = firstNonBlank(
                customer.PersonMailingStreet,
                customer.BillingStreet
            );
            details.city = firstNonBlank(
                customer.PersonMailingCity,
                customer.BillingCity
            );
            details.state = firstNonBlank(
                customer.PersonMailingState,
                customer.BillingState
            );
            details.postalCode = firstNonBlank(
                customer.PersonMailingPostalCode,
                customer.BillingPostalCode
            );
            details.mobile = formatPhone(customer.PersonMobilePhone);
            details.email = customer.PersonEmail;
        } else {
            details.street = customer.BillingStreet;
            details.city = customer.BillingCity;
            details.state = customer.BillingState;
            details.postalCode = customer.BillingPostalCode;
        }

        return details;
    }

    public static Boolean parsePdfParameter(String pdfParam, Boolean defaultToPdf) {
        if (String.isBlank(pdfParam)) {
            return defaultToPdf;
        }

        String normalized = pdfParam.trim().toLowerCase();
        if (normalized == 'true' || normalized == '1' || normalized == 'yes') {
            return true;
        }
        if (normalized == 'false' || normalized == '0' || normalized == 'no') {
            return false;
        }

        return defaultToPdf;
    }

    public static String firstNonBlank(String primaryValue, String fallbackValue) {
        return String.isNotBlank(primaryValue) ? primaryValue : fallbackValue;
    }

    /**
     * Formats common North American phone numbers for display. Numbers that
     * don't match a known digit-length are returned unchanged so international
     * or extension-bearing values are preserved.
     */
    public static String formatPhone(String value) {
        if (String.isBlank(value)) {
            return value;
        }

        String digits = value.replaceAll('[^0-9]', '');

        if (digits.length() == 11 && digits.startsWith('1')) {
            digits = digits.substring(1);
        }

        if (digits.length() == 10) {
            return '(' + digits.substring(0, 3) + ') '
                + digits.substring(3, 6) + '-' + digits.substring(6);
        }
        if (digits.length() == 7) {
            return digits.substring(0, 3) + '-' + digits.substring(3);
        }

        return value;
    }

    private static Map<String, String> currencySymbolMap = new Map<String, String>{
        'USD' => '$',
        'EUR' => '€',
        'GBP' => '£'
    };

    /**
     * Returns the currency symbol for the running user's default currency ISO code.
     */
    public static String symbol() {
        return getCurrencySymbol(UserInfo.getDefaultCurrency());
    }

    public static String resolveCurrencySymbol() {
        return symbol();
    }

    public static String resolveCurrencySymbolForIso(String isoCode) {
        return getCurrencySymbol(isoCode);
    }

    @TestVisible
    private static String getCurrencySymbol(String currencyCode) {
        if (String.isBlank(currencyCode)) {
            return '$';
        }

        String symbol = currencySymbolMap.get(currencyCode);
        return symbol != null ? symbol : currencyCode;
    }

    public static String resolvePrintedByName() {
        return UserInfo.getName();
    }

    public static String formatDateOnly(Date value) {
        return value == null ? null : value.format();
    }

    public static String formatDateOnly(Datetime value) {
        return value == null ? null : formatDateOnly(value.date());
    }

    public static String formatTodayDateOnly() {
        return formatDateOnly(Date.today());
    }

    public static String formatNowDateTime(String pattern) {
        String resolvedPattern = String.isBlank(pattern)
            ? 'MM/dd/yyyy HH:mm a'
            : pattern;
        return Datetime.now().format(resolvedPattern);
    }

    /**
     * Loads formatted service-hours lines for a dealer location from its linked
     * BusinessHours record.
     */
    public static List<String> resolveServiceHoursLines(Id dealerLocationId) {
        List<String> lines = new List<String>();
        if (dealerLocationId == null) {
            return lines;
        }

        List<dealer__Dealer_Location__c> locations = [
            SELECT dealer__Service_Hours__c
            FROM dealer__Dealer_Location__c
            WHERE Id = :dealerLocationId
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
    public static List<String> buildServiceHoursLines(BusinessHours bh) {
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

    @TestVisible
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

    /**
     * Loads posted General Ledger detail from dealer__GLDetail__x.
     * When journal is blank, matches on reference only (e.g. Parts Invoice PI1051).
     * When journal is provided, matches journal and reference (e.g. RepairOrders).
     * Queried in system mode; callout failures return an empty list so the rest
     * of the document still renders.
     */
    public static List<GlDetailLine> resolveGlDetailLines(
        String journal,
        String reference
    ) {
        List<GlDetailLine> lines = new List<GlDetailLine>();
        if (String.isBlank(reference) || Test.isRunningTest()) {
            return lines;
        }

        try {
            List<dealer__GLDetail__x> details = String.isBlank(journal)
                ? [
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
                    WHERE dealer__Reference__c = :reference
                    WITH SYSTEM_MODE
                    ORDER BY dealer__Account__c ASC
                ]
                : [
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
                    WHERE dealer__Journal__c = :journal
                        AND dealer__Reference__c = :reference
                    WITH SYSTEM_MODE
                    ORDER BY dealer__Account__c ASC
                ];

            for (dealer__GLDetail__x detail : details) {
                lines.add(new GlDetailLine(detail));
            }
        } catch (Exception e) {
            // External data source unavailable; render the rest of the page.
        }

        return lines;
    }

    public static Decimal sumGlDetailAmounts(List<GlDetailLine> lines) {
        Decimal total = 0;
        if (lines == null) {
            return total;
        }

        for (GlDetailLine line : lines) {
            total += line.amount == null ? 0 : line.amount;
        }

        return total;
    }

    public class GlDetailLine {
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

        public GlDetailLine(dealer__GLDetail__x detail) {
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
