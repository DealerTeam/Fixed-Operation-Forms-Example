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
| **Apex classes** | `FixedOpsFormUtil`, `FormServiceTechnicianHardCardExt`, `FormPurchaseOrderExt`, `FormServiceRepairOrderCustomerCopyExt` (+ matching test classes) |
| **Visualforce pages** | `form_ServiceTechnicianHardCard`, `form_PurchaseOrderVendorCopy`, `form_PurchaseOrderAccountingCopy`, `form_ServiceRepairOrderCustomerCopy` |
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
3. Add the pages as buttons/links or override print actions on the relevant fixed-ops records.

## Project layout

```
fixed-ops-forms/
├── force-app/main/default/
│   ├── classes/                  # Unmanaged Apex controllers/extensions + tests
│   ├── pages/                    # Unmanaged Visualforce pages
│   ├── contentassets/            # FormCompanyLogo
│   └── permissionsets/           # forms_FixedOperations
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
