/*
 * Register the unmanaged Fixed Ops Visualforce pages as DealerTeam Forms and
 * assign them to every Dealer Location.
 *
 * The print is invoked from a managed (dealer) component, so the Page Name must
 * carry the local namespace prefix: c__form_... . This script deletes any
 * existing dealer__Form__c records for these pages (prefixed or not, along with
 * their dealer__FormRef__c location assignments) and reinserts them with the
 * c__ prefix.
 *
 * Safe to re-run: each run replaces the form records and rebuilds the
 * location assignments from scratch.
 *
 * Run with:
 *   sf apex run --file scripts/apex/assignFormsToLocations.apex --target-org <alias>
 *
 * To scope to one group only, delete the entries you don't want from the maps below.
 */

// Prefix required because the print is called from a managed component;
// unprefixed page names would resolve inside the dealer namespace.
final String PAGE_PREFIX = 'c__';

// 1) Forms to register, keyed by Visualforce page API name -> object the form prints from.
Map<String, String> objectByPage = new Map<String, String>{
    // --- Service Repair Order forms ---
    'form_ServiceRepairOrderCustomerCopy' => 'dealer__Service_Repair_Order__c',
    'form_ServiceRepairOrderAuditCopy'    => 'dealer__Service_Repair_Order__c',
    'form_ServiceRepairOrderWarrantyCopy' => 'dealer__Service_Repair_Order__c',
    'form_ServiceTechnicianHardCard'      => 'dealer__Service_Repair_Order__c',
    // --- Purchase Order forms ---
    'form_PurchaseOrderVendorCopy'        => 'dealer__Purchase_Order__c',
    'form_PurchaseOrderAccountingCopy'    => 'dealer__Purchase_Order__c',
    // --- Parts Invoice forms ---
    'form_PartsInvoiceCopy'               => 'dealer__Parts_Invoice__c',
    'form_PartsInvoiceAccountingCopy'     => 'dealer__Parts_Invoice__c',
    'form_PartsPickTicketCopy'            => 'dealer__Parts_Invoice__c'
};

Map<String, String> labelByPage = new Map<String, String>{
    'form_ServiceRepairOrderCustomerCopy' => 'Service Repair Order Customer Copy (Custom)',
    'form_ServiceRepairOrderAuditCopy'    => 'Service Repair Order Audit Copy (Custom)',
    'form_ServiceRepairOrderWarrantyCopy' => 'Service Repair Order Warranty Copy (Custom)',
    'form_ServiceTechnicianHardCard'      => 'Tech Card (Custom)',
    'form_PurchaseOrderVendorCopy'        => 'Purchase Order Vendor Copy (Custom)',
    'form_PurchaseOrderAccountingCopy'    => 'Purchase Order Accounting Copy (Custom)',
    'form_PartsInvoiceCopy'               => 'Parts Invoice (Custom)',
    'form_PartsInvoiceAccountingCopy'     => 'Parts Invoice Accounting Copy (Custom)',
    'form_PartsPickTicketCopy'            => 'Parts Pick Ticket (Custom)'
};

Map<String, String> descriptionByPage = new Map<String, String>{
    'form_ServiceRepairOrderCustomerCopy' => 'Customer copy of the service repair order - Custom',
    'form_ServiceRepairOrderAuditCopy'    => 'Internal audit copy of the service repair order with cost, gross profit, and GL detail - Custom',
    'form_ServiceRepairOrderWarrantyCopy' => 'Warranty copy of the service repair order - Custom',
    'form_ServiceTechnicianHardCard'      => 'Technician hard card for the service repair order - Custom',
    'form_PurchaseOrderVendorCopy'        => 'Vendor copy of the purchase order - Custom',
    'form_PurchaseOrderAccountingCopy'    => 'Internal accounting copy of the purchase order - Custom',
    'form_PartsInvoiceCopy'               => 'Customer copy of the parts invoice - Custom',
    'form_PartsInvoiceAccountingCopy'     => 'Internal accounting copy of the parts invoice with cost, gross profit, and GL detail - Custom',
    'form_PartsPickTicketCopy'            => 'Parts pick ticket for the parts invoice - Custom'
};

// 2) Remove existing forms for these pages (match both prefixed and unprefixed
//    names so old records are cleaned up) and their location assignments.
Set<String> allPageNames = new Set<String>();
for (String page : objectByPage.keySet()) {
    allPageNames.add(page);
    allPageNames.add(PAGE_PREFIX + page);
}

List<dealer__Form__c> formsToDelete = [
    SELECT Id
    FROM dealer__Form__c
    WHERE dealer__Page_Name__c IN :allPageNames
];

List<dealer__FormRef__c> refsToDelete = [
    SELECT Id
    FROM dealer__FormRef__c
    WHERE dealer__Form__c IN :formsToDelete
];

delete refsToDelete;
delete formsToDelete;

// 3) Reinsert each form with the c__ prefixed page name (Print Type = Laser for Visualforce).
List<dealer__Form__c> formsToInsert = new List<dealer__Form__c>();
for (String page : objectByPage.keySet()) {
    formsToInsert.add(new dealer__Form__c(
        Name = labelByPage.get(page),
        dealer__Page_Name__c = PAGE_PREFIX + page,
        dealer__Print_Type__c = 'Laser',
        dealer__Based_on_Object__c = objectByPage.get(page),
        dealer__Description__c = descriptionByPage.get(page),
        dealer__Active__c = true
    ));
}
insert formsToInsert;

// 4) Link every form to every Dealer Location via dealer__FormRef__c.
List<dealer__FormRef__c> refsToInsert = new List<dealer__FormRef__c>();
for (dealer__Dealer_Location__c loc : [SELECT Id FROM dealer__Dealer_Location__c]) {
    for (dealer__Form__c f : formsToInsert) {
        refsToInsert.add(new dealer__FormRef__c(
            dealer__Form__c = f.Id,
            dealer__Location__c = loc.Id
        ));
    }
}
insert refsToInsert;

System.debug('Old forms removed: ' + formsToDelete.size() +
    ' (with ' + refsToDelete.size() + ' location assignments)');
System.debug('Forms reinserted with ' + PAGE_PREFIX + ' prefix: ' + formsToInsert.size());
System.debug('Location assignments created: ' + refsToInsert.size());
