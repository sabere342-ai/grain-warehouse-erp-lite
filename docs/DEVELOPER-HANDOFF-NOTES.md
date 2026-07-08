# Developer Handoff Notes

## Current state
- Latest phase: Phase 37B — customer opening balance.
- Functional baseline: Phase 37A opening balances + Phase 37B customer opening balance.
- Full test suite: 321/321 passed (11 new Phase 37B tests).
- Backup version: 2 (backward compatible with v1).
- Previous delivery: Phase 37A is superseded. Phase 37B is the current delivery.
- Main app path: `C:\dev\multi-pos\grain-warehouse-erp-lite`.
- Windows release exe path: `build\windows\x64\runner\Release\grain_warehouse_erp_lite.exe`.
- Delivery package: `delivery/grain_warehouse_erp_lite_pilot_<timestamp>/` (source-safe, owner-facing only).

## Verification commands
```powershell
flutter.bat test
flutter.bat analyze --no-pub
flutter.bat build windows --release
git diff --check
git status --short
```

## Do not commit
- `build/`
- `.dart_tool/`
- `delivery/`
- `tmp/`
- `*.log`
- `.exe` files or release package folders
- zip/package artifacts unless policy changes explicitly

## Known non-blocking build warnings
- Firebase C++ SDK CMake deprecation warning with newer CMake.
- MSVC `LNK4078` warning about multiple `.voltbl` sections.

## Core business rules
- Money is stored internally as integer piasters/qirsh.
- Normal UI displays Ø¬Ù†ÙŠÙ‡/`Ø¬.Ù…`, not raw qirsh.
- Minimum sale price is enforced before stock or sale mutation.
- Reference cost is optional.
- Estimated profit and stock valuation are incomplete when reference cost is missing.
- Restore remains limited to an empty system under the current safe design.

## Phase 23 pilot acceptance smoke
- Current pilot acceptance phase: Phase 23 pilot acceptance smoke validation.
- Stable tag after this phase: `phase-23-pilot-acceptance-smoke`.
- Rebuild Windows release with: `flutter.bat build windows --release`.
- Recreate the pilot delivery package with: `powershell -NoProfile -ExecutionPolicy Bypass -File tool\create_pilot_delivery_package.ps1`.
- Keep `build/`, `delivery/`, `tmp/`, logs, and generated release artifacts out of Git.
- During the pilot, do not change pricing rules, minimum sale enforcement, restore safety, local storage behavior, Firebase configuration, or backend/cloud behavior unless a new reviewed phase explicitly asks for it.

## Phase 24 pilot field trial feedback loop
- Current stable pilot tag: `phase-23-pilot-acceptance-smoke`.
- Current field trial docs:
  - `docs/PHASE-24-PILOT-FIELD-TRIAL-RUNBOOK-AR.md`
  - `docs/PILOT-FEEDBACK-FORM-AR.md`
  - `docs/PILOT-ISSUE-LOG-TEMPLATE.md`
  - `docs/PILOT-RELEASE-NOTES-AR.md`
- Do not change business logic during pilot feedback collection.
- Classify issues first.
- Separate bugs from feature requests.
- Do not modify backup/restore without a dedicated phase.

## Phase 25 first customer delivery lock
- Current stable customer delivery tag after this phase: `phase-25-first-customer-delivery-lock`.
- Purpose: lock the first customer delivery process so the delivered folder is understandable, safe, traceable, and recoverable.
- New checklist/report/manifest files:
  - `docs/PHASE-25-FIRST-CUSTOMER-DELIVERY-CHECKLIST-AR.md`
  - `docs/CUSTOMER-INSTALLATION-BACKUP-NOTE-AR.md`
  - `docs/FIRST-CUSTOMER-DELIVERY-MANIFEST.md`
  - `docs/PHASE-25-FIRST-CUSTOMER-DELIVERY-LOCK-REPORT.md`
- Do not change business logic during customer trial.
- Use the issue log to classify feedback.
- Separate bugs from feature requests.
- Require backup before any restore or troubleshooting.
- Do not promise cloud/mobile/multi-branch in this pilot version.

## Phase 26 first customer trial start
- Current stable trial-start tag after this phase: `phase-26-first-customer-trial-start`.
- Purpose: start and track the real first customer trial.
- New docs:
  - `docs/PHASE-26-FIRST-CUSTOMER-TRIAL-START-CHECKLIST-AR.md`
  - `docs/CUSTOMER-TRIAL-DAILY-LOG-AR.md`
  - `docs/PILOT-ISSUE-LOG.md`
  - `docs/PHASE-26-FIRST-CUSTOMER-TRIAL-START-REPORT.md`
- Do not fix anything during observation unless it blocks the trial.
- Record issues first.
- Separate bugs from feature requests.
- Require backup before troubleshooting.
- Do not promise cloud/mobile/multi-branch.

## Phase 27 first customer trial observation
- Current tag after this phase: `phase-27-first-customer-trial-observation`.
- Purpose: classify real trial feedback before starting fixes.
- New docs:
  - `docs/PHASE-27-FIRST-CUSTOMER-TRIAL-OBSERVATION-REPORT.md`
  - `docs/PHASE-27-ISSUE-TRIAGE-DECISION.md`
- Do not fix unverified issues.
- Do not mix feature requests with bugs.
- Do not change business logic without a dedicated fix phase.
- Require backup before any troubleshooting.
- Keep generated build/delivery files ignored.

## Phase 28 customer trial continuation
- Current tag after this phase: `phase-28-customer-trial-continuation`.
- Purpose: continue observation and decide whether first delivery confirmation is possible.
- New docs:
  - `docs/PHASE-28-CUSTOMER-TRIAL-CONTINUATION-REPORT.md`
  - `docs/CUSTOMER-TRIAL-OBSERVATION-SUMMARY-AR.md`
  - `docs/FIRST-CUSTOMER-DELIVERY-CONFIRMATION-CHECKLIST-AR.md`
- Do not start feature work without real trial evidence.
- Do not fix unverified issues.
- Do not mix feature requests with bugs.
- Require backup before troubleshooting.
- Keep build/delivery generated outputs ignored.

## Phase 29 first delivery pending freeze
- Current freeze tag after this phase: `phase-29-first-delivery-pending-freeze`.
- Purpose: freeze development until real customer evidence exists.
- New docs:
  - `docs/PHASE-29-FIRST-DELIVERY-PENDING-FREEZE-REPORT.md`
  - `docs/FIRST-DELIVERY-PENDING-FREEZE-NOTE-AR.md`
  - `docs/NEXT-PHASE-DECISION-GATE.md`
- Do not start Phase 30 without real evidence.
- Do not add features during freeze.
- Do not modify business logic without a dedicated evidence-based phase.
- Keep `build/` and `delivery/` ignored.
- Use `docs/PILOT-ISSUE-LOG.md` for actual customer issues only.
## Phase 30 strict visible pages UI readiness
- Current tag after this phase: `phase-30-strict-visible-pages-ui-readiness`.
- Purpose: customer-visible pages must be ready or hidden.
- Real feedback addressed:
  - no incomplete visible pages
  - back/navigation clarity
  - sales product cards
  - stronger colors
  - simple theme control
  - future accounting/online roadmap
- Do not expose unfinished pages.
- Do not add cashbox/credit/bank/wallets without dedicated phases.
- Do not migrate to Supabase without an architecture phase.
- Do not weaken pricing, stock, sales, backup, or restore tests.
- Continue collecting real feedback.
## Phase 31 strict no-hidden-pages functional recovery
- Current tag after this phase: `phase-31-strict-no-hidden-pages-functional-recovery`.
- Purpose: restore visible owner pages as real functional pages instead of hidden or placeholder-only screens.
- Customers are basic contact records only; do not show balances, credit, collections, or aging.
- Expenses are basic local records and report totals only; they do not mutate inventory and do not create payable accounting.
- Audit logs are read-only local history for supported actions.
- Backup and restore include customers, expenses, and audit logs while keeping old backups compatible.
- Do not remove visible pages to pass QA. Fix the page or keep the limitation explicit and honest.

## Phase 32 pilot delivery hardening
- Current tag after this phase: `phase-32-pilot-delivery-hardening`.
- Purpose: harden the local Windows pilot for owner acceptance after Phase 31 recovery.
- New docs:
  - `docs/PHASE-32-PILOT-DELIVERY-HARDENING.md`
  - `docs/PILOT-OWNER-ACCEPTANCE-CHECKLIST-AR.md`
- Use `tool\create_pilot_delivery_package.ps1` after a Windows release build to create the customer delivery folder.
- Send only the generated delivery package and selected owner-facing docs.
- Do not send the repository root, `.git/`, `lib/`, `test/`, `tool/`, source archives, full `docs/`, build intermediates, dev logs, or local temp folders.
- No cloud, SaaS, Supabase, Firebase migration, mobile app, multi-client architecture, cashbox, bank, wallet, tax, or full accounting module is part of this phase.
- Restore remains safe restore-to-empty only.
- Continue treating customer balances, credit sales, collections, payables, and expense accounting as future scoped work, not implied functionality.
## Phase 33 pilot smoke run and handoff finalization
- Current tag after this phase: `phase-33-pilot-smoke-run-handoff-finalization`.
- Purpose: prove the generated local Windows delivery package is safe and ready for current-client pilot testing.
- New/updated files:
  - `tool/check_pilot_delivery_package.ps1`
  - `tool/create_pilot_delivery_package.ps1`
  - `docs/PHASE-33-PILOT-SMOKE-RUN-HANDOFF.md`
- The package script now adds client-safe `README-AR.txt` to every generated delivery folder.
- Run the safety check after packaging: `powershell -NoProfile -ExecutionPolicy Bypass -File tool\check_pilot_delivery_package.ps1 -PackagePath <delivery-folder>`.
- The client receives the generated delivery package only.
- Do not send the repository root, `.git/`, `lib/`, `test/`, platform source folders, `.dart_tool/`, IDE folders, pubspec files, analysis config, scripts, logs, internal developer docs, or source archives.
- Keep `build/` and `delivery/` ignored and uncommitted.
- No new business feature scope was added in this phase.


## Phase 34 customer credit and collections
- Current tag after this phase: `phase-34-customer-credit-collections`.
- Purpose: add the local customer account ledger model for credit-sale debits, collection credits, derived balances, reports, backup/restore, and wipe integration.
- Customer balances are derived from ledger entries only. Do not add manual balance editing, opening balances, or prepayments without a dedicated accounting phase.
- Collections must not mutate inventory and must not count as new sales revenue or profit.

## Phase 35 customer credit UI pilot QA
- Current tag after this phase: `phase-35-customer-credit-ui-pilot-qa`.
- Purpose: expose Phase 34 credit sales, collections, statements, and receivable reporting in real owner-visible UI.
- New doc: `docs/PHASE-35-CUSTOMER-CREDIT-UI-PILOT-QA.md`.
- Sales credit mode must use `SaleController.createSale` and keep stock and minimum-price validations intact.
- Customers page balances must come from `CustomerAccountRepository`; no manual balance field is allowed.
- Collections must use `CustomerAccountRepository.createCollection` and reject amounts over the current balance.
- Reports must keep collections separate from sales and profit.
- Owner-facing backup wording should explain that customer balances are calculated from credit-sale and collection movements, not stored as a manual balance number.

## Phase 35A full test suite cleanup
- Current tag after this phase: `phase-35a-full-test-suite-cleanup`.
- Purpose: fix the pre-existing Phase 11 test failure and corrupted Arabic UTF-8 in delivery scripts and docs to achieve a fully green test suite before pilot handoff.
- Fix: updated sales screen cancellation dialog text to match the more complete Arabic warning the test expects.
- Delivery package re-created with corrected Arabic README.
- Full test suite: 262/262 green on commit.
- Do not skip the pre-flight test run before any future release.

## Phase 36 — Dashboard live data, supplier purchase link, supplier accounts
- Current tag after this phase: `phase-36-supplier-accounts-dashboard-live-data`.
- Purpose: fix two pilot blockers found from screen recording — dashboard showed fake data and suppliers had no functional account connection.
- Phase 36A: `DashboardService` / `DashboardController` — dashboard reads live data from all repositories (sales, inventory, products, expenses, customer accounts, supplier accounts).
- Phase 36B: `PurchaseIntake` / `PurchaseIntakeDraft` extended with `supplierName`, `supplierPhone`, `supplierAddress` snapshot fields. Backup/restore includes optional snapshot fields.
- Phase 36C: `SupplierAccountEntry`, `SupplierPaymentRecord`, `SupplierAccountRepository` — full supplier accounts ledger with purchase posting, payment validation, statement generation, cancellation safety, cash balance integration, backup/restore/wipe.
- Full test suite: 282/282 green on commit.

## Phase 36D — Pilot delivery refresh after supplier accounts
- Current tag after this phase: `phase-36d-pilot-delivery-refresh`.
- Purpose: refresh the pilot delivery package based on Phase 36. Supersedes Phase 35 delivery. No new features.
- Update docs, acceptance checklist, delivery README, and re-run quality gates.
- See `docs/PHASE-36D-PILOT-DELIVERY-REFRESH.md`.

## Phase 36E — Supplier payment UI completion
- Current tag after this phase: `phase-36e-supplier-payment-ui-completion`.
- Purpose: complete supplier payment UI — balance on supplier cards, payment button and dialog, statement payment button, purchase list balance, report supplier payments section.
- Adds `SupplierPaymentDialog` (reusable), `totalSupplierPaymentsQirsh`/`totalOutstandingSupplierPayablesQirsh` to `DailyActivityReport`.
- Full test suite: 294/294 green (12 new tests).
- See `docs/PHASE-36E-SUPPLIER-PAYMENT-UI-COMPLETION.md`.

## Phase 36F — Final pilot delivery after supplier payment UI
- Current tag after this phase: `phase-36f-final-pilot-delivery-after-supplier-payment-ui`.
- Purpose: final delivery refresh after Phase 36E. Supersedes Phase 36D. No new features.
- Phase 36E is the functional baseline.
- Supplier payment UI is available from supplier card and supplier statement.
- Reports include supplier payments and outstanding supplier payables.
- Dashboard cash balance includes supplier payments as cash outflow.
- Updated Arabic checklist, handoff docs, delivery README.
- Delivery package verified source-code safe.
- See `docs/PHASE-36F-FINAL-PILOT-DELIVERY-AFTER-SUPPLIER-PAYMENT-UI.md`.

## Phase 36G — Pilot UI clarity & cancellation safety polish
- Current tag after this phase: `phase-36g-pilot-ui-clarity-cancellation-safety-polish`.
- Purpose: improve clarity and safety of visible pilot UI without changing core accounting model.
- Purchase with supplier payments shows disabled cancel button with clear Arabic message.
- Report labels distinguish document movement from cash; customer/supplier balance labels clarified.
- Dashboard cash card shows calculation formula in subtitle.
- Supplier statement uses "مشتريات / دفعة للمورد / المتبقي" labels with explanation text.
- Customer statement shows explanation that credit sales increase balance, collections decrease it.
- No new features, no accounting changes, no safety weakening.
- See `docs/PHASE-36G-PILOT-UI-CLARITY-CANCELLATION-SAFETY-POLISH.md`.

## Phase 36G analyze cleanup
- Current tag after this phase: `phase-36g-analyze-cleanup`.
- Purpose: fix all warnings in Phase 36G test code before delivery refresh.
- Removed unused import, fixed `@override` on 4 fake methods, removed unused helpers, added `const` on 2 constructors, fixed string interpolation braces.
- Result: 0 errors, 0 warnings, 25 pre-existing info-only hints.

## Phase 36H — Delivery refresh after UI clarity polish
- Current tag after this phase: `phase-36h-delivery-refresh-after-ui-clarity-polish`.
- Purpose: refresh the pilot delivery package after Phase 36G and analyze cleanup. Supersedes Phase 36F. No new features.
- Phase 36G UI clarity improvements included: dashboard cash subtitle, report label clarity, supplier/customer statement explanations, cancellation safety UI.
- All quality gates passed: analyze 0 warnings, tests 300/300, Windows build successful, delivery source-code safe.
- See `docs/PHASE-36H-DELIVERY-REFRESH-AFTER-UI-CLARITY-POLISH.md`.

## Phase 37A — Accounting continuity: opening balances
- Current tag after this phase: `phase-37a-accounting-continuity-opening-balances`.
- Purpose: enable pilot warehouse owner to record opening balances for inventory items and supplier accounts before starting daily operations.
- **Inventory opening balance**: dedicated "إضافة رصيد افتتاحي" button on each product card without an opening balance. Unit selection (kg/ton). One opening balance per product.
- **Supplier opening balance**: new `SupplierAccountEntryType.openingBalance` (`'رصيد افتتاحي'`). `createOpeningBalanceEntry` with duplicate rejection. Debit entry (`sourceDocumentType: 'supplierOpeningBalance'`). Amount must be positive and multiples of 100 qirsh.
- **Supplier opening balance UI**: "رصيد افتتاحي" button on supplier cards (hidden after creation). `_SupplierOpeningBalanceDialog` with validation.
- **Supplier statement**: opening balance displayed with `Icons.account_balance_rounded`, label `'رصيد افتتاحي'`, debit amount.
- **Backup v2**: `backupVersion` bumped to 2. `supportedBackupVersions = {1, 2}`. v1 accepted (missing `supplierAccountEntries` resolves to `[]`). v99 rejected.
- See `docs/PHASE-37A-ACCOUNTING-CONTINUITY-OPENING-BALANCES.md`.
- Full test suite: 310/310 green (10 new Phase 37A tests).
- Quality gates: analyze 0 warnings, test 310/310, Windows build success.

## Phase 37B — Customer opening balance
- Current tag after this phase: `phase-37b-customer-opening-balance-finalization`.
- Purpose: enable pilot warehouse owner to record a pre-existing customer debt as an opening balance, mirroring the supplier opening balance pattern from Phase 37A.
- **Pre-existing support**: `CustomerAccountRepository.createOpeningBalanceEntry` and `hasOpeningBalanceEntry` already existed. `CustomerAccountEntryType.openingBalance` (`'رصيد افتتاحي'`) already existed.
- **Customer opening balance UI**: "رصيد افتتاحي" `OutlinedButton.icon` on customer cards (hidden after creation). `_CustomerOpeningBalanceDialog` with amount validation (positive, multiples of 100 qirsh). Success/error snackbars.
- **Controller**: `recordOpeningBalance`, `hasOpeningBalanceForCustomer`, `_loadCustomersWithOpeningBalance`, `_openingBalanceMessageForError` — all new.
- **Statement display**: opening balance shown with label `'الرصيد الافتتاحي: X ج.م'` instead of debit/credit. Misleading "لا يوجد رصيد افتتاحي يدوي" removed.
- **Rules**: one opening balance per customer. No opening balance after existing transactions. No negative/zero amounts.
- See `docs/PHASE-37B-CUSTOMER-OPENING-BALANCE.md`.
- Full test suite: 321/321 green (11 new Phase 37B tests).
- Quality gates: analyze 0 warnings, test 321/321, Windows build success.

## Delivery tool
- `tool\create_pilot_delivery_package.ps1` — creates the customer delivery folder.
- `tool\check_pilot_delivery_package.ps1` — verifies the delivery folder excludes source code.
- Run both before any customer handoff.
- Do not commit the `delivery/` folder.
- Use `-OutputRoot` parameter to customise the folder name, or let it auto-stamp.

## Core business rules
- Money is stored internally as integer piasters/qirsh.
- Normal UI displays ج.م/جنيه, not raw qirsh.
- Minimum sale price is enforced before stock or sale mutation.
- Reference cost is optional.
- Estimated profit and stock valuation are incomplete when reference cost is missing.
- Restore remains limited to an empty system under the current safe design.
- Supplier account balance = debit (purchases) − credit (payments). Cannot go below zero.
- Purchase cancellation is blocked if supplier payments have been recorded for that supplier.
- Dashboard cash balance = cash sales + customer collections − expenses − supplier payments.
