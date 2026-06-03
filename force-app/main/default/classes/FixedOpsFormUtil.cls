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
        details.phone = customer.Phone;

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
            details.mobile = customer.PersonMobilePhone;
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
}
