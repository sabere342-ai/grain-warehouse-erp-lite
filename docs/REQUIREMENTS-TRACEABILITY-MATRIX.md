# Requirements Traceability Matrix

> Grain Warehouse ERP Lite — Post-Owner Wipe (Unified Accounting Baseline)
> Generated from source code evidence as of baseline `4d8705b`.

---

## Legend

| Status | Meaning |
|---|---|
| IMPLEMENTED | Fully implemented with source code and test coverage |
| PARTIALLY IMPLEMENTED | Core logic exists but UI, edge cases, or secondary paths are incomplete |
| NOT IMPLEMENTED | No source code or test evidence |
| DEFERRED BY DEPENDENCY | Blocked by another module not yet built |
| PLANNED — SCOPE FROZEN | Remains in the product roadmap; its implementation scope and dependencies were documented without production code |
| REQUIRES OWNER DECISION | Architecture or scope decision needed before implementation |

---

## Operations (OPS)

### OPS-001: Product catalog management (CRUD, units, pricing)

| Field | Value |
|---|---|
| **Status** | IMPLEMENTED |
| **Source evidence** | Product catalog is a core domain entity in warehouse management. |
| **Implementation evidence** | `lib/core/catalog/product.dart:3` — `Product` model with `name`, `code`, `unit` (GrainUnit enum), `defaultSalePricePiastersPerKg`, `minimumSalePricePiastersPerKg`, `referenceCostPricePiastersPerKg`, `isActive`. `lib/core/catalog/product_repository.dart:19` — `LocalProductRepository` with full CRUD: `createProduct`, `updateProduct`, `setProductActive`, `listProducts`. Name/code uniqueness enforced. `lib/core/catalog/product_controller.dart:6` — `ProductController` with permission-gated CRUD. `lib/core/catalog/grain_unit.dart:1` — `GrainUnit` enum (kilogram, ton) with conversion. `lib/features/products/products_screen.dart` — Products UI screen. |
| **Test evidence** | `test/product_catalog_test.dart` — Full CRUD test coverage. `test/pricing_utils_test.dart` — Pricing validation tests. |
| **Missing behavior** | None — complete CRUD with units and three price fields. |
| **Dependencies** | None |
| **Proposed phase** | Phase 1 |
| **Acceptance evidence** | Product CRUD operations work; uniqueness constraints enforced; pricing fields validated (must be positive, minimum ≤ default). |

---

### OPS-002: Customer management (CRUD, active/inactive)

| Field | Value |
|---|---|
| **Status** | IMPLEMENTED |
| **Source evidence** | Customer management required for credit sales and collections. |
| **Implementation evidence** | `lib/core/customers/customer.dart:1` — `Customer` model with `name`, `phone`, `notes`, `isActive`. `lib/core/customers/customer_repository.dart:17` — `LocalCustomerRepository` with full CRUD + `setCustomerActive` + audit logging. Uniqueness on name and phone enforced. `lib/core/customers/customer_controller.dart:9` — `CustomerController` with permission checks, balance tracking, statement generation. `lib/features/customers/customers_screen.dart` — Customer UI. |
| **Test evidence** | `test/phase34_customer_credit_collections_test.dart` — Customer credit and collection flows. `test/phase37a_opening_balances_test.dart` — Customer opening balance tests. `test/phase37b_customer_opening_balances_test.dart` — Additional customer balance tests. |
| **Missing behavior** | None — full CRUD with active/inactive toggle, phone uniqueness. |
| **Dependencies** | None |
| **Proposed phase** | Phase 34 |
| **Acceptance evidence** | Customer create/update/disable/reactivate all tested; audit trail recorded. |

---

### OPS-003: Supplier management (CRUD, active/inactive)

| Field | Value |
|---|---|
| **Status** | IMPLEMENTED |
| **Source evidence** | Supplier management required for purchase intake and supplier accounts. |
| **Implementation evidence** | `lib/core/suppliers/supplier_repository.dart:19` — `LocalSupplierRepository` with full CRUD + `setSupplierActive`. Unique name/phone enforced. `lib/features/suppliers/suppliers_screen.dart` — Supplier UI. |
| **Test evidence** | `test/supplier_purchase_test.dart` — Supplier purchase flows. `test/phase36_supplier_accounts_dashboard_test.dart` — Supplier account tests. |
| **Missing behavior** | None — full CRUD with active/inactive toggle. |
| **Dependencies** | None |
| **Proposed phase** | Phase 1 |
| **Acceptance evidence** | Supplier CRUD with uniqueness constraints and active/inactive toggle. |

---

### OPS-004: Cash sales

| Field | Value |
|---|---|
| **Status** | IMPLEMENTED |
| **Source evidence** | Cash sales are the primary transaction type for walk-in customers. |
| **Implementation evidence** | `lib/core/sales/sale_record.dart:3` — `SalePaymentMode.cash`. `lib/core/sales/sale_repository.dart:32` — `LocalSaleRepository.createSale()` — creates stock movement, records sale with `paymentMode: SalePaymentMode.cash`, stock decreases on sale. `lib/features/sales/sales_screen.dart` — Sales UI. |
| **Test evidence** | `test/sales_test.dart` — Cash sale tests. `test/phase21d_end_to_end_business_release_test.dart` — End-to-end cash sale validation. |
| **Missing behavior** | None |
| **Dependencies** | OPS-001, INV-001 |
| **Proposed phase** | Phase 1 |
| **Acceptance evidence** | Cash sale creates stock movement and sale record with total = qty × price. |

---

### OPS-005: Credit sales

| Field | Value |
|---|---|
| **Status** | IMPLEMENTED |
| **Source evidence** | Credit sales allow deferred payment for trusted customers. |
| **Implementation evidence** | `lib/core/sales/sale_record.dart:5` — `SalePaymentMode.credit`. `lib/core/sales/sale_repository.dart:32` — `createSale()` resolves `paidAmountQirsh = 0` for credit. `lib/core/customer_accounts/customer_account_repository.dart:114` — `createCreditSaleEntry()` creates debit entry on customer ledger. |
| **Test evidence** | `test/phase35_customer_credit_ui_pilot_qa_test.dart` — Credit sale tests. `test/phase34_customer_credit_collections_test.dart` — Credit sale ledger impact. |
| **Missing behavior** | None |
| **Dependencies** | OPS-002, ACC-001 |
| **Proposed phase** | Phase 34 |
| **Acceptance evidence** | Credit sale posts to customer account ledger as debit; paidAmount = 0. |

---

### OPS-006: Partial payment sales

| Field | Value |
|---|---|
| **Status** | IMPLEMENTED |
| **Source evidence** | Partial payment allows upfront payment of part of the sale amount. |
| **Implementation evidence** | `lib/core/sales/sale_record.dart:6` — `SalePaymentMode.partial`. `lib/core/sales/sale_repository.dart:264` — `_resolvePaidAmount()` validates partial requires `paidAmountQirsh`. `lib/core/customer_accounts/customer_account_repository.dart:159` — `createCashSaleEntry()` handles partial sales, creates debit and credit entries. |
| **Test evidence** | `test/phase35_customer_credit_ui_pilot_qa_test.dart` — Partial payment tests. |
| **Missing behavior** | None |
| **Dependencies** | OPS-001, ACC-001 |
| **Proposed phase** | Phase 34 |
| **Acceptance evidence** | Partial sale creates customer ledger entry with debit=total, credit=paidAmount; remaining is outstanding. |

---

### OPS-007: Multi-item sales

| Field | Value |
|---|---|
| **Status** | IMPLEMENTED |
| **Source evidence** | Multi-item sales allow combining multiple products in one invoice. |
| **Implementation evidence** | `lib/core/sales/sale_record.dart:20` — `SaleLineItem` with per-line `productId`, `quantityKg`, `salePriceQirshPerKg`, `lineTotalQirsh`. `lib/core/sales/sale_repository.dart:204` — `_buildItems()` merges same-product lines, creates individual stock movements per item. |
| **Test evidence** | `test/phase39_customer_bound_multi_item_sales_test.dart` — Multi-item sale tests. |
| **Missing behavior** | None |
| **Dependencies** | OPS-001, INV-001 |
| **Proposed phase** | Phase 39 |
| **Acceptance evidence** | Multi-item sale creates per-product stock movements; items merged for duplicates; total = sum of line totals. |

---

### OPS-008: Customer-bound sales

| Field | Value |
|---|---|
| **Status** | IMPLEMENTED |
| **Source evidence** | Customer-bound sales link a sale to a specific customer for ledger tracking. |
| **Implementation evidence** | `lib/core/sales/sale_record.dart:75` — `customerId` field. `lib/core/sales/sale_repository.dart:366` — Draft requires non-null `customerId`. |
| **Test evidence** | `test/phase39_customer_bound_multi_item_sales_test.dart` — Customer-bound sales tested. |
| **Missing behavior** | None |
| **Dependencies** | OPS-002 |
| **Proposed phase** | Phase 39 |
| **Acceptance evidence** | All sales require a customer; sale record stores `customerId`. |

---

### OPS-009: Purchase intake

| Field | Value |
|---|---|
| **Status** | IMPLEMENTED |
| **Source evidence** | Purchase intake records incoming goods from suppliers. |
| **Implementation evidence** | `lib/core/purchases/purchase_intake.dart:4` — `PurchaseIntake` model with supplier, product, quantity, price, total. `lib/core/purchases/purchase_repository.dart:42` — `createPurchaseIntake()` validates supplier/product, creates stock movement, records supplier ledger entry. `lib/features/purchases/purchases_screen.dart` — Purchase UI. |
| **Test evidence** | `test/supplier_purchase_test.dart` — Purchase intake tests. `test/phase18_release_candidate_qa_test.dart` — Purchase flow validation. |
| **Missing behavior** | None |
| **Dependencies** | OPS-001, OPS-003, INV-001 |
| **Proposed phase** | Phase 1 |
| **Acceptance evidence** | Purchase intake creates stock movement (purchaseIntake type) and supplier ledger entry. |

---

### OPS-010: Supplier-bound purchases

| Field | Value |
|---|---|
| **Status** | IMPLEMENTED |
| **Source evidence** | Purchases are always bound to a supplier. |
| **Implementation evidence** | `lib/core/purchases/purchase_intake.dart:15` — `supplierId` required. `lib/core/purchases/purchase_repository.dart:45` — `_validateSupplier()` ensures active supplier exists. |
| **Test evidence** | `test/supplier_purchase_test.dart` — Supplier binding tested. |
| **Missing behavior** | None |
| **Dependencies** | OPS-003 |
| **Proposed phase** | Phase 1 |
| **Acceptance evidence** | Purchase intake always requires a valid active `supplierId`. |

---

### OPS-011: Customer collection recording

| Field | Value |
|---|---|
| **Status** | IMPLEMENTED |
| **Source evidence** | Collections record payments received from customers against outstanding balances. |
| **Implementation evidence** | `lib/core/customer_accounts/customer_collection.dart:1` — `CustomerCollectionRecord` model. `lib/core/customer_accounts/customer_account_repository.dart:210` — `createCollection()` validates balance, creates credit entry on customer ledger, audit logs. `lib/core/customers/customer_controller.dart:65` — `recordCollection()` with permission check. |
| **Test evidence** | `test/phase34_customer_credit_collections_test.dart` — Collection recording and balance impact tested. |
| **Missing behavior** | None |
| **Dependencies** | OPS-002, ACC-001 |
| **Proposed phase** | Phase 34 |
| **Acceptance evidence** | Collection posts credit entry to customer ledger; balance cannot go negative; collection > balance rejected. |

---

### OPS-012: Supplier payment recording

| Field | Value |
|---|---|
| **Status** | IMPLEMENTED |
| **Source evidence** | Supplier payments record outgoing payments to suppliers. |
| **Implementation evidence** | `lib/core/supplier_accounts/supplier_payment.dart:1` — `SupplierPaymentRecord` model. `lib/core/supplier_accounts/supplier_account_repository.dart:153` — `createPayment()` validates balance, creates credit entry on supplier ledger, audit logs. `lib/features/supplier_accounts/supplier_payment_dialog.dart` — Payment dialog UI. |
| **Test evidence** | `test/phase36e_supplier_payment_ui_test.dart` — Supplier payment UI tests. `test/phase36_supplier_accounts_dashboard_test.dart` — Supplier account balance tests. |
| **Missing behavior** | None |
| **Dependencies** | OPS-003, ACC-002 |
| **Proposed phase** | Phase 36 |
| **Acceptance evidence** | Supplier payment posts credit entry; balance cannot go negative; payment > balance rejected. |

---

### OPS-013: Expense recording

| Field | Value |
|---|---|
| **Status** | IMPLEMENTED |
| **Source evidence** | Expenses track operational costs outside of purchases. |
| **Implementation evidence** | `lib/core/expenses/expense.dart:1` — `ExpenseRecord` model with date, category, amount. `lib/core/expenses/expense_repository.dart:13` — `LocalExpenseRepository` with create and range-based total. Audit logged. `lib/core/expenses/expense_controller.dart:6` — `ExpenseController` with permission check. `lib/features/expenses/expenses_screen.dart` — Expense UI. |
| **Test evidence** | `test/reports_test.dart` — Expense totals in report calculations. |
| **Missing behavior** | None |
| **Dependencies** | None |
| **Proposed phase** | Phase 1 |
| **Acceptance evidence** | Expense created with category, amount, date; audit trail recorded. |

---

### OPS-014: Stock management (movements, manual adjustments)

| Field | Value |
|---|---|
| **Status** | IMPLEMENTED |
| **Source evidence** | Stock management tracks all inventory movements. |
| **Implementation evidence** | `lib/core/inventory/stock_movement.dart:1` — `StockMovementType` enum with `openingBalance`, `manualIncrease`, `manualDecrease`, `purchaseIntake`, `sale`, `purchaseCancellation`, `saleCancellation`. `lib/core/inventory/inventory_repository.dart:20` — `LocalInventoryRepository` with `createMovement()`, zero-stock guard, `currentStockKg()`, `allProductBalancesKg()`. `lib/core/inventory/inventory_controller.dart:8` — `InventoryController` with `createOpeningBalance()`, `createManualIncrease()`, `createManualDecrease()`, permission-gated. `lib/features/inventory/inventory_screen.dart` — Inventory UI. |
| **Test evidence** | `test/inventory_test.dart` — Stock movement tests. `test/phase49b_stock_adjustment_report_test.dart` — Stock adjustment tests. |
| **Missing behavior** | None |
| **Dependencies** | OPS-001 |
| **Proposed phase** | Phase 1 |
| **Acceptance evidence** | All 7 movement types implemented; stock cannot go negative; only one opening balance per product; balances computed by summing signed quantities. |

---

### OPS-015: Stock taking (physical count, variance)

| Field | Value |
|---|---|
| **Status** | IMPLEMENTED |
| **Source evidence** | Stock taking reconciles physical counts with system records. |
| **Implementation evidence** | `lib/features/inventory/stock_take_screen.dart` — Stock take UI screen. |
| **Test evidence** | `test/phase49a_stock_take_test.dart` — Stock take workflow tests. |
| **Missing behavior** | None |
| **Dependencies** | OPS-014 |
| **Proposed phase** | Phase 49a |
| **Acceptance evidence** | Stock take screen and workflow implemented. |

---

### OPS-016: Document history (unified view)

| Field | Value |
|---|---|
| **Status** | IMPLEMENTED |
| **Source evidence** | Document history provides a unified view of all purchases and sales. |
| **Implementation evidence** | `lib/core/documents/document_history.dart:102` — `LocalDocumentHistoryRepository` combines purchase intakes and sales into `DocumentHistoryEntry` list with filtering (date range, type, status, query). `lib/core/documents/document_history_controller.dart:5` — `DocumentHistoryController` with filter application. `lib/features/documents/document_history_screen.dart` — Document history UI. |
| **Test evidence** | `test/document_history_test.dart` — Document history filtering and status tests. |
| **Missing behavior** | None |
| **Dependencies** | OPS-009, OPS-004 |
| **Proposed phase** | Phase 1 |
| **Acceptance evidence** | Unified list of purchases and sales with filter by date, type (purchase/sale), status (active/cancelled). |

---

### OPS-017: Opening balances (customers, suppliers)

| Field | Value |
|---|---|
| **Status** | IMPLEMENTED |
| **Source evidence** | Opening balances allow migrating pre-existing debts/credits. |
| **Implementation evidence** | `lib/core/customer_accounts/customer_account_repository.dart:266` — `createOpeningBalanceEntry()` with one-per-customer guard, no-after-transactions guard. `lib/core/supplier_accounts/supplier_account_repository.dart:274` — `createOpeningBalanceEntry()` with one-per-supplier guard. `lib/core/customers/customer_controller.dart:160` — `recordOpeningBalance()`. |
| **Test evidence** | `test/phase37a_opening_balances_test.dart` — Opening balance creation tests. `test/phase37b_customer_opening_balances_test.dart` — Customer opening balance edge cases. |
| **Missing behavior** | None |
| **Dependencies** | ACC-001, ACC-002 |
| **Proposed phase** | Phase 37 |
| **Acceptance evidence** | One opening balance per customer/supplier; cannot add after transactions exist; audit logged. |

---

### OPS-018: Owner dashboard with alerts

| Field | Value |
|---|---|
| **Status** | IMPLEMENTED |
| **Source evidence** | Dashboard provides at-a-glance business health for the owner. |
| **Implementation evidence** | `lib/core/dashboard/dashboard_service.dart` — Dashboard data aggregation. `lib/core/dashboard/dashboard_controller.dart` — Dashboard controller. `lib/features/dashboard/dashboard_screen.dart` — Dashboard UI. `lib/features/dashboard/dashboard_alerts_section.dart` — Alerts section with stock/payment/credit alerts. |
| **Test evidence** | `test/phase64_owner_dashboard_alerts_test.dart` — Dashboard alerts tests. `test/phase37c_dashboard_labels_test.dart` — Dashboard label tests. |
| **Missing behavior** | None |
| **Dependencies** | All operational modules |
| **Proposed phase** | Phase 37c / Phase 64 |
| **Acceptance evidence** | Dashboard with alerts for low stock, outstanding balances, and operational health. |

---

## Accounting (ACC)

### ACC-001: Customer account ledger

| Field | Value |
|---|---|
| **Status** | IMPLEMENTED |
| **Source evidence** | Customer ledger tracks all debits and credits per customer. |
| **Implementation evidence** | `lib/core/customer_accounts/customer_account_entry.dart:1` — `CustomerAccountEntry` with types: `creditSale`, `cashSale`, `collection`, `openingBalance`, `saleCancellation`. Running balance via `signedBalanceImpactQirsh`. `lib/core/customer_accounts/customer_account_repository.dart:41` — `LocalCustomerAccountRepository` with `balanceForCustomer()`, `balancesByCustomerId()`, `statementForCustomer()`. |
| **Test evidence** | `test/phase34_customer_credit_collections_test.dart` — Ledger entry creation and balance calculation. `test/phase59_sale_cancellation_customer_ledger_symmetry_test.dart` — Reversal symmetry. |
| **Missing behavior** | None |
| **Dependencies** | None |
| **Proposed phase** | Phase 34 |
| **Acceptance evidence** | Ledger entries for credit sales, cash sales, partial sales, collections, opening balances, and sale cancellations; running balance calculated correctly. |

---

### ACC-002: Supplier account ledger

| Field | Value |
|---|---|
| **Status** | IMPLEMENTED |
| **Source evidence** | Supplier ledger tracks all debits and credits per supplier. |
| **Implementation evidence** | `lib/core/supplier_accounts/supplier_account_entry.dart:1` — `SupplierAccountEntry` with types: `purchase`, `payment`, `openingBalance`. `lib/core/supplier_accounts/supplier_account_repository.dart:33` — `LocalSupplierAccountRepository` with `balanceForSupplier()`, `balancesBySupplierId()`, `statementForSupplier()`. |
| **Test evidence** | `test/phase36_supplier_accounts_dashboard_test.dart` — Supplier ledger balance tests. |
| **Missing behavior** | None |
| **Dependencies** | None |
| **Proposed phase** | Phase 36 |
| **Acceptance evidence** | Ledger entries for purchases, payments, opening balances; running balance calculated. |

---

### ACC-003: Customer opening balance entries

| Field | Value |
|---|---|
| **Status** | IMPLEMENTED |
| **Source evidence** | See OPS-017. |
| **Implementation evidence** | `lib/core/customer_accounts/customer_account_repository.dart:266` — `createOpeningBalanceEntry()`. `lib/core/customer_accounts/customer_account_entry.dart:17` — `CustomerAccountEntryType.openingBalance`. |
| **Test evidence** | `test/phase37b_customer_opening_balances_test.dart` |
| **Missing behavior** | None |
| **Dependencies** | ACC-001 |
| **Proposed phase** | Phase 37 |
| **Acceptance evidence** | Single opening balance per customer; one-per-customer guard. |

---

### ACC-004: Supplier opening balance entries

| Field | Value |
|---|---|
| **Status** | IMPLEMENTED |
| **Source evidence** | See OPS-017. |
| **Implementation evidence** | `lib/core/supplier_accounts/supplier_account_repository.dart:274` — `createOpeningBalanceEntry()`. `lib/core/supplier_accounts/supplier_account_entry.dart:4` — `SupplierAccountEntryType.openingBalance`. |
| **Test evidence** | `test/phase36_supplier_accounts_dashboard_test.dart` |
| **Missing behavior** | None |
| **Dependencies** | ACC-002 |
| **Proposed phase** | Phase 36 |
| **Acceptance evidence** | Single opening balance per supplier. |

---

### ACC-005: Sale cancellation with customer account reversal

| Field | Value |
|---|---|
| **Status** | IMPLEMENTED |
| **Source evidence** | Cancelling a credit or partial sale must reverse the customer ledger. |
| **Implementation evidence** | `lib/core/customer_accounts/customer_account_repository.dart:328` — `reverseSaleEntry()` finds original entry, validates no collections against it, creates `saleCancellation` credit entry. `lib/core/sales/sale_repository.dart:117` — `cancelSale()` creates stock reversal movements. |
| **Test evidence** | `test/phase59_sale_cancellation_customer_ledger_symmetry_test.dart` — Symmetry tests for sale cancellation reversal. |
| **Missing behavior** | None |
| **Dependencies** | ACC-001, CAN-001 |
| **Proposed phase** | Phase 59 |
| **Acceptance evidence** | Cancellation blocked if collections exist against the sale; reversal entry created with reason; audit logged. |

---

### ACC-006: Purchase cancellation with supplier account reversal

| Field | Value |
|---|---|
| **Status** | IMPLEMENTED |
| **Source evidence** | Cancelling a purchase must reverse the supplier ledger. |
| **Implementation evidence** | `lib/core/supplier_accounts/supplier_account_repository.dart:209` — `reversePurchaseEntry()` finds original entry, validates no payments received, creates reversal credit entry. `lib/core/purchases/purchase_repository.dart:89` — `cancelPurchaseIntake()` calls supplier reversal. |
| **Test evidence** | `test/phase36_supplier_accounts_dashboard_test.dart` — Supplier ledger reversal tests. |
| **Missing behavior** | None |
| **Dependencies** | ACC-002, CAN-002 |
| **Proposed phase** | Phase 36 |
| **Acceptance evidence** | Cancellation blocked if payments received; reversal entry created; audit logged. |

---

### ACC-007: Financial account model (treasury/bank/wallet)

| Field | Value |
|---|---|
| **Status** | IMPLEMENTED |
| **Source evidence** | Future requirement for multi-account financial management. |
| **Implementation evidence** | `lib/core/financial_accounts/financial_account.dart` — `FinancialAccount` model with `FinancialAccountType` enum (treasury/bank/electronicWallet). `lib/core/financial_accounts/financial_account_repository.dart` — `LocalFinancialAccountRepository` with full CRUD, activate/deactivate, opening balance. `lib/features/financial_accounts/financial_accounts_screen.dart` — Account list screen. |
| **Test evidence** | `test/phase71_unified_financial_accounts_foundation_test.dart` — Model tests, repository CRUD tests, activate/deactivate tests, opening balance tests, balance calculation tests. |
| **Missing behavior** | None for Phase 71 scope. Account selection in transactions deferred to Phase 72. |
| **Dependencies** | None |
| **Proposed phase** | Phase 71 |
| **Acceptance evidence** | FinancialAccount model created, repository supports CRUD, opening balance set once, activate/deactivate, 630/630 tests passing. |

---

### ACC-008: Unified financial ledger

| Field | Value |
|---|---|
| **Status** | IMPLEMENTED |
| **Source evidence** | Future requirement for cross-account ledger. |
| **Implementation evidence** | `lib/core/financial_accounts/financial_account_entry.dart` — `FinancialAccountEntry` with `FinancialAccountEntryDirection` (inflow/outflow), `FinancialAccountEntrySource` (openingBalance/manualCorrection/restoreImport). Append-only ledger with running balance. `lib/core/financial_accounts/financial_account_repository.dart` — `statementForAccount()` with date filtering. |
| **Test evidence** | `test/phase71_unified_financial_accounts_foundation_test.dart` — Entry model tests, statement filtering tests, balance calculation edge cases. |
| **Missing behavior** | None for Phase 71 scope. Transaction integration deferred to Phase 72. |
| **Dependencies** | ACC-007 |
| **Proposed phase** | Phase 71 |
| **Acceptance evidence** | FinancialAccountEntry model with direction/source enums, append-only ledger, statement with date filtering, 630/630 tests passing. |

---

### ACC-009: Account selection in transactions

| Field | Value |
|---|---|
| **Status** | IMPLEMENTED |
| **Source evidence** | Transactions now accept optional `financialAccountId` to link to a unified financial account. |
| **Implementation evidence** | `lib/core/sales/sale_record.dart:64` — `SaleRecord` has `financialAccountId` field. `lib/core/sales/sale_controller.dart:82–158` — `SaleController.createSale` creates FA `salePayment` entry when `financialAccountId` provided; `cancelSale` creates `cancellationReversal` entry. `lib/core/purchases/purchase_intake.dart:39–42` — `PurchaseIntake` has `financialAccountId`. `lib/core/purchases/purchase_repository.dart:96–118` — `LocalPurchaseRepository.createPurchaseIntake` creates FA `purchasePayment` entry. `lib/core/customer_accounts/customer_collection.dart:13–14` — `CustomerCollectionRecord` has `financialAccountId`. `lib/core/customer_accounts/customer_account_repository.dart:271–287` — `createCollection` creates FA `customerCollection` entry. `lib/core/supplier_accounts/supplier_payment.dart:13–14` — `SupplierPaymentRecord` has `financialAccountId`. `lib/core/supplier_accounts/supplier_account_repository.dart:214–230` — `createPayment` creates FA `supplierSettlement` entry. `lib/core/expenses/expense.dart:12–13` — `ExpenseRecord` has `financialAccountId`. `lib/core/expenses/expense_repository.dart:66–82` — `createExpense` creates FA `expense` entry. |
| **Test evidence** | `test/phase72_transaction_integration_test.dart` — 43 tests covering: cash/partial/credit sales → FA entry creation, paid/partial/credit purchases → FA entry creation, customer collections → FA entry, supplier payments → FA entry, expenses → FA entry, cancellation reversals, balance consistency, direction consistency, no-FA-entry when `financialAccountId` null. |
| **Missing behavior** | UI for account selection in sale/purchase/payment screens (deferred to separate UI phase). |
| **Dependencies** | ACC-007 |
| **Proposed phase** | Phase 72 |
| **Acceptance evidence** | All transaction types correctly create/omit FA entries based on `financialAccountId` presence; balance consistency verified. |

---

### ACC-010: Payment method tracking

| Field | Value |
|---|---|
| **Status** | IMPLEMENTED |
| **Source evidence** | Payment method tracked alongside financial account selection. |
| **Implementation evidence** | `lib/core/financial_accounts/financial_account_entry.dart:52–70` — `PaymentMethod` enum with `cash`, `bankTransfer`, `mobileWallet`, `check` values and Arabic labels. `lib/core/financial_accounts/financial_account_entry.dart:88` — `FinancialAccountEntry.paymentMethod` field. `lib/core/sales/sale_record.dart:84` — `SaleRecord.paymentMethod`. `lib/core/purchases/purchase_intake.dart:61` — `PurchaseIntake.paymentMethod`. `lib/core/customer_accounts/customer_collection.dart:26` — `CustomerCollectionRecord.paymentMethod`. `lib/core/supplier_accounts/supplier_payment.dart:26` — `SupplierPaymentRecord.paymentMethod`. `lib/core/expenses/expense.dart:22` — `ExpenseRecord.paymentMethod`. All repos forward `paymentMethod` to FA entries. |
| **Test evidence** | `test/phase72_transaction_integration_test.dart` — Tests verify `PaymentMethod` enum labels, `paymentMethod` stored on FA entries, `paymentMethod` stored on all transaction records, `paymentMethod` forwarded through `copyWith`. |
| **Missing behavior** | UI for payment method selection in transaction screens (deferred to separate UI phase). |
| **Dependencies** | ACC-007 |
| **Proposed phase** | Phase 72 |
| **Acceptance evidence** | `PaymentMethod` enum functional; all transaction models and FA entries carry payment method; Arabic labels correct. |

---

### ACC-011: Internal transfers

| Field | Value |
|---|---|
| **Status** | IMPLEMENTED |
| **Source evidence** | Future requirement — transferring between treasury/bank/wallet. |
| **Implementation evidence** | `lib/core/financial_accounts/financial_transfer.dart` — `FinancialTransfer` model with `id`, `displayNumber`, `clientRequestId`, `transferReference`, `sourceAccountId`, `destinationAccountId`, `amountQirsh`, `effectiveDate`, `createdAt`, `createdByUserId`, `sourceEntryId`, `destinationEntryId`, `note`, `originalTransferId`, `reversalTransferId`, `reversalReason`. `lib/core/financial_accounts/financial_account_repository.dart` — `createTransfer()` creates atomic paired entries (source outflow + destination inflow); `reverseTransfer()` creates documented paired reversal with mandatory reason; `listTransfers()` for transfer history. `lib/core/financial_accounts/financial_account_entry.dart` — `FinancialAccountEntrySource` includes `transferOut`, `transferIn`, `transferReversalOut`, `transferReversalIn`. `lib/features/financial_accounts/financial_transfers_screen.dart` — Arabic RTL transfer review/confirmation UI, transfer history, reversal action. |
| **Test evidence** | `test/phase76_internal_financial_transfers_test.dart` — 110 tests covering: creation happy path, same-account rejection, inactive account rejection, zero/negative amount rejection, future date rejection, insufficient balance rejection, idempotency, atomic rollback, duplicate reversal rejection, source/reversal linkage, balance conservation, permission enforcement, backup/restore round-trip. |
| **Missing behavior** | None for Phase 76 scope. Transfer fees deferred (DC-U013: no first-release fees). |
| **Dependencies** | ACC-007 |
| **Proposed phase** | Phase 76 |
| **Acceptance evidence** | Transfer creates two equal/opposite linked ledger entries atomically; source balance sufficient check enforced; owner-only create/reverse; documented paired reversal with mandatory reason; immutable saved transfers; idempotent retry; Arabic RTL review/confirmation UI; backup/restore preserves transfer relationships. |

---

### ACC-012: Daily cash closing

| Field | Value |
|---|---|
| **Status** | PLANNED — SCOPE FROZEN IN PHASE 73 |
| **Source evidence** | Future requirement — end-of-day cash reconciliation. |
| **Implementation evidence** | None. The daily activity report (`RPT-001`) provides cash in/out calculations but not a formal closing process. |
| **Test evidence** | None |
| **Missing behavior** | Cash closing process, expected vs. actual cash, discrepancy recording. |
| **Dependencies** | ACC-007, ACC-010 |
| **Proposed phase** | Planning: Phase 73. Implementation is blocked by open owner decision `DC-U006`. |
| **Acceptance evidence** | Not implemented. No hard daily close, accounting-period lock, posting lock, automatic carry-forward, irreversible close, or backdated-entry restriction may be implemented until an explicit owner decision is recorded. |

---

### ACC-013: Financial reports

| Field | Value |
|---|---|
| **Status** | PARTIALLY IMPLEMENTED |
| **Source evidence** | Phase 79 implemented 4 financial reports; additional reports remain planned. |
| **Implementation evidence** | Phase 79 implemented: Account Balance Report, Account Statement Report, Payment Method Report, Transfer Report. All read-only from financial-account ledger. PDF and CSV export. |
| **Test evidence** | `test/phase79_account_based_financial_reports_test.dart` — 65 tests |
| **Missing behavior** | Inflows/outflows report, collection-by-account report, supplier-payment-by-account report, expense-by-account report, fee tracking, reconciliation report. |
| **Dependencies** | ACC-007 ✅, ACC-008 ✅, ACC-011 ✅ |
| **Proposed phase** | Planning: Phase 73. Partial implementation: Phase 79. Remaining reports deferred until Split Payments and Advances UI are complete. |
| **Acceptance evidence** | 4 reports implemented and tested. Remaining reports must be derived from the auditable financial-account ledger. |

---

## Inventory (INV)

### INV-001: Stock movements (opening, purchase, sale, manual, cancellation)

| Field | Value |
|---|---|
| **Status** | IMPLEMENTED |
| **Source evidence** | Stock movements are the backbone of inventory management. |
| **Implementation evidence** | `lib/core/inventory/stock_movement.dart:1` — `StockMovementType` enum with 7 types. `lib/core/inventory/inventory_repository.dart:20` — Full movement creation with validation. `lib/core/inventory/inventory_controller.dart:8` — Controller with manual increase/decrease/opening balance. |
| **Test evidence** | `test/inventory_test.dart` — Movement type tests. `test/phase49b_stock_adjustment_report_test.dart` — Adjustment tests. |
| **Missing behavior** | None |
| **Dependencies** | None |
| **Proposed phase** | Phase 1 |
| **Acceptance evidence** | All 7 movement types create proper signed quantities; stock cannot go negative. |

---

### INV-002: Stock balance calculation

| Field | Value |
|---|---|
| **Status** | IMPLEMENTED |
| **Source evidence** | Stock balance is the sum of all signed movements. |
| **Implementation evidence** | `lib/core/inventory/inventory_repository.dart:74` — `currentStockKg()` sums `signedQuantityKg` across all movements for a product. `allProductBalancesKg()` returns map of all product balances. |
| **Test evidence** | `test/inventory_test.dart` — Balance calculation after various movement types. |
| **Missing behavior** | None |
| **Dependencies** | INV-001 |
| **Proposed phase** | Phase 1 |
| **Acceptance evidence** | Balance = Σ signedQuantityKg where voided movements contribute 0. |

---

### INV-003: Stock take workflow

| Field | Value |
|---|---|
| **Status** | IMPLEMENTED |
| **Source evidence** | Stock take reconciles physical count with system count. |
| **Implementation evidence** | `lib/features/inventory/stock_take_screen.dart` — Stock take screen UI. |
| **Test evidence** | `test/phase49a_stock_take_test.dart` — Stock take workflow tests. |
| **Missing behavior** | None |
| **Dependencies** | INV-001, INV-002 |
| **Proposed phase** | Phase 49a |
| **Acceptance evidence** | Stock take screen implemented and tested. |

---

### INV-004: Variance report

| Field | Value |
|---|---|
| **Status** | IMPLEMENTED |
| **Source evidence** | Variance report shows difference between system and physical stock. |
| **Implementation evidence** | `lib/features/inventory/stock_adjustment_report_screen.dart` — Stock adjustment report UI. |
| **Test evidence** | `test/phase49b_stock_adjustment_report_test.dart` — Adjustment report tests. |
| **Missing behavior** | None |
| **Dependencies** | INV-003 |
| **Proposed phase** | Phase 49b |
| **Acceptance evidence** | Stock adjustment report screen implemented and tested. |

---

### INV-005: PDF for stock adjustment

| Field | Value |
|---|---|
| **Status** | NOT IMPLEMENTED |
| **Source evidence** | Future requirement for printable stock adjustment documents. |
| **Implementation evidence** | None. PDF export exists for sales, purchases, statements, and daily reports but not for stock adjustments. |
| **Test evidence** | None |
| **Missing behavior** | PDF generation for stock adjustment/variance reports. |
| **Dependencies** | INV-004 |
| **Proposed phase** | Deferred |
| **Acceptance evidence** | N/A |

---

## Cancellation (CAN)

### CAN-001: Sale cancellation with stock reversal

| Field | Value |
|---|---|
| **Status** | IMPLEMENTED |
| **Source evidence** | Cancelling a sale reverses the stock movement. |
| **Implementation evidence** | `lib/core/sales/sale_repository.dart:117` — `cancelSale()` creates `saleCancellation` stock movement for each item, sets `CancellationMetadata`. |
| **Test evidence** | `test/phase36g_ui_clarity_cancellation_safety_test.dart` — Cancellation safety tests. `test/phase59_sale_cancellation_customer_ledger_symmetry_test.dart` — Full cancellation flow. |
| **Missing behavior** | None |
| **Dependencies** | INV-001 |
| **Proposed phase** | Phase 36g |
| **Acceptance evidence** | Sale cancellation creates reversal stock movement; sale marked with `CancellationMetadata`. |

---

### CAN-002: Purchase cancellation with stock reversal

| Field | Value |
|---|---|
| **Status** | IMPLEMENTED |
| **Source evidence** | Cancelling a purchase reverses the stock movement. |
| **Implementation evidence** | `lib/core/purchases/purchase_repository.dart:89` — `cancelPurchaseIntake()` creates `purchaseCancellation` movement, validates stock ≥ quantity to reverse. |
| **Test evidence** | `test/phase36g_ui_clarity_cancellation_safety_test.dart` |
| **Missing behavior** | None |
| **Dependencies** | INV-001 |
| **Proposed phase** | Phase 36g |
| **Acceptance evidence** | Purchase cancellation creates reversal movement; blocked if stock insufficient. |

---

### CAN-003: Sale cancellation with customer account reversal (Phase 59)

| Field | Value |
|---|---|
| **Status** | IMPLEMENTED |
| **Source evidence** | Phase 59 added customer ledger reversal on sale cancellation. |
| **Implementation evidence** | `lib/core/customer_accounts/customer_account_repository.dart:328` — `reverseSaleEntry()`. Called from sale cancellation flow. |
| **Test evidence** | `test/phase59_sale_cancellation_customer_ledger_symmetry_test.dart` — Symmetry validation. |
| **Missing behavior** | None |
| **Dependencies** | ACC-001 |
| **Proposed phase** | Phase 59 |
| **Acceptance evidence** | Reversal entry created; blocked if collections exist. |

---

### CAN-004: Purchase cancellation with supplier account reversal

| Field | Value |
|---|---|
| **Status** | IMPLEMENTED |
| **Source evidence** | Purchase cancellation reverses supplier ledger entry. |
| **Implementation evidence** | `lib/core/supplier_accounts/supplier_account_repository.dart:209` — `reversePurchaseEntry()`. Called from purchase cancellation in `lib/core/purchases/purchase_repository.dart:144`. |
| **Test evidence** | `test/phase36_supplier_accounts_dashboard_test.dart` |
| **Missing behavior** | None |
| **Dependencies** | ACC-002 |
| **Proposed phase** | Phase 36 |
| **Acceptance evidence** | Reversal entry created; blocked if payments exist. |

---

### CAN-005: Collection cancellation

| Field | Value |
|---|---|
| **Status** | IMPLEMENTED |
| **Source evidence** | Future requirement — reversing a customer collection. |
| **Implementation evidence** | `CustomerAccountRepository.cancelCollection()` creates an immutable cancellation operation, compensating customer-ledger entry, linked financial-account reversal, and audit trail in one `RepositoryTransaction`. |
| **Test evidence** | `test/can_005_006_007_financial_reversals_test.dart` |
| **Missing behavior** | None |
| **Dependencies** | ACC-001 |
| **Proposed phase** | CAN-005/006/007 financial reversals |
| **Acceptance evidence** | Original collection is retained, reversal links are recorded, duplicate/replay attempts are rejected, and fault-injection rollback is verified. |

---

### CAN-006: Payment cancellation

| Field | Value |
|---|---|
| **Status** | IMPLEMENTED |
| **Source evidence** | Future requirement — reversing a supplier payment. |
| **Implementation evidence** | `SupplierAccountRepository.cancelPayment()` creates an immutable cancellation operation, compensating supplier-ledger entry, linked financial-account reversal, and audit trail in one `RepositoryTransaction`. |
| **Test evidence** | `test/can_005_006_007_financial_reversals_test.dart` |
| **Missing behavior** | None |
| **Dependencies** | ACC-002 |
| **Proposed phase** | CAN-005/006/007 financial reversals |
| **Acceptance evidence** | Original payment is retained, reversal links are recorded, duplicate/replay attempts are rejected, and fault-injection rollback is verified. |

---

### CAN-007: Financial account reversal

| Field | Value |
|---|---|
| **Status** | IMPLEMENTED |
| **Source evidence** | Requires ACC-007 financial account model. |
| **Implementation evidence** | CAN-005 and CAN-006 create compensating financial-account entries with `cancellationReversal`, a new reversal document id, and `reversalOf` linkage to the original collection/payment entry. |
| **Test evidence** | `test/can_005_006_007_financial_reversals_test.dart` |
| **Missing behavior** | None |
| **Dependencies** | ACC-007 ✅, CAN-005, CAN-006 |
| **Proposed phase** | CAN-005/006/007 financial reversals |
| **Acceptance evidence** | Financial, customer/supplier, and audit state commits or rolls back together. |

---

### CAN-008: Cancellation permission (owner only)

| Field | Value |
|---|---|
| **Status** | IMPLEMENTED |
| **Source evidence** | Only the owner can cancel posted documents. |
| **Implementation evidence** | `lib/core/auth/permissions.dart:49` — `canCancelInvoice: true` only for owner; `false` for employee. `lib/core/purchases/purchase_controller.dart:145` — `_canCancelPostedDocument()` checks `canCancelInvoice`. `lib/core/sales/sale_controller.dart` — Same permission gate. |
| **Test evidence** | `test/phase36g_ui_clarity_cancellation_safety_test.dart` — Permission tests. `test/auth_permissions_test.dart` — Permission flag tests. |
| **Missing behavior** | None |
| **Dependencies** | AUTH-002 |
| **Proposed phase** | Phase 36g |
| **Acceptance evidence** | Employee cannot cancel; only owner has `canCancelInvoice = true`. |

---

## Documents (DOC)

### DOC-001: Printable sales invoice

| Field | Value |
|---|---|
| **Status** | IMPLEMENTED |
| **Source evidence** | Sales invoices must be printable for customers. |
| **Implementation evidence** | `lib/features/prints/printable_sales_invoice_view.dart` — Sales invoice printable view. `lib/features/prints/printable_document_scaffold.dart` — Shared document scaffold for print layout. |
| **Test evidence** | `test/phase40_printable_business_documents_test.dart` — Printable document tests. `test/phase44_final_owner_acceptance_after_pdf_whatsapp_test.dart` — Final acceptance. |
| **Missing behavior** | None |
| **Dependencies** | OPS-004 |
| **Proposed phase** | Phase 40 |
| **Acceptance evidence** | Sales invoice printable view implemented. |

---

### DOC-002: Printable purchase invoice

| Field | Value |
|---|---|
| **Status** | IMPLEMENTED |
| **Source evidence** | Purchase invoices must be printable. |
| **Implementation evidence** | `lib/features/prints/printable_purchase_invoice_view.dart` — Purchase invoice printable view. |
| **Test evidence** | `test/phase40_printable_business_documents_test.dart` |
| **Missing behavior** | None |
| **Dependencies** | OPS-009 |
| **Proposed phase** | Phase 40 |
| **Acceptance evidence** | Purchase invoice printable view implemented. |

---

### DOC-003: Printable customer statement

| Field | Value |
|---|---|
| **Status** | IMPLEMENTED |
| **Source evidence** | Customer statements show ledger history. |
| **Implementation evidence** | `lib/features/prints/printable_customer_statement_view.dart` — Customer statement printable view. |
| **Test evidence** | `test/phase40_printable_business_documents_test.dart` |
| **Missing behavior** | None |
| **Dependencies** | ACC-001 |
| **Proposed phase** | Phase 40 |
| **Acceptance evidence** | Customer statement printable view implemented. |

---

### DOC-004: Printable supplier statement

| Field | Value |
|---|---|
| **Status** | IMPLEMENTED |
| **Source evidence** | Supplier statements show ledger history. |
| **Implementation evidence** | `lib/features/prints/printable_supplier_statement_view.dart` — Supplier statement printable view. |
| **Test evidence** | `test/phase40_printable_business_documents_test.dart` |
| **Missing behavior** | None |
| **Dependencies** | ACC-002 |
| **Proposed phase** | Phase 40 |
| **Acceptance evidence** | Supplier statement printable view implemented. |

---

### DOC-005: Printable daily report

| Field | Value |
|---|---|
| **Status** | IMPLEMENTED |
| **Source evidence** | Daily report summarizes daily operations. |
| **Implementation evidence** | `lib/features/prints/printable_daily_report_view.dart` — Daily report printable view. |
| **Test evidence** | `test/phase40_printable_business_documents_test.dart` |
| **Missing behavior** | None |
| **Dependencies** | RPT-001 |
| **Proposed phase** | Phase 40 |
| **Acceptance evidence** | Daily report printable view implemented. |

---

### DOC-006: PDF export (all 5 document types)

| Field | Value |
|---|---|
| **Status** | IMPLEMENTED |
| **Source evidence** | All documents must be exportable as PDF files. |
| **Implementation evidence** | `lib/features/prints/printable_document_scaffold.dart` — Shared PDF generation scaffold. Phase 42 added PDF export foundation. |
| **Test evidence** | `test/phase42_pdf_export_foundation_test.dart` — PDF export tests for all 5 document types. |
| **Missing behavior** | None |
| **Dependencies** | DOC-001 through DOC-005 |
| **Proposed phase** | Phase 42 |
| **Acceptance evidence** | PDF export implemented for sales invoice, purchase invoice, customer statement, supplier statement, daily report. |

---

### DOC-007: WhatsApp assisted sharing

| Field | Value |
|---|---|
| **Status** | IMPLEMENTED |
| **Source evidence** | Documents can be shared via WhatsApp with user guidance. |
| **Implementation evidence** | `lib/core/sharing/whatsapp_assisted_share_service.dart:5` — `WhatsAppAssistedShareService` opens WhatsApp with prepared Arabic message, phone normalization, web fallback. `lib/core/sharing/phone_number_normalizer.dart` — Phone number normalization. `lib/core/sharing/whatsapp_message_templates.dart` — Message templates. |
| **Test evidence** | `test/phase43_whatsapp_assisted_sharing_test.dart` — WhatsApp sharing tests. |
| **Missing behavior** | None |
| **Dependencies** | DOC-006 |
| **Proposed phase** | Phase 43 |
| **Acceptance evidence** | WhatsApp URL launched with prepared message; web fallback; instruction snackbar shown. |

---

### DOC-008: Cancellation status display in documents

| Field | Value |
|---|---|
| **Status** | IMPLEMENTED |
| **Source evidence** | Cancelled documents show cancellation status in their display. |
| **Implementation evidence** | `lib/core/documents/document_history.dart:22` — `DocumentHistoryStatus` enum (`active`, `cancelled`). `lib/core/documents/cancellation_metadata.dart:1` — `CancellationMetadata` with `cancelledAt`, `cancelledByUserId`, `cancellationReason`. Cancelled status displayed in document history. |
| **Test evidence** | `test/document_history_test.dart` — Status display tests. |
| **Missing behavior** | None |
| **Dependencies** | CAN-001, CAN-002 |
| **Proposed phase** | Phase 1 |
| **Acceptance evidence** | Cancelled documents display with "ملغي" (cancelled) status in document history. |

---

## Backup (BKP)

### BKP-001: JSON backup export

| Field | Value |
|---|---|
| **Status** | IMPLEMENTED |
| **Source evidence** | Business data must be exportable as JSON backup. |
| **Implementation evidence** | `lib/core/backup/backup_export.dart:30` — `BackupExportService.createBackup()` exports all 13 data categories (products, movements, suppliers, purchases, sales, document history, customers, customer ledger, customer collections, supplier ledger, supplier payments, expenses, audit logs) with checksum. `lib/features/backup/backup_export_screen.dart` — Export UI. |
| **Test evidence** | `test/phase13_backup_export_test.dart` — Backup export tests. |
| **Missing behavior** | None |
| **Dependencies** | None |
| **Proposed phase** | Phase 13 |
| **Acceptance evidence** | JSON export with metadata, counts, data, and adler32 checksum; sensitive key validation. |

---

### BKP-002: JSON backup restore (to empty system)

| Field | Value |
|---|---|
| **Status** | IMPLEMENTED |
| **Source evidence** | Backup can be restored but only to an empty system. |
| **Implementation evidence** | `lib/core/backup/backup_restore_service.dart:35` — `BackupRestoreService.restoreToEmpty()` — validates preview, checks system is empty, restores all 13 data categories, restores business identity with logo. |
| **Test evidence** | `test/phase16_restore_empty_system_test.dart` — Restore to empty system tests. |
| **Missing behavior** | None |
| **Dependencies** | BKP-001 |
| **Proposed phase** | Phase 16 |
| **Acceptance evidence** | Restore only succeeds on empty system; all data categories restored; relationship validation. |

---

### BKP-003: Restore preview

| Field | Value |
|---|---|
| **Status** | IMPLEMENTED |
| **Source evidence** | User must see what a backup contains before restoring. |
| **Implementation evidence** | `lib/core/backup/backup_restore_preview.dart:3` — `BackupRestorePreviewService.preview()` validates JSON structure, checks version compatibility, returns counts summary. `lib/features/backup/backup_restore_preview_screen.dart` — Preview UI. |
| **Test evidence** | `test/phase15_restore_preview_test.dart` — Preview validation tests. |
| **Missing behavior** | None |
| **Dependencies** | BKP-001 |
| **Proposed phase** | Phase 15 |
| **Acceptance evidence** | Preview shows counts, version, generated date; validates metadata/counts/data structure. |

---

### BKP-004: Pre-restore validation

| Field | Value |
|---|---|
| **Status** | IMPLEMENTED |
| **Source evidence** | Restore must validate data integrity before writing. |
| **Implementation evidence** | `lib/core/backup/backup_restore_service.dart:495` — `_validateRelationships()` checks product IDs, supplier IDs, movement IDs, purchase/sale totals vs. line items, cancellation references. `lib/core/backup/backup_restore_preview.dart:33` — Structural validation of JSON, version, sensitive keys. |
| **Test evidence** | `test/phase15_restore_preview_test.dart` — Validation edge cases. `test/phase16_restore_empty_system_test.dart` — Relationship validation. |
| **Missing behavior** | None |
| **Dependencies** | BKP-001 |
| **Proposed phase** | Phase 15 |
| **Acceptance evidence** | Structural, version, sensitive key, and relationship validation all enforced. |

---

### BKP-005: Backup v3 with logo

| Field | Value |
|---|---|
| **Status** | IMPLEMENTED |
| **Source evidence** | Backup version 3 includes business logo as base64. |
| **Implementation evidence** | `lib/core/backup/backup_export.dart:59` — `backupVersion = 3`. `lib/core/backup/backup_export.dart:393` — `_identityWithLogoJson()` exports logo as base64 with SHA256 hash. `lib/core/backup/backup_restore_service.dart:638` — Logo restore with integrity verification. |
| **Test evidence** | `test/phase68_business_logo_invoice_windows_icon_test.dart` — Logo backup/restore tests. |
| **Missing behavior** | None |
| **Dependencies** | BRD-002 |
| **Proposed phase** | Phase 68 |
| **Acceptance evidence** | Logo exported as base64 in backup; restored with SHA256 verification; format/type validation. |

---

### BKP-006: Backward compatibility (v1, v2, v3)

| Field | Value |
|---|---|
| **Status** | IMPLEMENTED |
| **Source evidence** | Restore must accept backup versions 1, 2, and 3. |
| **Implementation evidence** | `lib/core/backup/backup_restore_preview.dart:6` — `supportedBackupVersions = {1, 2, 3}`. `lib/core/backup/backup_restore_service.dart:260` — `_optionalList()` handles missing fields in older versions. |
| **Test evidence** | `test/phase15_restore_preview_test.dart` — Version compatibility tests. |
| **Missing behavior** | None |
| **Dependencies** | None |
| **Proposed phase** | Phase 15 |
| **Acceptance evidence** | Versions 1, 2, and 3 all accepted; optional fields handled gracefully. |

---

### BKP-007: Business data wipe with pre-wipe backup

| Field | Value |
|---|---|
| **Status** | IMPLEMENTED |
| **Source evidence** | Owner can wipe all business data after automatic backup. |
| **Implementation evidence** | `lib/core/backup/business_data_wipe_service.dart:17` — `BusinessDataWipeService.wipeBusinessData()` — creates backup, validates, saves, then clears all 10 repositories. Requires confirmation phrase. `lib/features/backup/data_wipe_screen.dart` — Wipe UI. |
| **Test evidence** | `test/phase17_owner_data_wipe_test.dart` — Data wipe tests. |
| **Missing behavior** | None |
| **Dependencies** | BKP-001 |
| **Proposed phase** | Phase 17 |
| **Acceptance evidence** | Backup created before wipe; confirmation phrase required; all repositories cleared; counts returned. |

---

### BKP-008: Transaction-safe restore

| Field | Value |
|---|---|
| **Status** | NOT IMPLEMENTED |
| **Source evidence** | Future requirement — atomic restore with rollback. |
| **Implementation evidence** | None. Current restore is sequential writes without transaction/rollback. Comment at `lib/core/backup/backup_restore_service.dart:111` acknowledges this limitation. |
| **Test evidence** | None |
| **Missing behavior** | Transaction wrapping with rollback on failure. |
| **Dependencies** | Requires in-memory repository transaction support |
| **Proposed phase** | Deferred |
| **Acceptance evidence** | N/A |

---

### BKP-009: Transaction-safe wipe

| Field | Value |
|---|---|
| **Status** | NOT IMPLEMENTED |
| **Source evidence** | Future requirement — atomic wipe with rollback. |
| **Implementation evidence** | None. Current wipe is sequential without transaction/rollback. |
| **Test evidence** | None |
| **Missing behavior** | Transaction wrapping for wipe operation. |
| **Dependencies** | Requires in-memory repository transaction support |
| **Proposed phase** | Deferred |
| **Acceptance evidence** | N/A |

---

## Authentication (AUTH)

### AUTH-001: Owner/employee roles

| Field | Value |
|---|---|
| **Status** | IMPLEMENTED |
| **Source evidence** | Two roles: owner (full access) and employee (limited). |
| **Implementation evidence** | `lib/core/auth/user_role.dart:1` — `UserRole` enum with `owner`, `employee`. Arabic labels. `lib/core/auth/app_user.dart:4` — `AppUser` with `role` field and computed `permissions`. |
| **Test evidence** | `test/auth_permissions_test.dart` — Role-based permission tests. `test/auth_controller_test.dart` — Authentication tests. |
| **Missing behavior** | None |
| **Dependencies** | None |
| **Proposed phase** | Phase 1 |
| **Acceptance evidence** | Two roles with distinct permission sets; role persisted in user record. |

---

### AUTH-002: 16 permission flags

| Field | Value |
|---|---|
| **Status** | IMPLEMENTED |
| **Source evidence** | 16 fine-grained permission flags control access. |
| **Implementation evidence** | `lib/core/auth/permissions.dart:3` — `Permissions` class with 16 boolean flags: `canCreateSale`, `canCreatePurchase`, `canCreateCustomerPayment`, `canCreateSupplierPayment`, `canCreateExpense`, `canCreateStockAdjustment`, `canManageSuppliers`, `canCreatePurchaseIntake`, `canCancelInvoice`, `canManageProducts`, `canViewReports`, `canViewAuditLogs`, `canAccessSettings`, `canExportBackups`, `canWipeBusinessData`, `canApproveBelowMinimumPrice`. Owner gets all 16; employee gets 4. |
| **Test evidence** | `test/auth_permissions_test.dart` — All 16 flags tested per role. |
| **Missing behavior** | None |
| **Dependencies** | None |
| **Proposed phase** | Phase 1 |
| **Acceptance evidence** | 16 flags defined; owner has all true; employee has 4 true, 12 false. |

---

### AUTH-003: Login screen

| Field | Value |
|---|---|
| **Status** | IMPLEMENTED |
| **Source evidence** | Phone + password login for existing users. |
| **Implementation evidence** | `lib/features/auth/login_screen.dart` — Login screen UI. `lib/core/auth/auth_controller.dart:38` — `signIn()` with phone/password validation. `lib/core/auth/auth_repository.dart:90` — `LocalAuthRepository.signIn()`. |
| **Test evidence** | `test/auth_controller_test.dart` — Login success/failure tests. |
| **Missing behavior** | None |
| **Dependencies** | None |
| **Proposed phase** | Phase 1 |
| **Acceptance evidence** | Login with phone+password; invalid credentials rejected; inactive users rejected. |

---

### AUTH-004: First owner setup

| Field | Value |
|---|---|
| **Status** | IMPLEMENTED |
| **Source evidence** | First launch requires creating the owner account. |
| **Implementation evidence** | `lib/core/auth/auth_controller.dart:78` — `createFirstOwner()` with name, phone, password validation. `lib/core/auth/auth_repository.dart:114` — `createFirstOwner()` creates owner with role=owner, validates no existing owner. `lib/features/auth/first_owner_setup_screen.dart` — First owner setup UI. `lib/core/auth/auth_state.dart` — `AuthState.needsFirstOwner()` state. |
| **Test evidence** | `test/auth_controller_test.dart` — First owner creation tests. |
| **Missing behavior** | None |
| **Dependencies** | None |
| **Proposed phase** | Phase 1 |
| **Acceptance evidence** | First owner created; password ≥ 6 chars; cannot create second owner; auto-login after creation. |

---

### AUTH-005: Role-based UI filtering

| Field | Value |
|---|---|
| **Status** | IMPLEMENTED |
| **Source evidence** | UI elements are hidden/shown based on user permissions. |
| **Implementation evidence** | `lib/core/auth/permissions.dart:87` — `hasFullAccess` getter. Controllers throughout the codebase check `user.permissions.canXxx` before enabling actions (e.g., `product_controller.dart:93`, `inventory_controller.dart:143`, `purchase_controller.dart:130`, `customer_controller.dart:202`). `lib/features/dashboard/dashboard_shell.dart` — Navigation filtered by permissions. |
| **Test evidence** | `test/auth_permissions_test.dart` — Permission-based access tests. |
| **Missing behavior** | None |
| **Dependencies** | AUTH-001, AUTH-002 |
| **Proposed phase** | Phase 1 |
| **Acceptance evidence** | UI controls gated by permission checks; employees see limited menu. |

---

## Audit (AUD)

### AUD-001: Audit log entries

| Field | Value |
|---|---|
| **Status** | IMPLEMENTED |
| **Source evidence** | System records audit trail for key operations. |
| **Implementation evidence** | `lib/core/audit/audit_log_entry.dart:1` — `AuditLogEntry` with `timestamp`, `actionType`, `descriptionAr`, `referenceId`. `lib/core/audit/audit_log_repository.dart:10` — `LocalAuditLogRepository` with `record()` and `listLogs()` (sorted by timestamp desc). |
| **Test evidence** | `test/auth_permissions_test.dart` — Audit-related permission tests. |
| **Missing behavior** | None |
| **Dependencies** | None |
| **Proposed phase** | Phase 1 |
| **Acceptance evidence** | Entries created for customer CRUD, collections, opening balances, supplier purchases/payments, expenses, theme changes, sale/purchase reversals. |

---

### AUD-002: Audit log screen

| Field | Value |
|---|---|
| **Status** | IMPLEMENTED |
| **Source evidence** | Owner can view audit log history. |
| **Implementation evidence** | `lib/features/audit/audit_logs_screen.dart` — Audit log screen UI. `lib/core/audit/audit_log_controller.dart` — Audit log controller. |
| **Test evidence** | `test/auth_permissions_test.dart` — `canViewAuditLogs` flag tested. |
| **Missing behavior** | None |
| **Dependencies** | AUD-001, AUTH-002 |
| **Proposed phase** | Phase 1 |
| **Acceptance evidence** | Audit log screen accessible only to users with `canViewAuditLogs = true` (owner only). |

---

### AUD-003: Audit trail for financial operations

| Field | Value |
|---|---|
| **Status** | IMPLEMENTED |
| **Source evidence** | Financial operations (credit sales, collections, payments, reversals) create audit entries. |
| **Implementation evidence** | `lib/core/customer_accounts/customer_account_repository.dart:150` — Audit entry for `customer.credit_sale.posted`, `customer.cash_sale.posted`, `customer.collection.recorded`, `customer.opening-balance.posted`, `customer.sale.reversed`. `lib/core/supplier_accounts/supplier_account_repository.dart:143` — Audit entry for `supplier.purchase.posted`, `supplier.payment.recorded`, `supplier.opening-balance.posted`, `supplier.purchase.reversed`. `lib/core/expenses/expense_repository.dart:50` — Audit entry for `expense.created`. |
| **Test evidence** | Indirectly covered by financial operation tests. |
| **Missing behavior** | None |
| **Dependencies** | AUD-001 |
| **Proposed phase** | Phase 34+ |
| **Acceptance evidence** | All financial operations create audit entries with action type, Arabic description, and reference ID. |

---

## Branding (BRD)

### BRD-001: Business identity (establishment name)

| Field | Value |
|---|---|
| **Status** | IMPLEMENTED |
| **Source evidence** | Business establishment name is configurable. |
| **Implementation evidence** | `lib/core/business_identity/business_identity.dart:80` — `BusinessIdentity` with `establishmentName`, `displayName` (defaults to "نظام إدارة مخازن الحبوب"). `lib/core/business_identity/business_identity_controller.dart:7` — `BusinessIdentityController` with `saveEstablishmentName()`. |
| **Test evidence** | `test/phase68_business_logo_invoice_windows_icon_test.dart` — Business identity tests. |
| **Missing behavior** | None |
| **Dependencies** | None |
| **Proposed phase** | Phase 68 |
| **Acceptance evidence** | Establishment name saved and displayed; defaults used when empty. |

---

### BRD-002: Logo upload

| Field | Value |
|---|---|
| **Status** | IMPLEMENTED |
| **Source evidence** | Business logo can be uploaded and displayed. |
| **Implementation evidence** | `lib/core/business_identity/business_identity.dart:1` — `LogoMetadata` with `managedFileName`, `mimeType`, `sha256`, `byteLength`, `width`, `height`. `lib/core/business_identity/business_identity_controller.dart:45` — `saveLogo()` with file save, old logo cleanup. `lib/core/business_identity/business_identity_repository.dart` — Repository for logo file management. |
| **Test evidence** | `test/phase68_business_logo_invoice_windows_icon_test.dart` — Logo upload and display tests. |
| **Missing behavior** | None |
| **Dependencies** | None |
| **Proposed phase** | Phase 68 |
| **Acceptance evidence** | Logo uploaded, saved, SHA256 tracked, old logo cleaned up; logo appears in invoices. |

---

### BRD-003: Theme settings (light/dark)

| Field | Value |
|---|---|
| **Status** | IMPLEMENTED |
| **Source evidence** | App supports multiple theme presets. |
| **Implementation evidence** | `lib/core/theme/app_theme_preset.dart` — `AppThemePreset` enum with multiple presets (olive, etc.). `lib/core/theme/theme_settings_repository.dart:12` — `LocalThemeSettingsRepository` persists theme to file. `lib/core/theme/theme_controller.dart:5` — `ThemeController` with `selectPreset()`. `lib/core/theme/app_theme.dart` — Theme generation from preset. |
| **Test evidence** | `test/phase67_navigation_theme_branding_test.dart` — Theme switching tests. |
| **Missing behavior** | None — supports multiple color presets (not strictly light/dark toggle but equivalent). |
| **Dependencies** | None |
| **Proposed phase** | Phase 67 |
| **Acceptance evidence** | Theme presets selectable; persisted to file; audit logged on change. |

---

### BRD-004: Arabic RTL UI

| Field | Value |
|---|---|
| **Status** | IMPLEMENTED |
| **Source evidence** | Full Arabic right-to-left UI throughout the application. |
| **Implementation evidence** | `assets/fonts/Amiri-Bold.ttf` and `Amiri-Regular.ttf` — Arabic font files. All error messages, labels, and descriptions throughout the codebase are in Arabic (e.g., `product_controller.dart:98`, `customer_controller.dart:204`). `lib/shared/layout/responsive_layout.dart` — Layout handling. All UI screens use `textDirection: TextDirection.rtl`. |
| **Test evidence** | `test/phase11_ux_test.dart` — UX tests. `test/phase32_pilot_acceptance_test.dart` — Arabic UI acceptance. |
| **Missing behavior** | None |
| **Dependencies** | None |
| **Proposed phase** | Phase 11 |
| **Acceptance evidence** | All text in Arabic; RTL layout throughout; Arabic fonts bundled. |

---

## Cloud (CLD)

### CLD-001: Cloud sync

| Field | Value |
|---|---|
| **Status** | NOT IMPLEMENTED |
| **Source evidence** | Future requirement for cloud data synchronization. |
| **Implementation evidence** | None. App is local-only (in-memory repositories). Firebase bootstrap files exist (`lib/core/firebase/firebase_bootstrap.dart`, `lib/core/firebase/firebase_options.dart`) but are scaffolding only. |
| **Test evidence** | `test/phase53_cloud_migration_readiness_test.dart` — Readiness assessment only, not implementation. |
| **Missing behavior** | All cloud sync functionality. |
| **Dependencies** | CLD-002 |
| **Proposed phase** | Deferred |
| **Acceptance evidence** | N/A |

---

### CLD-002: Backend server/API

| Field | Value |
|---|---|
| **Status** | NOT IMPLEMENTED |
| **Source evidence** | Future requirement — no backend exists. |
| **Implementation evidence** | None. |
| **Test evidence** | None |
| **Missing behavior** | Backend API server. |
| **Dependencies** | None |
| **Proposed phase** | Deferred |
| **Acceptance evidence** | N/A |

---

### CLD-003: Multi-device support

| Field | Value |
|---|---|
| **Status** | NOT IMPLEMENTED |
| **Source evidence** | Future requirement — single-device only currently. |
| **Implementation evidence** | None. |
| **Test evidence** | None |
| **Missing behavior** | Multi-device data access and synchronization. |
| **Dependencies** | CLD-002 |
| **Proposed phase** | Deferred |
| **Acceptance evidence** | N/A |

---

### CLD-004: Tenant management

| Field | Value |
|---|---|
| **Status** | NOT IMPLEMENTED |
| **Source evidence** | Future requirement — single-tenant currently. |
| **Implementation evidence** | None. |
| **Test evidence** | None |
| **Missing behavior** | Multi-tenant isolation. |
| **Dependencies** | CLD-002 |
| **Proposed phase** | Deferred |
| **Acceptance evidence** | N/A |

---

### CLD-005: User/device identity

| Field | Value |
|---|---|
| **Status** | NOT IMPLEMENTED |
| **Source evidence** | Future requirement for cloud user identity. |
| **Implementation evidence** | None. Current identity is local-only. |
| **Test evidence** | None |
| **Missing behavior** | Cloud-based user/device identity. |
| **Dependencies** | CLD-002 |
| **Proposed phase** | Deferred |
| **Acceptance evidence** | N/A |

---

### CLD-006: Offline queue

| Field | Value |
|---|---|
| **Status** | NOT IMPLEMENTED |
| **Source evidence** | Future requirement for offline transaction queuing. |
| **Implementation evidence** | None. |
| **Test evidence** | None |
| **Missing behavior** | Offline queue with sync-on-reconnect. |
| **Dependencies** | CLD-001 |
| **Proposed phase** | Deferred |
| **Acceptance evidence** | N/A |

---

### CLD-007: Conflict resolution

| Field | Value |
|---|---|
| **Status** | NOT IMPLEMENTED |
| **Source evidence** | Future requirement for multi-device conflict resolution. |
| **Implementation evidence** | None. |
| **Test evidence** | None |
| **Missing behavior** | Conflict detection and resolution strategy. |
| **Dependencies** | CLD-003 |
| **Proposed phase** | Deferred |
| **Acceptance evidence** | N/A |

---

### CLD-008: Server-side validation

| Field | Value |
|---|---|
| **Status** | NOT IMPLEMENTED |
| **Source evidence** | Future requirement for server-side business rule validation. |
| **Implementation evidence** | None. |
| **Test evidence** | None |
| **Missing behavior** | Server-side validation layer. |
| **Dependencies** | CLD-002 |
| **Proposed phase** | Deferred |
| **Acceptance evidence** | N/A |

---

## Mobile (MOB)

### MOB-001: Mobile application

| Field | Value |
|---|---|
| **Status** | NOT IMPLEMENTED |
| **Source evidence** | Future requirement — app currently runs as Windows desktop only. |
| **Implementation evidence** | None. Delivery package is `grain_warehouse_erp_lite.exe` (Windows). |
| **Test evidence** | None |
| **Missing behavior** | Mobile (Android/iOS) application build. |
| **Dependencies** | CLD-003 |
| **Proposed phase** | Deferred |
| **Acceptance evidence** | N/A |

---

### MOB-002: Mobile authentication

| Field | Value |
|---|---|
| **Status** | NOT IMPLEMENTED |
| **Source evidence** | Future requirement for mobile auth (biometrics, etc.). |
| **Implementation evidence** | None. |
| **Test evidence** | None |
| **Missing behavior** | Mobile-specific authentication mechanisms. |
| **Dependencies** | MOB-001 |
| **Proposed phase** | Deferred |
| **Acceptance evidence** | N/A |

---

### MOB-003: Mobile data access

| Field | Value |
|---|---|
| **Status** | NOT IMPLEMENTED |
| **Source evidence** | Future requirement for mobile data access patterns. |
| **Implementation evidence** | None. |
| **Test evidence** | None |
| **Missing behavior** | Mobile-optimized data access. |
| **Dependencies** | MOB-001, CLD-003 |
| **Proposed phase** | Deferred |
| **Acceptance evidence** | N/A |

---

### MOB-004: Mobile transaction posting

| Field | Value |
|---|---|
| **Status** | NOT IMPLEMENTED |
| **Source evidence** | Future requirement for posting transactions from mobile. |
| **Implementation evidence** | None. |
| **Test evidence** | None |
| **Missing behavior** | Mobile transaction creation flow. |
| **Dependencies** | MOB-001, CLD-001 |
| **Proposed phase** | Deferred |
| **Acceptance evidence** | N/A |

---

## Financial Reports (RPT)

### RPT-001: Daily activity report

| Field | Value |
|---|---|
| **Status** | IMPLEMENTED |
| **Source evidence** | Daily report summarizes all business activity for a selected date. |
| **Implementation evidence** | `lib/core/reports/daily_activity_report.dart:3` — `DailyActivityReport` with purchases, sales, expenses, collections, supplier payments, receivables, payables, stock balances, recent movements, estimated profit. `lib/core/reports/report_repository.dart:19` — `LocalReportRepository.dailyActivityReport()` computes all metrics. `lib/core/reports/report_controller.dart` — Report controller. `lib/features/reports/reports_screen.dart` — Reports UI. |
| **Test evidence** | `test/reports_test.dart` — Daily report calculation tests. `test/phase21c_profit_stock_valuation_reports_test.dart` — Profit and stock valuation tests. |
| **Missing behavior** | None |
| **Dependencies** | All operational modules |
| **Proposed phase** | Phase 21c |
| **Acceptance evidence** | Report includes purchases, sales, expenses, credit sales, collections, supplier payments, receivables, payables, estimated profit, stock balances, recent movements. |

---

### RPT-002: Product stock balances in report

| Field | Value |
|---|---|
| **Status** | IMPLEMENTED |
| **Source evidence** | Stock balances per product are shown in the daily report. |
| **Implementation evidence** | `lib/core/reports/daily_activity_report.dart:76` — `ProductStockBalance` with `productId`, `productName`, `quantityKg`, `unitLabel`. `lib/core/reports/report_repository.dart:94` — Stock balances computed for all products. |
| **Test evidence** | `test/reports_test.dart` — Stock balance tests. |
| **Missing behavior** | None |
| **Dependencies** | INV-002 |
| **Proposed phase** | Phase 21c |
| **Acceptance evidence** | Each product's stock balance included in report with quantity and unit label. |

---

### RPT-003: Financial account balance report

| Field | Value |
|---|---|
| **Status** | IMPLEMENTED |
| **Source evidence** | Requires ACC-007 financial accounts. |
| **Implementation evidence** | `lib/core/financial_accounts/financial_report_service.dart` — `accountBalanceReport()` method reads from `FinancialAccountRepository`, computes opening balance (entries before period start), inflow/outflow totals, and closing balance per account. `lib/core/financial_accounts/financial_report_models.dart` — `AccountBalanceRow` immutable data class. `lib/features/financial_reports/account_balance_report_screen.dart` — Arabic RTL UI with date filters and PDF/CSV export. `lib/features/exports/financial_report_pdf_builder.dart` — PDF generation for balance report. `lib/features/exports/financial_report_csv_exporter.dart` — CSV export for balance report. |
| **Test evidence** | `test/phase79_account_based_financial_reports_test.dart` — Balance report tests covering empty period, date filtering, opening balance computation, inflow/outflow totals, closing balance, permission gating, PDF/CSV export. |
| **Missing behavior** | None |
| **Dependencies** | ACC-007 ✅ |
| **Proposed phase** | Phase 79 |
| **Acceptance evidence** | Balance report shows per-account opening/closing balance with inflow/outflow totals; read-only from ledger data; permission-gated; PDF/CSV export functional. |

---

### RPT-004: Payment method report

| Field | Value |
|---|---|
| **Status** | IMPLEMENTED |
| **Source evidence** | Requires ACC-010 payment method tracking. |
| **Implementation evidence** | `lib/core/financial_accounts/financial_report_service.dart` — `paymentMethodReport()` method reads FA entries, filters out transfer-related sources via `transferSourceTypes` set, aggregates by `PaymentMethod` enum. `lib/core/financial_accounts/financial_report_models.dart` — `PaymentMethodRow` immutable data class. `lib/features/financial_reports/payment_method_report_screen.dart` — Arabic RTL UI with date/method filters and PDF/CSV export. `lib/features/exports/financial_report_pdf_builder.dart` — PDF generation for payment method report. `lib/features/exports/financial_report_csv_exporter.dart` — CSV export for payment method report. |
| **Test evidence** | `test/phase79_account_based_financial_reports_test.dart` — Payment method report tests covering empty data, transfer exclusion, per-method aggregation, date filtering, permission gating, PDF/CSV export. |
| **Missing behavior** | None |
| **Dependencies** | ACC-010 ✅ |
| **Proposed phase** | Phase 79 |
| **Acceptance evidence** | Payment method report aggregates FA entries by method (cash, bankTransfer, mobileWallet, check); transfers excluded; read-only; permission-gated; PDF/CSV export functional. |

---

### RPT-005: Collection report

| Field | Value |
|---|---|
| **Status** | NOT IMPLEMENTED |
| **Source evidence** | Future requirement for standalone collection report. |
| **Implementation evidence** | None as standalone. Collection totals are included in the daily activity report (`RPT-001`). |
| **Test evidence** | None |
| **Missing behavior** | Dedicated collection report with filtering, totals, per-customer breakdown. |
| **Dependencies** | ACC-001 |
| **Proposed phase** | Deferred |
| **Acceptance evidence** | N/A |

---

### RPT-006: Settlement report

| Field | Value |
|---|---|
| **Status** | NOT IMPLEMENTED |
| **Source evidence** | Future requirement for debt settlement tracking. |
| **Implementation evidence** | None. |
| **Test evidence** | None |
| **Missing behavior** | Settlement report showing payment progress against original debts. |
| **Dependencies** | ACC-001, ACC-002 |
| **Proposed phase** | Deferred |
| **Acceptance evidence** | N/A |

---

### RPT-007: Transfer report

| Field | Value |
|---|---|
| **Status** | IMPLEMENTED |
| **Source evidence** | Requires ACC-011 internal transfers. |
| **Implementation evidence** | `lib/core/financial_accounts/financial_report_service.dart` — `transferReport()` method reads from authoritative transfer register via `listTransfers()`, joins with account names, shows reversal/reversed status. `lib/core/financial_accounts/financial_report_models.dart` — `TransferReportRow` immutable data class with reversal status fields. `lib/features/financial_reports/transfer_report_screen.dart` — Arabic RTL UI with date/status filters and PDF/CSV export. `lib/features/exports/financial_report_pdf_builder.dart` — PDF generation for transfer report. `lib/features/exports/financial_report_csv_exporter.dart` — CSV export for transfer report. |
| **Test evidence** | `test/phase79_account_based_financial_reports_test.dart` — Transfer report tests covering empty data, date filtering, reversal status, reversed status, permission gating, PDF/CSV export. |
| **Missing behavior** | None |
| **Dependencies** | ACC-011 ✅ |
| **Proposed phase** | Phase 79 |
| **Acceptance evidence** | Transfer report reads from authoritative transfer register; shows source/destination accounts, amount, date, reversal status; read-only; permission-gated; PDF/CSV export functional. |

---

### RPT-008: Reconciliation report

| Field | Value |
|---|---|
| **Status** | NOT IMPLEMENTED |
| **Source evidence** | Requires ACC-007 and ACC-012. |
| **Implementation evidence** | None. |
| **Test evidence** | None |
| **Missing behavior** | Account reconciliation report. |
| **Dependencies** | ACC-007, ACC-012 |
| **Proposed phase** | Deferred |
| **Acceptance evidence** | N/A |

---

## Summary

| Status | Count | IDs |
|---|---|---|
| **IMPLEMENTED** | 61 | OPS-001–018, ACC-001–011, INV-001–004, CAN-001–004, CAN-008, DOC-001–008, BKP-001–007, AUTH-001–005, AUD-001–003, BRD-001–004, RPT-001–004, RPT-007 |
| **NOT IMPLEMENTED** | 19 | ACC-012–013, INV-005, CAN-005–007, BKP-008–009, CLD-001–008, MOB-001–004, RPT-005–006, RPT-008 |

### Not Implemented Requirements by Blocker

| Blocker | Requirements |
|---|---|
| Blocked by DC-U006 (daily closing policy) | ACC-012, RPT-008 |
| Scope defined, pending approved phase | ACC-013 |
| No backend/cloud (CLD-002) | CLD-001–008, MOB-001–004 |
| No in-memory transactions | BKP-008, BKP-009 |
| Future scope only | CAN-005, CAN-006, CAN-007, INV-005, RPT-005, RPT-006 |

# Phase 77 governing baseline reconciliation

`ACC-011` is implemented in Phase 76: immutable paired financial-account entries, owner-only transfer/reversal, idempotency, source-balance validation, review/history UI, and additive backup restore coverage. The historical Phase 75 entry below is superseded by this update; DC-U006 remains open.

This matrix was reconciled with the actual codebase state in Phase 77. The following corrections were made:
- ACC-011 status corrected from "NOT IMPLEMENTED" to "IMPLEMENTED" (Phase 76).
- CAN-007 updated to reflect that financial accounts exist but general-purpose financial-account reversal is not implemented.
- RPT-003, RPT-004, RPT-007 updated to reflect that their dependencies (ACC-007, ACC-010, ACC-011) are now met.
- Summary counts corrected: 58 implemented (was 57), 22 not implemented (was 23).

---

# Phase 78 owner decisions adoption & compatibility audit

`DC-U002` (split payments), `DC-U006` (daily/period closing), `DC-U007` (negative balance), and `DC-U008` (overpayment) are all CLOSED per owner directive in Phase 78. The owner decisions are adopted as follows:

- **DC-U002**: Max 3–5 payment methods per invoice; per-account owner config; partial payments allowed; no new financial-account creation during split.
- **DC-U006**: Mandatory actual balance; owner-only approve/reopen; period lock with configurable periods; no backdated entries into locked periods.
- **DC-U007**: Per-account Boolean `allowNegativeBalance`; owner-only toggle; owner approval required for each negative-balance operation; non-owner operations blocked when balance insufficient. **IMPLEMENTED** — `allowNegativeBalance` field, balance guard in `createEntry`, owner-only `updateAccountPolicy`, backup contract updated.
- **DC-U008**: Owner approval per overpayment operation; recorded as customer/supplier credit or advance; no editing of original collection/payment document; refund via separate compensating entry.

A compatibility audit of all production code was completed. No confirmed defects were found in audited areas (transfers, cancellations, reversals, balance invariants). DC-U007 has been implemented. Implementation gaps remain for DC-U002, DC-U006, DC-U008 — they require new implementation phases to realize.
- Blocker table corrected to reflect current dependency state.

---

# Phase 79 account-based financial reports implementation

RPT-003 (account balance report), RPT-004 (payment method report), and RPT-007 (transfer report) are IMPLEMENTED in Phase 79. A new Account Statement report (unnumbered in the traceability matrix but covered by Phase 79 scope) was also implemented. Summary counts corrected: 61 implemented (was 58), 19 not implemented (was 22).

# Phase 81 transaction-level financial Backup/Restore remediation

Backup v6 preserves `financialAccountId` and `paymentMethod` on sales, purchases, customer collections, supplier payments, and expenses. Restore accepts v1–v5 with safe `null` defaults when the fields are absent and rejects non-null references to missing financial accounts before writes. This closes the transaction-linkage Backup gap recorded in Phase 78 without changing transaction accounting, stock, reports, or closing behavior.

# Post-Phase 81 governance audit

Governance audit completed. No "Phase 82" exists in the repository. Multiple valid candidates identified (DC-U007, CAN-005/CAN-006, DC-U002, DC-U008) with no explicit ordering. DC-U014 is CLOSED (Phase 75) and implemented (Phase 76). DC-U007 (negative-balance controls) — **IMPLEMENTED**. Remaining candidates: CAN-005/CAN-006, DC-U002, DC-U008. See `docs/POST-PHASE-81-GOVERNANCE-AUDIT.md`.
