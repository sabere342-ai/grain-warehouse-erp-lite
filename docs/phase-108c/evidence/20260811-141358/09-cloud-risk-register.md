# Phase 108C — Cloud Migration Risk Register

Severity scale: R0 Critical, R1 High, R2 Medium, R3 Low.

| ID | Severity | Risk | Evidence | Consequence | Mitigation phase |
| --- | --- | --- | --- | --- | --- |
| C-001 | R0 | Accounting command posts twice after retry/timeout | Current coverage is uneven; transfer/purchase/expense/sale keys exist in parts, not one universal server record | Duplicate revenue, expense, cash, payable or receivable | 108E contract; first governed write slice |
| C-002 | R0 | Concurrent devices oversell stock or misorder valuation | Current authority is one local SQLite process; no server lock/version | Negative stock, wrong COGS/profit | Cloud schema/command contract before sale writes |
| C-003 | R0 | Partial sale/purchase/payment writes | Some composite flows use snapshots and separate adapter transactions | Document/stock/ledger divergence | Application boundary freeze, then one Postgres transaction per command |
| C-004 | R0 | Tenant/RLS isolation failure | Current schema has no `business_id` or memberships | Cross-business disclosure/mutation | Auth/tenancy schema plus adversarial RLS tests before any business table exposure |
| C-005 | R0 | Local restore overwrites/duplicates cloud history | Restore v1–v8 is restore-to-empty local workflow, not cloud merge | Catastrophic duplicated or erased ledgers | Separate staged import/cutover/reconciliation protocol |
| C-006 | R1 | Clock/counter ID collision across devices | IDs use `DateTime.now()` microseconds and local counters/sequences | Key collision/wrong reference mapping | UUID contract and legacy mapping before schema |
| C-007 | R1 | Device provisional state displayed as final | Current UI has no accepted/pending/conflict vocabulary | Owner acts on false totals/documents | Query/result state contract and UI status gates before offline writes |
| C-008 | R1 | Stale authorization accepts privileged operation | Local roles/session and no device revocation | Unauthorized posting/closing/approval | Supabase Auth, membership/device checks on every server command |
| C-009 | R1 | Unsafe generic row sync/LWW | Local schema contains aggregates, JSON lines and derived values | Ledger edits, lost changes, partial transactions | Select S4; prohibit raw critical table writes |
| C-010 | R1 | Hard-delete/tombstone mismatch | Current local wipe intentionally deletes business tables | Reappearing rows or silent cloud deletion | Separate cache reset, archive, reversal and business deletion semantics |
| C-011 | R1 | Full-table aggregate persistence causes conflicts/performance issues | Financial/customer/supplier durable adapters hydrate/persist aggregates | Lost concurrent updates and wide writes | Replace write path with atomic server commands/projections |
| C-012 | R1 | Secrets leak in client/log/backup | Cloud is absent; future configuration not yet separated | Full backend compromise | Never ship service role; secure token storage and secret scan in bootstrap phase |
| C-013 | R1 | Incomplete RLS on a new table/view/function | Many domains and future projections | Isolation bypass despite correct UI | Default deny, schema checklist, SECURITY DEFINER review and cross-tenant tests |
| C-014 | R1 | Logout/business switch replays old queued write | No outbox/user/device/business model exists | Cross-scope posting | Queue binding and quarantine/recovery rules before O3 writes |
| C-015 | R1 | Document number duplicates/gaps are mishandled | Sales/purchases commonly expose internal ID; transfer number is local counter | Duplicate legal/business references or blocked offline work | Separate server numbering contract; accept audited gaps, forbid duplicates |
| C-016 | R1 | Import reconciles counts but not financial invariants | Current backup spans many linked ledgers/projections | Silent financial drift | Zero-tolerance counts/totals/hashes and owner acceptance |
| C-017 | R2 | Realtime event loss/order treated as truth | Realtime not implemented | Stale projection | Treat as invalidation only; cursor/version refetch |
| C-018 | R2 | Android suspension kills queued work | No Android/outbox implementation | Lost/duplicate commands | Durable pre-send outbox, lifecycle/restart tests, bounded background behavior |
| C-019 | R2 | Business identity/logo remains device-divergent | JSON/files outside SQLite | Wrong branding on invoices/devices | Versioned org settings + private Storage |
| C-020 | R2 | Local trial conflicts with cloud subscription | 107G is device-local and reset resistance is limited | Reinstall resets access or paid user blocked | Transitional policy then server entitlement with signed offline grace |
| C-021 | R2 | Client checksum mistaken for secure authenticity | Backup uses Adler-32 | Tampered import accepted if attacker rewrites checksum | Server-side staged validation; later signed/encrypted export policy |
| C-022 | R2 | Branch/warehouse assumptions become irreversible | Current app is single business/local and schema lacks either | Expensive future schema/key changes | Include business ownership now; defer branch behavior but reserve scope model |
| C-023 | R2 | Product read success hides write coupling | Narrow catalog read contract exists, while many writes orchestrate locally | Premature “cloud ready” claim | Read slice first, then one governed financial command |
| C-024 | R3 | Inactive Firebase scaffold is confused with provider progress | `firebase_core` and intentional no-options bootstrap remain | Wrong dependencies/security assumptions | Document as unrelated legacy scaffold; do not modify in 108C |

## Stop conditions

Stop Cloud implementation if any critical command can partially apply, an
idempotency replay changes totals, RLS permits cross-business access, the client
can insert journal/inventory accepted rows, import variance is unexplained, or
pending and accepted totals cannot be distinguished.
