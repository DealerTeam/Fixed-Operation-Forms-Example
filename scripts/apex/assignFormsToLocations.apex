/*
 * Register the unmanaged Fixed Ops Visualforce pages as DealerTeam Forms and
 * assign them to every Dealer Location.
 *
 * Idempotent / safe to re-run:
 *   - dealer__Form__c records are matched by Page Name and reused (not duplicated).
 *   - dealer__FormRef__c (Form <-> Location) links are created only where missing.
 *
 * Run with:
 *   sf apex run --file scripts/apex/assignFormsToLocations.apex --target-org <alias>
 *
 * To scope to one group only, delete the entries you don't want from the maps below.
 */

// 1) Forms to register, keyed by Visualforce page API name -> object the form prints from.
Map<String, String> objectByPage = new Map<String, String>{
    // --- Service Repair Order forms ---
    'form_ServiceRepairOrderCustomerCopy' => 'dealer__Service_Repair_Order__c',
    'form_ServiceTechnicianHardCard'      => 'dealer__Service_Repair_Order__c',
    // --- Purchase Order forms ---
    'form_PurchaseOrderVendorCopy'        => 'dealer__Purchase_Order__c',
    'form_PurchaseOrderAccountingCopy'    => 'dealer__Purchase_Order__c',
    // --- Parts Invoice forms ---
    'form_PartsInvoiceCopy'               => 'dealer__Parts_Invoice__c',
    'form_PartsInvoiceAuditCopy'          => 'dealer__Parts_Invoice__c',
    'form_PartsPickTicketCopy'            => 'dealer__Parts_Invoice__c'
};

Map<String, String> labelByPage = new Map<String, String>{
    'form_ServiceRepairOrderCustomerCopy' => 'Service Repair Order Customer Copy (Custom)',
    'form_ServiceTechnicianHardCard'      => 'Tech Card (Custom)',
    'form_PurchaseOrderVendorCopy'        => 'Purchase Order Vendor Copy (Custom)',
    'form_PurchaseOrderAccountingCopy'    => 'Purchase Order Accounting Copy (Custom)',
    'form_PartsInvoiceCopy'               => 'Parts Invoice (Custom)',
    'form_PartsInvoiceAuditCopy'          => 'Parts Invoice Audit Copy (Custom)',
    'form_PartsPickTicketCopy'            => 'Parts Pick Ticket (Custom)'
};

// 2) Ensure a dealer__Form__c exists for each page (Print Type = Laser for Visualforce).
Map<String, dealer__Form__c> formByPage = new Map<String, dealer__Form__c>();
for (dealer__Form__c f : [
    SELECT Id, dealer__Page_Name__c
    FROM dealer__Form__c
    WHERE dealer__Page_Name__c IN :objectByPage.keySet()
]) {
    formByPage.put(f.dealer__Page_Name__c, f);
}

List<dealer__Form__c> formsToUpsert = new List<dealer__Form__c>();
for (String page : objectByPage.keySet()) {
    dealer__Form__c f = formByPage.containsKey(page)
        ? formByPage.get(page)
        : new dealer__Form__c();
    f.Name = labelByPage.get(page);
    f.dealer__Page_Name__c = page;
    f.dealer__Print_Type__c = 'Laser';
    f.dealer__Based_on_Object__c = objectByPage.get(page);
    f.dealer__Active__c = true;
    formsToUpsert.add(f);
}
upsert formsToUpsert;
for (dealer__Form__c f : formsToUpsert) {
    formByPage.put(f.dealer__Page_Name__c, f);
}

// 3) Link every form to every Dealer Location via dealer__FormRef__c (skip existing pairs).
Set<Id> formIds = new Set<Id>();
for (dealer__Form__c f : formByPage.values()) {
    formIds.add(f.Id);
}

Set<String> existingPairs = new Set<String>();
for (dealer__FormRef__c r : [
    SELECT dealer__Form__c, dealer__Location__c
    FROM dealer__FormRef__c
    WHERE dealer__Form__c IN :formIds
]) {
    existingPairs.add(r.dealer__Form__c + '|' + r.dealer__Location__c);
}

List<dealer__FormRef__c> refsToInsert = new List<dealer__FormRef__c>();
for (dealer__Dealer_Location__c loc : [SELECT Id FROM dealer__Dealer_Location__c]) {
    for (Id formId : formIds) {
        if (!existingPairs.contains(formId + '|' + loc.Id)) {
            refsToInsert.add(new dealer__FormRef__c(
                dealer__Form__c = formId,
                dealer__Location__c = loc.Id
            ));
        }
    }
}
insert refsToInsert;

System.debug('Forms registered/ensured: ' + formIds.size());
System.debug('New location assignments created: ' + refsToInsert.size());
