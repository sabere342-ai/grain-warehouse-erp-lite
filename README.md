# Grain Warehouse ERP — مشروع غلال

**An Arabic-first Windows ERP that helps a grain warehouse control inventory, sales, purchases, accounts, and daily financial operations in one local, safeguarded workflow.**

## Demo

[Watch the public YouTube demo](https://youtu.be/8bmJR0_Zmp4) — a 2:54 walkthrough with Arabic narration and burned-in Arabic captions. This English README provides the accompanying context for non-Arabic judges.

## Overview

Grain warehouses connect weighted products, purchases, sales, customer and supplier accounts, expenses, and stock movement. When those records are split across notebooks, quantities, balances, and document history become difficult to reconcile. مشروع غلال brings that work together in an offline Windows desktop application for one warehouse, without requiring a server or continuous internet connection.

## Core Capabilities

- Products measured in kilograms and tons, with internal weight consistency.
- A movement-led inventory ledger, stocktaking and adjustment workflows, variance reporting, and protection against invalid stock outcomes.
- Customer-linked, multi-item cash and credit sales.
- Customer collections, balances, account ledgers, and statements.
- Supplier-linked purchases, payments, balances, account ledgers, and statements.
- Expense recording and analysis.
- Treasury, bank, and wallet financial accounts, including balances, statements, transfers, and payment-method reporting.
- Operational and financial reports covering activity, flows, collections, supplier payments, advances and refunds, closing, and expense analysis.
- Document history with cancellation status and five supported printable/PDF documents: sales invoice, purchase invoice, customer statement, supplier statement, and daily activity report.
- Period closing and reconciliation with retained variances and controlled reopening.
- Versioned backup, validation before restore writes, and protected owner-only data deletion with a required pre-wipe backup.
- Separate owner and employee roles with granular permissions.
- Arabic help and first-run guidance.
- Twelve narrowly scoped, permission-controlled, read-only AI actions over canonical inventory and financial-report boundaries.

## How Codex Was Used

Codex reviewed repository evidence, worked within narrow phases, implemented authorized changes, added or updated tests, ran focused and complete verification, audited permission and accounting boundaries, verified the Windows release, and prepared and verified source-safe delivery artifacts.

## How GPT-5.6 Was Used

GPT-5.6 supported product-requirement reasoning, accounting-boundary and permission analysis, scope definition, test and acceptance planning, review of Codex results, and release and competition-readiness decisions.

## Build Week Scope and Prior Work

This project existed before Build Week. Dated commits and the `docs/BUILD-WEEK-*` records distinguish the inherited product from the work completed during the event.

### Before Build Week

The project already had its core local ERP foundation: Arabic RTL Windows workflows for products, inventory movements, customers, suppliers, purchases, multi-item sales, collections, payments, expenses, financial accounts, documents, backup and restore, roles, permissions, and durable local persistence.

### During Build Week

Build Week work added and hardened:

- Read-only AI action boundaries, canonical reader delegation, and caller-supplied tool composition.
- Financial reporting and analysis surfaces, including flows, account-filtered collections and supplier payments, advances/refunds, closing/reconciliation history, and expense analysis.
- Dashboard truth, protected-read ordering, and permission boundaries.
- Navigation, visible workflow polish, and competition readiness.
- Focused and full-suite testing, Windows release verification, packaging, source-safe delivery, and integrity checks.
- Competition README preparation, video editing, captions, media QC, and submission materials.

## Architecture and Safety Principles

- **Accounting correctness:** financial balances and reports come from canonical ledger entries and domain services; the AI layer does not recalculate or repair them.
- **Protected reads:** permission checks occur before readers are invoked, preventing unauthorized data discovery.
- **Read-only reporting and AI:** report and AI actions do not post transactions, change balances, or reopen periods.
- **Inventory protection:** stock is derived from movements rather than direct quantity edits, with guarded outflows and auditable reversals.
- **Closed-period protection:** closing records retain actual balances and variances, lock the period, and require controlled reopening.
- **Restore safety:** backups are previewed and validated before writes; restore is limited to an empty business system.
- **Auditable cancellations:** original documents remain in history and reversals record the business effect instead of deleting evidence.

## Running the Windows Release

1. Download the approved release ZIP from the Devpost submission or another approved release location.
2. Extract the entire ZIP to a normal writable folder.
3. Keep the executable, DLLs, and `data` directory together.
4. Run `grain_warehouse_erp_lite.exe` from the extracted folder, not from inside the ZIP.
5. Use fictional test data.
6. Follow the in-app Arabic first-run and help guidance.

## Building From Source

Install Flutter with Windows desktop support and the normal Flutter Windows prerequisites, including Visual Studio with the **Desktop development with C++** workload and a Windows SDK. No additional version constraint is asserted here beyond the project files and Flutter's supported Windows toolchain.

From the repository root:

```powershell
flutter pub get
flutter analyze
flutter test
flutter build windows --release
```

The release executable is produced under Flutter's Windows release output directory.

## Verification

The final pre-documentation freeze recorded:

- Flutter and Dart analysis completed cleanly.
- 1,460 tests passed, with one established expected skip and zero failures.
- The Windows release candidate built successfully.
- An independently extracted, per-file-verified, source-safe delivery package passed smoke launch verification.
- The final captioned competition video is approximately 2:54.767 and has SHA-256 `AB49334FD3C3931962752E81596327A4F8DB14239A186971BC8CAE9C844C9834`.

## Current Scope

- Windows desktop.
- One warehouse.
- Arabic-first interface.
- Local, offline operation.

## Roadmap

The following are future work and are **not implemented in the current release**:

- Cloud synchronization.
- Android and other mobile access.
- Multi-device operation and conflict handling.
- Further reporting and visual modernization.

## Repository and Delivery Integrity

The verified engineering baseline before this README-only update is `2a8ac3de953551103bd097f4bd9aba6799102c0c`.

The frozen delivery ZIP has SHA-256:

```text
C0DAD6FA349177CB909CC161198ED4BEFB31A136952959CF58AF290C09DA0820
```

This documentation-only Git commit does not modify the frozen executable, delivery ZIP, final handoff, media exports, production code, accounting behavior, inventory behavior, permissions, or tests. Editing or recompressing the frozen ZIP would invalidate its verified identity and require a new integrity review.

Repository: [sabere342-ai/grain-warehouse-erp-lite](https://github.com/sabere342-ai/grain-warehouse-erp-lite)

## License

No repository license has been added in this documentation-only update.
