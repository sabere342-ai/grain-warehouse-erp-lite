# Financial Accounts Gap Audit — Grain Warehouse ERP Lite

> **Status:** Gap analysis — not implemented
> **Last updated:** 2026-07-10
> **Scope:** All money as integers in Qirsh (piasters). All weight as integers in grams. All repositories in-memory. No database. No financial account model exists today.

---

## Table of Contents

1. [8.1 Unified Financial Account Model](#81-unified-financial-account-model)
2. [8.2 Financial Movement Ledger](#82-financial-movement-ledger)
3. [8.3 Required Source Types](#83-required-source-types)
4. [8.4 Sales](#84-sales)
5. [8.5 Purchases](#85-purchases)
6. [8.6 Customer Collections](#86-customer-collections)
7. [8.7 Supplier Settlements](#87-supplier-settlements)
8. [8.8 Expenses](#88-expenses)
9. [8.9 Returns/Refunds](#89-returnsrefunds)
10. [8.10 Internal Transfers](#810-internal-transfers)
11. [8.11 Daily Cash Closing & Reconciliation](#811-daily-cash-closing--reconciliation)
12. [8.12 Financial Reports](#812-financial-reports)
13. [Source-to-Ledger Matrix](#source-to-ledger-matrix)

---

## 8.1 Unified Financial Account Model

### Current State

There is no financial account model. No concept of cashbox, bank account, or electronic wallet exists. Money movement is only partially inferred through `CustomerAccountEntry`, `SupplierAccountEntry`, and `Expense` records — none of which reference a financial account.

### Requirements

#### Account Entity

Each financial account must have:

| Field | Type | Notes |
|---|---|---|
| `id` | String (UUID) | Stable, immutable, system-generated. Never reused. |
| `name` | String | Display name. Must be unique per active account. |
| `type` | Enum | `CASH` / `TREASURY` / `BANK` / `ELECTRONIC_WALLET` |
| `isActive` | bool | Active/inactive toggle. Inactive accounts cannot receive new movements. |
| `openingBalance` | int | Documented opening balance in Qirsh. Set once at creation. |
| `openingBalanceDate` | String (ISO date) | Date the opening balance was established. |
| `currency` | String | Always `"QIRSH"` today. Future: multi-currency is a decision point. |
| `referenceInfo` | String? | Non-sensitive reference info (e.g. bank branch, card last-4). |
| `notes` | String? | Free-form notes. |
| `createdBy` | String | User ID who created the account. |
| `createdAt` | DateTime | Immutable creation timestamp. |
| `archivedAt` | DateTime? | Null while active. Set on archival. |

#### Business Rules

- **Cannot delete** an account that has any financial movement records. Archival only.
- **Archival** sets `archivedAt`, sets `isActive = false`. Archived accounts appear in historical reports but cannot be selected for new transactions.
- **Opening balance** is documented with a date. Changing it requires a correction entry through the ledger, never a direct edit.
- **Single currency today.** The `currency` field exists for forward compatibility. Multi-currency support is a future decision and must not be assumed in any current logic.
- **Name uniqueness** enforced among active accounts only. An archived account's name may be reused.

#### Account Type Semantics

| Type | Typical Use | Physical Form |
|---|---|---|
| `CASH` / `TREASURY` | On-hand cash, petty cash, safe | Physical cashbox |
| `BANK` | Bank accounts, savings, current | Bank account |
| `ELECTRONIC_WALLET` | Mobile money, e-wallet | Digital wallet |

#### Archival Behavior

- Archived accounts are read-only for all future operations.
- Historical reports must include archived accounts.
- An archived account may be reactivated only if it has zero movements after archival (never expected in practice).
- No soft-delete semantics — archival is explicit and logged.

### Current Gap

**No account model exists.** All of the above must be built from scratch.

---

## 8.2 Financial Movement Ledger

### Current State

There is no financial ledger. `CustomerAccountEntry` and `SupplierAccountEntry` track debt only. Money movement between accounts is never recorded as a ledger entry.

### Requirements

#### Movement Entity

Each ledger entry must have:

| Field | Type | Notes |
|---|---|---|
| `id` | String (UUID) | Stable, immutable, system-generated. |
| `accountId` | String | The financial account this movement belongs to. |
| `direction` | Enum | `IN` (inflow, increases balance) / `OUT` (outflow, decreases balance) |
| `amount` | int | Always positive. Direction determines sign. |
| `sourceType` | Enum | See §8.3. |
| `sourceId` | String | ID of the originating document. |
| `sourceDocumentNumber` | String | Human-readable document number for display. |
| `effectiveDate` | String (ISO date) | When the movement is effective for accounting. |
| `createdAt` | DateTime | Immutable record creation timestamp. |
| `createdBy` | String | User ID who created the movement. |
| `reference` | String? | External reference (receipt number, bank ref). |
| `note` | String? | Free-form note. |
| `reversalOf` | String? | ID of the movement being reversed, if any. |
| `transferGroupId` | String? | Links paired entries in an internal transfer. |
| `idempotencyKey` | String | Unique key preventing duplicate movements. |
| `syncStatus` | String | Future: `SYNCED` / `PENDING` / `CONFLICT`. Default `SYNCED` for offline-first. |

#### Business Rules

- **Immutability:** Once created, a movement is never edited or deleted. Corrections are reversal entries.
- **Balance calculation:** `Balance = openingBalance + SUM(inflows) - SUM(outflows)` for all movements on that account.
- **No manual balance edits** without a documented correction entry (source type `MANUAL_CORRECTION`).
- **Idempotency:** Each movement carries a unique `idempotencyKey`. Duplicate submissions with the same key are rejected or returned as no-op.
- **Transfer grouping:** Internal transfers produce two linked entries with the same `transferGroupId` — one `OUT` on the source account, one `IN` on the destination account.
- **Reversal:** A reversal entry references the original movement via `reversalOf`. The original movement is not deleted. Net effect: balance changes, audit trail preserved.
- **Effective date vs. created date:** `effectiveDate` is when the movement is accounting-effective (may be backdated for corrections). `createdAt` is the real wall-clock time.

### Current Gap

**No ledger exists.** All of the above must be built from scratch. Every transaction that changes a financial account balance must produce a ledger entry.

---

## 8.3 Required Source Types

### Current State

Source types are not tracked. Sales, expenses, collections, and payments do not reference which financial account was affected, nor do they produce ledger entries.

### Required Source Types

| Source Type | Description | Direction |
|---|---|---|
| `SALE_PAYMENT` | Payment received from a sale (cash or partial) | IN |
| `CUSTOMER_COLLECTION` | Collection received from customer toward debt | IN |
| `PURCHASE_PAYMENT` | Payment made to supplier for a purchase | OUT |
| `SUPPLIER_SETTLEMENT` | Settlement payment to reduce supplier payable | OUT |
| `EXPENSE` | Operational expense paid from an account | OUT |
| `SALE_REFUND` | Cash refund issued to customer for a return | OUT |
| `PURCHASE_REFUND` | Cash refund received from supplier for a return | IN |
| `INTERNAL_TRANSFER` | Transfer between financial accounts (paired) | IN or OUT |
| `OPENING_BALANCE` | Documented opening balance for an account | IN (initial) |
| `MANUAL_CORRECTION` | Manual correction with required permission | IN or OUT |
| `BANK_WALLET_FEE` | Fee charged by bank or wallet provider | OUT |
| `CANCELLATION_REVERSAL` | Reversal of a cancelled transaction | IN or OUT |
| `RESTORE_IMPORT` | Restoring or importing historical data | IN or OUT |

### Tracing Requirement

Every movement on any financial account **must** be traceable to its source document. The `sourceType` + `sourceId` pair must resolve to exactly one originating document. Reports must be able to show the full chain: account movement → source document → line items.

### Restore/Import Behavior

Restore and import operations must produce `RESTORE_IMPORT` entries. They must not silently alter balances without ledger entries. When importing historical data, each imported transaction must generate its corresponding ledger entry.

---

## 8.4 Sales

### Current State

| Aspect | Status | Detail |
|---|---|---|
| Credit sale | **PARTIALLY** | CustomerAccountEntry created, but no financial account movement |
| Cash sale | **PARTIALLY** | Payment recorded, but no account selected, no ledger entry |
| Partial payment sale | **PARTIALLY** | Split between credit/cash, but no account tracking |
| Account selection | **NOT AT ALL** | No concept of which account receives payment |
| Payment method field | **PARTIALLY** | `paymentMode` exists (cash/credit/partial) but not linked to account |
| Transfer reference | **NOT AT ALL** | No field for bank/wallet transfer reference |
| Split payment | **NOT AT ALL** | No support for multiple accounts per invoice |
| No treasury on credit sale | **NOT AT ALL** | No account system to enforce this |
| Invoice total cap | **NOT AT ALL** | No prevention of payment exceeding invoice total |
| Current totals stable | **NOT APPLICABLE** | Must remain stable during migration |
| Cancellation with financial reversal | **NOT AT ALL** | Cancellation reverses stock but not financial movement |

### Detailed Gaps

#### Full Cash Sale

- **Current:** `paymentMode = CASH`. CustomerAccountEntry is NOT created. No account is selected.
- **Required:** Account selection (mandatory). Ledger entry: `SALE_PAYMENT` IN to selected account. CustomerAccountEntry created with `cashSale` type. If account has no balance, this should still work (payment received).
- **Gap:** Account model, ledger, account selection UI, ledger entry creation on sale.

#### Full Credit Sale

- **Current:** `paymentMode = CREDIT`. CustomerAccountEntry created with `creditSale` type.
- **Required:** CustomerAccountEntry created (existing). NO financial account movement. NO ledger entry. This is correct behavior — no money changed hands.
- **Gap:** Minimal. Verify no financial account movement is generated. Ensure future code does not accidentally create one.

#### Partial Payment Sale

- **Current:** `paymentMode = PARTIAL`. CustomerAccountEntry created for full amount. Paid portion is not tracked to any account.
- **Required:** CustomerAccountEntry for full amount (existing). Ledger entry: `SALE_PAYMENT` IN for the paid portion to selected account. Remaining debt stays on customer.
- **Gap:** Account model, ledger, account selection, ledger entry for paid portion only.

#### Account Selection

- **Current:** No field exists on sale to select a receiving account.
- **Required:** Each sale with a cash/partial component must have a mandatory account selection. The UI must present only active accounts of type CASH, BANK, or ELECTRONIC_WALLET.
- **Gap:** New field, UI, validation.

#### Transfer Reference

- **Current:** No field for transfer reference.
- **Required:** When payment method is electronic (bank transfer, mobile money), a reference field must be available for the external transaction reference.
- **Gap:** New field, conditional visibility.

#### Split Payment (Multiple Accounts)

- **REQUIRES OWNER DECISION.** The current system does not support split payments. If split payments are desired:
  - A single sale could receive payments from multiple accounts.
  - Each payment portion produces its own ledger entry.
  - The sale totals must equal the sum of all portions plus any remaining credit.
  - UI complexity increases significantly.
  - **Recommendation:** Defer to post-MVP unless explicitly required.

#### Prevention of Payment Exceeding Invoice Total

- **Current:** No validation exists.
- **Required:** The sum of all payments (across all accounts) must never exceed the sale total. Validation at entry time.
- **Gap:** New validation logic.

#### Cancellation with Financial Reversal

- **Current:** Sale cancellation reverses stock but does not reverse any financial account movement. If the sale was cash, the money is still counted in the account. If credit, the customer debt reversal is handled but no financial reversal exists.
- **Required:** On cancellation, generate `CANCELLATION_REVERSAL` entries for every financial movement associated with the sale. For cash sales: OUT entry on the receiving account. For partial: OUT for the paid portion. For credit: no financial reversal needed (no money moved).
- **Gap:** Cancellation logic must be extended to trace and reverse all linked financial movements.

---

## 8.5 Purchases

### Current State

| Aspect | Status | Detail |
|---|---|---|
| Credit purchase | **PARTIALLY** | SupplierAccountEntry created, no financial account movement |
| Paid purchase | **PARTIALLY** | Payment recorded, but no account selected, no ledger entry |
| Partial payment purchase | **PARTIALLY** | Split between credit/cash, but no account tracking |
| Account selection | **NOT AT ALL** | No concept of which account pays |
| No treasury decrease on credit purchase | **NOT AT ALL** | No account system to enforce this |
| Financial link for paid amount | **NOT AT ALL** | No account selected, no ledger entry |
| Cancellation reversal | **NOT AT ALL** | Cancellation reverses stock but not financial movement |

### Detailed Gaps

#### Credit Purchase

- **Current:** `SupplierAccountEntry` created with `purchase` type. No money movement.
- **Required:** SupplierAccountEntry created (existing). NO financial account movement. Correct behavior — no money changed hands.
- **Gap:** Minimal. Verify no financial account movement is generated.

#### Paid Purchase

- **Current:** Payment recorded, but no account is selected. No ledger entry.
- **Required:** Account selection (mandatory). Ledger entry: `PURCHASE_PAYMENT` OUT from selected account. SupplierAccountEntry for full amount (or partial if part-credit).
- **Gap:** Account model, ledger, account selection UI, ledger entry creation.

#### Partial Payment Purchase

- **Current:** SupplierAccountEntry for full amount. Paid portion not tracked to any account.
- **Required:** SupplierAccountEntry for full amount. Ledger entry: `PURCHASE_PAYMENT` OUT for the paid portion from selected account. Remaining payable stays on supplier.
- **Gap:** Account model, ledger, account selection, ledger entry for paid portion.

#### Cancellation Reversal

- **Current:** Purchase cancellation reverses stock but does not reverse any financial account movement.
- **Required:** On cancellation, generate `CANCELLATION_REVERSAL` entries for every financial movement. For paid purchases: IN entry on the paying account. For credit: no financial reversal.
- **Gap:** Cancellation logic extension.

---

## 8.6 Customer Collections

### Current State

| Aspect | Status | Detail |
|---|---|---|
| Customer, amount | **FULLY** | Recorded in SupplierAccountEntry |
| Receiving account | **NOT AT ALL** | No concept of which account receives money |
| Payment method | **NOT AT ALL** | No field for how the money was received |
| Reference | **NOT AT ALL** | No external reference field |
| Date | **FULLY** | Date is recorded |
| Source (manual entry) | **PARTIALLY** | Collections exist but are not traced to a financial account |
| Reduce receivable | **FULLY** | CustomerAccountEntry with `collection` type reduces debt |
| Increase financial account | **NOT AT ALL** | No account system, no ledger entry |
| Atomic transaction | **NOT AT ALL** | No transactional guarantee across entry types |
| Cancellation and reversal | **NOT AT ALL** | No cancellation mechanism for collections |
| Over-collection prevention | **NOT AT ALL** | No prevention of collection exceeding debt |

### Detailed Gaps

A customer collection must:

1. **Reduce customer receivable** — existing behavior via `CustomerAccountEntry`.
2. **Increase financial account balance** — not implemented. Requires account selection and `CUSTOMER_COLLECTION` IN ledger entry.
3. **Be atomic** — both the customer entry and the financial entry must succeed or fail together. Today these are separate in-memory operations with no transactional wrapper.
4. **Support cancellation** — must reverse both the customer entry and the financial ledger entry.
5. **Prevent over-collection** — validate that collection amount does not exceed remaining customer debt. Current system does not check this.
6. **Record payment method and reference** — which account, how was it paid, external reference if electronic.

### Over-Collection / Credit Balance Policy

- **REQUIRES OWNER DECISION.** Options:
  - (A) Strictly prevent collections exceeding debt. Error on entry.
  - (B) Allow over-collection, creating a credit balance on the customer. Credit balance offsets future purchases.
  - **Current system does neither.**

---

## 8.7 Supplier Settlements

### Current State

| Aspect | Status | Detail |
|---|---|---|
| Supplier | **FULLY** | SupplierAccountEntry exists |
| Paying account | **NOT AT ALL** | No concept of which account pays |
| Amount | **FULLY** | Amount recorded |
| Reference | **NOT AT ALL** | No external reference field |
| Reduce payable | **FULLY** | SupplierAccountEntry with `payment` type reduces debt |
| Decrease financial account | **NOT AT ALL** | No account system, no ledger entry |
| Cancellation | **NOT AT ALL** | No cancellation mechanism for payments |
| Overpayment prevention | **NOT AT ALL** | No prevention of payment exceeding debt |

### Detailed Gaps

A supplier settlement must:

1. **Reduce supplier payable** — existing behavior via `SupplierAccountEntry`.
2. **Decrease financial account balance** — not implemented. Requires account selection and `SUPPLIER_SETTLEMENT` OUT ledger entry.
3. **Be atomic** — both entries must succeed or fail together.
4. **Support cancellation** — must reverse both the supplier entry and the financial ledger entry.
5. **Prevent overpayment** — validate that payment does not exceed remaining supplier debt.
6. **Record payment method and reference** — which account, how was it paid.

### Overpayment Policy

- **REQUIRES OWNER DECISION.** Options:
  - (A) Strictly prevent payments exceeding debt. Error on entry.
  - (B) Allow overpayment, creating a credit balance on the supplier. Credit balance offsets future purchases.
  - **Current system does neither.**

---

## 8.8 Expenses

### Current State

| Aspect | Status | Detail |
|---|---|---|
| Amount | **FULLY** | Expense amount recorded |
| Mandatory account selection | **NOT AT ALL** | No account selected, money direction inferred |
| Fees (bank/wallet) | **NOT AT ALL** | No separate treatment for fees |
| Category | **PARTIALLY** | Category exists but not linked to account |
| Reference | **NOT AT ALL** | No external reference field |
| Account impact | **NOT AT ALL** | No ledger entry |
| Cancellation | **NOT AT ALL** | No cancellation mechanism |
| Permissions | **NOT AT ALL** | No special permission for expense entry |

### Detailed Gaps

An expense must:

1. **Mandatorily select a paying account** — every expense reduces a financial account balance.
2. **Produce an `EXPENSE` OUT ledger entry** — not implemented.
3. **Record category** — existing category field must be linked to the expense properly.
4. **Record external reference** — receipt number, vendor reference, etc.
5. **Support cancellation** — must reverse the financial ledger entry and restore the account balance.
6. **Require appropriate permissions** — expense creation should require a permission flag. Today there is no such mechanism.

### Bank/Wallet Fees

- Fees are a special sub-type of expense: `BANK_WALLET_FEE` OUT ledger entry.
- They may be auto-deducted (e.g. bank charges) or manually entered.
- If auto-deducted, a reconciliation import may be needed.
- **Current system has no concept of fees.**

---

## 8.9 Returns/Refunds

### Current State

| Aspect | Status | Detail |
|---|---|---|
| Sale return with cash refund | **NOT AT ALL** | No refund mechanism |
| Sale return as customer credit | **NOT AT ALL** | No credit balance mechanism |
| Purchase return with cash refund | **NOT AT ALL** | No refund mechanism |
| Purchase return reducing supplier balance | **NOT AT ALL** | No such linkage |
| Separate stock from financial | **NOT AT ALL** | No financial impact exists |
| Do not assume auto cash refund | **NOT AT ALL** | No refund flow at all |
| Account selection for refund | **NOT AT ALL** | No account system |
| Reverse payment fees | **NOT AT ALL** | No fee tracking |

### Detailed Gaps

#### Sale Return (Cash Refund)

- **Current:** No mechanism exists.
- **Required:**
  1. Stock impact: reverse inventory (existing sale return logic).
  2. Financial impact: `SALE_REFUND` OUT ledger entry from selected account.
  3. Customer account: adjust receivable if the original sale was credit. If cash, reduce the customer's paid amount.
  4. Account selection: mandatory for the refunding account.
  5. **Do not assume automatic cash refund.** The user must choose: refund to account (cash/bank/wallet) or add as customer credit.
- **Gap:** Entire flow must be built.

#### Sale Return (Customer Credit)

- **Required:** `CustomerAccountEntry` with a credit type. No financial account movement. Customer's debt is reduced or a credit balance is created.
- **Gap:** Credit balance mechanism does not exist.

#### Purchase Return (Cash Refund)

- **Required:**
  1. Stock impact: reverse inventory.
  2. Financial impact: `PURCHASE_REFUND` IN ledger entry to selected account.
  3. Supplier account: adjust payable if original purchase was credit.
- **Gap:** Entire flow must be built.

#### Purchase Return (Supplier Credit)

- **Required:** `SupplierAccountEntry` with a credit type. No financial account movement. Supplier's payable is reduced or a credit balance is created.
- **Gap:** Credit balance mechanism does not exist.

#### Payment Fees

- If a refund involves reversing a previous payment that had a fee, the fee should also be reversed or noted. Currently no fee tracking exists.

---

## 8.10 Internal Transfers

### Current State

**NOT AT ALL.** No internal transfer mechanism exists.

### Requirements

An internal transfer moves money from one financial account to another.

#### Required Fields

| Field | Notes |
|---|---|
| `fromAccountId` | Source account (deducted) |
| `toAccountId` | Destination account (credited) |
| `amount` | Amount in Qirsh |
| `transferFee` | Optional fee amount |
| `feeAccountId` | Account from which fee is charged (may be same as `fromAccountId` or a separate expense account) |
| `reference` | External reference |
| `date` | Effective date |

#### Business Rules

1. **Atomic two-sided entries:** Two `INTERNAL_TRANSFER` ledger entries share the same `transferGroupId`:
   - `OUT` on `fromAccountId` for `amount + transferFee` (or `amount` if fee is separate).
   - `IN` on `toAccountId` for `amount`.
   - If fee has a separate `feeAccountId`, an additional `BANK_WALLET_FEE` OUT entry on the fee account.
2. **Prevent same account:** `fromAccountId != toAccountId`. Validation error otherwise.
3. **Prevent single-sided:** Both entries must be created atomically. If one fails, both must not persist.
4. **Reversal:** Transfer reversal produces two `CANCELLATION_REVERSAL` entries with the same `transferGroupId`: IN on `fromAccountId`, OUT on `toAccountId`.
5. **Permissions:** Transfer creation should require appropriate permission (e.g. `CAN_CREATE_TRANSFER`).
6. **Both accounts must exist and be active** at time of transfer.

---

## 8.11 Daily Cash Closing & Reconciliation

### Current State

**NOT AT ALL.** No daily closing or reconciliation mechanism exists. Any claim otherwise is incorrect without evidence in the codebase.

### Requirements

#### Closing Flow

1. **Opening cash count:** User counts physical cash at start of day. System records expected balance (from ledger).
2. **Expected balance:** Calculated from the ledger: `openingBalance + SUM(IN movements) - SUM(OUT movements)` for the day.
3. **Actual count:** User enters the physical cash counted.
4. **Difference:** `actualCount - expectedBalance`. May be positive (overage) or negative (shortage).
5. **Reason:** If difference is non-zero, a reason must be recorded (required field).
6. **Approval:** A supervisor/manager must approve the reconciliation. Self-approval should be restricted.
7. **Close day:** Once approved, the day is marked closed. No new movements for closed days are allowed without reopening.
8. **Reopen permission:** Only a designated permission (e.g. `CAN_REOPEN_DAY`) may reopen a closed day. Reopening is logged.

#### Data Model

| Field | Notes |
|---|---|
| `date` | The date being reconciled |
| `accountId` | Which account is being reconciled |
| `expectedBalance` | System-calculated |
| `actualCount` | User-entered |
| `difference` | `actualCount - expectedBalance` |
| `reason` | Required if difference != 0 |
| `closedBy` | User who closed |
| `closedAt` | Timestamp |
| `approvedBy` | Supervisor who approved |
| `approvedAt` | Timestamp |
| `reopenedBy` | If reopened |
| `reopenedAt` | If reopened |
| `reopenReason` | If reopened |

#### Audit Trail

- Every close, reopen, and approval must be logged.
- Reconciliation records must be immutable after approval.
- Reports must show all reconciliation history per account.

#### Important

Do NOT consider daily closing implemented without **explicit evidence** in the codebase showing:
- A reconciliation UI or form
- The closing logic with balance calculation
- Approval workflow
- Reopen mechanism
- Audit logging

---

## 8.12 Financial Reports

### Current State

**NOT AT ALL.** No financial reports exist because there is no financial account model or ledger.

### Required Reports

| # | Report | Description |
|---|---|---|
| 1 | **Account Balances** | All accounts with current balance. Filter by type, active status. |
| 2 | **Account Statement** | All movements for a specific account over a date range. Running balance. |
| 3 | **Collections Received** | All customer collections with account, amount, date, reference. |
| 4 | **Payments Made** | All supplier payments/settlements with account, amount, date, reference. |
| 5 | **Sales by Payment Method** | Sales grouped by payment method (cash/credit/partial). |
| 6 | **Collections by Account** | Collections grouped by receiving account. |
| 7 | **Supplier Payments by Account** | Supplier payments grouped by paying account. |
| 8 | **Expenses by Account** | Expenses grouped by paying account and category. |
| 9 | **Transfers** | All internal transfers with source, destination, amount, fee. |
| 10 | **Fees** | All bank/wallet fees with account, amount, date. |
| 11 | **Opening/Closing Period Balance** | Period start and end balances for each account. |
| 12 | **Daily Reconciliation** | All reconciliation records with differences and approvals. |
| 13 | **Cancelled/Reversed Movements** | All movements that were cancelled or reversed, with original and reversal. |
| 14 | **Source for Each Movement** | Drill-down: every ledger entry shows its source document. |
| 15 | **Discrepancy Report** | Accounts where expected balance differs from actual count, or where movements are missing source documents. |

### Source-to-Ledger Matrix

The following matrix shows every operation, its current support level, and what it must produce in a complete system.

Legend:
- **FULLY** = currently implemented correctly
- **PARTIALLY** = implemented but missing financial account/ledger integration
- **NOT AT ALL** = not implemented at all
- **REQUIRES DECISION** = needs owner/design decision before implementation

| # | Scenario | Inventory Impact | Customer Impact | Supplier Impact | Financial Account Impact | Expense Impact | Source Document | Cancellation Movement | Transaction Requirements | Idempotency | Sync | Current Status |
|---|---|---|---|---|---|---|---|---|---|---|---|---|
| 1 | **Credit Purchase** | IN stock qty, cost | — | SupplierAccountEntry (purchase) | None (no money moved) | — | Purchase order/invoice | Reverse supplier entry, reverse stock | Atomic stock + supplier | Key on purchase ID | Future | **PARTIALLY** |
| 2 | **Cash Purchase** | IN stock qty, cost | — | SupplierAccountEntry (cashPurchase) or none | OUT on paying account (PURCHASE_PAYMENT) | — | Purchase order/invoice | OUT reversal on account, reverse stock | Atomic stock + ledger + supplier | Key on purchase ID | Future | **PARTIALLY** |
| 3 | **Partial Payment Purchase** | IN stock qty, cost | — | SupplierAccountEntry (full amount) | OUT on paying account for paid portion | — | Purchase order/invoice | OUT reversal for paid portion, reverse supplier entry | Atomic stock + ledger + supplier | Key on purchase ID | Future | **PARTIALLY** |
| 4 | **Credit Sale** | OUT stock qty | CustomerAccountEntry (creditSale) | — | None (no money moved) | — | Sale invoice | Reverse customer entry, reverse stock | Atomic stock + customer | Key on sale ID | Future | **PARTIALLY** |
| 5 | **Cash Sale** | OUT stock qty | CustomerAccountEntry (cashSale) or none | — | IN on receiving account (SALE_PAYMENT) | — | Sale invoice | IN reversal on account, reverse stock | Atomic stock + ledger + customer | Key on sale ID | Future | **PARTIALLY** |
| 6 | **Partial Payment Sale** | OUT stock qty | CustomerAccountEntry (full amount) | — | IN on receiving account for paid portion | — | Sale invoice | IN reversal for paid portion, reverse customer entry | Atomic stock + ledger + customer | Key on sale ID | Future | **PARTIALLY** |
| 7 | **Customer Collection** | — | CustomerAccountEntry (collection, reduces debt) | — | IN on receiving account (CUSTOMER_COLLECTION) | — | Collection receipt | IN reversal on account, reverse customer entry | Atomic ledger + customer | Key on collection ID | Future | **PARTIALLY** |
| 8 | **Supplier Settlement** | — | — | SupplierAccountEntry (payment, reduces debt) | OUT on paying account (SUPPLIER_SETTLEMENT) | — | Payment receipt | OUT reversal on account, reverse supplier entry | Atomic ledger + supplier | Key on settlement ID | Future | **PARTIALLY** |
| 9 | **Expense** | — | — | — | OUT on paying account (EXPENSE) | Category, amount | Expense receipt/voucher | IN reversal on account | Ledger required | Key on expense ID | Future | **NOT AT ALL** |
| 10 | **Sale Return** | IN stock qty (return) | Adjust receivable or create credit | — | OUT on account if cash refund (SALE_REFUND) | — | Return document | Reverse financial entry, reverse stock | Atomic stock + ledger + customer | Key on return ID | Future | **NOT AT ALL** |
| 11 | **Purchase Return** | OUT stock qty (return) | — | Adjust payable or create credit | IN on account if cash refund (PURCHASE_REFUND) | — | Return document | Reverse financial entry, reverse stock | Atomic stock + ledger + supplier | Key on return ID | Future | **NOT AT ALL** |
| 12 | **Sale Cancellation** | Reverse stock | Reverse customer entry | — | OUT reversal on account if cash was paid | — | Original sale invoice | CANCELLATION_REVERSAL OUT on account | Atomic stock + ledger + customer | Key on cancellation ID | Future | **NOT AT ALL** |
| 13 | **Purchase Cancellation** | Reverse stock | — | Reverse supplier entry | IN reversal on account if cash was paid | — | Original purchase invoice | CANCELLATION_REVERSAL IN on account | Atomic stock + ledger + supplier | Key on cancellation ID | Future | **NOT AT ALL** |
| 14 | **Collection Cancellation** | — | Reverse customer entry (re-instate debt) | — | OUT reversal on receiving account | — | Original collection receipt | CANCELLATION_REVERSAL OUT on account | Atomic ledger + customer | Key on cancellation ID | Future | **NOT AT ALL** |
| 15 | **Payment Cancellation** | — | — | Reverse supplier entry (re-instate debt) | IN reversal on paying account | — | Original payment receipt | CANCELLATION_REVERSAL IN on account | Atomic ledger + supplier | Key on cancellation ID | Future | **NOT AT ALL** |
| 16 | **Internal Transfer** | — | — | — | OUT on source + IN on destination (INTERNAL_TRANSFER) paired | — | Transfer voucher | CANCELLATION_REVERSAL: IN on source, OUT on destination | Atomic two-sided ledger | Key on transfer ID | Future | **NOT AT ALL** |
| 17 | **Opening Balance** | — | — | — | IN on account (OPENING_BALANCE) with date | — | Opening balance document | OUT reversal to zero (or correction entry) | Ledger required | Key on account + date | Future | **NOT AT ALL** |
| 18 | **Cash Reconciliation** | — | — | — | Record expected vs actual, log difference | — | Reconciliation form | N/A (reconciliation is a check, not a movement) | Approval workflow | N/A | Future | **NOT AT ALL** |
| 19 | **Bank/Wallet Fee** | — | — | — | OUT on account (BANK_WALLET_FEE) | Fee category | Fee notification/statement | IN reversal on account | Ledger required | Key on fee ID | Future | **NOT AT ALL** |
| 20 | **Restore/Import** | May restore stock | May restore customer entries | May restore supplier entries | IN or OUT on account (RESTORE_IMPORT) | May restore expenses | Import manifest/file | CANCELLATION_REVERSAL to undo import | Atomic across all affected areas | Key on import batch ID | Future | **NOT AT ALL** |

### Report Source Traceability

Every report must be able to answer: **"Where did this number come from?"**

- Account balance → sum of ledger entries for that account.
- Ledger entry → source document (via `sourceType` + `sourceId`).
- Source document → line items, amounts, participants.
- Cancellation → original movement + reversal movement.
- Discrepancy → expected vs actual, missing entries, orphaned movements.

---

## Summary of Current Gaps

| Category | Status |
|---|---|
| Financial Account Model | **NOT AT ALL** |
| Financial Movement Ledger | **NOT AT ALL** |
| Source Type Tracking | **NOT AT ALL** |
| Sales (financial integration) | **PARTIALLY** |
| Purchases (financial integration) | **PARTIALLY** |
| Customer Collections (financial integration) | **PARTIALLY** |
| Supplier Settlements (financial integration) | **PARTIALLY** |
| Expenses (financial integration) | **NOT AT ALL** |
| Returns/Refunds | **NOT AT ALL** |
| Internal Transfers | **NOT AT ALL** |
| Daily Cash Closing | **NOT AT ALL** |
| Financial Reports | **NOT AT ALL** |

**Owner decisions required before implementation:**
1. Split payment (multiple accounts per invoice) — §8.4
2. Over-collection / customer credit balance policy — §8.6
3. Overpayment / supplier credit balance policy — §8.7
4. Multi-currency scope (future vs. never) — §8.1
5. Reconciliation approval hierarchy — §8.11
