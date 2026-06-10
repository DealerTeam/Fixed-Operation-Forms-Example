# Fixed Ops Forms — Release Notes

**Release date:** June 9, 2026

This release renames the Parts Invoice Audit Copy to the Parts Invoice Accounting Copy, improves the Purchase Order Vendor Copy layout and vendor addressing, and overhauls the form registration script so all nine custom forms are loaded into every dealer location with the correct namespace prefix.

---

## What's New

### Parts Invoice Accounting Copy (replaces Audit Copy)

The internal Parts Invoice Audit Copy has been renamed to the **Parts Invoice Accounting Copy** to match the naming used by the Purchase Order Accounting Copy.

- Visualforce page is now `form_PartsInvoiceAccountingCopy` (was `form_PartsInvoiceAuditCopy`), backed by `FormPartsInvoiceAccountingCopyExt`.
- All printed titles updated: "Parts Invoice - Accounting Copy", "Vendor Return - Accounting Copy", "Counter Return - Accounting Copy", "Core Return - Accounting Copy", and "Service Repair Order - Parts Invoice Accounting Copy".
- Banner wording updated from "Internal audit copy..." to "Internal accounting copy..." on the repair order, vendor return, counter return, and core return variants.
- Content is unchanged: line-level cost and price, gross profit summary, cashiering detail, and posted General Ledger entries.

### Purchase Order Vendor Copy improvements

- **Part # column widened ~30%** (16% → 21% of the table width) so long part numbers have room to print. The space was taken from the Description column; quantity and money columns are unchanged.
- **Long part numbers now word-wrap** instead of overflowing into the Description column. The PDF renderer cannot break long unbroken strings (e.g. `OEM:N1040427506MTR`), so invisible break opportunities are now inserted every 12 characters. Short part numbers print exactly as before.
- **Vendor address now prints from the vendor Account** instead of the Purchase Order header fields, so the form always reflects the vendor's current address on file. If the PO has no vendor Account, or the Account has no address, the form falls back to the address captured on the PO header. Vendor name, account number, and phone still print from the PO.

### Form registration script overhaul (`scripts/apex/assignFormsToLocations.apex`)

- **All nine custom forms are now registered**, adding the Service Repair Order Audit Copy and Service Repair Order Warranty Copy, which were previously missing.
- **Page names are now registered with the `c__` namespace prefix** (e.g. `c__form_PartsInvoiceAccountingCopy`). The DealerTeam print action runs inside the `dealer` managed package, so unprefixed page names fail to resolve to these local pages.
- **The script now deletes and reinserts** the `dealer__Form__c` records for these pages (matching both prefixed and unprefixed names) along with their `dealer__FormRef__c` location assignments, then rebuilds the assignments for **every** Dealer Location. It remains safe to re-run.
- **Each form now gets a Description** explaining its purpose, ending in "Custom" so the custom forms are easy to identify alongside packaged forms.

### Documentation

- New `FORMS.md`: a human-readable overview of all nine forms, their audience, and intent — suitable for sharing outside the repo.
- README updated for the renamed page, the two added Service RO forms, and the new script behavior.

---

## Forms in this package

| Form | Source record | Audience |
| --- | --- | --- |
| Service Repair Order Customer Copy (Custom) | Service Repair Order | Customer |
| Service Repair Order Audit Copy (Custom) | Service Repair Order | Internal |
| Service Repair Order Warranty Copy (Custom) | Service Repair Order | Warranty provider |
| Tech Card (Custom) | Service Repair Order | Technician |
| Purchase Order Vendor Copy (Custom) | Purchase Order | Vendor |
| Purchase Order Accounting Copy (Custom) | Purchase Order | Internal |
| Parts Invoice (Custom) | Parts Invoice | Customer |
| Parts Invoice Accounting Copy (Custom) | Parts Invoice | Internal |
| Parts Pick Ticket (Custom) | Parts Invoice | Warehouse staff |

---

## Upgrade & Deployment Notes

1. **Deploy the metadata** using `manifest/package.xml`:

   ```bash
   sf project deploy start --manifest manifest/package.xml --target-org <alias>
   ```

2. **Remove the old Audit Copy components** from any org where they were previously deployed. `form_PartsInvoiceAuditCopy`, `FormPartsInvoiceAuditCopyExt`, and `FormPartsInvoiceAuditCopyTest` are not deleted automatically — remove them via Setup or a `destructiveChanges.xml`.

3. **Re-run the assignment script** so the form records pick up the `c__` page-name prefix, the new descriptions, and the two newly registered Service RO forms:

   ```bash
   sf apex run --file scripts/apex/assignFormsToLocations.apex --target-org <alias>
   ```

   Note: the script deletes and reinserts the `dealer__Form__c` records for these pages, so any manual edits made to those records in the org (sequence, applicable states, etc.) will need to be reapplied.

4. **Run the test classes** to validate the org:

   ```bash
   sf apex run test \
     --tests FixedOpsFormUtilTest \
     --tests FormServiceTechnicianHardCardExtTest \
     --tests FormPurchaseOrderExtTest \
     --tests FormPartsInvoiceExtTest \
     --tests FormPartsInvoiceAccountingCopyTest \
     --tests FormServiceRepairOrderCustomerCopyTest \
     --tests FormServiceRepairOrderAuditCopyTest \
     --tests FormServiceRepairOrderWarrantyCopyTest \
     --wait 10
   ```

5. **Spot-check the prints**: a Parts Invoice Accounting Copy (verify the new titles), and a Purchase Order Vendor Copy with a long part number and a vendor whose Account address differs from the PO header (verify wrapping and the Account address).

---

## Breaking / Behavioral Changes

- **Page rename:** `form_PartsInvoiceAuditCopy` no longer exists in the source. Anything pointing at the old page name (bookmarks, custom buttons, the old `dealer__Form__c` record) must be updated to `c__form_PartsInvoiceAccountingCopy`.
- **Form Page Names now carry the `c__` prefix.** Forms registered by an earlier run of the script under unprefixed names are removed and re-created by the new script.
- **PO Vendor Copy vendor address source changed.** POs whose header address intentionally differs from the vendor Account will now print the Account address whenever the Account has one on file.
