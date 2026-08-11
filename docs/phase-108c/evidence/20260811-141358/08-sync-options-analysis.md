# Phase 108C — Sync Architecture Options and Supabase Direction

## Options

| Option | Advantages | Project-specific risks | Decision |
| --- | --- | --- | --- |
| S1 row-level bidirectional sync | Simple mental model for CRUD/cache rows | Splits sale/stock/COGS/ledger transaction groups; hard deletes/timestamps/LWW create corruption; cannot safely arbitrate concurrent devices | Rejected for critical/shared writes |
| S2 command/event sync | Durable intent, replay/audit/idempotency and natural offline queue | Requires explicit handlers, projections and compatibility/versioning | Accepted foundation for writes |
| S3 server-authoritative API/RPC | Strong validation and atomic Postgres transaction; compact security boundary | Online dependency unless paired with outbox/cache; RPC design burden | Accepted for all critical commands |
| S4 hybrid: row/version sync for safe master reads + commands/RPC for critical writes | Matches catalog/settings versus accounting risk; supports Android offline cache | Two controlled paths and explicit classification required | **Selected** |

The selected architecture is S4: server-authoritative commands/RPC or trusted
server handlers for financial, inventory, auth and destructive operations;
versioned row/query synchronization for safe reference data and projections.
There is no generic client permission to insert journal or inventory rows.

## Supabase service direction

| Service | Needed? | Use case | Why | Main risk/control |
| --- | --- | --- | --- | --- |
| Postgres | YES | Authoritative relational business store, transactions, constraints, reconciliation | Best fit for cross-domain accounting invariants | Schema must model commands/tenancy, not mirror SQLite blindly |
| Supabase Auth | YES | Cloud identity, sessions, refresh/revocation | Replaces local credential authority | Map current app user; membership and RLS still required |
| RLS | YES | Default-deny business isolation and role-sensitive reads/writes | Defense in depth on all exposed tables/views | Cross-business negative tests mandatory |
| RPC/database functions | YES | Atomic idempotent critical commands close to Postgres | One transaction for posting/locking/result | Version functions and test authorization/invariants |
| Edge Functions | LATER / selective | Orchestration needing secrets, external integration, import jobs | Trusted boundary when SQL function is insufficient | Avoid splitting one atomic DB mutation across network calls |
| Realtime | LATER | Invalidate/refresh projections and sync hints | Usability, not authority | Events can drop/reorder; always refetch/version-check |
| Storage | YES, when logos/exports/attachments migrate | Private organization-scoped objects | Replaces unmanaged shared files | Signed URLs, MIME/size/integrity and RLS controls |
| Managed backups/PITR | YES before production cutover | Server recovery | Separate from user export | Plan/retention/RPO/RTO and restore rehearsal required |

## RLS requirements matrix

| Resource/class | Read | Direct client write | Trusted server write | Required isolation |
| --- | --- | --- | --- | --- |
| Business/membership | Active members within authorized scope; owner sees administration | No privilege/self-scope escalation | Membership/admin handler | `business_id` derived from auth membership |
| Master data | Authorized business roles | Versioned safe commands only | Yes | Every row scoped by `business_id` from first schema |
| Sales/purchases/expenses/payments | Authorized business roles | No raw ledger/document inserts | Critical RPC/handler only | Business plus branch/warehouse where enabled |
| Inventory/valuation/journal/audit | Authorized read by role | No direct insert/update/delete | Server-only append/reversal | Strict business scope; immutable accepted rows |
| Approvals/closings/import/deletion | Owner/privileged role | No raw writes | Server-only with reauth/audit | Business scope and privilege checks |
| Device/sync records | Current authorized user/device; owner administration | Limited registration/ack contract | Server validates/revokes | Business/user/device binding |
| Objects/exports | Authorized scoped users | Signed governed upload/download only | Jobs/admin handlers | Private bucket path plus metadata scope |

`service_role` is never embedded in Windows or Android. URL and anon/publishable
key may be public client configuration. Access/refresh tokens belong in secure
platform storage, not logs/backups/ordinary business tables. Server-only secrets
remain in Supabase/managed server secret storage.
