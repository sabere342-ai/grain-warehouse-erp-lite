# Developer Handoff Notes

## Current state
- Latest phase: Phase 35 customer credit UI pilot QA.
- Previous stable tag before this phase: `phase-34-customer-credit-collections`.
- Main app path: `C:\dev\multi-pos\grain-warehouse-erp-lite`.
- Windows release exe path: `build\windows\x64\runner\Release\grain_warehouse_erp_lite.exe`.

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
