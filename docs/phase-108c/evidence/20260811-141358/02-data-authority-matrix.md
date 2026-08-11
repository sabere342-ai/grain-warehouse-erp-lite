# Phase 108C — Frozen Data Authority Matrix

`CLOUD AUTHORITY + LOCAL CACHE` means the cloud owns accepted shared truth and
SQLite holds the latest acknowledged projection plus explicitly provisional
offline work. It does not authorize blind row-level replication.

| Data | Frozen authority | Consistency | Why / constraint |
| --- | --- | --- | --- |
| Organization/business and memberships | CLOUD AUTHORITY + LOCAL CACHE | Strong | Tenant isolation and roles cannot depend on client claims |
| Cloud user identity/session/grants | CLOUD AUTHORITY + LOCAL CACHE | Strong | Supabase Auth identity mapped to application membership |
| Device registration/revocation | CLOUD AUTHORITY + LOCAL CACHE | Strong | Required for sync/audit and revoked-device control |
| Product/customer/supplier master data | CLOUD AUTHORITY + LOCAL CACHE | Eventual for reads; versioned writes | Offline edits may queue; server version decides conflicts |
| Product price | CLOUD AUTHORITY + LOCAL CACHE | Versioned | Stale price must be surfaced; sale command carries evidence and server policy decides |
| Sales/purchases/expenses/payments/collections | CLOUD AUTHORITY + LOCAL CACHE | Strong on acceptance | Client may create provisional commands, never final postings |
| Accounting journal/account balances | CLOUD AUTHORITY + LOCAL CACHE | Strong | Derived only from one accepted atomic command stream |
| Inventory movement/value/COGS | CLOUD AUTHORITY + LOCAL CACHE | Strong | Server serializes stock/valuation acceptance; never LWW |
| Transfers/closings/approvals/opening balances | CLOUD AUTHORITY + LOCAL CACHE | Strong | Privileged atomic server commands |
| Audit log | CLOUD AUTHORITY + LOCAL CACHE | Append-only | Server actor/device/time and result are authoritative |
| Human document numbers | CLOUD AUTHORITY + LOCAL CACHE | Strong/unique | Server-issued after acceptance; provisional local reference is separate |
| Global entity/operation IDs | Client-generated global ID, cloud validated | Unique | UUIDv7 preferred, UUIDv4 fallback; never local counter authority |
| Business identity/settings | CLOUD AUTHORITY + LOCAL CACHE | Versioned | Shared across devices within a business |
| Logo/object attachments | CLOUD AUTHORITY + LOCAL CACHE | Eventual with integrity/version | Private storage object, scoped by business |
| Theme, window state, file handles | DEVICE-LOCAL ONLY | Local | Device preference/capability, no business truth |
| UI drafts and unsent command payloads | DEVICE-LOCAL ONLY | Local | Not business truth; encrypted/safely scoped where sensitive |
| Outbox/inbox/cursors/cache metadata | DEVICE-LOCAL ONLY | Local state machine | Operational sync state; server has command result/idempotency truth |
| Dashboards/reports/document history | DERIVED / RECOMPUTABLE | Eventual | Must distinguish accepted, stale, and provisional data |
| Inventory/account/customer/supplier balances | DERIVED / RECOMPUTABLE | Strong at server; eventual cache | Recompute from accepted ledgers, never overwrite as independent values |
| Local backup v1–v8 | LOCAL AUTHORITY + CLOUD IMPORT ARTIFACT | Offline file | Portable export/legacy import input, not a live cloud restore |
| Server backup/PITR | CLOUD AUTHORITY | Operational | Managed disaster-recovery capability, never client-controlled row sync |
| Current 14-day trial state | DEVICE-LOCAL ONLY (TRANSITIONAL) | Local | Preserve now; future commercial access is server-authoritative |
| Subscription/entitlement (future) | CLOUD AUTHORITY + LOCAL CACHE | Strong with explicit grace | Account/business-level, not reset by reinstall |

## Authority rule

When device and server disagree after Cloud mode is enabled, the server's
accepted command result and ledger version are final. A device may retain a
rejected/provisional command for review but may not rewrite the accepted cloud
ledger or present its provisional balances as final.

No accounting-critical data type remains `UNDECIDED — BLOCKER`.
