# Project Identity

Grain Warehouse ERP Lite is an Arabic-first, right-to-left Flutter/Dart ERP for a grain warehouse. Its verified current product scope is a local, offline Windows desktop application for one warehouse. It manages weighted grain inventory, purchases and sales, customers and suppliers, collections and payments, expenses, financial accounts and transfers, advances and refunds, closings and reconciliation, reports and PDFs, business identity, backup/restore, roles, permissions, and audit history.

The repository uses Drift/SQLite for durable local business data. It also contains Supabase adapters and distributed-state foundations; their presence does not by itself prove that cloud synchronization, Android, multi-device operation, deployment, or production use is implemented or authorized. Verify current evidence before making such claims.

# Authority and Scope

Instruction precedence is:

1. Explicit owner/user instruction.
2. Binding repository governance.
3. The closest applicable `AGENTS.md`.
4. Selected task skills.
5. General engineering defaults.

Operate only within the authority of the current task. A skill supplies procedure, never permission. It does not authorize implementation, architecture migration, dependency changes, commits, pushes, release, delivery, deployment, production work, publishing, or destructive actions.

# Required Skill Routing

Before non-trivial Flutter work, classify the task, choose the minimum relevant skills, verify that each selected skill is available, read each selected `SKILL.md` completely, read only relevant linked references, inspect repository instructions and the existing implementation, and restate the authorized boundary.

- General Flutter implementation: `flutter-core-engineering`.
- UI/UX: `flutter-core-engineering`, `flutter-ui-ux`, `flutter-accessibility`, and `flutter-testing`; add `flutter-rtl-arabic` whenever Arabic, RTL, bidirectional, numeric, financial, report, or PDF presentation can change.
- Business logic or bug fixes: `flutter-core-engineering` and `flutter-testing`.
- Offline, database, persistence, migration, backup, or synchronization: `flutter-core-engineering`, `flutter-offline-data`, and `flutter-testing`; add `flutter-security` when identity, authentication, authorization, sensitive data, tenant scope, cloud access, permissions, or credentials are involved.
- Performance work: `flutter-core-engineering`, `flutter-performance`, and `flutter-testing`.
- Security work: `flutter-core-engineering`, `flutter-security`, and `flutter-testing`.
- Review: `flutter-code-review`; add only the specialist skills genuinely needed by the review.
- Release, build, signing, packaging, or delivery: `flutter-release`.

Do not load every skill for every task. If a required skill is unavailable, stop before implementation and report:

```text
REQUIRED_SKILL_UNAVAILABLE
SKILL = <name>
ACTION = STOP_BEFORE_IMPLEMENTATION
```

# PRESERVE ESTABLISHED ARCHITECTURE

The codebase has established `app`, `application`, `composition`, `core`, `features`, `infrastructure`, and `shared` boundaries, including application commands and queries, repositories, infrastructure adapters, and a composition root. Inspect the relevant paths and preserve their actual ownership.

Do not treat generic Flutter guidance as permission to migrate wholesale to BLoC, Riverpod, Provider, Redux, MVVM, Clean Architecture, another database, another navigation framework, another repository framework, or another synchronization architecture. Do not perform unrelated reorganization. Improve incrementally and reuse established controllers, services, repositories, models, error semantics, dependency composition, UI components, and state-management patterns.

# Application Query and Command Boundaries

Keep reads behind established application-query and read-repository seams. Keep writes behind the existing application/domain commands, controllers, repositories, transaction owners, gateways, and projection writers. Do not move business logic into widgets for convenience, bypass these layers with direct persistence or cloud calls, or collapse command/query seams without explicit authorization and repository evidence.

Composition ownership is part of the architecture: construct and inject dependencies at the established roots instead of creating hidden service locators or parallel dependency graphs. Preserve caller-visible behavior, serialized formats, persistence compatibility, and failure semantics unless the task explicitly changes them.

# Domain and Accounting Integrity

Treat inventory balances, grain quantities, warehouse movements, purchases, sales, expenses, customer collections, supplier payments, financial-account entries, transfers, refunds, advances, closings, financial totals, reports, backups, and PDF outputs as high-integrity data. UI success is never proof of accounting correctness.

For any authorized mutation of financial or inventory state, identify and verify:

- transaction ownership and the real durable atomic boundary;
- balance, ledger, inventory, and double-entry invariants where applicable;
- duplicate execution, replay, and idempotency behavior;
- partial failure, timeout, retry, rollback, and recovery behavior;
- cancellation or reversal semantics and audit history;
- consistency among source records, projections, balances, reports, and exports.

Do not invent accounting behavior. Use repository code, tests, and governing evidence. Preserve movement-led inventory and append/reversal history where those are established; do not replace them with direct balance edits or deletion of accepted evidence.

# Testing and Verification

Add or update tests proportionate to the behavior and risk:

- Business or domain calculation: unit test.
- Widget rendering or interaction: widget test.
- Bug fix: regression test that fails for the defect.
- Critical end-to-end workflow: integration test or the repository's established critical-flow equivalent.
- Persistent schema or migration: fresh-database and upgrade-path tests using representative existing data.
- Financial command: positive, negative, duplicate/replay, and atomicity/failure cases where applicable.
- Offline operation: offline, restart durability, retry, reconnect, duplicate prevention, rejection, and conflict handling where applicable.
- PDF or report: source records, totals, dates, identities, Arabic/RTL, fonts, pagination, and export/print behavior as applicable.

Run the repository-approved formatter, targeted tests, analyzer, broader tests, and platform/build checks warranted by risk. Report exact commands, exit codes, failures, skips, and unverified areas. `flutter analyze` is not behavioral testing. `flutter test` is not proof that a packaged release works. Never claim success without current evidence.

# Offline, Persistence, and Data Safety

Protect the persistent database, schema and migrations, local caches, durable operation queues, outboxes, inboxes, conflict records, checkpoints/cursors, identity/scope/time metadata, trial/security state, business identity files, and backup/export data wherever they exist.

Any authorized persistent-schema or restore change must address fresh install, upgrade from supported prior data, existing customer data, transactions, rollback/recovery, backup compatibility, and tests. Do not casually mutate schema, delete data, regenerate persistence code outside scope, or treat an in-memory rollback as proof of crash-safe durability.

Backup/restore and destructive-data workflows require exact target resolution, validation before writes, authorization, recovery planning, and preservation of current repository invariants. A local cache reset and destruction of authoritative business data are different operations.

# Distributed and Synchronization Safety

For distributed or synchronization work, first verify what is implemented versus planned. Consider stable global identity, business/user/device scope, authority ownership, time semantics, payload fingerprints, idempotency, duplicate and out-of-order delivery, durable outbox/inbox behavior, retries, checkpoints, conflict state, partial network failure, reconnect, and local/remote divergence. Never assume exactly-once delivery.

Financial, inventory, closing, numbering, approval, and reversal acceptance requires the authoritative transaction boundary defined by the system; cached UI state or provisional/offline state must not silently become final accounting truth. Make provisional, queued, accepted, rejected, and conflict states explicit when the applicable design requires them.

# PDF and Reporting

PDF, printable-document, CSV, dashboard, and report changes must preserve the correctness of underlying records, totals, dates, customer/supplier identity, warehouse/business identity, financial and inventory semantics, Arabic text, bundled fonts, pagination, and print/export consistency. Visual similarity alone is insufficient.

Branding or logo work must not silently change report queries, domain selection, authorization, totals, or data ownership. Reuse established application queries and report services rather than issuing convenient direct reads from presentation or export code.

# UI, RTL, and Accessibility

Arabic-first RTL behavior is a product invariant. Use directional start/end layout APIs where direction can vary. Verify mixed Arabic/English content, tables, numeric columns, weights, currency, forms, dialogs, reports, PDFs, keyboard and focus flow, and dense Windows desktop layouts. Do not redesign unrelated screens.

For user-visible changes, proportionally verify semantics, labels, focus order, keyboard access, text scaling, contrast, disabled state, target size, non-color status cues, destructive confirmations, and actionable error feedback.

# Security

Never commit secrets or expose credentials, tokens, private endpoints, personal data, or sensitive financial data in logs, screenshots, reports, fixtures, or artifacts. Protect authentication and trial state, permission decisions, local databases, backups, business identity assets, exported files, Supabase communication, and future tenant boundaries.

Hidden UI is not authorization. Client checks are not server authorization. `NOT_VERIFIED` is not `PASS`. Security and dependency findings require evidence and explicit disposition. Production penetration testing, live data access, credential rotation, and security deployment are not automatically authorized.

# Performance

Do not claim a performance improvement without comparable measurement. Use representative data and appropriate build-mode evidence for large inventory tables, ledgers, database queries, startup, reports/PDFs, backup/export, synchronization queues, memory, blocking file I/O, and widget rebuilds. Avoid speculative or unrelated optimization.

# Git and Repository Safety

Before mutation, capture repository root, Git directory, branch, HEAD, status, unstaged and staged changes, untracked files, stashes, remotes, and active merge/rebase/cherry-pick/revert/bisect/sequencer or index-lock state. Classify and preserve all pre-existing work. Stop on unsafe ambiguity.

Stage explicit paths only and keep unrelated changes out of the index, commit, and push. Do not use destructive cleanup merely to obtain a clean status; do not broadly restore, reset, clean, stash, rewrite history, switch branches, alter remotes, commit, or push unless the task explicitly authorizes it.

Before an authorized push, verify the remote name and URL directly. Use a normal fast-forward push only; never force unless the owner explicitly authorizes a separately justified history rewrite. Where remote-lock proof is required, compare local HEAD, the remote-tracking ref, direct remote evidence, merge-base, and ahead/behind counts after the push.

# Release and Delivery Boundaries

Debug is not release. Test pass is not packaged-release pass. Feature pass is not release pass. Keep debug, profile, release, release candidate, delivery, production, deployment, and publishing as distinct stages.

For authorized release work, verify source provenance, version and application identity, build mode, signing where applicable, artifact hashes, assets/fonts, native plugins and runtime dependencies, database/file paths, launch and clean exit, packaging/relocation, and target-platform evidence. Windows evidence does not establish Android evidence, and platform folders do not establish support. No upstream pass grants downstream authority.

# Definition of Done

The exact authorized outcome is implemented or reviewed; established architecture, data integrity, and public behavior are preserved; relevant tests and checks provide current evidence; Arabic/RTL, accessibility, security, performance, persistence, platform, and release impacts are addressed in proportion to scope; limitations are explicit; and unrelated or successor work has not begun.

# Prohibited Actions

Do not fabricate evidence, hide blockers, bypass application/query or authorization boundaries, replace architecture wholesale, casually alter persistent data, weaken financial or inventory invariants, add or upgrade dependencies without authority, expose secrets, touch unrelated files, or start a roadmap successor, signing, delivery, production, deployment, publishing, or destructive operation without explicit authorization.
