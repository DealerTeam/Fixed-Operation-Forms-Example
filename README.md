# Fixed Ops Forms

Unmanaged Visualforce PDF forms for [DealerTeam DMS](https://www.dealerteam.com/) customer orgs. Deploy these pages and supporting Apex into subscriber orgs to customize fixed-ops print layouts without modifying the managed package.

## Deploy to Salesforce

Click the button to deploy directly into your org (sandbox or production). The deploy runs the included Apex tests.

<a href="https://githubsfdeploy.herokuapp.com?owner=DealerTeam&repo=Fixed-Operation-Forms-Example&ref=master">
  <img alt="Deploy to Salesforce" src="https://raw.githubusercontent.com/afawcett/githubsfdeploy/master/deploy.png">
</a>

> **Deploying to production?** Salesforce requires Apex tests to pass before code is committed. The button triggers a test run automatically. If you hit an org-wide coverage error, deploy to a sandbox first and validate, then use a change set or the CLI for production.

> **Heads up:** the button authenticates you into *your* org and installs the metadata from this repository. It does **not** install DealerTeam DMS — that managed package must already be present (see Prerequisites).

## Overview

DealerTeam DMS ships managed Visualforce pages for fixed-ops documents (parts, service, and related workflows). Those pages cannot be edited directly in subscriber orgs. This project holds **unmanaged copies** so you can:

- Adjust layout, branding, and field visibility
- Add or remove sections for your dealership workflow
- Test changes safely without touching the managed package

Pages use Apex controllers and extensions from the DealerTeam managed package (`dealer__` namespace), plus the unmanaged Apex helpers included here.

## What gets deployed

| Type | Members |
| --- | --- |
| **Apex classes** | `FixedOpsFormUtil`, `FormServiceTechnicianHardCardExt`, `FormPurchaseOrderExt`, `FormPartsInvoiceExt`, `FormPartsInvoiceAccountingCopyExt`, `FormServiceRepairOrderCustomerCopyExt` (+ matching test classes) |
| **Visualforce pages** | `form_ServiceTechnicianHardCard`, `form_PurchaseOrderVendorCopy`, `form_PurchaseOrderAccountingCopy`, `form_PartsInvoiceCopy`, `form_PartsInvoiceAccountingCopy`, `form_PartsPickTicketCopy`, `form_ServiceRepairOrderCustomerCopy` |
| **Content asset** | `FormCompanyLogo` (replace with your dealership logo) |
| **Permission set** | `forms_FixedOperations` (grants access to the pages and Apex) |

## Prerequisites

| Requirement | Details |
| --- | --- |
| **DealerTeam DMS** | The managed package must be installed. Pages and Apex depend on `dealer__` objects, fields, and classes. |
| **Record access** | Users who print forms need access to the underlying fixed-ops records. |
| **Deploy permissions** | The deploying user needs permission to customize application metadata and author Visualforce pages. |

> A scratch org from `config/project-scratch-def.json` alone will **not** include DealerTeam DMS. Use a sandbox or production org that already has the package installed.

## After deploying

1. Assign the **`forms_FixedOperations`** permission set to users who print these forms.
2. Replace the **`FormCompanyLogo`** content asset with your dealership logo.
3. **Register each page as a DealerTeam Form and assign it to your locations** (see below).

## Assigning forms to a location and an object type

Deploying the Visualforce pages only adds the markup to your org. For the pages to appear as printable forms on Service Repair Order, Purchase Order, and Parts Invoice records, DealerTeam needs two things:

1. A **Form** record that points at the Visualforce page and declares which object it prints from.
2. A **Form Reference** record that makes the form available at a specific **Location**.

### The data model

| Object | Purpose | Key fields |
| --- | --- | --- |
| `dealer__Form__c` | Registers a page as a form ("make it available to an object type") | `dealer__Page_Name__c` (the VF page API name), `dealer__Print_Type__c` = `Laser` (Visualforce), `dealer__Based_on_Object__c` (object API name the form prints from, e.g. `dealer__Service_Repair_Order__c` or `dealer__Purchase_Order__c`), `dealer__Active__c` |
| `dealer__FormRef__c` | Assigns a form to a location | `dealer__Form__c` (lookup to the Form), `dealer__Location__c` (lookup to `dealer__Dealer_Location__c`) |

This project's pages map to objects as follows:

| Visualforce page | `dealer__Based_on_Object__c` |
| --- | --- |
| `form_ServiceRepairOrderCustomerCopy` | `dealer__Service_Repair_Order__c` |
| `form_ServiceRepairOrderAuditCopy` | `dealer__Service_Repair_Order__c` |
| `form_ServiceRepairOrderWarrantyCopy` | `dealer__Service_Repair_Order__c` |
| `form_ServiceTechnicianHardCard` | `dealer__Service_Repair_Order__c` |
| `form_PurchaseOrderVendorCopy` | `dealer__Purchase_Order__c` |
| `form_PurchaseOrderAccountingCopy` | `dealer__Purchase_Order__c` |
| `form_PartsInvoiceCopy` | `dealer__Parts_Invoice__c` |
| `form_PartsInvoiceAccountingCopy` | `dealer__Parts_Invoice__c` |
| `form_PartsPickTicketCopy` | `dealer__Parts_Invoice__c` |

### Option A — DealerTeam UI

Follow the DealerTeam Success guides:

- [How to Upload Visualforce Forms](https://success.dealerteam.com/s/article/How-to-Create-and-Use-Merged-Forms) — create the `dealer__Form__c` record (Print Type **Laser**, Page Name = the page above, Based on Object = the matching object).
- [How to Assign Forms to a Location](https://success.dealerteam.com/s/article/How-to-Create-and-Use-Merged-Forms) — add the form to each Location so it is selected by default.

### Option B — Anonymous Apex (all locations at once)

Use the included script to register all forms and assign them to **every** Dealer Location in one pass. Because the print is invoked from a managed (`dealer`) component, the Form's Page Name must carry the local namespace prefix (`c__form_...`). The script deletes any existing Form records for these pages (prefixed or not, along with their location assignments) and reinserts them with the `c__` prefix, so it is safe to re-run.

```bash
sf apex run --file scripts/apex/assignFormsToLocations.apex --target-org my-org
```

The script (`scripts/apex/assignFormsToLocations.apex`) groups the service (RO) forms and the purchase order forms separately, so you can trim the maps to scope it to just one group:

```apex
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
```

It then inserts a `dealer__Form__c` per page (Page Name `c__form_...`, Print Type `Laser`, the correct Based-on object, a Description ending in "Custom", Active) and a `dealer__FormRef__c` linking each form to every `dealer__Dealer_Location__c`.

## Project layout

```
fixed-ops-forms/
├── force-app/main/default/
│   ├── classes/                  # Unmanaged Apex controllers/extensions + tests
│   ├── pages/                    # Unmanaged Visualforce pages
│   ├── contentassets/            # FormCompanyLogo
│   └── permissionsets/           # forms_FixedOperations
├── scripts/apex/                 # assignFormsToLocations.apex
├── manifest/package.xml          # Metadata manifest (API 66.0)
├── config/project-scratch-def.json
└── sfdx-project.json             # No namespace (unmanaged metadata)
```

## Deploy (CLI)

```bash
cd fixed-ops-forms

sf org login web --alias my-org --set-default

sf project deploy start --source-dir force-app --wait 10
```

### Manifest deploy with tests

Deploys everything in `manifest/package.xml` and runs the project test classes:

```bash
sf project deploy start \
  --manifest manifest/package.xml \
  --target-org my-org \
  --test-level RunSpecifiedTests \
  --tests FixedOpsFormUtilTest \
  --tests FormServiceTechnicianHardCardExtTest \
  --tests FormPurchaseOrderExtTest \
  --tests FormPartsInvoiceExtTest \
  --tests FormPartsInvoiceAccountingCopyTest \
  --tests FormServiceRepairOrderCustomerCopyTest \
  --wait 10
```

### Sandbox

```bash
sf org login web --alias my-sandbox --instance-url https://test.salesforce.com --set-default
sf project deploy start --source-dir force-app --wait 10
```

## Adding a form

1. Copy the managed package page markup from your org (or from package documentation).
2. Save as `force-app/main/default/pages/form_<PageName>.page` and `form_<PageName>.page-meta.xml`.
3. Remove the `dealer__` prefix from the page **name** (keep `dealer__` on controllers, extensions, and merge fields).
4. Deploy and validate PDF output against a real record.

Target API version: **66.0** (see `sfdx-project.json`).
