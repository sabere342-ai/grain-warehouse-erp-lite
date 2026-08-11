# Phase 108C — Conflict, Mutability, Delete, Time and Numbering Strategy

## Conflict classes

| Conflict | Frozen strategy | Never allowed |
| --- | --- | --- |
| Product descriptive fields | Expected version; safe field merge or manual review | Blind whole-row LWW |
| Product price/cost | Expected version; server rejects stale sensitive update | Silent overwrite |
| Duplicate entity create | Global ID and scoped natural-key checks; return existing only for exact replay | Creating two records from one command |
| Sale/purchase/expense/payment replay | Idempotency record + payload fingerprint + stable result | Reposting ledger effects |
| Concurrent stock sale | Server serializes/locks or uses serializable retry; reject insufficient stock | Client balance overwrite/LWW |
| Stock-take vs newer movements | Base version/cursor check; append reviewed adjustment or reject | Replacing stock balance |
| Customer/supplier/account balance | Recompute from accepted entries | Balance field merge |
| Financial posting conflict | Server rejects or serializes atomic command | Editing accepted journal rows |
| Transfer conflict | Lock/version both accounts and one idempotency key | Half transfer or independent row sync |
| Closing conflict | Server serializes close against all affected postings | Client-declared final close |
| Document number conflict | Server allocates unique scoped number after acceptance | Offline authoritative number collision |
| Deletion conflict | Archive/inactivate master data; void/reverse posted data | Hard delete of synchronized financial history |
| Shared settings | Expected version; LWW only for explicitly harmless scalar fields | LWW for accounting policies |
| Membership/role/device | Server-only versioned command and audit | Offline privilege expansion |
| Import/restore collision | Stage, validate, map, reconcile, then atomic cutover or abort | Merge into live tenant silently |

## Immutable versus mutable

- Append-only/immutable after server acceptance: inventory movements, valuation
  events, financial entries, audit events, accepted command/idempotency results.
- Posted sales, purchases, expenses, payments, collections, transfers, opening
  balances and closings retain the original record. Corrections use linked
  cancellation, reversal, correction or reopen events.
- Mutable with versions: product/customer/supplier descriptions, active state,
  business identity, selected non-accounting settings and membership state.
- Never synchronize computed balances as editable rows.

## Delete semantics

| Domain | Future meaning |
| --- | --- |
| Products/customers/suppliers/accounts | Inactive/archive; hard delete only before references and by governed retention tooling |
| Posted documents/ledger/movements/audit | No normal hard delete; void/reversal/correction |
| Drafts/provisional commands | Delete locally only before send; after send use cancel state, never key reuse |
| Membership/device/session | Revoke/disable with audit |
| Attachments | Retention/tombstone; financial parent remains |
| Cache rows | Hard delete permitted as local cache reset, without cloud mutation |
| Entire business | Separate privileged lifecycle with export, reauthentication, delay/confirmation, audit and retention; not “wipe business data” |

## Time contract

- `created_at`: immutable server timestamp for accepted record creation.
- `server_accepted_at`: authoritative command ordering timestamp.
- `business_date`: explicit business/calendar date supplied under validation and
  closing rules; not a replacement for server time.
- `device_created_at`: client metadata only, stored in UTC, never sole critical order.
- `posted_at`: server time at final posting.
- `synced_at`: device-local projection metadata.
- `effective_at`/`effective_date`: domain date validated by server.
- Ordering ties use authoritative monotonic/version/sequence data, not device clock.
- Existing local `DateTime.now()` and microsecond IDs are evidence that the
  current scheme cannot be carried into multi-device authority unchanged.

## ID and numbering contract

- Current string IDs combine local clock microseconds and local/repository
  counters; they are not safe as a guaranteed multi-device global scheme.
- New entity and command IDs: client-generated UUIDv7 preferred; UUIDv4 is the
  permitted fallback if library/platform evidence rejects v7.
- Legacy IDs are preserved as `legacy_local_id` under a migration mapping; do
  not rewrite historic references silently.
- Internal IDs and human document numbers are separate.
- Official document numbers are server-issued, immutable and unique within a
  frozen scope such as `(business_id, document_type, fiscal_series)`.
- Offline commands use a visibly provisional reference. Gaps after reservations
  or rejected commands are acceptable and audited; duplicates are not.
- Exact number format, fiscal reset policy and reservation blocks are deferred
  to the document-numbering contract phase.
