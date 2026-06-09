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
    static void buildServiceHoursLinesGroupsConsecutiveDays() {
        BusinessHours hours = new BusinessHours(
            MondayStartTime = Time.newInstance(7, 0, 0, 0),
            MondayEndTime = Time.newInstance(17, 0, 0, 0),
            TuesdayStartTime = Time.newInstance(7, 0, 0, 0),
            TuesdayEndTime = Time.newInstance(17, 0, 0, 0),
            WednesdayStartTime = Time.newInstance(7, 0, 0, 0),
            WednesdayEndTime = Time.newInstance(17, 0, 0, 0),
            ThursdayStartTime = Time.newInstance(7, 0, 0, 0),
            ThursdayEndTime = Time.newInstance(17, 0, 0, 0),
            FridayStartTime = Time.newInstance(7, 0, 0, 0),
            FridayEndTime = Time.newInstance(17, 0, 0, 0),
            SaturdayStartTime = Time.newInstance(8, 0, 0, 0),
            SaturdayEndTime = Time.newInstance(14, 0, 0, 0)
        );

        List<String> lines = FixedOpsFormUtil.buildServiceHoursLines(hours);

        System.assertEquals(2, lines.size());
        System.assertEquals('7:00 AM - 5:00 PM Monday - Friday', lines[0]);
        System.assertEquals('8:00 AM - 2:00 PM Saturday', lines[1]);
    }

    @IsTest
    static void resolveServiceHoursLinesReturnsEmptyWithoutLocationId() {
        System.assertEquals(0, FixedOpsFormUtil.resolveServiceHoursLines(null).size());
    }

    @IsTest
    static void resolveCustomerDetailsReturnsNullWithoutRepairOrderId() {
        System.assertEquals(null, FixedOpsFormUtil.resolveCustomerDetails(null));
    }

    @IsTest
    static void resolveCustomerDetailsByAccountIdReturnsNullWithoutAccountId() {
        System.assertEquals(
            null,
            FixedOpsFormUtil.resolveCustomerDetailsByAccountId(null)
        );
    }

    @IsTest
    static void resolveCustomerDetailsByAccountIdLoadsAccount() {
        Account businessAccount = new Account(
            RecordTypeId = getAccountRecordTypeId(BUSINESS_ACCOUNT_RT),
            Name = 'Parts Customer LLC',
            BillingStreet = '100 Parts Way',
            BillingCity = 'Denver',
            BillingState = 'CO',
            BillingPostalCode = '80202'
        );
        insert businessAccount;

        FixedOpsFormUtil.CustomerDetails details =
            FixedOpsFormUtil.resolveCustomerDetailsByAccountId(businessAccount.Id);

        System.assertEquals('Parts Customer LLC', details.name);
        System.assertEquals('100 Parts Way', details.street);
        System.assertEquals('Denver', details.city);
    }

    @IsTest
    static void chunkListHandlesEmptyNullAndPaging() {
        System.assertEquals(0, FixedOpsFormUtil.chunkList(null, 25).size());
        System.assertEquals(0, FixedOpsFormUtil.chunkList(new List<Object>(), 25).size());

        List<Object> items = new List<Object>{ 'a', 'b', 'c', 'd', 'e' };
        List<List<Object>> pages = FixedOpsFormUtil.chunkList(items, 2);

        System.assertEquals(3, pages.size());
        System.assertEquals(2, pages[0].size());
        System.assertEquals('a', pages[0][0]);
        System.assertEquals('b', pages[0][1]);
        System.assertEquals(1, pages[2].size());
        System.assertEquals('e', pages[2][0]);

        List<List<Object>> singlePage = FixedOpsFormUtil.chunkList(items, 0);
        System.assertEquals(1, singlePage.size());
        System.assertEquals(5, singlePage[0].size());
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
        System.assertEquals('(555) 111-2222', details.phone);
        System.assertEquals('(555) 333-4444', details.mobile);
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
        System.assertEquals('(555) 999-0000', details.phone);
        System.assertEquals(null, details.mobile);
        System.assertEquals(null, details.email);
    }

    @IsTest
    static void formatPhoneHandlesCommonFormats() {
        System.assertEquals(null, FixedOpsFormUtil.formatPhone(null));
        System.assertEquals('', FixedOpsFormUtil.formatPhone(''));
        System.assertEquals(
            '(555) 123-4567',
            FixedOpsFormUtil.formatPhone('5551234567')
        );
        System.assertEquals(
            '(555) 123-4567',
            FixedOpsFormUtil.formatPhone('555-123-4567')
        );
        System.assertEquals(
            '(555) 123-4567',
            FixedOpsFormUtil.formatPhone('1 (555) 123-4567')
        );
        System.assertEquals(
            '123-4567',
            FixedOpsFormUtil.formatPhone('1234567')
        );
        System.assertEquals(
            '+44 20 7946 0958',
            FixedOpsFormUtil.formatPhone('+44 20 7946 0958')
        );
    }

    @IsTest
    static void resolveGlDetailLinesReturnsEmptyForBlankInputOrDuringTests() {
        System.assertEquals(
            0,
            FixedOpsFormUtil.resolveGlDetailLines(null, null).size()
        );
        System.assertEquals(
            0,
            FixedOpsFormUtil.resolveGlDetailLines('RepairOrders', null).size()
        );
        System.assertEquals(
            0,
            FixedOpsFormUtil.resolveGlDetailLines(null, 'PI1005').size()
        );
        System.assertEquals(
            0,
            FixedOpsFormUtil.resolveGlDetailLines('RepairOrders', 'RO1005').size()
        );
    }

    @IsTest
    static void glDetailLineMapsExternalObjectFields() {
        dealer__GLDetail__x detail = (dealer__GLDetail__x) JSON.deserialize(
            '{' +
            '"dealer__Account__c":"1200",' +
            '"dealer__AccountName__c":"Parts Inventory",' +
            '"dealer__Amount__c":120.00,' +
            '"dealer__ControlNumber__c":"CUST-1",' +
            '"dealer__Journal__c":"PartsInvoices",' +
            '"dealer__PostingDescription__c":"Parts sale",' +
            '"dealer__SaleType__c":"Retail",' +
            '"dealer__Reference__c":"PI1005",' +
            '"dealer__CompanyNumber__c":"1",' +
            '"dealer__Tax__c":8.50,' +
            '"dealer__AccountingDate__c":"2026-06-01T00:00:00.000Z"' +
            '}',
            dealer__GLDetail__x.class
        );

        FixedOpsFormUtil.GlDetailLine line = new FixedOpsFormUtil.GlDetailLine(
            detail
        );

        System.assertEquals('1200', line.account);
        System.assertEquals('Parts Inventory', line.accountName);
        System.assertEquals(120.00, line.amount);
        System.assertEquals('Parts sale', line.postingDescription);
        System.assertEquals(8.50, line.taxAmount);
    }

    @IsTest
    static void sumGlDetailAmountsTotalsLinesAndHandlesNull() {
        dealer__GLDetail__x detail = (dealer__GLDetail__x) JSON.deserialize(
            '{"dealer__Amount__c":120.00}',
            dealer__GLDetail__x.class
        );
        FixedOpsFormUtil.GlDetailLine line = new FixedOpsFormUtil.GlDetailLine(
            detail
        );

        System.assertEquals(
            240.00,
            FixedOpsFormUtil.sumGlDetailAmounts(
                new List<FixedOpsFormUtil.GlDetailLine>{ line, line }
            )
        );
        System.assertEquals(0, FixedOpsFormUtil.sumGlDetailAmounts(null));
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
