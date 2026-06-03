@IsTest
private class FixedOpsFormUtilTest {
    private static final String PERSON_ACCOUNT_RT = 'PersonAccount';
    private static final String BUSINESS_ACCOUNT_RT = 'Business_Account';

    @IsTest
    static void parsePdfParameterHandlesCommonValues() {
        System.assertEquals(true, FixedOpsFormUtil.parsePdfParameter(null, true));
        System.assertEquals(true, FixedOpsFormUtil.parsePdfParameter('', true));
        System.assertEquals(true, FixedOpsFormUtil.parsePdfParameter('1', false));
        System.assertEquals(true, FixedOpsFormUtil.parsePdfParameter('yes', false));
        System.assertEquals(false, FixedOpsFormUtil.parsePdfParameter('false', true));
        System.assertEquals(false, FixedOpsFormUtil.parsePdfParameter('0', true));
        System.assertEquals(false, FixedOpsFormUtil.parsePdfParameter('no', true));
        System.assertEquals(true, FixedOpsFormUtil.parsePdfParameter('maybe', true));
    }

    @IsTest
    static void resolveLogoUrlReturnsNullForBlankName() {
        System.assertEquals(null, FixedOpsFormUtil.resolveLogoUrl(null));
        System.assertEquals(null, FixedOpsFormUtil.resolveLogoUrl(''));
    }

    @IsTest
    static void getCurrencySymbolMapsKnownIsoCodes() {
        System.assertEquals('$', FixedOpsFormUtil.getCurrencySymbol('USD'));
        System.assertEquals('€', FixedOpsFormUtil.getCurrencySymbol('EUR'));
        System.assertEquals('£', FixedOpsFormUtil.getCurrencySymbol('GBP'));
        System.assertEquals('XYZ', FixedOpsFormUtil.getCurrencySymbol('XYZ'));
        System.assertEquals('$', FixedOpsFormUtil.getCurrencySymbol(null));
    }

    @IsTest
    static void symbolReturnsNonBlankValue() {
        System.assert(String.isNotBlank(FixedOpsFormUtil.symbol()));
        System.assertEquals(
            FixedOpsFormUtil.symbol(),
            FixedOpsFormUtil.resolveCurrencySymbol()
        );
    }

    @IsTest
    static void resolvePrintedByNameReturnsCurrentUserName() {
        System.assertEquals(
            UserInfo.getName(),
            FixedOpsFormUtil.resolvePrintedByName()
        );
    }

    @IsTest
    static void formatDateOnlyHandlesNullAndValues() {
        System.assertEquals(null, FixedOpsFormUtil.formatDateOnly((Date)null));
        System.assertEquals(null, FixedOpsFormUtil.formatDateOnly((Datetime)null));

        Date sampleDate = Date.newInstance(2026, 6, 1);
        System.assertEquals(
            sampleDate.format(),
            FixedOpsFormUtil.formatDateOnly(sampleDate)
        );
        System.assertEquals(
            sampleDate.format(),
            FixedOpsFormUtil.formatDateOnly(
                Datetime.newInstance(2026, 6, 1, 10, 30, 0)
            )
        );
    }

    @IsTest
    static void formatTodayDateOnlyMatchesToday() {
        System.assertEquals(
            Date.today().format(),
            FixedOpsFormUtil.formatTodayDateOnly()
        );
    }

    @IsTest
    static void formatNowDateTimeUsesDefaultPattern() {
        String formatted = FixedOpsFormUtil.formatNowDateTime(null);
        System.assertNotEquals(null, formatted);
        System.assert(formatted.contains('/'));
    }

    @IsTest
    static void resolveCustomerDetailsReturnsNullWithoutRepairOrderId() {
        System.assertEquals(null, FixedOpsFormUtil.resolveCustomerDetails(null));
    }

    @IsTest
    static void buildCustomerDetailsUsesPersonAccountFields() {
        Account personAccount = buildPersonAccount('Jane', 'Customer');
        personAccount.Phone = '555-111-2222';
        personAccount.PersonEmail = 'jane@example.com';
        personAccount.PersonMobilePhone = '555-333-4444';
        personAccount.PersonMailingStreet = '123 Main St';
        personAccount.PersonMailingCity = 'Denver';
        personAccount.PersonMailingState = 'CO';
        personAccount.PersonMailingPostalCode = '80202';
        insert personAccount;

        Account insertedAccount = queryCustomerAccount(personAccount.Id);
        FixedOpsFormUtil.CustomerDetails details =
            FixedOpsFormUtil.buildCustomerDetails(insertedAccount);

        System.assertEquals(true, insertedAccount.IsPersonAccount);
        System.assertEquals('Jane Customer', details.name);
        System.assertEquals('123 Main St', details.street);
        System.assertEquals('Denver', details.city);
        System.assertEquals('CO', details.state);
        System.assertEquals('80202', details.postalCode);
        System.assertEquals('555-111-2222', details.phone);
        System.assertEquals('555-333-4444', details.mobile);
        System.assertEquals('jane@example.com', details.email);
    }

    @IsTest
    static void buildCustomerDetailsFallsBackToBillingAddressForPersonAccount() {
        Account personAccount = buildPersonAccount('Jane', 'Customer');
        personAccount.BillingStreet = '456 Oak Ave';
        personAccount.BillingCity = 'Boulder';
        personAccount.BillingState = 'CO';
        personAccount.BillingPostalCode = '80301';
        insert personAccount;

        Account insertedAccount = queryCustomerAccount(personAccount.Id);
        FixedOpsFormUtil.CustomerDetails details =
            FixedOpsFormUtil.buildCustomerDetails(insertedAccount);

        System.assertEquals(true, insertedAccount.IsPersonAccount);
        System.assertEquals('456 Oak Ave', details.street);
        System.assertEquals('Boulder', details.city);
        System.assertEquals('CO', details.state);
        System.assertEquals('80301', details.postalCode);
    }

    @IsTest
    static void buildCustomerDetailsUsesBillingAddressForBusinessAccount() {
        Account businessAccount = new Account(
            RecordTypeId = getAccountRecordTypeId(BUSINESS_ACCOUNT_RT),
            Name = 'Fleet Services LLC',
            Phone = '555-999-0000',
            BillingStreet = '789 Commerce Dr',
            BillingCity = 'Austin',
            BillingState = 'TX',
            BillingPostalCode = '78701'
        );
        insert businessAccount;

        Account insertedAccount = queryCustomerAccount(businessAccount.Id);
        FixedOpsFormUtil.CustomerDetails details =
            FixedOpsFormUtil.buildCustomerDetails(insertedAccount);

        System.assertEquals(false, insertedAccount.IsPersonAccount);
        System.assertEquals('Fleet Services LLC', details.name);
        System.assertEquals('789 Commerce Dr', details.street);
        System.assertEquals('Austin', details.city);
        System.assertEquals('TX', details.state);
        System.assertEquals('78701', details.postalCode);
        System.assertEquals('555-999-0000', details.phone);
        System.assertEquals(null, details.mobile);
        System.assertEquals(null, details.email);
    }

    private static Account buildPersonAccount(String firstName, String lastName) {
        return new Account(
            RecordTypeId = getAccountRecordTypeId(PERSON_ACCOUNT_RT),
            FirstName = firstName,
            LastName = lastName
        );
    }

    private static Id getAccountRecordTypeId(String developerName) {
        return Schema.SObjectType.Account.getRecordTypeInfosByDeveloperName()
            .get(developerName)
            .getRecordTypeId();
    }

    private static Account queryCustomerAccount(Id accountId) {
        return [
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
            LIMIT 1
        ];
    }
}
