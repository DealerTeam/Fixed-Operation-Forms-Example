/**
 * Unmanaged extension for form_ServiceTechnicianHardCard.
 */
public with sharing class FormServiceTechnicianHardCardExt {
    private final dealer__Service_Repair_Order__c repairOrder;

    public String logoUrl { get; private set; }
    public Boolean hasLogo { get; private set; }
    public String renderAs { get; private set; }
    public Boolean isPdf { get; private set; }

    public String customerName { get; private set; }
    public String customerStreet { get; private set; }
    public String customerCity { get; private set; }
    public String customerState { get; private set; }
    public String customerPostalCode { get; private set; }
    public String customerPhone { get; private set; }
    public String customerMobile { get; private set; }
    public String customerEmail { get; private set; }

    public FormServiceTechnicianHardCardExt(ApexPages.StandardController controller) {
        repairOrder = (dealer__Service_Repair_Order__c)controller.getRecord();

        FixedOpsFormUtil.RenderFormat renderFormat = new FixedOpsFormUtil.RenderFormat(true);
        isPdf = renderFormat.isPdf;
        renderAs = renderFormat.renderAs;

        logoUrl = FixedOpsFormUtil.resolveLogoUrl(
            FixedOpsFormUtil.DEFAULT_LOGO_ASSET_DEVELOPER_NAME
        );
        hasLogo = String.isNotBlank(logoUrl);

        applyCustomerDetails(FixedOpsFormUtil.resolveCustomerDetails(repairOrder.Id));
    }

    public dealer__Service_Repair_Order__c getRepairOrder() {
        return repairOrder;
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
}
