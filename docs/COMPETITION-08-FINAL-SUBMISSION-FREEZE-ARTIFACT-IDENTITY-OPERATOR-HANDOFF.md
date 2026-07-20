# COMPETITION-08 — Final Submission Freeze, Artifact Identity, and Operator Handoff

## A. Final decision

**GO — Final Competition Submission Frozen.** The authorized baseline was
independently reverified with clean Flutter and Dart analysis, a complete
1,460-test pass with the one established expected skip, and a successful
Windows Release build through the repository-established direct Flutter-tool
fallback. The expected executable exists and has been assigned the exact
identity recorded below. No reproducible qualifying submission blocker was
found, and no production or test change was required.

## B. Repository baseline

| Item | Observed value |
| --- | --- |
| Branch | `phase9e-expense-analysis-report` |
| Starting HEAD | `a245e15fb335f59be4c6fe8b4bcab1245b6f4aac` |
| Starting message | `COMPETITION-07: verify final competition delivery package readiness` |
| Parent COMPETITION-06 commit | `d8676b5de137c7090d95771a36fb098b27c7b013` |
| Parent relationship | `git rev-parse HEAD^` returned the exact COMPETITION-06 hash above |
| Initial Git status | `?? .build-diagnostics/` |
| Initial staged files | None; `git diff --cached --name-only` was empty |
| Final evidence HEAD before this documentation-only closure commit | `a245e15fb335f59be4c6fe8b4bcab1245b6f4aac` |
| Closure commit | `COMPETITION-08: freeze final submission artifact and operator handoff`; its hash is recorded by the final Git log and completion report because a commit cannot embed its own hash |
| Expected post-commit status | `?? .build-diagnostics/` only |

`.build-diagnostics/` remained untouched, untracked, and unstaged. No reset,
restore, checkout cleanup, stash, history rewrite, tag, or push occurred. The
existing COMPETITION-07 document was preserved without modification.

## C. Relationship to COMPETITION-07

COMPETITION-07 established a source-safe competition package from
COMPETITION-06, verified its complete Windows runtime, scanned it for source,
secrets, databases, backups, and build leakage, launched it from the package,
and verified archive extraction and hash continuity. Its verified executable
was 785,408 bytes with SHA-256
`C429E3DB59C6512409C8CCA19B4F03158B5B1E3B5336BC917B2B5C7341F3D93B`.

COMPETITION-08 is a distinct final freeze because it starts at the committed
COMPETITION-07 baseline, reruns both analyzers and the entire automated suite,
performs a fresh release build, assigns a new exact executable identity, and
freezes the final operator, recovery, and change-control rules. It does not
duplicate or replace the COMPETITION-07 package audit and did not create a new
archive. No COMPETITION-07 conclusion was contradicted. The new hash differs
because COMPETITION-08 rebuilt the executable; this is precisely why artifact
identity must be re-recorded after every build.

## D. Verification matrix

| Gate | Exact observed result |
| --- | --- |
| Flutter analyzer | `flutter analyze --no-pub` exited `0`; `No issues found! (ran in 159.5s)`. It printed an informational Flutter-update notice; no update was performed. |
| Dart analyzer | `C:\src\flutter\bin\cache\dart-sdk\bin\dart.exe analyze` exited `0`; `No issues found!`. |
| Full suite | `flutter test` exited `0` after 253.7 seconds; final result `+1460 ~1: All tests passed!`: 1,460 passed, one skipped, zero failures, no unexpected skips or hangs. |
| Expected skip | One: `test/phase9a_inflows_outflows_reports_test.dart`, annotated `Requires negative balance approval with actual credentials`. |
| Normal Windows launcher attempt | `flutter build windows --release` produced no diagnostics and timed out after 601.4 seconds with exit `124`; it is not counted as the successful build. |
| Direct build attempt without SDK lock access | The established direct command exited `1` because `C:\src\flutter\bin\cache\lockfile` was inaccessible; no SDK file was changed or deleted. |
| Windows Release build | The same established direct Flutter-tool command, with required SDK lockfile access, exited `0`; Flutter reported `Built build\windows\x64\runner\Release\grain_warehouse_erp_lite.exe` in 59.5 seconds. |
| Build warnings | Existing non-blocking Firebase CMake compatibility deprecation and MSVCRT `LNK4078` multiple-`.voltbl` warnings. No new source warning or failed link was observed. |
| Pre-document Git integrity | `git diff --check` exited `0` with no output; no file was staged. |

## E. Windows artifact identity

| Property | Frozen value |
| --- | --- |
| Filename | `grain_warehouse_erp_lite.exe` |
| Exact local path | `C:\dev\multi-pos\grain-warehouse-erp-lite\build\windows\x64\runner\Release\grain_warehouse_erp_lite.exe` |
| Build mode | Windows Release |
| Successful build command | `C:\src\flutter\bin\cache\dart-sdk\bin\dart.exe C:\src\flutter\packages\flutter_tools\bin\flutter_tools.dart build windows --release` |
| Successful build exit code | `0` |
| Exists | Yes |
| Size | `785408` bytes |
| Last modified, Africa/Cairo | `2026-07-20 14:37:19.2700115 +03:00` |
| Last modified, UTC | `2026-07-20T11:37:19.2700115Z` |
| SHA-256 | `CC24816F7E88F12C3DAEED322027EC022A0799EBD0E7DF88C15B591968CA7792` |

This hash identifies the locally verified executable produced by this run. A
rebuild creates a different artifact identity even when the source commit is
unchanged. A rebuilt executable must not replace the frozen submission binary
without rerunning all release gates, recording a new hash, and re-auditing the
external package.

## F. Source-safe delivery manifest

The approved recipient boundary remains the one proven by COMPETITION-07: the
complete compiled Windows Release runtime plus explicitly approved user-facing
support documents. Source remains excluded. COMPETITION-08 does not invent a
new package directory, silently replace the existing archive, or claim that an
executable alone is a complete Flutter Windows runtime.

The recipient package may contain only:

- The complete contents of the verified
  `build\windows\x64\runner\Release\` directory, including the executable,
  required DLLs, `data\` assets, and generated runtime dependencies.
- Approved user-facing instructions, demo guidance, implemented-scope notes,
  and release identity information.
- Compiled branding/runtime assets required by the application.

It must exclude source code, `.git`, tests, internal audit or developer records
not approved for the recipient, `.build-diagnostics/`, development scripts,
debug executables, symbols unless an approved runtime dependency requires
them, build intermediates outside the Release runtime, user databases, backup
files containing business data, credentials, secrets, tokens, machine-specific
configuration, and unrelated repository files.

No canonical automatic final-competition packager is current. The existing
pilot packaging scripts describe an older Phase-69 client package and must not
be treated as authority for this final artifact. If a fresh external package is
required, use this manual established boundary:

1. Create an empty recipient folder outside the source tree or in an already
   ignored delivery workspace; do not stage it.
2. Copy the complete verified `Release\` directory, not only the `.exe`.
3. Add only owner-approved user-facing documents. Do not copy this internal
   governance record unless the owner explicitly approves it for delivery.
4. Confirm the copied executable is exactly 785,408 bytes and has SHA-256
   `CC24816F7E88F12C3DAEED322027EC022A0799EBD0E7DF88C15B591968CA7792`.
5. Recursively reject `.dart`, `.git`, source/test/tool directories, scripts,
   logs, databases, backup JSON, private keys/certificates, environment files,
   credentials, tokens, developer paths, `.dart_tool`, `.build-diagnostics`,
   and non-Release build intermediates.
6. Extract any final archive into a separate verification folder, repeat the
   path audit, and verify the extracted executable hash before handoff.

## G. Final competition demo sequence

Use controlled synthetic demo data and the owner account. Keep the route short
and do not enter deferred features.

1. Start the frozen Release executable. On a first installation, show the
   first-owner setup guidance; otherwise sign in with the authorized owner.
2. Establish the role boundary: the owner receives owner navigation and
   financial data; an employee lacks owner-only reports, audit, backup, wipe,
   settings, cancellation, purchasing, stock-adjustment, and supplier-payment
   capabilities according to the permission model. Do not expose credentials.
3. Open the owner dashboard and explain that financial-account balances are the
   canonical KPI source, including inactive accounts where required; daily
   sales/cash-flow, receivables, payables, stock, and alerts remain read-only.
4. Show Products and Inventory, one active product, its stock movement context,
   and the stocktake/variance navigation without making an unnecessary
   adjustment.
5. Create one controlled customer sale, then show the sale record and the
   resulting stock decrease and customer/financial effect appropriate to the
   selected payment mode.
6. Create one controlled supplier purchase, then show the purchase and stock
   increase. The competition route does not claim a purchase `paidNow` field.
7. Record a customer collection against the selected financial account and
   show the customer ledger/account effect.
8. Record a supplier payment as owner and show the supplier and financial
   account effect; this also demonstrates the employee boundary.
9. Record one controlled expense with account and payment method, then show the
   resulting financial-account outflow.
10. Open operational and owner-only financial reports; show canonical balances,
    account statement/flows, expense analysis, and the applicable party/account
    summaries without recalculating figures in the UI.
11. Open Document History and show immutable original records, cancellation
    status, and owner-only cancellation audit detail where present.
12. Preview/export the five frozen printable documents listed below. Confirm the
    PDF destination before writing and avoid overwriting an existing filename.
13. Open Closing/Reconciliation as owner. Explain ledger-derived expected
    balance, mandatory actual balances, retained difference, posting lock,
    confirmation, and reason-required reopening. Avoid closing a live demo
    period unless that controlled action is planned.
14. Open Backup and create or point to a known-good controlled backup. Show
    restore preview and the empty-system guard only; do not perform restore or
    data wipe during the normal demonstration. Show the wipe confirmation
    boundary without completing it.
15. Open Help/first-run guidance, confirm the configured establishment name,
    logo, theme, and Arabic RTL presentation, then finish by showing the frozen
    executable filename and SHA-256 from Section E.

## H. Printable-document freeze

Repository and COMPETITION-05/06/07 evidence establish exactly these five PDF
document types. The daily activity report is an existing member of the five;
this freeze adds no new daily-report implementation or sixth print type.

| Document | Entry point and authorization | Preview and PDF/export | Branding and cancellation |
| --- | --- | --- | --- |
| Sales invoice (`فاتورة بيع`) | Sales list → invoice preview; reachable through the authenticated sales flow. Employees may create sales, while cancellation and protected audit detail remain owner-controlled. | Shared RTL printable scaffold with visible return and export; canonical immutable sale, item order, totals, payment mode/method, and notes; `MultiPage` PDF and non-overwriting filename suffixes. | Saved establishment identity and safe optional logo are used. A cancelled sale is explicitly shown as cancelled with reversed balances, not deleted or presented as a refund. |
| Purchase invoice (`فاتورة شراء`) | Supplier purchases → invoice preview; purchase intake/supplier management is owner-authorized in the current permission model. | Shared preview/return/export using the immutable purchase, stored supplier snapshot/fallback, item, quantity, price, payment data, and notes; `MultiPage` PDF. | Saved identity/logo are used. Cancellation is displayed explicitly and is not reclassified as a refund. |
| Customer statement (`كشف حساب عميل`) | Customers/customer statement → preview; follows the authenticated customer route and canonical customer-account repository statement. | Shared preview/return/export preserves ordered statement lines and supplied running/final balances; `MultiPage` PDF. | Saved identity/logo are used. Ledger lines retain their canonical status; no cancellation or refund meaning is invented. |
| Supplier statement (`كشف حساب مورد`) | Supplier statement → preview; supplier/account management is owner-controlled in the current route and permission model. | Shared preview/return/export preserves ordered statement lines and supplied running/final balances; `MultiPage` PDF. | Saved identity/logo are used. Ledger lines retain their canonical status; no cancellation or refund meaning is invented. |
| Daily activity report (`التقرير اليومي`) | Operational Reports → printable daily report; `canViewReports` is owner-only in the frozen role matrix. | Shared preview/return/export uses the selected date and canonical report totals/sections; `MultiPage` PDF. | Saved identity/logo are used. Party and cancellation fields do not apply to this aggregate report. |

There is PDF export and assisted WhatsApp handoff where implemented, but no
automatic WhatsApp sending and no direct thermal-printer contract.

## I. Security, permission, and safety freeze

- **Owner-only financial boundary:** `canViewFinancialReports` and
  `canExportFinancialReports` are true for the owner and false by default for
  the employee. Protected dashboard/report readers authorize before reading.
- **Employee boundary:** the employee may create sales, customer payments, and
  expenses, but cannot manage products/suppliers, create purchase intake,
  create supplier payments, adjust stock, cancel invoices, view reports or
  audit logs, access settings, export backups, wipe data, approve below-minimum
  pricing, or view/export financial reports.
- **Inventory:** both authenticated roles can open the inventory destination and
  read the operational product/quantity view. Stock remains derived from
  immutable movements. Product management, stocktake/adjustment actions, and
  the stock-adjustment report are permission-gated to the owner; employee read
  access does not grant an inventory write.
- **Audit logs:** visible only with `canViewAuditLogs`; current employee
  permissions deny it. Document history also withholds owner-only cancellation
  audit detail from employees.
- **Closing/reopening:** owner-only. Actual balances are mandatory for active
  accounts; expected balances remain ledger-derived; differences never create
  fabricated balancing entries. Approved periods lock dated postings, and
  reopening requires a reason while preserving history.
- **Backup:** owner-only export. Backup v6 preserves the documented transaction
  financial-account/payment-method fields and supports v1–v5 compatibility
  without inventing missing values.
- **Restore:** owner-only; preview, checksum/structure and relationship checks
  occur before writes; non-null financial references are validated; restore is
  allowed only into an empty business system. Production Drift operations are
  transaction-backed, and auth/session data is intentionally not restored.
- **Data wipe:** owner-only, requires the established exact confirmation phrase,
  creates a backup before clearing business data, blocks the wipe if backup
  fails, and preserves the owner authentication and business-identity boundary.
- **Destructive confirmations:** invoice cancellation, closing/reopening,
  restore, and wipe retain their existing review/reason/confirmation contracts;
  no shortcut is authorized for the demo.
- **AI:** the inventory is frozen at 12 caller-supplied actions. All are
  read-only; financial actions authorize before their injected reader; the
  closing action is owner-gated. Registries are explicitly caller-composed,
  immutable, have no global/default discovery, and reject duplicate IDs. AI
  tools/readers do not import repositories, recalculate qirsh totals, reorder
  canonical rows, repair nulls, or mutate application state.

## J. Intentional exclusions

The competition demonstration and delivery contract intentionally excludes:

- Split Payments. The repository contains DC-U002 core/UI implementation and
  regression coverage, so this is a competition-contract exclusion rather than
  a claim that no code exists; do not depend on or demonstrate it in the frozen
  submission route.
- Cloud synchronization, backend operation, and online mode.
- Android or other mobile application delivery.
- Concurrent operation of the same business data across multiple devices.
- Automatic WhatsApp sending. Existing assisted sharing only opens a prepared
  handoff; it is not automated delivery.
- Direct thermal-printer integration. Supported output is preview/PDF export.
- A purchase `paidNow` contract.
- AI Action 13 or any expansion beyond the frozen 12-action inventory.
- Multi-currency, SaaS/multi-tenancy/licensing, remote database/API,
  allocation-aware future AI reports, and other items still marked deferred by
  the governing roadmap.

These are deferred or deliberately excluded scope items, not submission defects.

## K. Submission-day operator checklist

- [ ] Confirm the file is `grain_warehouse_erp_lite.exe`, size is 785,408 bytes,
      and SHA-256 is
      `CC24816F7E88F12C3DAEED322027EC022A0799EBD0E7DF88C15B591968CA7792`.
- [ ] Use the frozen executable and its complete Release runtime; do not rebuild.
- [ ] Open the application before judging begins and sign in with the controlled
      owner account.
- [ ] Confirm establishment name, optional logo, Arabic RTL, and selected theme.
- [ ] Use controlled synthetic demonstration data only.
- [ ] Confirm the PDF export destination and ensure it does not contain client
      or developer material that should not be shown.
- [ ] Confirm a known-good backup exists on a clear external destination.
- [ ] Keep source and development directories entirely outside the recipient
      package and presentation folder.
- [ ] Avoid restore and data wipe during the normal demo; show preview/guards only.
- [ ] Record feedback separately without changing or rebuilding the frozen
      release during the session.
- [ ] Preserve the frozen runtime and its hash after the competition.

## L. Recovery and rollback

- **Frozen source baseline:**
  `a245e15fb335f59be4c6fe8b4bcab1245b6f4aac` plus this documentation-only
  COMPETITION-08 closure commit. Production bytes are unchanged from the
  starting source baseline.
- **Frozen binary:** use only the exact artifact identity in Section E. Preserve
  a read-only copy of the complete Release runtime or verified external archive
  and its hash manifest.
- **Safe return:** stop using any experimental or rebuilt copy, retrieve the
  preserved complete frozen runtime, verify the executable hash, and launch it
  with the intended business data location. Do not copy only the `.exe` over a
  mismatched runtime directory.
- **Business recovery:** preserve a known-good owner-created backup before risky
  operations. Preview and validate a selected backup; restore only as owner and
  only into an empty business system. Never test restore or wipe against the
  live competition data during the normal session.
- **Repository safety:** databases, runtime-generated data, user backups, logos
  containing client material, and exported PDFs are user data, not source. They
  must never be committed, staged, or placed in the source-safe recipient
  package unless explicitly approved and sanitized.
- **Replacement rule:** any rebuilt or modified executable has a new artifact
  identity. It requires both analyzers, focused regressions where relevant, the
  full suite, Windows Release build, hashing, runtime/package audit, and a new
  freeze record before it can replace this binary.

## M. Final production freeze rule

No further production change may enter the competition build unless all of the
following are true:

1. A reproducible qualifying submission blocker is proven.
2. The owner explicitly authorizes a narrow remediation.
3. The change is limited to the proven blocker.
4. Relevant focused regression tests pass.
5. The complete automated suite passes.
6. Flutter and direct Dart analyzers pass.
7. The Windows Release build passes.
8. The replacement artifact is hashed and documented.
9. The source-safe delivery boundary is re-audited.

Cosmetic preferences, optional refactoring, deferred roadmap work, new feature
ideas, unsupported cloud/mobile behavior, and hypothetical concerns are not
qualifying blockers. Until the complete gate is repeated, this submission
baseline and the artifact identity in Section E remain frozen.
