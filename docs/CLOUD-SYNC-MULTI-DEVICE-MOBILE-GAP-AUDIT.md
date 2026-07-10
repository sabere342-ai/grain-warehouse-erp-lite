# Cloud Sync, Multi-Device, and Mobile Gap Audit

## Current State Summary

- Pure in-memory local Windows desktop application
- No database — all data lives in Dart in-memory maps/lists
- No backend, server, or API
- No cloud synchronization
- No multi-device support
- No mobile application
- Firebase project scaffolded but not actively used
- Supabase transition note states "not now"
- Phase 53 documented cloud migration readiness (planning only)
- Backup/restore is JSON export/import to local files
- All persistence depends on app session lifetime

---

## 11.1 Cloud System Boundaries

Every cloud-bound system component must be defined before any sync or multi-device feature is implemented. The following subsections define required boundaries.

### 11.1.1 Tenant / Establishment Model

- Multi-tenant isolation is mandatory from day one of cloud deployment.
- Each tenant (establishment/company) owns its own data, users, roles, and documents.
- Tenant ID must be embedded in every row, every API request, and every sync payload.
- Cross-tenant data leakage is a blocking severity-one defect.
- Tenant provisioning requires explicit admin action — no self-service signup without approval.
- Tenant state must track: active, suspended, archived, deleted.
- A tenant deletion must cascade soft-deletes to all child entities without physical data removal for audit retention.

### 11.1.2 Users Management

- Users are scoped to a tenant. A user may belong to multiple tenants only if explicitly designed.
- User lifecycle: invited → active → disabled → removed.
- User attributes: id, email, display name, phone, avatar, tenant role assignments, created at, updated at, last login, status.
- Password management handled by authentication provider (Firebase Auth, Supabase Auth, or equivalent).
- Password reset must go through provider — never through application code.
- User disabling must immediately invalidate all active sessions.
- User removal must not delete historical audit records — audit logs retain user reference by ID and display name.

### 11.1.3 Roles and Permissions

- Role-based access control (RBAC) with per-tenant role definitions.
- System roles: Owner, Admin, Manager, Cashier, Warehouse Keeper, Viewer, Mobile Field Agent.
- Each role maps to a permission set. Permissions are atomic strings (e.g., `sale.create`, `stock.view`, `account.transfer`).
- Roles are tenant-scoped — role IDs are globally unique but role definitions are per-tenant.
- Permission checks occur both server-side (API gateway) and client-side (UI gating). Server-side is authoritative.
- Role changes take effect immediately — no grace period for concurrent offline operations.
- Custom roles (user-defined permission sets) are deferred to Phase 75+.

### 11.1.4 Device Identity

- Every device (desktop or mobile) must register with the server and receive a device ID.
- Device registration requires: device type (windows/android/ios), app version, OS version, user agent, registration timestamp.
- Device states: active, suspended, revoked, wiped.
- Owner must be able to view all registered devices and revoke any device.
- Revoked devices must lose access immediately (token invalidation).
- Device identity is used in audit logs, sync tracking, and conflict resolution.
- A single user may have multiple devices — all must be listed and independently revocable.

### 11.1.5 Sessions

- Sessions are tied to device + user + tenant triple.
- Session tokens must be short-lived (access token: 15 minutes, refresh token: 7 days).
- Refresh token rotation on every use — old refresh token is invalidated.
- Concurrent session limit per user (configurable, default: 5).
- Owner must be able to revoke individual sessions or all sessions for a user.
- Session metadata: device ID, IP address, user agent, created at, last activity, expires at.
- Session revocation must propagate to all API endpoints within one second.

### 11.1.6 API Design

- RESTful API with versioned endpoints (e.g., `/api/v1/sales`).
- All requests require authentication via Bearer token.
- All requests are tenant-scoped — tenant ID extracted from token, never from request body.
- Request/response format: JSON with consistent envelope: `{ "success": true, "data": {...}, "meta": {...} }`.
- Pagination: cursor-based for lists, offset-based only for simple admin screens.
- Rate limiting per device and per user (see Section 11.7).
- Idempotency key header for all write operations (`X-Idempotency-Key`).
- Request ID header (`X-Request-ID`) for tracing.
- Server response includes server timestamp for clock skew detection.
- API versioning: breaking changes require new major version, minimum 6-month overlap.
- OpenAPI/Swagger specification maintained and published.

### 11.1.7 Central Database

- Relational database (PostgreSQL recommended) as single source of truth.
- Every table includes: `id` (UUID), `tenant_id`, `created_at`, `updated_at`, `deleted_at` (soft delete).
- `updated_at` is automatically managed by database triggers or ORM.
- `version` column (integer) on all mutable tables for optimistic concurrency.
- Indexes on: `tenant_id` + all frequently queried columns, foreign keys, `deleted_at`.
- Connection pooling required — no direct connections from application code.
- Database backups: continuous WAL archiving + daily full backup + point-in-time recovery.
- Read replicas optional for reporting — never for writes.
- Schema migrations managed through versioned migration files (never raw DDL in production).

### 11.1.8 File and Logo Storage

- Cloud object storage (S3-compatible) for logos, attachments, and exported documents.
- All files scoped under `/{tenant_id}/{entity_type}/{entity_id}/{filename}`.
- Files are immutable once uploaded — modifications create new versions.
- Signed URLs with expiry (15 minutes default) for access.
- No direct public access to any file.
- Maximum file size: 5 MB for logos, 10 MB for attachments.
- Supported MIME types enforced server-side (images: png, jpg, webp, svg; documents: pdf).
- See Section 11.8 for full file storage requirements.

### 11.1.9 Server-Side Audit Log

- Every create, update, delete, cancel, and restore operation is logged.
- Audit log entries: `id`, `tenant_id`, `user_id`, `device_id`, `action`, `entity_type`, `entity_id`, `changes` (JSON diff), `ip_address`, `user_agent`, `timestamp`.
- Audit logs are append-only — no updates, no deletes.
- Audit log retention: minimum 7 years (configurable per tenant, never less than 2 years).
- Audit logs are queryable by: user, entity, action type, date range.
- Owner can export audit logs.
- See Section 14 for permission gaps on audit access.

### 11.1.10 Monitoring

- Application performance monitoring (APM) for API response times, error rates, database query performance.
- Uptime monitoring with alerting (target: 99.9% availability).
- Error tracking with stack traces and context (no financial data in error reports).
- Sync failure rate monitoring with alerting thresholds.
- Device registration anomaly detection.
- Disk usage, memory usage, CPU usage on server infrastructure.
- Log aggregation with structured logging (JSON format).
- Alerting channels: email + SMS for critical, dashboard for non-critical.

### 11.1.11 Server-Side Backup

- Automated daily full database backup with 30-day retention.
- Continuous WAL archiving for point-in-time recovery (RPO: 1 minute).
- Backup encryption at rest (AES-256).
- Backup storage in separate geographic region.
- Monthly backup restoration test (automated).
- Backup integrity verification (checksum validation).
- Object storage files backed up separately (versioning enabled).
- See Section 15 for backup and migration audit.

### 11.1.12 Restore

- Point-in-time restore capability from database backups.
- Restore to a specific timestamp (for data corruption recovery).
- Restore to a new tenant (for migration verification).
- Restore does not overwrite live data — restore to staging environment first.
- Restore must include audit trail verification.
- Owner approval required for production restore.
- Restore must be tested in staging before production execution.

### 11.1.13 Data Export

- Tenant-scoped data export in structured formats (JSON, CSV).
- Export must include: all entities, audit logs, financial records, documents.
- Export is async — generates download link when complete.
- Export limited to prevent abuse: max 1 request per hour, max 5 concurrent exports.
- Exported files are encrypted and signed.
- Export does not include: other tenants' data, server infrastructure details, internal IDs.
- Owner can initiate full export. Admin can export within their permission scope.

### 11.1.14 Subscription / Licensing (Deferred)

- Subscription management deferred to Phase 80+.
- Tenant must have a subscription status (active, trial, expired, suspended).
- Subscription controls: user count limit, feature access, storage limit.
- Expired subscription: read-only access, no new postings.
- Suspended subscription: no access at all.
- Owner can override subscription limits temporarily for emergency access.

---

## 11.2 Record Identity Strategy

Every record in the system must have a globally unique, unambiguous identity. This section defines the identity strategy for all entity types.

### 11.2.1 Globally Unique IDs

- All entity IDs are UUIDs (version 7 preferred for time-ordering, version 4 acceptable).
- UUIDs are generated client-side before submission to server.
- UUID format: `550e8400-e29b-41d4-a716-446655440000` (standard hyphenated lowercase).
- UUIDs are never reused — even if a record is deleted, its UUID is retired.
- Server validates UUID format on receipt — rejects malformed IDs.

### 11.2.2 Server IDs

- Server assigns an auto-incrementing integer `server_id` for human-readable references.
- `server_id` is tenant-scoped — resets per tenant (or continues sequentially, design choice).
- `server_id` is never exposed to other tenants.
- `server_id` is used in UI display, printed documents, and human communication.
- `server_id` is immutable after creation.

### 11.2.3 Client-Generated IDs (UUID)

- Client generates UUID v7 before creating any entity locally.
- This UUID becomes the entity's permanent identity across all devices and sync.
- If sync fails, the UUID persists locally and is retried on next sync attempt.
- UUID collision across devices is astronomically unlikely with v7 — collision handling is not required.
- Client must store the UUID in local persistence (SharedPreferences, database, or file) immediately upon creation.

### 11.2.4 Document Numbers

- Document numbers (invoice number, receipt number, transfer number) are server-assigned.
- Document numbers are sequential per document type per tenant.
- Format: `{TYPE}-{YYYY}-{NNNNN}` (e.g., `INV-2026-00001`, `RCPT-2026-00142`).
- Document numbers are never reused — cancelled documents retain their number.
- Client displays placeholder number (`PENDING`) until server assigns real number.
- Document number assignment happens during sync processing, not at creation time.

### 11.2.5 Device Identity

- Device ID is a UUID assigned during device registration.
- Device ID is stored securely on device (platform secure storage).
- Device ID is included in every API request header (`X-Device-ID`).
- Device ID is included in every sync payload.
- Device ID is used to trace which device created or modified which record.
- See Section 11.1.4 for full device identity requirements.

### 11.2.6 Client Request IDs

- Every client operation generates a unique `clientRequestId` (UUID).
- `clientRequestId` is used for idempotency and deduplication.
- `clientRequestId` is included in sync payloads and API requests.
- Server stores `clientRequestId` with the operation result for deduplication checks.
- Client stores `clientRequestId` with the pending operation in the offline queue.
- If the same `clientRequestId` is submitted twice, server returns the original result (idempotent).

### 11.2.7 Idempotency Keys

- Idempotency key is the `clientRequestId` for write operations.
- Server caches idempotency results for 24 hours.
- Same idempotency key + same user + same tenant = same result.
- Different user or tenant with same key = treated as separate operations (key is scoped to tenant + user).
- Idempotency prevents duplicate postings from retry logic, network failures, and user double-clicks.

### 11.2.8 createdAt vs effectiveDate

- `createdAt`: server timestamp when the record was persisted. Client-submitted value is adjusted to server time.
- `effectiveDate`: business date chosen by the user (e.g., sale date, payment date). Client-submitted, not adjusted.
- Both fields are required on all financial documents.
- `effectiveDate` may be in the past (backdated posting) but never more than 30 days ago (configurable).
- `effectiveDate` may be in the future only for scheduled operations (deferred feature).
- `createdAt` is never modifiable by the user.

### 11.2.9 updatedAt

- `updatedAt` is managed by the server — always set to current server timestamp on every update.
- Client-submitted `updatedAt` is ignored — server value is authoritative.
- `updatedAt` is used for optimistic concurrency (see version number below).
- `updatedAt` is included in sync payloads for conflict detection.

### 11.2.10 Version Number

- Every mutable entity has an integer `version` column starting at 1.
- On every update, server increments `version` by 1.
- Client submits `version` with update request — server rejects if submitted version does not match current version.
- This prevents lost updates from concurrent edits.
- On conflict, server returns the current version and latest data — client must merge and resubmit.
- Version is never reset, even after soft delete and restore.

### 11.2.11 Deleted / Tombstone State

- Soft delete: `deleted_at` column set to timestamp, `deleted_by` set to user ID.
- Soft-deleted records are excluded from normal queries but retained for audit.
- Tombstone records are created for sync purposes — tombstone records propagate the deletion to all devices.
- Tombstone records include: entity type, entity ID, deleted at, deleted by.
- Tombstones are retained for sync duration (configurable, default: 90 days) then archived.
- Physical deletion of tombstones requires explicit admin action with confirmation.
- Posted financial documents are never physically deleted — only cancelled/reversed.

---

## 11.3 Offline-First Queue

When a device is offline, all write operations must be queued locally and synchronized when connectivity is restored.

### 11.3.1 Pending Operations Queue

- Local queue stores all un-synced operations in insertion order.
- Each queue entry contains: `queueId` (UUID), `clientRequestId`, `operationType`, `entityType`, `entityId`, `payload` (JSON), `createdAt`, `status`, `retryCount`, `lastError`, `nextRetryAt`, `dependencies` (list of queue IDs that must complete first).
- Queue is persisted to local storage (database, not just in-memory) to survive app restarts.
- Queue is displayed to the owner in a sync status screen.

### 11.3.2 Operation Status Tracking

- Status values: `pending`, `syncing`, `synced`, `failed`, `retrying`, `cancelled`.
- `pending`: queued, waiting for sync turn.
- `syncing`: currently being transmitted to server.
- `synced`: server acknowledged successful processing.
- `failed`: server rejected with a non-retryable error.
- `retrying`: server rejected with a retryable error, waiting for next attempt.
- `cancelled`: owner chose to cancel the operation (e.g., duplicate entry).

### 11.3.3 Retry Count, Last Error, Next Retry Time

- `retryCount`: integer, incremented on each failed attempt.
- `lastError`: string containing server error message or network error description.
- `nextRetryAt`: timestamp for next retry attempt (exponential backoff: 1 min, 5 min, 15 min, 1 hour, 4 hours, 24 hours).
- Maximum retry count: 10 attempts before permanent failure.
- Owner can manually trigger retry regardless of `nextRetryAt`.
- Exponential backoff is per-queue-entry — different entries retry independently.

### 11.3.4 Dependency Ordering

- Some operations depend on others (e.g., sale items depend on sale header being synced first).
- Dependencies are declared at queue insertion time.
- Server processes operations only when all dependencies are marked `synced`.
- Dependency graph is validated client-side — circular dependencies are rejected.
- Example: creating a new customer for an invoice — customer sync must complete before invoice sync.

### 11.3.5 Transaction Groups

- Operations can be grouped into a transaction group (e.g., a complete sale with items, stock movements, and financial entries).
- Transaction groups are submitted to the server as a single atomic unit.
- If any operation in the group fails, the entire group fails and is retried together.
- Transaction group ID is a UUID linking all related queue entries.
- Server processes transaction groups atomically — all succeed or all fail.

### 11.3.6 Upload Acknowledgement

- Server sends acknowledgement for each successfully processed operation.
- Acknowledgement includes: `serverId`, `documentNumber`, `serverTimestamp`, `version`.
- Client updates local record with server-assigned values upon acknowledgement.
- If no acknowledgement received within timeout (30 seconds), client assumes failure and retries.
- Acknowledgement is idempotent — re-acknowledging the same operation is a no-op.

### 11.3.7 Duplicate Submission Behavior

- Duplicate submissions detected via `clientRequestId` (idempotency key).
- If server detects duplicate `clientRequestId` from same tenant + user, it returns the original result.
- If server detects duplicate `clientRequestId` from different user, it is treated as a new operation.
- Client must never submit the same `clientRequestId` with different payloads — this is a client bug.
- Duplicate detection window: 24 hours.

### 11.3.8 Permanent Failure Behavior

- After 10 retry attempts, operation enters `failed` status permanently.
- Owner is notified with error details and options:
  - Edit the operation and resubmit (fix data issues).
  - Cancel the operation (abandon the entry).
  - Contact support (server-side issues).
- Failed operations block dependent operations from syncing.
- Owner must resolve or cancel all failed operations before queue can fully drain.

### 11.3.9 Owner-Visible Sync Status

- Sync status screen shows:
  - Total operations in queue.
  - Operations by status (pending, syncing, synced, failed).
  - Last successful sync timestamp.
  - Next scheduled sync attempt.
  - Individual operation details (expandable).
  - Error messages for failed operations.
  - Manual retry button per operation.
  - Manual cancel button per operation.
- Sync status icon in main navigation (green = all synced, yellow = syncing, red = failures).
- Push notification (if mobile) when sync completes or fails (configurable).

---

## 11.4 Atomicity Boundaries

Every business operation must transfer from client to server as a logical unit. Partial transfers are forbidden for accounting data.

### 11.4.1 Atomic Operation Requirement

Each operation must include ALL related data entities in a single submission. The server must process all entities atomically — all succeed or all fail.

### 11.4.2 Example — Cash Sale Atomic Transfer

A cash sale must transfer atomically. The following entities must be included in a single transaction group:

1. **Sale document** — header with customer reference, date, totals, notes
2. **Sale items** — line items with product, quantity, unit price, line total
3. **Stock movements** — one stock movement per product: product out, quantity, warehouse location
4. **Customer account effect** — customer balance adjustment (if credit sale) or cash receipt
5. **Financial account entry** — cash received entry in the cash register/financial account
6. **Document history** — creation audit record with user, device, timestamp

**Forbidden scenario**: Invoice arrives at server without stock movements — customer gets credit for products that were never deducted from inventory.

**Forbidden scenario**: Stock movements arrive without financial entry — products leave warehouse but no payment is recorded.

### 11.4.3 Default Recommendation

**Use atomic server-side business commands over blind table sync.**

Blind table sync (sending raw table rows to server and letting server merge) is dangerous because:
- It cannot enforce business rules at the server level.
- It cannot validate referential integrity across tables.
- It cannot guarantee atomicity across multiple tables.
- It allows clients to submit inconsistent data states.

Instead, define business commands that the server validates and processes:

```
POST /api/v1/commands/cash-sale
{
  "clientRequestId": "uuid",
  "effectiveDate": "2026-07-10",
  "customerId": "uuid",
  "items": [
    { "productId": "uuid", "quantity": 100, "unitPrice": 2.50 }
  ],
  "payment": {
    "method": "cash",
    "financialAccountId": "uuid",
    "amount": 250.00
  },
  "notes": "..."
}
```

Server-side processing:
1. Validate all referenced entities exist and are active.
2. Validate stock availability.
3. Validate financial account exists and is accessible.
4. Create sale document with server-assigned number.
5. Create sale items.
6. Create stock movements.
7. Create financial account entry.
8. Create audit log entry.
9. All within a single database transaction.
10. Return success with all server-assigned IDs and document numbers.

### 11.4.4 Required Atomic Commands

| Command | Entities Involved |
|---------|------------------|
| Cash sale | Sale + items + stock + financial entry + audit |
| Credit sale | Sale + items + stock + customer balance + audit |
| Collection | Collection + customer balance + financial entry + audit |
| Supplier payment | Payment + supplier balance + financial entry + audit |
| Stock transfer | Transfer + source stock + destination stock + audit |
| Expense | Expense + financial entry + audit |
| Reversal | Original document reversal + all entity reversals + audit |

---

## 11.5 Conflict Resolution

Conflict resolution policies must be defined for every scenario where two devices may modify the same data concurrently.

### 11.5.1 Core Principle

**Do NOT use "last write wins" for accounting data.**

Last write wins silently overwrites one user's changes with another's. In accounting, this can cause:
- Lost financial entries.
- Incorrect stock balances.
- Duplicate payments.
- Missing audit trails.

### 11.5.2 Same Product Edited from Two Devices

- **Scenario**: User A on Device 1 edits product name and price. User B on Device 2 edits product name and description.
- **Expected behavior**: Both edits are submitted with version numbers. Server detects version mismatch. Server merges non-conflicting fields (name from latest, price from A, description from B). Conflicting fields (same field, different values) are flagged for owner review.
- **Truth source**: Server version is authoritative. Client receives updated version on sync.
- **Prevention**: Optimistic concurrency with version check. Real-time notifications of concurrent edits (Phase 75+).
- **User message**: "Product {name} was modified by {user} on {device} while you were editing. Your changes to {field} were saved. {conflictingField} was not updated — please review."
- **Acceptance test**: Two devices edit same product simultaneously. Both edits are preserved where non-conflicting. Conflict is flagged in UI.

### 11.5.3 Last Stock Quantity Sold from Two Devices

- **Scenario**: Product X has 10 units in stock. Device A sells 8 units. Device B sells 5 units.
- **Expected behavior**: Device A's sale is processed (stock goes to 2). Device B's sale is rejected server-side because stock is insufficient. Device B receives error and must adjust quantity or wait for stock replenishment.
- **Truth source**: Server stock level after Device A's transaction.
- **Prevention**: Server validates stock availability at processing time, not at creation time. Client optimistic check with server confirmation.
- **User message**: "Insufficient stock for {product}. Available: {available}, requested: {requested}. Please adjust quantity."
- **Acceptance test**: Create product with 10 units. Submit two sales from different devices totaling more than 10. Second sale is rejected.

### 11.5.4 Same Customer Debt Collected Twice

- **Scenario**: Customer owes 1000. Device A collects 500. Device B collects 600.
- **Expected behavior**: Device A's collection is processed (debt goes to 500). Device B's collection is rejected server-side because outstanding debt is only 500. Device B receives error.
- **Truth source**: Server customer balance after Device A's transaction.
- **Prevention**: Server validates outstanding balance at processing time. Client optimistic check with server confirmation.
- **User message**: "Customer {name} outstanding balance is {balance}. You attempted to collect {amount}. Please adjust collection amount."
- **Acceptance test**: Create customer with 1000 debt. Submit two collections from different devices exceeding 1000 total. Second collection is rejected.

### 11.5.5 Same Supplier Paid Twice

- **Scenario**: Supplier Y is owed 2000. Device A pays 1000. Device B pays 1500.
- **Expected behavior**: Device A's payment is processed (debt goes to 1000). Device B's payment is rejected server-side because outstanding debt is only 1000. Device B receives error.
- **Truth source**: Server supplier balance after Device A's transaction.
- **Prevention**: Same as customer debt — server validates at processing time.
- **User message**: "Supplier {name} outstanding balance is {balance}. You attempted to pay {amount}. Please adjust payment amount."
- **Acceptance test**: Create supplier with 2000 debt. Submit two payments from different devices exceeding 2000 total. Second payment is rejected.

### 11.5.6 Document Cancelled While Another Device Edits It

- **Scenario**: Device A cancels a sale. Device B is editing the same sale (adding a note, adjusting quantity).
- **Expected behavior**: Device A's cancellation is processed. Device B's edit is rejected server-side because the document is cancelled. Device B receives error and must start fresh.
- **Truth source**: Server document status.
- **Prevention**: Server checks document status before processing edits. Real-time status broadcast (Phase 75+).
- **User message**: "Document {number} was cancelled by {user} on {device}. Your changes could not be saved."
- **Acceptance test**: Create sale. Cancel from Device A while editing on Device B. Device B's edit is rejected.

### 11.5.7 Product Price Changed During Pending Operation

- **Scenario**: User creates a sale at price 2.50. While offline, admin changes product price to 3.00. Sale syncs with old price.
- **Expected behavior**: Server accepts the sale at the price that was valid when the sale was created (2.50). Server logs the price discrepancy. Owner is notified of price change during offline period.
- **Truth source**: Server accepts client-submitted price but logs discrepancy. Price at time of server processing is noted in audit.
- **Prevention**: Client fetches latest prices on reconnection before syncing. Server logs any price that differs from current product price.
- **User message**: "Product {name} price has changed from {old} to {new}. Your sale was recorded at {old} price as originally entered."
- **Acceptance test**: Create sale offline at old price. Change price online. Sync sale. Sale is accepted with old price, discrepancy logged.

### 11.5.8 Financial Account Changed During Pending Operation

- **Scenario**: User records a collection to Account A while offline. Admin changes Account A status to inactive.
- **Expected behavior**: Server rejects the collection because Account A is now inactive. Collection enters retry/failed status. User must choose a different account and resubmit.
- **Truth source**: Server account status is authoritative.
- **Prevention**: Client checks account status on reconnection. Server validates account status at processing time.
- **User message**: "Financial account {name} is no longer active. Please select a different account for this collection."
- **Acceptance test**: Create collection offline targeting Account A. Deactivate Account A online. Sync collection. Collection is rejected.

### 11.5.9 User Disabled on Device While Offline

- **Scenario**: Admin disables user on Device A. Disabled user's Device B is offline.
- **Expected behavior**: Device B's local token expires on next refresh attempt. Device B cannot sync. Device B shows "Account disabled" message. User must contact admin.
- **Truth source**: Server user status, enforced at authentication.
- **Prevention**: Token refresh always validates user status server-side. Disabled user cannot authenticate.
- **User message**: "Your account has been disabled. Please contact your administrator."
- **Acceptance test**: Disable user while Device B is offline. Attempt to sync from Device B. Sync fails with disabled account error.

### 11.5.10 Permissions Changed Before Old Operation Synced

- **Scenario**: User has cashier role. User creates a sale offline. Admin changes user role to viewer. Sale syncs.
- **Expected behavior**: Server checks the role that was active when the sale was created (stored in the operation's metadata). If the role was valid at creation time, the sale is accepted. Server logs the permission change.
- **Truth source**: Server validates against the role that was active at the time the operation was created (not current role).
- **Prevention**: Each operation includes the role snapshot at creation time. Server validates that role was valid at that timestamp.
- **User message**: "Your role has changed since this operation was created. The operation was accepted based on your previous permissions. Please contact your administrator."
- **Acceptance test**: Create sale offline as cashier. Change role to viewer. Sync sale. Sale is accepted with warning.

---

## 11.6 Deletion Policy

Deletion of accounting and business data is restricted to prevent data loss and maintain audit integrity.

### 11.6.1 Soft Delete

- All entity deletions are soft deletes — `deleted_at` and `deleted_by` are set.
- Soft-deleted entities are excluded from normal queries by default.
- Soft-deleted entities can be restored by owner/admin within retention period.
- Soft-deleted entities remain in the database for audit trail purposes.

### 11.6.2 Tombstones

- Tombstone records are created for sync propagation.
- Tombstone contains: entity type, entity ID, deleted at, deleted by, tenant ID.
- Tombstones are stored in a dedicated tombstones table.
- Tombstones are retained for 90 days (configurable) then archived.
- Devices download tombstones during sync to locally delete corresponding records.
- Tombstone delivery is guaranteed — if a device misses a tombstone, it may display stale data.

### 11.6.3 Archive

- Records older than retention period (configurable, default: 7 years for financial, 3 years for operational) are moved to archive tables.
- Archive tables are identical in structure to live tables but are not included in normal queries.
- Archived records can be restored if needed.
- Archive is separate from sync — archived records are not synced to devices.

### 11.6.4 No Deletion of Posted Documents

- Posted financial documents (invoices, receipts, payments, transfers, journal entries) cannot be deleted.
- They can only be cancelled or reversed (see Section 11.6.5).
- This is a hard rule — no exception, even for owner.

### 11.6.5 Cancellation / Reversal Instead of Deletion

- Posted documents are cancelled by creating a reversal document.
- Reversal document references the original document.
- Reversal document reverses all effects: stock, financial entries, customer/supplier balances.
- Original document retains all data — cancellation is recorded as a status change.
- Cancellation requires a reason (mandatory text field).
- Cancellation is logged in audit trail with user, device, timestamp, and reason.

### 11.6.6 Sync Record Retention Duration

- Synced records are retained on devices for the duration they remain relevant (e.g., current fiscal year + 1 year).
- Old synced records can be purged from device local storage to save space.
- Purged records are re-downloaded from server if accessed again.
- Tombstones are retained on devices for 90 days after creation.

---

## 11.7 Security

Security is not optional — every component must meet minimum security standards.

### 11.7.1 TLS

- All client-server communication must use TLS 1.2 or higher.
- HTTP is never accepted — all HTTP requests are rejected or redirected.
- Certificate pinning on mobile devices (optional but recommended).
- HSTS header enabled on all API responses.

### 11.7.2 Authentication

- Authentication handled by provider (Firebase Auth, Supabase Auth, or equivalent).
- Supported methods: email + password, phone OTP (for mobile), biometric (for mobile).
- Password requirements: minimum 8 characters, at least 1 uppercase, 1 lowercase, 1 number.
- Account lockout after 5 failed attempts (30-minute cooldown).
- Two-factor authentication (2FA) — deferred to Phase 75+.

### 11.7.3 Authorization

- Authorization checks on every API endpoint.
- Role-based access control (see Section 11.1.3).
- Server-side authorization is authoritative — client-side checks are for UX only.
- Unauthorized requests return 403 Forbidden with descriptive error.

### 11.7.4 Refresh / Session Tokens

- Access token: short-lived (15 minutes), contains user ID, tenant ID, roles.
- Refresh token: longer-lived (7 days), used to obtain new access tokens.
- Refresh token rotation: every use invalidates old token and issues new one.
- Refresh tokens stored in secure storage (platform keychain/keystore).
- Access tokens stored in memory only — never persisted.

### 11.7.5 Secure Local Token Storage

- Access tokens: memory only (cleared on app backgrounding after 5 minutes).
- Refresh tokens: platform secure storage (iOS Keychain, Android Keystore, Windows DPAPI).
- Tokens never logged, never included in error reports, never transmitted in URLs.
- Token clear on logout — both local and server-side invalidation.

### 11.7.6 Tenant Isolation

- Every database query includes `WHERE tenant_id = ?`.
- API endpoints extract tenant ID from authentication token — never from request body.
- Cross-tenant access attempts are logged and blocked.
- Tenant isolation is enforced at the database level (Row-Level Security in PostgreSQL).

### 11.7.7 Device Revocation

- Owner can revoke any device at any time.
- Revoked device's refresh token is immediately invalidated.
- Revoked device loses all access within one second.
- Revoked device displays "Device revoked" message on next API call.
- Revoked device must re-register to regain access (requires owner approval).

### 11.7.8 Rate Limiting

- Per-device: 100 requests per minute (write), 500 requests per minute (read).
- Per-user: 200 requests per minute (write), 1000 requests per minute (read).
- Per-tenant: 10,000 requests per minute (all).
- Rate limit exceeded returns 429 Too Many Requests with retry-after header.
- Rate limiting is applied at API gateway level.

### 11.7.9 Server-Side Audit Logs

- See Section 11.1.9 for audit log requirements.
- Audit logs are tamper-proof — append-only with checksums.
- Audit logs are accessible only to owner and admin roles.
- Audit logs are never deleted or modified.

### 11.7.10 Server Validation

- All input is validated server-side — client validation is for UX only.
- Validation rules: required fields, data types, ranges, referential integrity, business rules.
- Validation errors return 400 Bad Request with field-level error messages.
- Server never trusts client data — all values are validated and sanitized.

### 11.7.11 Encrypted Secrets

- Database credentials, API keys, and other secrets stored in environment variables or secret manager.
- Secrets are never committed to source code.
- Secrets are never logged in application logs.
- Secrets are rotated periodically (at least every 90 days).
- Secret rotation does not require downtime (dual-key rotation pattern).

### 11.7.12 Backup Encryption Policy

- All backups are encrypted at rest (AES-256).
- Encryption keys are managed by cloud provider (KMS).
- Backup decryption requires explicit authorization (owner or admin).
- Backup encryption is verified during monthly restoration tests.
- Backup files are never stored unencrypted, even temporarily.

### 11.7.13 Sensitive Fields Protection

- Passwords: never stored, only hashed (bcrypt).
- Financial account numbers: stored encrypted, displayed masked (last 4 digits only).
- Tax identification numbers: stored encrypted, displayed masked.
- Personal contact information: stored in database, displayed only to authorized users.
- API keys: stored encrypted, displayed only once at creation time.

### 11.7.14 Breach Response

- Anomaly detection triggers alert on: unusual access patterns, mass data export, multiple failed authentications.
- On suspected breach: immediately revoke affected sessions, notify owner, log all access.
- Breach investigation: preserve all logs, do not modify or delete anything.
- Communication: owner is notified within 1 hour of detection.
- Post-breach: rotate all secrets, review access controls, update policies.

### 11.7.15 Logs Without Financial Data Leakage

- Application logs must never contain: account numbers, balances, payment amounts, transaction details.
- Application logs contain: user IDs, device IDs, operation types, timestamps, success/failure status.
- Error reports contain: stack traces, request IDs, user IDs — never financial data.
- Log sanitization is enforced at the logging framework level.

---

## 11.8 File and Logo Storage

### 11.8.1 Cloud Object Storage

- S3-compatible object storage (AWS S3, Cloudflare R2, or MinIO for self-hosted).
- Bucket structure: `{tenant_id}/{entity_type}/{entity_id}/{filename}`.
- Bucket versioning enabled for file history.
- Bucket lifecycle policies: move old versions to cheaper storage after 90 days.

### 11.8.2 Hash Integrity

- Every uploaded file is hashed (SHA-256) before storage.
- Hash is stored as metadata alongside the file.
- On download, hash is verified to detect corruption.
- Hash mismatch triggers re-upload request.

### 11.8.3 MIME Validation

- Server validates MIME type on upload using magic bytes, not file extension.
- Allowed MIME types: `image/png`, `image/jpeg`, `image/webp`, `image/svg+xml`, `application/pdf`.
- Rejected uploads return 415 Unsupported Media Type.

### 11.8.4 Size Limits

- Logo: maximum 5 MB.
- Attachment: maximum 10 MB.
- Export document: maximum 50 MB.
- Size limit exceeded returns 413 Payload Too Large.

### 11.8.5 Tenant-Scoped Paths

- Every file path includes tenant ID as the first path component.
- Signed URLs are tenant-scoped — a signed URL for tenant A cannot access tenant B files.
- Tenant isolation enforced at the storage access layer.

### 11.8.6 Signed Access URLs

- All file access requires a signed URL with expiry (default: 15 minutes).
- Signed URLs are generated server-side and returned to client.
- Client uses signed URL for direct download/upload (bypasses server for large files).
- Signed URLs are single-use for write operations, multi-use for read (within expiry).

### 11.8.7 Offline Cache

- Logos are cached locally on device for offline display.
- Cache is invalidated on sync (when server indicates logo has changed).
- Cache size limit: 50 MB per tenant.
- Cache is cleared on logout.

### 11.8.8 Backup Behavior

- Object storage files are backed up via bucket versioning and cross-region replication.
- Backup retention: same as database backup (30 days full, 1 year incremental).
- File backup restoration is tested monthly.

---

## 12. Multi-Device Concurrent Scenarios

This matrix defines expected behavior for all multi-device concurrent scenarios.

### 12.1 Windows + Windows (Two Desktop Instances)

| Aspect | Value |
|--------|-------|
| **Danger** | Medium — two desktops editing same data |
| **Expected Behavior** | Both devices sync to server. Conflicts detected via version numbers. Non-conflicting changes merged. Conflicting changes flagged for review. |
| **Truth Source** | Server database |
| **Prevention Mechanism** | Optimistic concurrency (version check on every write) |
| **User Message** | "Data conflict detected. Your changes to {field} were saved. {conflictingField} was modified by {user} on {device}. Please review." |
| **Acceptance Test** | Two Windows instances edit same product simultaneously. Both edits preserved where non-conflicting. Conflict flagged in UI. |

### 12.2 Windows + Mobile

| Aspect | Value |
|--------|-------|
| **Danger** | Medium — different form factors, same data |
| **Expected Behavior** | Same as Windows + Windows. Mobile may have limited operations (depending on chosen mobile option). |
| **Truth Source** | Server database |
| **Prevention Mechanism** | Optimistic concurrency + operation scope restrictions per device type |
| **User Message** | Same as above |
| **Acceptance Test** | Windows creates sale while mobile views inventory. No conflict. Windows creates sale while mobile creates collection for same customer. Both accepted if amounts valid. |

### 12.3 Online Device + Offline Device

| Aspect | Value |
|--------|-------|
| **Danger** | High — offline device operates on stale data |
| **Expected Behavior** | Online device's operations are processed immediately. Offline device queues operations locally. When offline device reconnects, queued operations are synced. Server validates all queued operations against current state. Conflicts detected and flagged. |
| **Truth Source** | Server database (online device has advantage) |
| **Prevention Mechanism** | Server-side validation of all queued operations, optimistic concurrency, stock/balance checks |
| **User Message** | "Some of your offline operations could not be completed: {reason}. Please review and adjust." |
| **Acceptance Test** | Device A goes offline, creates 3 sales. Device B processes 2 sales for same products. Device A reconnects. 1 sale synced, 2 rejected due to insufficient stock. |

### 12.4 Internet Drops During Sale

| Aspect | Value |
|--------|-------|
| **Danger** | Medium — user thinks sale is saved but it is not synced |
| **Expected Behavior** | Sale is saved locally in pending queue. User sees "Not synced" indicator. On reconnection, sale is automatically synced. If sync fails, user is notified. |
| **Truth Source** | Local device until sync confirmed by server |
| **Prevention Mechanism** | Offline queue with persistent storage, automatic retry on reconnection |
| **User Message** | "Sale saved locally. Will sync when connection is restored." |
| **Acceptance Test** | Start sale, disconnect internet mid-entry, complete sale, reconnect. Sale appears in queue, syncs successfully. |

### 12.5 Request Retransmission

| Aspect | Value |
|--------|-------|
| **Danger** | Low — network layer handles retransmission |
| **Expected Behavior** | HTTP layer may retransmit requests. Server uses idempotency keys to detect and deduplicate. Same clientRequestId = same result. |
| **Truth Source** | Server idempotency cache |
| **Prevention Mechanism** | Idempotency key on every write operation |
| **User Message** | No user-facing message — deduplication is transparent |
| **Acceptance Test** | Submit same request twice with same idempotency key. Second request returns same result as first. No duplicate data created. |

### 12.6 App Restart Before Acknowledgement

| Aspect | Value |
|--------|-------|
| **Danger** | Medium — user may not know if operation completed |
| **Expected Behavior** | Pending queue survives app restart (persisted to disk). On restart, app resumes sync from where it left off. Unacknowledged operations are retried. |
| **Truth Source** | Local pending queue |
| **Prevention Mechanism** | Persistent offline queue, automatic retry on app start |
| **User Message** | "Resuming sync... {count} operations pending." |
| **Acceptance Test** | Submit sale, kill app immediately, restart app. Sale is in pending queue, syncs automatically. |

### 12.7 Edit from Two Devices

| Aspect | Value |
|--------|-------|
| **Danger** | High — data conflict |
| **Expected Behavior** | Both edits submitted with version numbers. Server rejects the second edit if version has changed. Client receives conflict error with current data. Client must merge and resubmit. |
| **Truth Source** | Server version number |
| **Prevention Mechanism** | Optimistic concurrency with version check |
| **User Message** | "This record was modified by {user} on {device} since you last loaded it. Your changes have not been saved. Please review the current version and reapply your changes." |
| **Acceptance Test** | Open same product on two devices. Edit different fields. First save succeeds. Second save is rejected with conflict error. |

### 12.8 clientRequestId Duplication

| Aspect | Value |
|--------|-------|
| **Danger** | Low — idempotency prevents duplicates |
| **Expected Behavior** | If same clientRequestId submitted twice, server returns original result. No duplicate data created. |
| **Truth Source** | Server idempotency cache |
| **Prevention Mechanism** | Idempotency key validation |
| **User Message** | No user-facing message — deduplication is transparent |
| **Acceptance Test** | Generate same clientRequestId for two different operations. Second is rejected as duplicate. |

### 12.9 Clock Skew

| Aspect | Value |
|--------|-------|
| **Danger** | Low — server time is authoritative |
| **Expected Behavior** | Server adjusts client-submitted timestamps to server time. `createdAt` is always server time. `effectiveDate` is client-submitted but validated (not too far in past/future). Clock skew warning if device time differs from server by more than 5 minutes. |
| **Truth Source** | Server clock |
| **Prevention Mechanism** | Server timestamp adjustment, clock skew detection, NTP sync recommendation |
| **User Message** | "Your device clock is {minutes} minutes off. Some dates may be adjusted. Please sync your device clock." |
| **Acceptance Test** | Set device clock 10 minutes ahead. Submit operation. Server adjusts timestamp. Warning shown to user. |

### 12.10 Server Unavailable

| Aspect | Value |
|--------|-------|
| **Danger** | Medium — all operations must queue |
| **Expected Behavior** | All write operations queued locally. Read operations use cached/local data with staleness indicator. On server recovery, queue drains automatically. |
| **Truth Source** | Local device (stale data acknowledged) |
| **Prevention Mechanism** | Offline queue, automatic retry with exponential backoff |
| **User Message** | "Server is temporarily unavailable. Your operations are saved locally and will sync when the server is back online." |
| **Acceptance Test** | Shut down server. Submit 5 operations from client. Restart server. All 5 operations sync successfully. |

### 12.11 Partial Network Response

| Aspect | Value |
|--------|-------|
| **Danger** | Medium — client does not know if server processed request |
| **Expected Behavior** | Client times out after 30 seconds. Client retries with same idempotency key. Server returns original result if already processed. |
| **Truth Source** | Server (idempotency key determines if already processed) |
| **Prevention Mechanism** | Idempotency key, timeout + retry logic |
| **User Message** | "Sync is taking longer than expected. Retrying..." |
| **Acceptance Test** | Simulate network timeout mid-request. Client retries. Server returns cached result. No duplicate data. |

### 12.12 Device Revoked

| Aspect | Value |
|--------|-------|
| **Danger** | High — unauthorized access attempt |
| **Expected Behavior** | Revoked device's next API call is rejected with 401. Device cannot sync, cannot read data. Local data remains but is inaccessible. User sees revocation message. |
| **Truth Source** | Server device status |
| **Prevention Mechanism** | Token invalidation on revocation, server-side device status check |
| **User Message** | "This device has been revoked by the administrator. All data on this device is now inaccessible. Contact your administrator for access." |
| **Acceptance Test** | Revoke device. Attempt any operation on revoked device. Operation rejected. |

### 12.13 User Disabled

| Aspect | Value |
|--------|-------|
| **Danger** | High — unauthorized access attempt |
| **Expected Behavior** | Disabled user's token refresh fails. All API calls rejected. Local data inaccessible. User sees disabled message. |
| **Truth Source** | Server user status |
| **Prevention Mechanism** | Token refresh validates user status, server-side user status check |
| **User Message** | "Your account has been disabled. Contact your administrator." |
| **Acceptance Test** | Disable user. Attempt token refresh. Refresh rejected. All operations blocked. |

### 12.14 Stock Conflict

| Aspect | Value |
|--------|-------|
| **Danger** | High — overselling risk |
| **Expected Behavior** | Server validates stock availability at processing time. If insufficient stock, sale is rejected. Client must adjust quantity or cancel. |
| **Truth Source** | Server stock level |
| **Prevention Mechanism** | Server-side stock validation, optimistic check + server confirmation |
| **User Message** | "Insufficient stock for {product}. Available: {available}, requested: {requested}. Please adjust quantity." |
| **Acceptance Test** | Product with 10 units. Two devices sell 8 and 5 units respectively. Second sale rejected. |

### 12.15 Account Balance Conflict

| Aspect | Value |
|--------|-------|
| **Danger** | High — incorrect balance |
| **Expected Behavior** | Server validates account balance at processing time. If operation would cause invalid state (e.g., overdraft), operation is rejected. Client must adjust. |
| **Truth Source** | Server account balance |
| **Prevention Mechanism** | Server-side balance validation, optimistic check + server confirmation |
| **User Message** | "Account {name} has insufficient balance. Available: {available}, requested: {requested}. Please adjust amount." |
| **Acceptance Test** | Account with 500 balance. Two devices attempt collections of 300 and 400 respectively. Second rejected. |

### 12.16 Duplicate Collection

| Aspect | Value |
|--------|-------|
| **Danger** | High — customer overpaid |
| **Expected Behavior** | Server validates outstanding debt at processing time. If collection exceeds outstanding debt, operation is rejected. |
| **Truth Source** | Server customer balance |
| **Prevention Mechanism** | Server-side debt validation |
| **User Message** | "Customer {name} outstanding balance is {balance}. Collection of {amount} exceeds outstanding debt." |
| **Acceptance Test** | Customer with 1000 debt. Two collections of 600 and 500. Second rejected. |

### 12.17 Duplicate Supplier Payment

| Aspect | Value |
|--------|-------|
| **Danger** | High — supplier overpaid |
| **Expected Behavior** | Same as duplicate collection but for supplier payments. |
| **Truth Source** | Server supplier balance |
| **Prevention Mechanism** | Server-side debt validation |
| **User Message** | "Supplier {name} outstanding balance is {balance}. Payment of {amount} exceeds outstanding debt." |
| **Acceptance Test** | Supplier with 2000 debt. Two payments of 1200 and 1000. Second rejected. |

### 12.18 Transfer Submitted Twice

| Aspect | Value |
|--------|-------|
| **Danger** | High — double stock movement |
| **Expected Behavior** | Server uses idempotency key to detect duplicate transfer. Same clientRequestId = same result. No duplicate stock movement. |
| **Truth Source** | Server idempotency cache |
| **Prevention Mechanism** | Idempotency key validation |
| **User Message** | No user-facing message — deduplication is transparent |
| **Acceptance Test** | Submit transfer twice with same clientRequestId. Stock moves only once. |

### 12.19 Cancellation Submitted Twice

| Aspect | Value |
|--------|-------|
| **Danger** | Medium — double reversal attempt |
| **Expected Behavior** | Server uses idempotency key to detect duplicate cancellation. Same clientRequestId = same result. No double reversal. |
| **Truth Source** | Server idempotency cache |
| **Prevention Mechanism** | Idempotency key validation, document status check |
| **User Message** | No user-facing message — deduplication is transparent |
| **Acceptance Test** | Submit cancellation twice with same clientRequestId. Document cancelled once. No double reversal. |

---

## 13. Mobile Application Audit

Three mobile options are evaluated. Each option represents a different scope of mobile functionality.

### 13.1 Mobile Option A — Owner Read-Only

**Scope**: Dashboard, reports, inventory levels, account balances, alerts. No posting capability.

**Complexity**: Low. Read-only data access requires minimal new business logic. Primarily a data presentation layer.

**Risks**:
- Data freshness depends on sync frequency.
- Owner may expect real-time data but receive stale data.
- Alert delivery depends on push notification infrastructure.

**Cloud Dependencies**:
- Requires cloud database for data access.
- Requires authentication for device registration.
- Requires push notification service (Firebase Cloud Messaging).

**Offline Requirements**:
- Cached data for offline viewing (last sync snapshot).
- Clear staleness indicator ("Last updated: {timestamp}").
- No offline posting capability.

**Permission Requirements**:
- `dashboard.view`
- `reports.view`
- `inventory.view`
- `accounts.view`
- `alerts.view`

**Estimated Phases**: 3-4 phases (Phase 71: auth + device registration, Phase 72: read-only API + dashboard, Phase 73: reports + alerts, Phase 74: push notifications).

**Tests**:
- Device registration and authentication.
- Dashboard data display.
- Report generation and display.
- Alert delivery.
- Offline data display with staleness indicator.
- Data accuracy compared to desktop.

**Recommendation**: Recommended as the first mobile option. Low risk, high value for owner visibility. Establishes cloud infrastructure and mobile framework for future expansion.

---

### 13.2 Mobile Option B — Field Collections & Payments

**Scope**: Customer collections, supplier payments, account selection, receipt generation. No sales or purchases.

**Complexity**: Medium. Requires write operations with offline queue, conflict resolution for financial data, and receipt generation.

**Risks**:
- Financial data integrity — collections/payments must be atomic with customer/supplier balance updates.
- Offline queue complexity — financial operations must not be duplicated or lost.
- Receipt generation requires PDF creation on mobile.
- Field conditions may cause unreliable connectivity.

**Cloud Dependencies**:
- Requires cloud database for write operations.
- Requires offline queue with sync.
- Requires authentication and device registration.
- Requires file storage for receipts.

**Offline Requirements**:
- Full offline queue for collections and payments.
- Offline receipt generation (local PDF template).
- Conflict resolution when syncing offline financial operations.
- Stock validation may not be fully available offline (stale data risk).

**Permission Requirements**:
- `collection.create`
- `payment.create`
- `accounts.view`
- `customers.view`
- `suppliers.view`
- `reports.view`

**Estimated Phases**: 5-6 phases (Phase 71-74 from Option A + Phase 75: offline queue + write API, Phase 76: receipt generation + conflict resolution).

**Tests**:
- All Option A tests.
- Collection creation online and offline.
- Payment creation online and offline.
- Offline queue sync and conflict resolution.
- Receipt generation.
- Duplicate collection prevention.
- Duplicate payment prevention.
- Balance accuracy after offline operations.

**Recommendation**: Recommended as the second mobile option if field collections are required. Medium complexity, high business value. Builds on Option A infrastructure.

---

### 13.3 Mobile Option C — Full Operational Mobile

**Scope**: Sales, purchases, inventory movements, collections, payments, expenses, reports, account operations. Full parity with desktop.

**Complexity**: High. Requires all desktop business logic replicated for mobile, complex offline queue, comprehensive conflict resolution, and mobile-optimized UI.

**Risks**:
- Mobile form factor may be unsuitable for complex operations (multi-item sales, purchase orders).
- Offline queue becomes very complex with all operation types.
- Conflict resolution across all operation types.
- Data entry speed on mobile vs desktop.
- Battery and performance impact of background sync.
- Security risk — mobile devices are more likely to be lost or stolen.

**Cloud Dependencies**:
- Full cloud infrastructure required.
- Complex offline queue with all operation types.
- Authentication, device management, session management.
- File storage, push notifications, real-time sync.

**Offline Requirements**:
- Full offline queue for all operation types.
- Offline receipt and document generation.
- Comprehensive conflict resolution.
- Local data caching for all entity types.
- Graceful degradation when offline (e.g., limited inventory operations).

**Permission Requirements**:
- All permissions from Options A and B.
- `sale.create`
- `purchase.create`
- `stock.create`
- `expense.create`
- `transfer.create`
- `reconciliation.create`

**Estimated Phases**: 10-12 phases (Phase 71-76 from Option B + Phase 77: sales/purchases + Phase 78: inventory + Phase 79: expenses/transfers + Phase 80: reconciliation + Phase 81: advanced features).

**Tests**:
- All Option A and B tests.
- Sales creation online and offline.
- Purchase creation online and offline.
- Inventory movements online and offline.
- Expense recording online and offline.
- Transfer execution online and offline.
- Reconciliation online and offline.
- Comprehensive conflict resolution for all types.
- Performance testing on low-end devices.
- Security testing for device loss/theft scenarios.

**Recommendation**: Not recommended as a first mobile option. High complexity, high risk. Consider only after Options A and B are proven stable. Desktop should remain the primary operational interface.

---

### 13.4 Required Owner Decisions

The following decisions must be made before mobile development begins:

1. **Android only vs Android + iOS?** — Android first recommended (larger user base in target market). iOS can be added later.
2. **Owner only vs employees?** — Determines permission model and device management scope.
3. **Sales from mobile required?** — If yes, Option C required. If no, Option A or B sufficient.
4. **Purchases from mobile required?** — If yes, Option C required. If no, Option A or B sufficient.
5. **Field collections required?** — If yes, Option B or C required. If no, Option A sufficient.
6. **Printing from mobile required?** — Requires Bluetooth printer integration. Adds complexity.
7. **Offline mode required?** — Strongly recommended for field use. Required for Option B and C.
8. **Images/attachments required?** — Adds file upload complexity and storage requirements.
9. **Notifications required?** — Push notifications require Firebase Cloud Messaging or equivalent.
10. **Location tracking required?** — Adds GPS permission, battery drain, and privacy concerns.

---

## 14. Permission Gaps

### 14.1 Current Permission Model

The current desktop application uses a simple role-based model with roles: Owner, Admin, Manager, Cashier, Warehouse Keeper, Viewer. Permissions are coarse-grained (e.g., "can access sales screen").

### 14.2 Financial Account Permission Gaps

The following financial account operations lack dedicated permissions:

| Operation | Current State | Required Permission | Gap |
|-----------|---------------|---------------------|-----|
| View account balances | Owner/Admin only (hardcoded) | `account.balance.view` | Missing — no granular control |
| Create financial account | Owner only (hardcoded) | `account.create` | Missing — no delegation possible |
| Edit financial account | Owner only (hardcoded) | `account.edit` | Missing — no delegation possible |
| Enter opening balance | Owner only (hardcoded) | `account.opening-balance.create` | Missing — critical financial operation without permission control |
| Record collection | Owner/Admin (hardcoded) | `collection.create` | Missing — no cashier-level control |
| Record payment | Owner/Admin (hardcoded) | `payment.create` | Missing — no cashier-level control |
| Execute transfer | Owner only (hardcoded) | `transfer.create` | Missing — critical financial operation without permission control |
| Cancel movement | Owner only (hardcoded) | `movement.cancel` | Missing — should require approval workflow |
| Approve reconciliation | Owner only (hardcoded) | `reconciliation.approve` | Missing — no dual-authorization |
| Reopen closed day | Owner only (hardcoded) | `day.reopen` | Missing — high-risk operation without permission control |

### 14.3 Cloud Permission Gaps

The following cloud operations lack permissions entirely (new for cloud deployment):

| Operation | Required Permission | Notes |
|-----------|---------------------|-------|
| View all branches/devices | `device.view-all` | For multi-device visibility |
| Manage devices | `device.manage` | Register, suspend, revoke devices |
| Revoke session | `session.revoke` | Force logout of specific sessions |
| View sync errors | `sync.view-errors` | For troubleshooting sync issues |
| Retry sync | `sync.retry` | Manual retry of failed sync operations |
| Export data | `data.export` | Tenant-scoped data export |
| Restore backup | `data.restore` | High-privilege operation |
| Manage mobile users | `mobile.manage` | Control mobile device access |

### 14.4 Role Sufficiency Assessment

The current role model does NOT suffice for cloud deployment. Reasons:

1. **No granular financial permissions** — Owner/Admin/Manager roles are too coarse. A cashier should be able to record collections but not execute transfers. A manager should view all accounts but not modify them.
2. **No cloud-specific permissions** — Device management, sync management, and data export need dedicated permissions.
3. **No approval workflow permissions** — High-risk operations (reconciliation, day reopen, large transfers) should require dual authorization.
4. **No temporal permissions** — Permissions should be time-limited (e.g., temporary admin access for a specific task).

### 14.5 Recommended Permission Matrix

Implement a full permission matrix (Phase 72+):

- Define all permissions as atomic strings.
- Map permissions to roles via a role-permission join table.
- Allow custom roles with custom permission sets.
- Server-side permission check on every API endpoint.
- Client-side permission check for UI gating (non-authoritative).

---

## 15. Backup and Migration Audit

### 15.1 Backup vs Sync vs Export — They Are NOT the Same

| Term | Definition | Scope | Frequency | Purpose |
|------|-----------|-------|-----------|---------|
| **Local Backup** | JSON export/import to local file system | Single device, all data | On-demand | Disaster recovery for single device |
| **Cloud Backup** | Automated server-side database backup | Server, all tenants | Automated (daily) | Server disaster recovery |
| **Sync** | Client-server data synchronization | Single tenant, all devices | Continuous | Multi-device data consistency |
| **Discovery Recovery** | Full system restoration from backup | Server + all tenants | Emergency | Complete system rebuild |
| **Export** | Tenant-scoped data export in structured format | Single tenant | On-demand | Data portability, compliance |
| **Device Migration** | Moving data from one device to another | Single tenant, single device | On-demand | Hardware replacement |

**These are NOT interchangeable.** Using sync as a backup is dangerous — sync can propagate corruption. Using export as a backup is incomplete — export may not include all metadata.

### 15.2 Future Backup v3+ Requirements

When adding the following features, backup format must be updated:

- Financial accounts and balances
- Financial ledger (all journal entries)
- Payment allocations (which payment covers which invoice)
- Transfer records (inter-account transfers)
- Sync metadata (pending operations, tombstones, conflict records)
- Device registry (all registered devices)
- Tenant configuration (roles, permissions, settings)

Backup v3 format must include all of the above in a single atomic export file.

### 15.3 Backup Versioning Policy

| Version | Format | Includes | When to Use |
|---------|--------|----------|-------------|
| v1 | JSON | Sales, purchases, stock, customers, suppliers, products | Current (Phase 70-) |
| v2 | JSON + checksum | v1 + expenses, settings, user data | Phase 71-74 |
| v3 | JSON + checksum + metadata | v2 + financial accounts, ledger, sync metadata, devices | Phase 75+ |

- Backup files include a version header.
- Restore logic checks version and applies appropriate migration.
- Old backup versions remain restorable for 2 years after deprecation.

### 15.4 Migration Plan: Local Single-Device to Cloud Multi-Device

#### Phase 1: Pre-Migration Preparation
1. Create full local backup (current format).
2. Validate backup integrity (checksum, record counts).
3. Backup file stored in three locations: local, external drive, cloud storage.
4. Migration window scheduled (minimum 4 hours, off-business-hours).
5. All users notified of downtime.

#### Phase 2: Data Upload
1. Local backup file uploaded to server.
2. Server parses backup and creates tenant.
3. All entities imported with original UUIDs preserved.
4. Server-assigned IDs (server_id) generated during import.
5. Document numbers re-sequenced if needed.

#### Phase 3: Server-Side Reconciliation
1. Row count comparison: local backup vs server import.
2. Total comparison: sales total, purchase total, stock value, customer balances, supplier balances, financial account balances.
3. Every discrepancy logged and reported.
4. Zero-tolerance for financial total discrepancies.

#### Phase 4: Validation
| Check | Method | Tolerance |
|-------|--------|-----------|
| Sales count | Local backup count == server count | 0 |
| Sales total | Local backup total == server total | 0.00 |
| Purchase count | Local backup count == server count | 0 |
| Purchase total | Local backup total == server total | 0.00 |
| Stock quantity per product | Local backup == server | 0 |
| Customer balance | Local backup == server | 0.00 |
| Supplier balance | Local backup == server | 0.00 |
| Financial account balance | Local backup == server | 0.00 |
| Product count | Local backup == server | 0 |
| Document numbers | No duplicates, no gaps | 0 |

#### Phase 5: Rollback Plan
1. If any validation check fails, abort migration.
2. Local backup remains intact.
3. Server-side imported data is deleted.
4. Owner notified of failure with detailed report.
5. Root cause analysis before retry.

#### Phase 6: Migration Report
1. Migration report generated with:
   - Migration date and time
   - Backup file version and checksum
   - Total records imported per entity type
   - Total financial values per category
   - Validation results (all checks pass/fail)
   - Any warnings or discrepancies
   - Migration duration
2. Report stored in server audit logs.
3. Report presented to owner for acceptance.

#### Phase 7: Owner Acceptance
1. Owner reviews migration report.
2. Owner verifies key data points (stock counts, customer balances).
3. Owner signs off on migration (digital acceptance).
4. Desktop app switched to cloud mode.
5. Local data cleared (after owner confirmation).

---

## 16. Reports and PDF Gaps

### 16.1 New Reports Required for Cloud / Multi-Device

| Report | Description | Data Sources | Priority |
|--------|-------------|-------------|----------|
| Financial accounts summary | All account balances, totals, movements | Financial accounts, ledger entries | High |
| Payment methods summary | Breakdown by cash, electronic, credit | Collections, payments, sales | High |
| Collection account report | Collections per account with details | Collections, financial accounts | High |
| Settlement account report | Payments per account with details | Payments, financial accounts | High |
| Expense account report | Expenses per account with details | Expenses, financial accounts | Medium |
| Mixed payments report | Sales with multiple payment methods | Sales, payment splits | Medium |
| Refunds report | All refunds with original document references | Reversals, original documents | Medium |
| Transfers report | All inter-account transfers | Transfers, financial accounts | High |
| Reconciliation report | Account reconciliation status and history | Reconciliations, ledger entries | Medium |
| Sync status report | Sync health across all devices | Sync queue, device registry | High |
| Device activity report | Per-device activity, last sync, errors | Device registry, audit logs | Medium |
| Audit trail report | Filterable audit log with export | Audit logs | High |

### 16.2 Invoice/PDF Display Gaps

Current invoices do not display payment-related information. Required additions:

| Field | Display | Notes |
|-------|---------|-------|
| Payment method | "Cash" / "Electronic" / "Credit" | Must not display bank account numbers |
| Account received from | Account name only (not number) | Formatted: "Cash Register - Main" |
| Account paid to | Account name only (not number) | For supplier payments |
| Transfer reference | Transfer document number | For inter-account transfers |
| Cash paid amount | Amount in local currency | Displayed separately from electronic |
| Electronic paid amount | Amount in local currency | Displayed separately from cash |
| Credit amount | Remaining balance after payment | For credit sales |

### 16.3 Sensitive Information Policy for PDFs

- Never display full bank account numbers — show last 4 digits only: `****1234`.
- Never display full tax identification numbers — show masked version.
- Never display internal server IDs — use document numbers instead.
- Never display user passwords or authentication tokens.
- Payment method labels should be generic ("Electronic Payment") not specific ("Bank of Iraq Account #12345678").

### 16.4 PDF Modification Constraint

**Do NOT modify PDF generation logic in Phase 70.**

PDF changes should be implemented in Phase 74+ when:
- Cloud sync is operational.
- Payment methods are fully integrated.
- Financial account data is available.
- Design team has reviewed layout requirements.

---

## Summary of Phase Dependencies

| Feature | Requires | Blocks |
|---------|----------|--------|
| Cloud sync | Central database, API, auth | Multi-device, mobile |
| Multi-device | Cloud sync, device identity | Concurrent editing, conflict resolution |
| Mobile Option A | Cloud sync, auth | Mobile Options B and C |
| Mobile Option B | Mobile Option A, offline queue | Mobile Option C |
| Mobile Option C | Mobile Option B, full business logic | Nothing (terminal) |
| Cloud backup | Central database, cloud storage | Disaster recovery |
| Migration | Cloud backup, validation tools | Multi-device operation |
| Permission matrix | Cloud auth, RBAC | Mobile Option B+ |

**Recommended order**: Cloud infrastructure → Auth → Read-only API → Sync engine → Multi-device → Mobile Option A → Mobile Option B → Mobile Option C.
