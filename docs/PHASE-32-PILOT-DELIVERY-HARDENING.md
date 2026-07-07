# Phase 32 Pilot Delivery Hardening

## Purpose
Phase 32 hardens the local Windows pilot after the Phase 31 visible-page recovery. The goal is to make the owner delivery safer to accept without adding cloud, SaaS, mobile, multi-client, or full accounting modules.

## Scope Completed
- Reviewed the owner-visible pages for real function and clear Arabic wording.
- Kept Customers, Expenses, and Audit Logs visible as functional pages, not placeholder bodies.
- Updated backup wording so it no longer says restore is unavailable when safe restore-to-empty exists.
- Added an owner acceptance scenario test covering product setup, supplier intake, sale, invalid sale rejection, customer entry, expense entry, report totals, audit logs, backup, and restore-to-empty.
- Verified old backups without Phase 31 customer, expense, and audit lists remain previewable and restorable.
- Updated the pilot package script to include the owner acceptance checklist.

## Visible Page Status
| Page | Phase 32 status |
| --- | --- |
| First owner setup | Functional local setup. |
| Login | Functional local login. |
| Dashboard | Functional owner summary and backup guidance. |
| Sales | Functional cash sale flow with minimum price and stock checks. |
| Purchases | Functional supplier intake and inventory movement. |
| Products | Functional product and pricing setup. |
| Inventory | Functional stock movement review. |
| Suppliers | Functional supplier records. |
| Customers | Basic customer records only; no balances, credit, collections, or aging. |
| Expenses | Basic expense records and reporting only; no inventory mutation and no payable accounting. |
| Reports | Functional pilot reports; estimated profit appears only when reference costs are complete. |
| Audit logs | Read-only local audit records for supported owner actions. |
| Settings and help | Local pilot guidance only. |
| Backup export | Functional export with selected pilot docs. |
| Restore preview and restore-to-empty | Functional safe preview and restore only into an empty system. |
| Document history | Functional history for purchase and sale documents. |
| Data wipe | Functional local maintenance action with existing safety checks. |

## Accounting Boundaries
- Customers are contact records only in this pilot.
- No customer balances, credit sale ledger, collections, aging, or settlement reports are exposed.
- Expenses are standalone local records and report totals only.
- Expenses do not reduce inventory and do not create supplier/customer payables.
- Profit is not invented when product reference cost is missing.
- Audit logs are local read-only history, not a tamper-proof external audit system.

## Backup And Restore
- Backup export includes products, inventory movements, suppliers, purchases, sales, document history, customers, expenses, and audit logs.
- Restore remains limited to an empty system.
- Preview does not modify existing data.
- Older backups without Phase 31 lists default those lists to empty.
- Owner-facing backup wording now describes safe restore-to-empty instead of saying restore is unavailable.

## Code Exposure Rules
Send only the pilot delivery package and selected owner documents.

Safe to send:
- The generated `delivery\grain_warehouse_erp_lite_pilot*` folder.
- The `Release` folder inside the generated delivery package.
- Owner documents included by `tool\create_pilot_delivery_package.ps1`.
- `docs\PILOT-OWNER-ACCEPTANCE-CHECKLIST-AR.md`.

Do not send:
- The repository root.
- `.git/`.
- `lib/`, `test/`, `tool/`, or source archives.
- `docs/` wholesale.
- Build intermediates outside the delivery package.
- Development logs, local temp folders, or IDE metadata.

## Verification
Completed on 2026-07-07:

| Command | Result |
| --- | --- |
| `flutter.bat analyze --no-pub` | Passed, no issues found. |
| `flutter.bat test test\phase32_pilot_acceptance_test.dart` | Passed, 4 Phase 32 checks. |
| `flutter.bat test` | Passed, 250 tests. |
| `flutter.bat build windows --release` | Passed; built `build\windows\x64\runner\Release\grain_warehouse_erp_lite.exe`. |
| `powershell -NoProfile -ExecutionPolicy Bypass -File tool\create_pilot_delivery_package.ps1` | Passed; created `delivery\grain_warehouse_erp_lite_pilot_20260707-152631`. |

The Windows build kept the known non-blocking CMake deprecation and MSVC `LNK4078` warnings already tracked in the handoff notes.

## Known Limitations
- This is a local Windows pilot, not a cloud or multi-branch product.
- Restore is intentionally restricted to an empty system.
- Customer and expense features are intentionally basic until real pilot feedback proves the next accounting scope.
- Full accounting, cashbox, credit, bank, wallet, tax, and supplier/customer settlement modules remain outside this phase.
