# BUILD-21 — AI Action Discovery and Caller-Supplied Composition Scope Freeze

## 1. Owner decision

The owner authorizes BUILD-21 as a **documentation-only** and
**architecture-governance-only** build. It authorizes no production
implementation, no action-inventory change, no registry implementation, no
automatic discovery, and no BUILD-22 implementation.

The inventory has reached twelve deliberately narrow actions. The next safe
step is therefore to freeze how those actions are discovered and explicitly
composed, rather than add a thirteenth name or turn the existing allow-list
into implicit application state. This freeze preserves caller ownership,
prevents accidental capability exposure, and gives future entry points a
stable boundary without changing accounting behavior.

## 2. Verified baseline

- Baseline commit: `ac039e9fb15665febbc46df08b3403b554727b39`.
- Baseline message: `BUILD-20: audit AI financial action coverage and boundaries`.
- Preflight worktree: exactly the inherited modified
  `lib/features/financial_reports/advances_and_refunds_report_screen.dart`
  and untracked `.build-diagnostics/`; no other path was present.
- Protected file working-tree SHA-256:
  `A4F7A89BF096339FBB05D2706F82F8A0C2B4C7B7A89D69FAA386A6869C0D455C`.
  Its working-tree Git object is
  `22800a9ccb08ee5796f0fa69c87bd9995739adbf`, its size is 32,418 bytes, and
  its state is modified and unstaged. The pre-existing index blob is
  `3f4f943ed19ec113665752db6da3071ea1b7eba2`; that is the tracked baseline,
  not the protected inherited working-tree content.
- `.build-diagnostics/` exists as an untracked directory and is inherited;
  BUILD-21 neither reads as evidence from it nor changes it.
- Current inventory: exactly 12 exported `AiTool` implementations, verified
  against `ai_assistant.dart`, all tool source files, BUILD-20, and the
  12-action fixture in `supplier_payments_by_financial_account_tool_test.dart`.
- Registry architecture: `AiToolRegistry(Iterable<AiTool>)` indexes only the
  caller-provided iterable, rejects blank or duplicate IDs, and stores a
  `Map.unmodifiable`. `AiExecutionService` is constructed with that registry.

## 3. Existing composition architecture

Current code is intentionally small and contains no production composition
root. A caller constructs `AiToolRegistry` and passes an explicit iterable of
tools. The registry iterates that iterable in supplied order, inserts each tool
into a local Dart map by `tool.id`, rejects blank IDs and an already-present
exact ID with `ArgumentError`, and freezes the resulting map with
`Map.unmodifiable`.

`findById` performs exact map lookup. `all` exposes the map values; because a
Dart map preserves insertion order, the supplied order is retained in that
view, but lookup itself is by ID and must not depend on position. The caller
collection is not retained: it is copied into the registry's private index.
Registry mapping state cannot mutate after construction. Whether individual
tool objects are safe to reuse remains their own dependency/immutability
question.

The caller may supply any valid subset, including an empty registry. Tests
construct one-tool registries, and the BUILD-19 fixture constructs the
intentional full inventory of 12. There is no default full catalog, default
registry, global registry, singleton, mutable static registry, auto-registering
mechanism, application-wide scan, or service-location behavior in production
AI code. `AiExecutionService` resolves an intent only against its injected
registry and returns `unknownTool` when the ID is absent.

The registry performs availability lookup, not authorization. Financial tools
validate their read-only mode and caller authorization before invoking their
reader; eleven require an active caller with `canViewFinancialReports`, while
closing reconciliation requires an active owner. `inventory_attention` has no
caller permission dependency in its present contract. Each tool contains its
own ID, human name, description, parameter metadata, validation and execution
behavior. The `AiTool` interface exposes `id`, `name`, `description`,
`parameters`, and `execute`; it does not yet expose every policy item as
uniform executable metadata.

### Evidence and documentation discrepancy

`docs/AI_ACTION_LAYER_ARCHITECTURE.md` describes adding a tool to a
“composition-root” registry and says tools receive controllers. Current code
proves neither a production composition root nor controller injection for the
current reporting actions: the tools receive narrow readers, and the reader
adapters delegate to canonical services. BUILD-20 and the current source/tests
are the stronger evidence for this freeze. The older note is a documentation
gap; BUILD-21 does not edit it because this build changes only the authorized
scope-freeze document.

## 4. Terminology freeze

- **Action** — one executable AI capability with its own exact name,
  description, input contract, output/result contract, execution mode,
  confirmation policy, permission contract, and tool implementation.
- **Canonical domain boundary** — the approved non-AI source of business or
  accounting truth.
- **Reader** — the narrow abstraction supplied to an AI tool that returns a
  canonical result without exposing repositories.
- **Registry** — an immutable lookup/composition object created from actions
  explicitly supplied by a caller.
- **Caller** — the composition owner that chooses which actions are available
  in a given context.
- **Catalog** — a documentation or metadata view of known actions. A catalog
  must not automatically become a runtime registry.
- **Composition profile** — a documented recommended subset of actions for a
  specific caller context. A composition profile must not become implicit
  global runtime state.
- **Discovery** — the process by which a caller or developer learns what
  actions are available for explicit composition. Discovery does not mean
  automatic runtime registration.

These terms are deliberately separate: composition answers “which explicitly
supplied actions are available here?”, whereas authorization answers “may this
caller execute this available action?”

## 5. Action naming freeze

Existing IDs are frozen. Future IDs must be lowercase `snake_case`, globally
unique within every caller-supplied registry, and use stable business-domain
prefixes. Financial actions use the stable `financial_` prefix; an inventory
capability uses `inventory_`. Names must express a stable business intent,
not UI wording, widget/screen names, reader/service/repository terminology,
or a temporary implementation detail.

Use nouns for the business subject and a contractually distinct report or
operation term only where it clarifies scope. `report`, `summary`, and
`details` are prohibited unless their difference from every existing action is
specified in the input and result contract. Do not create aliases, names that
differ only by word order, or symmetry-only counterparts. Do not encode an
assumption of one account per transaction, one row per transaction, or a
globally unique transaction ID per report row. Read/report names must not
masquerade as mutations, and a mutation must never reuse a read-only ID.

No existing name may be renamed in BUILD-21. Any later rename requires a
separately authorized compatibility migration; it cannot be concealed by an
alias.

## 6. Action metadata freeze

Every future action proposal must document the following, and every existing
action must retain the information already represented by its source or tests:

| Metadata | Present executable representation | Status / audience |
| --- | --- | --- |
| Exact action name | `AiTool.id` | executable contract; caller-facing; test-enforced |
| User-intent description | `name` and `description` | executable metadata; caller-facing; metadata-test candidate |
| Input names, types, descriptions, required flag | `AiTool.parameters` / `AiToolParameter` | executable contract; caller-facing; test-enforced |
| Execution mode | passed to `execute`; current tools validate `readOnly` | executable contract; test-enforced |
| Confirmation requirement | concrete tools expose `requiresConfirmation`; absent from `AiTool` | current-tool contract; documentation/test-enforced, not generic executable metadata |
| Required permission | individual tool authorization code | executable behavior; internal and security-review evidence |
| Result type/category | `AiToolResult` data/tables and concrete tool behavior | executable result contract; caller-facing |
| Canonical boundary reference | reader interface/adapter and tool documentation | documentation and review evidence |
| Privacy classification | no common code field | documentation-only until separately authorized |
| Mutation classification | current read-only mode/tool behavior | executable behavior plus documentation |
| Version/compatibility note | no current common support | documentation-only future gap |

BUILD-21 does not invent fields on `AiTool`, add annotations, or make a
metadata catalog executable. Missing common fields are gaps for a future,
separately authorized architecture decision.

## 7. Input-description freeze

Future inputs must have stable names, use existing domain identifiers, state
required versus optional status and expected `AiParameterType`, and preserve
null semantics exactly where the canonical boundary permits null. They must
not expose raw repository selectors, persistence objects, UI labels,
free-form filters where a boundary requires exact identifiers, presentation
amount-formatting options, or caller-directed sort options when canonical
ordering exists. Date inputs must identify whether they are local business
dates, inclusive/exclusive, and their accepted serialized form. Money must
state integer qirsh semantics whenever relevant; tools must not format or
recalculate qirsh values.

The present collections and supplier-payment actions demonstrate exact,
inclusive local `YYYY-MM-DD` business dates. Existing contracts remain
unchanged. Input removal or rename, adding a required input, or changing null,
date, qirsh, filtering, or ordering semantics is breaking and needs a
separate authorized compatibility review.

## 8. Caller-supplied composition rules

1. Every runtime registry is created by a caller.
2. Every action in a registry is explicitly supplied.
3. A registry may contain all 12 actions or an approved subset.
4. A registry must not discover actions through reflection or scanning.
5. A registry must not reach into global state.
6. A registry must not mutate after construction.
7. Two actions with the same exact name must be rejected.
8. The caller selects actions suitable for its context.
9. Tool-level authorization remains mandatory even when composition is permission-aware.
10. Omitting an action is not an authorization check.
11. Composition must not bypass tool validation.
12. Composition must not bypass confirmation rules for any future mutating action.
13. Reuse a tool instance only where its dependencies and immutability contract make it safe.
14. Composition must remain fake-testable without application-global state.
15. Composition must remain compatible with future Cloud, Mobile, and multi-device entry points.

## 9. Permission-aware composition

A caller may choose not to include actions that its current user cannot use,
and may apply stricter context-specific availability rules. That is
defense-in-depth only: individual tools remain the primary authorization
boundary and must validate their established permission before their reader.
Permissions must come from established authorization contracts, never be
inferred from IDs or names. A caller may not weaken a tool's required
permission.

Mixed-permission registries are allowed only when each constituent tool
independently enforces its own permission. Permission state must not live in a
global mutable registry. Future per-session, per-user, remote, mobile, or
multi-device contexts must be able to build their own context-safe registry.
Registry absence yields unavailable/unknown action behavior; it is not proof
that a user was denied permission.

## 10. Recommended composition profiles

The following are conceptual documentation-only profiles, not constants,
lists, builders, factories, default registries, or runtime configuration.

| Profile | Intended caller/context | Appropriate actions | Permissions and exclusions | Privacy / current need |
| --- | --- | --- | --- | --- |
| Full owner financial | Active owner reviewing all approved financial reports | All eleven `financial_*` actions | `canViewFinancialReports` plus active-owner-only closing reconciliation; excludes `inventory_attention` because it is not financial | Broad balances, account and party-report exposure; conceptual only, no production caller presently composes it |
| Financial reporting | Active financial-report user | All financial actions except closing reconciliation unless the caller is an active owner | `canViewFinancialReports`; owner-only closing is excluded for a non-owner | Exposes only already-authorized report data; documentation-only |
| Inventory-focused | Operational inventory attention context | `inventory_attention` | Present action has no caller permission dependency; excludes financial reports | Narrow operational stock-status exposure; meaningful as a conceptual subset, not currently implemented |
| Read-only operational | A conservative support/operations context with independently enforceable access | `inventory_attention`; optionally an explicitly authorized financial subset only when each financial tool receives an authorized caller | Never use registry inclusion to grant financial access; excludes closing by default | Avoid balances, party reports, audit/persistence data, paths, and raw entities; documentation-only |
| Minimal diagnostic/support | No supported generic support profile is evidenced | None by default | No action should be exposed merely for diagnosis | A future owner decision is required before treating business reports as support diagnostics |

## 11. Action discovery rules

Approved discovery, in priority order, is: (1) Build Week documentation;
(2) an action-matrix document; (3) explicit tool metadata; (4) caller-owned
composition code; and (5) tests that intentionally enumerate a full
inventory. A future human-readable catalog may improve discovery, but must
remain separate from runtime composition unless separately authorized.

The following are rejected: runtime reflection, source-directory or filesystem
scanning, annotation scanning, auto-import generation without explicit owner
authorization, service-location discovery, global mutable catalogs, plugin
loading that bypasses caller composition, and environment-dependent action
registration. The current barrel export is source visibility, not automatic
runtime availability.

## 12. Duplicate and overlap prevention

Before a thirteenth action is authorized, review every existing action. A
proposal is not sufficient merely because a symmetrical name is missing,
another entity has a similar action, an optional filter could receive a new
name, a report can be trivially renamed, or a caller can already answer the
intent with an existing action.

The review must show distinct business intent, a distinct canonical output
contract, why existing actions are insufficient, why optional inputs cannot
safely answer the need, permission and privacy contracts, accounting contract,
canonical boundary, Split Payments compatibility, Cloud/Mobile/multi-device
compatibility, and a duplication analysis against all twelve actions.

Classify the result as one of: **distinct**, **acceptable specialization**,
**discoverability-only gap**, **probable duplication**, **confirmed
duplication**, **blocked by missing domain boundary**, or **blocked by
unresolved accounting semantics**. BUILD-20's rejected allocation-aware
transaction-by-account candidate is an example of a proposal blocked by a
missing allocation-aware canonical boundary and Split Payments semantics.

## 13. Future action authorization gate

No future action may skip these gates:

1. **Business intent** — owner approves the exact business question or operation.
2. **Existing coverage review** — all current actions are checked for equivalent or sufficient coverage.
3. **Domain boundary review** — an immutable canonical boundary exists, or a separate domain-only build is authorized.
4. **Permission and privacy contract** — required permission and exposed fields are explicitly approved.
5. **Accounting contract** — ordering, filtering, calculations, qirsh, null, and mutation behavior are assigned to the correct layer.
6. **Future compatibility** — Split Payments, advances, refunds, negative balances, closing, backup versions, Cloud, Mobile, and multi-device implications are reviewed.
7. **AI wrapper authorization** — only then may a read-only or mutating AI action be authorized.
8. **Registry impact** — count change and intended caller compositions are explicitly approved.

## 14. Read-only versus mutating action freeze

The current inventory is read-only. Its confirmation-free behavior is valid
because the actions are read-only; it is not a reusable mutation policy.

Every future mutating action requires explicit mutation authorization and a
separately decided confirmation policy. It must define idempotency,
mutation-specific permission, error and audit behavior, retry behavior, and
duplicate-execution behavior. Reader abstractions alone are insufficient for
writes. Generic AI tool logic must not access repositories; write access must
remain behind approved application/domain services. BUILD-21 authorizes no
mutation.

## 15. Compatibility with future roadmap

**Split Payments.** Composition, IDs, profiles, inputs, and result descriptions
must not assume one account per transaction, one report row per transaction,
or globally unique transaction IDs across report rows. The approved
collections/payment boundaries preserve allocation-compatible rows.

**Advances, overpayments, and refunds.** Do not imply unfinished semantics are
stable through profile/category wording. The advances/refunds action remains a
governed existing report. The inherited protected UI file is not evidence of
completed domain behavior.

**Negative balances.** No name, description, or profile may imply that
negative balances are universally allowed or prohibited.

**Period closing.** Keep book balances, actual balances, variances, historical
reports, current balances, and reopened periods distinct. Closing
reconciliation remains owner-gated.

**Backup and restore.** Inputs and results must tolerate nullable fields
restored from supported older backup versions whenever canonical boundaries
permit them; no AI layer may repair nulls.

**Cloud, Mobile, and multi-device.** Future entry points require separate
caller contexts, per-session registries, per-user permissions, remote API and
mobile entry points, multiple devices, and process-independent composition.
Architecture depending on widget context, local paths, a permanent authenticated
user, a single device, or one process-wide mutable registry is rejected.

## 16. Testing freeze

Every future registry or action addition must test exact ID, duplicate-ID
rejection, registry immutability, caller-supplied subsets, and full inventory
count when intentionally testing one. It must also establish no global or
singleton registry, no silent registration, permission-before-reader behavior,
validation, confirmation, canonical-result preservation, no AI-layer
repository access, and no AI-layer recalculation, sorting, filtering,
aggregation, or identity enrichment. Existing actions must remain unchanged;
profile or catalog documentation must not register tools.

The existing focused action tests and `ai_execution_service_test.dart` provide
partial current evidence. BUILD-21 adds no tests because it changes no
executable behavior.

## 17. Versioning and compatibility freeze

Action IDs are stable external identifiers. Input removal/rename or a new
required input is breaking; optional-input additions require compatibility
review. Removing a result field or changing result semantics is breaking.
Permission weakening is prohibited; strengthening requires owner
authorization. Changing read-only to mutating is prohibited absent a new
action or explicit migration. Confirmation-policy changes require explicit
authorization. Canonical-boundary changes require regression evidence.

Registry-count changes require documentation updates. Aliases are not casual
compatibility: do not add them. Deprecated actions must not disappear
silently. The code has no formal metadata version field, so these are
documentation and review rules until a future authorized compatibility design
introduces supported executable versioning.

## 18. Current 12-action catalog reference

BUILD-20 is the complete verified boundary matrix. This concise catalog is
independently checked against current IDs, readers, source contracts, and the
full-inventory test. All actions are `readOnly` and confirmation-free.

| Action ID | Business category | Permission | Canonical boundary | Intended profiles |
| --- | --- | --- | --- | --- |
| `inventory_attention` | Inventory exception attention | No caller permission contract | `InventoryAttentionService.loadAttention()` | Inventory-focused; limited operational |
| `financial_account_balances` | Financial account balances | Active `canViewFinancialReports` | `FinancialReportService.accountBalanceReport(includeInactive: true)` | Full owner financial; financial reporting |
| `financial_account_statement` | One-account statement | Active `canViewFinancialReports` | `FinancialReportService.accountStatementReport(accountId:)` | Full owner financial; financial reporting |
| `financial_payment_method_summary` | Payment-method aggregate | Active `canViewFinancialReports` | `FinancialReportService.paymentMethodReport()` | Full owner financial; financial reporting |
| `financial_transfer_summary` | Transfer register | Active `canViewFinancialReports` | `FinancialReportService.transferReport()` | Full owner financial; financial reporting |
| `financial_advances_and_refunds_summary` | Governed advances/refunds | Active `canViewFinancialReports` | `FinancialReportService.getAdvancesAndRefundsReport()` | Full owner financial; financial reporting |
| `financial_closing_reconciliation_summary` | Closing/reopening history | Active owner | `FinancialReportService.closingReconciliationReport()` | Full owner financial; owner-only financial reporting |
| `financial_inflows_summary` | Inflow report | Active `canViewFinancialReports` | `FinancialReportService.inflowsReport()` | Full owner financial; financial reporting |
| `financial_outflows_summary` | Outflow report | Active `canViewFinancialReports` | `FinancialReportService.outflowsReport()` | Full owner financial; financial reporting |
| `financial_expense_analysis` | Expense analysis | Active `canViewFinancialReports` | `FinancialReportService.expenseAnalysisReport(...)` | Full owner financial; financial reporting |
| `financial_customer_collections_by_account` | Customer collections by account/period | Active `canViewFinancialReports` | `CustomerCollectionsByFinancialAccountReportService.customerCollectionsByFinancialAccountReport(...)` | Full owner financial; financial reporting |
| `financial_supplier_payments_by_account` | Supplier payments by account/period | Active `canViewFinancialReports` | `SupplierPaymentsByFinancialAccountReportService.supplierPaymentsByFinancialAccountReport(...)` | Full owner financial; financial reporting |

The two account-and-period actions require `financialAccountId`, inclusive
`startDate` and `endDate`, and accept optional party IDs. Expense analysis has
only optional account, payment-method, and category inputs. The statement has
required `financialAccountId`; the remaining present actions have no inputs.

## 19. Open questions and non-blocking gaps

| Gap | Classification | Disposition |
| --- | --- | --- |
| Older architecture note says controller/composition-root while current tools use readers and no production root exists | Documentation gap | Update only in a separately authorized documentation reconciliation if needed |
| No centralized human-readable catalog beyond Build Week matrices and source metadata | Future architecture decision | A catalog may be proposed, but must remain non-runtime unless separately authorized |
| No approved production caller profiles or production composition root | No action required | This is consistent with caller ownership; profiles remain conceptual |
| Confirmation and permission are not uniform `AiTool` metadata fields | Future architecture decision | Do not invent metadata/annotations in BUILD-21 |
| Full-inventory fixture is intentionally tied to 12 IDs and will require deliberate maintenance | Documentation gap | Update only through the future action authorization gate |
| Similar `summary` names can create discoverability friction | Documentation gap | Use the catalog and overlap review; do not add aliases or duplicate actions |
| Potential future transaction-by-account report lacks allocation-aware boundary | Blocked pending owner decision | Needs separate domain-only authorization and Split Payments review |

## 20. Build Week closure recommendation

### Preferred default

Close the current AI Build Week track after BUILD-21. The stable final
baseline is BUILD-21 on top of BUILD-20 with the verified twelve stable
actions, documented canonical boundaries, caller-owned composition, and the
authorization gates frozen here. No additional AI action is justified by the
current evidence: remaining candidates are either covered, discoverability-only,
or require a new allocation-aware domain boundary.

The next owner decision, if any, should approve a separate workstream for a
material product-roadmap area—most notably Split Payments and its accounting
domain boundaries—rather than extend the AI track by default. Any future AI
proposal must start again at the eight authorization gates above.

BUILD-22 is not authorized by BUILD-21. A separate owner decision is required before any implementation or additional AI action.
