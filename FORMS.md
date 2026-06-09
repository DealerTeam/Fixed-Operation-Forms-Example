# Fixed Ops Custom Forms

Custom Visualforce print forms for DealerTeam Fixed Operations. Each form is registered as a DealerTeam Form (Print Type: Laser), assigned to every dealer location, and prints as a PDF from its source record.

---

## Service Repair Order Forms

*Printed from a Service Repair Order.*

### Service Repair Order Customer Copy (Custom)

**Who it's for:** The customer.

The finished repair order the customer signs and takes home. Shows the dealership header and service hours, customer and vehicle information, each job with its story, labor, parts, and sublet charges at retail price, taxes, totals, and payment summary. No internal cost information appears on this copy.

### Service Repair Order Audit Copy (Custom)

**Who it's for:** Office, accounting, and management (internal only).

The behind-the-scenes version of the repair order. Includes everything on the customer copy plus internal cost detail: labor cost, parts cost, sublet and misc charge costs, gross profit by job, and the posted General Ledger entries for the RO. Used to audit profitability and verify accounting postings. Never given to a customer.

### Service Repair Order Warranty Copy (Custom)

**Who it's for:** Warranty administrators and manufacturers/warranty providers.

A copy of the repair order scoped to warranty-pay work. Used to document and submit warranty claims, showing the warranty jobs, causal parts, labor operations, and amounts claimed against the warranty provider.

### Tech Card (Custom)

**Who it's for:** Service technicians on the shop floor.

The technician hard card (job card). A working document printed when the RO is dispatched, giving the tech the vehicle info, requested jobs, and space to record findings, recommendations, and time. No pricing intended for customers.

---

## Purchase Order Forms

*Printed from a Purchase Order.*

### Purchase Order Vendor Copy (Custom)

**Who it's for:** The vendor/supplier.

The copy sent to the vendor to place the order. Shows the dealership's billing and shipping details, the vendor's information, and the lines being ordered with quantities and agreed pricing.

### Purchase Order Accounting Copy (Custom)

**Who it's for:** Accounting (internal only).

The internal record of the purchase order used to match against vendor invoices and verify postings. Includes the same order detail as the vendor copy plus internal accounting context.

---

## Parts Invoice Forms

*Printed from a Parts Invoice.*

### Parts Invoice (Custom)

**Who it's for:** The customer (counter sales).

The customer-facing parts invoice for counter and ship-out sales. Shows sold-to/ship-to details, the counterman, each part with quantity and retail price, core charges, misc charges, tax, payments, and the balance due. Adapts its layout for returns (counter return, core return, vendor return) and for invoices tied to a repair order.

### Parts Invoice Accounting Copy (Custom)

**Who it's for:** Parts managers and accounting (internal only).

The internal version of the parts invoice with full cost visibility. Every line shows unit cost, extended cost, price, and extended price, followed by a gross profit summary (parts vs. misc, with gross percentages), the cashiering/payment detail, and the posted General Ledger entries for the invoice. Used to review margins and reconcile postings. Never given to a customer.

### Parts Pick Ticket (Custom)

**Who it's for:** Warehouse/parts counter staff.

A pull sheet for fulfilling a parts invoice. Lists the parts with bin locations and quantities so staff can pick the order from the shelves. No pricing emphasis — it's a fulfillment document, not a billing one.

---

## Quick Reference

| Form | Source record | Audience | Cost data shown? |
| --- | --- | --- | --- |
| Service Repair Order Customer Copy (Custom) | Service Repair Order | Customer | No |
| Service Repair Order Audit Copy (Custom) | Service Repair Order | Internal | Yes (cost, gross, GL) |
| Service Repair Order Warranty Copy (Custom) | Service Repair Order | Warranty provider | Claim amounts |
| Tech Card (Custom) | Service Repair Order | Technician | No |
| Purchase Order Vendor Copy (Custom) | Purchase Order | Vendor | Order pricing |
| Purchase Order Accounting Copy (Custom) | Purchase Order | Internal | Yes |
| Parts Invoice (Custom) | Parts Invoice | Customer | No |
| Parts Invoice Accounting Copy (Custom) | Parts Invoice | Internal | Yes (cost, gross, GL) |
| Parts Pick Ticket (Custom) | Parts Invoice | Warehouse staff | No |
