# Phase 108O — Governance Reconciliation and Canonical Scope

## 1. Purpose

This artifact reconciles the conflicting historical uses of the ordinal
`Phase 108O` and establishes one repository-backed canonical meaning for the
new Phase 108O. It preserves the historical evidence, supersedes its ordinal
authority, and authorizes no planning or implementation.

```text
SESSION = PHASE_108O_GOVERNANCE_RECONCILIATION
MODE = FORENSIC_GOVERNANCE_RECONCILIATION_ONLY

HISTORICAL_108O_DISPOSITION = SUPERSEDED

PHASE_108O_CANONICAL_SCOPE =
ONE_LOCAL_READ_ONLY_PRINTABLE_DOCUMENT_SCAFFOLD_LOGO_UI_QUERY_MIGRATION_THROUGH_EXISTING_APPLICATION_BOUNDARY
```

The completed scope-discovery result supplied to this session is a governance
input. No Phase 108O scope-discovery report exists as a file on the governing
branch, so the conclusions below are recovered from the authorized session
record and independently checked against current Git, documents, source, and
tests where repository evidence exists.

```text
PASS_PHASE_108O_SCOPE_DISCOVERY
PHASE_108O_SCOPE_DISCOVERY = COMPLETE
HISTORICAL_108O_DISPOSITION = SUPERSEDED
SETTINGS_LOGO_SCOPE = FUNCTIONALLY_COMPLETED_UNDER_PHASE_108N
INVOICE_CONTRACT_INTENT = DEFERRED_AS_UNNUMBERED_FUTURE_WORK
OLD_108O_SCOPE_REUSE = FORBIDDEN
```

## 2. Governing baseline

The repository entry gate was verified before this document was created.
`git fetch origin --prune --tags` then completed successfully, and the critical
branch comparison remained unchanged.

```text
ROOT = C:/dev/multi-pos/grain-warehouse-erp-lite
BRANCH = codex/phase-108h-app-shell-runtime-ownership-boundary
REMOTE_NAME = origin
FETCH_URL = https://github.com/sabere342-ai/grain-warehouse-erp-lite.git
PUSH_URL = https://github.com/sabere342-ai/grain-warehouse-erp-lite.git

ENTRY_HEAD = e8e27d4ef4ab960e6bdb53bd19f1e27907587d6e
ENTRY_REMOTE_HEAD = e8e27d4ef4ab960e6bdb53bd19f1e27907587d6e
ENTRY_AHEAD = 0
ENTRY_BEHIND = 0
ENTRY_WORKTREE = CLEAN
ENTRY_INDEX = EMPTY
ENTRY_UNTRACKED = NONE
ENTRY_STASH = EMPTY
RECOVERY_CLASSIFICATION = CASE_A_FRESH_GOVERNANCE_RECONCILIATION
```

No existing Phase 108O governance reconciliation commit or current
`phase-108o-governance-reconciliation-locked` tag was present. No reset,
clean, rebase, merge, cherry-pick, branch deletion, history rewrite, or remote
mutation was used.

## 3. Phase 108N locked lineage

The current Phase 108O definition is anchored to the officially locked Phase
108N lineage. All three local refs are annotated tags. The local tag objects,
local peeled commits, remote tag objects, and remote peeled commits are equal.

| Lock | Annotated tag | Tag object | Peeled commit | Local/remote |
|---|---|---|---|---|
| Governance | `phase-108n-governance-reconciliation-locked` | `c02f308c660b352a53b13118e96ce42dff733655` | `f1f7cb8abd21323f1172074d6088caa905732070` | MATCH |
| Planning | `phase-108n-planning-baseline-locked` | `64522963ad1ac69d5da4fa1efe245eb54f180009` | `cdef1249c9b50181b87bb01412e793528b6819f2` | MATCH |
| Implementation | `phase-108n-implementation-locked` | `8b5c467baa2be473cb4a7ee74396cd8eba739293` | `e8e27d4ef4ab960e6bdb53bd19f1e27907587d6e` | MATCH |

Git parentage proves a direct, one-parent chain:

```text
232adb4d29104f54e873a743b023d87f5a49ca29
  Phase 108N: discover and freeze canonical scope
→ f1f7cb8abd21323f1172074d6088caa905732070
  Phase 108N: reconcile governance remote-lock marker
→ cdef1249c9b50181b87bb01412e793528b6819f2
  Phase 108N: plan settings logo preview query migration
→ e8e27d4ef4ab960e6bdb53bd19f1e27907587d6e
  Phase 108N: migrate settings logo preview query
```

The current HEAD is the locked Phase 108N implementation commit. The Phase
108N scope-discovery and plan artifacts are:

- `docs/phase-108n/PHASE-108N-SCOPE-DISCOVERY.md`;
- `docs/phase-108n/PHASE-108N-PLAN.md`.

Together with the implementation diff, they prove that the Settings logo
preview migration is accepted current history rather than pending Phase 108O
work.

## 4. Historical Phase 108O collision

Repository evidence contains two conflicting historical meanings of `108O`:

1. an invoice data, numbering, and version contract in the Phase 108A roadmap;
2. a Settings logo-preview application-query migration in a divergent local
   lineage.

Neither retains current ordinal authority. Supersession records the conflict
without deleting, rewriting, merging, or reviving either source.

```text
HISTORICAL_108O_DISPOSITION = SUPERSEDED
```

## 5. Historical invoice-contract disposition

`docs/phase-108a/PHASE-108A-COMPREHENSIVE-REAUDIT-AND-REORDERED-ROADMAP.md`
assigned:

```text
Phase ID: 108O
Title: Invoice Data, Numbering and Version Contract
```

That roadmap also depended on its own proposed cloud, Android, document, and
Settings sequence. The subsequently accepted and locked Phase 108F–108N
lineage reused those ordinals for different incremental application-boundary
work. Current locked Git lineage therefore outranks the roadmap's proposed
numbering.

```text
HISTORICAL_INVOICE_108O_ASSIGNMENT =
NON_GOVERNING_HISTORICAL_ROADMAP_INTENT

OLD_108O_INVOICE_ASSIGNMENT_AUTHORITY =
SUPERSEDED_AS_ORDINAL_ASSIGNMENT

INVOICE_CONTRACT_WORK = NOT_CANCELLED
INVOICE_CONTRACT_INTENT = DEFERRED_AS_UNNUMBERED_FUTURE_WORK
INVOICE_CONTRACT_WORK_IS_NOT_CURRENT_PHASE_108O = TRUE
```

The roadmap remains unchanged and inspectable. A later governance decision may
number and scope the preserved invoice-contract intent, but it may not inherit
the old `108O` assignment implicitly.

## 6. Historical settings-logo disposition

The divergent lineage is present locally and was inspected without switching,
merging, cherry-picking, rebasing, deleting, or pushing it.

```text
HISTORICAL_LOCAL_BRANCH =
codex/phase-108o-fifth-read-only-ui-query-migration

HISTORICAL_FREEZE_COMMIT =
6bb4e0a57fd1715c3216c6411a1d17d335568204

HISTORICAL_FREEZE_SUBJECT =
PHASE 108N: freeze fifth read-only UI query slice

HISTORICAL_IMPLEMENTATION_COMMIT =
a5c724652453a01c2185006228ce212624c509c2

HISTORICAL_IMPLEMENTATION_SUBJECT =
PHASE 108O: migrate Settings logo preview read to application query boundary

MERGE_BASE_WITH_CURRENT_HEAD =
deac34e7db2a5f6fd01f6fa7ff04020e308dfb6e

HISTORICAL_IMPLEMENTATION_IS_ANCESTOR_OF_CURRENT_HEAD = NO
```

The historical freeze proposed
`SettingsScreen._LogoPreview._loadLogoBytes()` as a future `108O` slice. Its
implementation commit changed that Settings read on the divergent branch. The
current locked Phase 108N lineage independently selected, planned, implemented,
and locked the same functional Settings seam at
`e8e27d4ef4ab960e6bdb53bd19f1e27907587d6e`.

Current source confirms that `SettingsScreen._LogoPreview` now executes
`ApplicationScope.of(context).queries.businessLogo` with
`LoadBusinessLogoQuery` and returns the query result value.

```text
HISTORICAL_SETTINGS_108O_LINEAGE = SUPERSEDED
HISTORICAL_SETTINGS_108O_LINEAGE = NON_GOVERNING
OLD_108O_SETTINGS_LINEAGE_AUTHORITY = SUPERSEDED
SETTINGS_LOGO_SCOPE = FUNCTIONALLY_COMPLETED_UNDER_PHASE_108N
SETTINGS_LOGO_SCOPE_MUST_NOT_BE_REOPENED_UNDER_PHASE_108O = TRUE
```

No commit, test, document, inventory count, or implementation result from the
divergent lineage is imported into current history by this reconciliation.

## 7. Authority hierarchy

Conflicts are resolved using this binding order:

1. Current Git HEAD, the authorized `origin` remote-tracking branch, and
   verified locked tags.
2. The current locked Phase 108N governance, planning, and implementation
   lineage.
3. `docs/phase-108n/PHASE-108N-SCOPE-DISCOVERY.md`.
4. `docs/phase-108n/PHASE-108N-PLAN.md` and the actual Phase 108N
   implementation.
5. Current production code and tests.
6. `docs/phase-108i/PHASE-108I-SECOND-READ-ONLY-UI-QUERY-MIGRATION-PLAN.md`,
   where divergent later-numbered local lineage is classified as
   non-authoritative.
7. Phase 108D architectural direction, accepted as broad direction and
   constrained by later phase re-partitioning.
8. Phase 108A and old ALIGN/LD/divergent branches as preserved historical
   evidence, not current ordinal authority.

Current locked Git evidence overrides a historical ordinal claim. Historical
evidence may explain intent but cannot silently reopen a completed scope or
rename itself into the current lifecycle.

## 8. Current architecture evidence

### 8.1 Remaining direct read

Current production source still contains exactly the relevant direct read in
`lib/features/prints/printable_document_scaffold.dart`:

```text
_PrintableLogo._loadBytes
→ AppRepositories.businessIdentityRepository.loadLogoBytes(managedFileName)
→ managed local logo file
```

The private loader returns null before any read for an empty managed filename,
catches failures and returns null, and performs no write. Its `FutureBuilder`
silently renders no widget for absent/null data. Existing successful rendering
uses `Image.memory`, maximum `60 x 200` constraints, `BoxFit.contain`, and a
silent image error builder. These are current facts, not implementation
instructions.

The shared scaffold serves printable sales and purchase invoices, customer and
supplier statements, and the daily activity report. That visibility explains
why earlier phases deferred the candidate even though the read itself is
atomic and read-only.

### 8.2 Existing reusable application boundary

Current production already contains:

- `LoadBusinessLogoQuery(managedFileName)`;
- `LoadBusinessLogoQueryHandler` with a captured
  `BusinessIdentityRepository`;
- `ApplicationQueries.businessLogo`;
- `ApplicationScope` above presentation;
- `ApplicationDependencies.repositories.businessIdentityRepository`; and
- `AppCompositionRoot` wiring the handler from that exact captured production
  dependency.

The existing handler preserves local managed-file authority and
current-known-state consistency, returns null without a repository call for an
empty filename, forwards a non-empty managed filename to the repository, and
returns the repository bytes/null value. It does not write.

```text
EXISTING_QUERY_CAN_REUSE = YES
EXISTING_HANDLER_CAN_REUSE = YES
NEW_QUERY_REQUIRED = NO
NEW_HANDLER_REQUIRED = NO
BOUNDARY_EXTENSION_REQUIRED = NO
NEW_DEPENDENCY_CAPTURE_REQUIRED = NO
EXACT_REPOSITORY_ALREADY_CAPTURED = YES
```

## 9. Accepted new Phase 108O canonical scope

```text
NEW_PHASE_108O_SCOPE =
PRINTABLE_DOCUMENT_SCAFFOLD_LOGO_QUERY_MIGRATION

PHASE_108O_CANONICAL_SCOPE =
ONE_LOCAL_READ_ONLY_PRINTABLE_DOCUMENT_SCAFFOLD_LOGO_UI_QUERY_MIGRATION_THROUGH_EXISTING_APPLICATION_BOUNDARY
```

Human-readable definition:

> Migrate the remaining direct business-logo read performed by the shared
> printable-document scaffold through the already-existing application query
> boundary, without changing logo persistence, writes, printable layout,
> document preview behavior, PDF export behavior, or any unrelated feature.

The intended architectural direction, subject to a separate remotely locked
planning session, is:

```text
CURRENT:
_PrintableLogo
→ AppRepositories.businessIdentityRepository.loadLogoBytes

FUTURE INTENT:
_PrintableLogo
→ ApplicationScope.queries.businessLogo
→ LoadBusinessLogoQueryHandler
→ captured BusinessIdentityRepository
```

This is a governance definition only. It does not select edit mechanics, test
files, inventory deltas, implementation order, or acceptance commands for a
future implementation.

## 10. Candidate-selection rationale

Repository history had already identified the printable scaffold logo read as
a valid, pure, high-atomicity candidate with exact reuse of the established
business-logo query. It was deferred while smaller Settings/header seams were
available. Those smaller seams are now completed in the locked current
lineage, and current source confirms that this direct printable read remains.

The completed Phase 108O scope discovery supplied these binding selection
results:

```text
ARE_THERE_STILL_GOOD_SMALL_READ_ONLY_UI_QUERY_MIGRATIONS = YES
MIGRATION_FAMILY_EXHAUSTED = NO

RANK_1 = C1_PRINTABLE_DOCUMENT_LOGO
RECOMMENDATION = ACCEPT

C2_DAILY_ACTIVITY_REPORT = DEFER
C3_DASHBOARD_GUIDANCE = DEFER
C4_OWNER_ALERTS = REJECT_AS_NEXT_SMALL_PHASE
```

The accepted candidate is one local, read-only presentation-to-managed-file
seam; it reuses an existing query, handler, dependency capture, and repository.
The deferred/rejected candidates involve broader report aggregation,
multi-repository consistency, lazy state, financial/inventory consequences, or
a larger contract surface. This ranking explains the governance identity; it
does not constitute Phase 108O planning.

## 11. Binding historical disposition

```text
HISTORICAL_108O_DISPOSITION = SUPERSEDED
OLD_108O_INVOICE_ASSIGNMENT_AUTHORITY = SUPERSEDED_AS_ORDINAL_ASSIGNMENT
OLD_108O_SETTINGS_LINEAGE_AUTHORITY = SUPERSEDED
INVOICE_CONTRACT_INTENT = PRESERVED_AS_UNNUMBERED_FUTURE_WORK
SETTINGS_LOGO_SCOPE = ALREADY_COMPLETED_UNDER_PHASE_108N
NEW_PHASE_108O_SCOPE = PRINTABLE_DOCUMENT_SCAFFOLD_LOGO_QUERY_MIGRATION
OLD_108O_SCOPE_REUSE = FORBIDDEN

SUPERSEDED != DELETED
SUPERSEDED != REWRITTEN
SUPERSEDED != MERGED
SUPERSEDED != CHERRY_PICKED
```

The old invoice designation and old Settings branch remain inspectable only as
historical evidence. Neither may supply current ordinal authority, current
implementation, or an implicit exception to the new negative scope.

## 12. Binding negative scope

The following prohibitions bind Phase 108O planning and implementation unless
a later explicit governance reconciliation supersedes them:

```text
NO_WRITE_PATH_CHANGES
NO_DATABASE_CHANGES
NO_SUPABASE_CHANGES
NO_DEPENDENCY_CHANGES
NO_NEW_REPOSITORY
NO_NEW_QUERY
NO_NEW_HANDLER
NO_NEW_RUNTIME_OWNER
NO_BOUNDARY_EXTENSION
NO_CROSS_FEATURE_REFACTOR
NO_APP_SHELL_REDESIGN
NO_ROUTING_CHANGES
NO_PRINTABLE_VISUAL_REDESIGN
NO_PDF_EXPORT_MIGRATION
NO_FINANCIAL_REPORT_BRANDING_MIGRATION
NO_BUSINESS_IDENTITY_PROFILE_MIGRATION
NO_SETTINGS_LOGO_PREVIEW_REIMPLEMENTATION
NO_LOGO_SAVE_CHANGE
NO_LOGO_DELETE_CHANGE
NO_NEW_PERSISTENCE
NO_BEHAVIOR_CHANGE
NO_UNRELATED_TEST_REWRITES
NO_HISTORY_REWRITE
NO_HISTORICAL_BRANCH_MERGE
NO_HISTORICAL_BRANCH_CHERRY_PICK
NO_HISTORICAL_BRANCH_REBASE
NO_HISTORICAL_BRANCH_DELETION
NO_PHASE_108O_IMPLEMENTATION
NO_PHASE_108O_PLANNING
```

This governance session also authorizes no mutation beneath `lib/`, `test/`,
`integration_test/`, platform directories, database/schema/migration paths,
`pubspec.yaml`, or `pubspec.lock`.

## 13. Planning authorization boundary

The required lifecycle is:

```text
SCOPE_DISCOVERY
→ GOVERNANCE_RECONCILIATION
→ GOVERNANCE_REMOTE_LOCK
→ PLANNING
→ PLANNING_REMOTE_LOCK
→ IMPLEMENTATION
→ IMPLEMENTATION_REMOTE_LOCK
```

This session may reach only
`PHASE_108O_GOVERNANCE_RECONCILIATION_LOCAL_CLOSURE`. Phase 108O planning is
not authorized until this governance commit is verified and remotely locked
in a separate `PHASE_108O_GOVERNANCE_REMOTE_LOCK` session.

```text
PHASE_108O_GOVERNANCE_REMOTE_LOCK = NOT_STARTED
PHASE_108O_PLANNING = NOT_STARTED
PHASE_108O_IMPLEMENTATION = NOT_STARTED
```

No `phase-108o-governance-reconciliation-locked` tag may be created locally or
remotely during this session.

## 14. Implementation prohibition

This artifact authorizes no production or test mutation and no preparatory
implementation work. In particular, it does not authorize changing
`_PrintableLogo`, adding a Phase 108O test, updating live architecture guards,
changing PDF/export behavior, or altering logo persistence. Those questions
belong only to later lifecycle stages after the required remote locks.

If future planning discovers that the frozen scope requires a new query,
handler, repository, dependency capture, boundary extension, runtime owner,
write change, visual change, or second feature migration, it must stop for
governance review rather than expand this definition implicitly.

## 15. Historical preservation rules

The following evidence remains untouched and inspectable:

- the Phase 108A roadmap and its historical invoice-contract assignment;
- divergent commits `6bb4e0a57fd1715c3216c6411a1d17d335568204`
  and `a5c724652453a01c2185006228ce212624c509c2`;
- local branches that contain the divergent lineage, including
  `codex/phase-108o-fifth-read-only-ui-query-migration`;
- the locked current Phase 108N documents, commits, tests, and tags; and
- the accepted current production source and test history.

Preservation does not make the divergent branch governing. No historical ref
may be merged, cherry-picked, rebased, deleted, retagged as current, or pushed
as part of this reconciliation.

## 16. Quality evidence classification

The following results are inherited from the completed Phase 108O scope
discovery session record. They are preserved as baseline evidence and are not
claimed as newly executed by this governance session:

```text
INHERITED_SCOPE_DISCOVERY_BASELINE

flutter analyze = PASS — No issues found
dart format --output=none --set-exit-if-changed lib test =
PASS — 461 files, 0 changed
FULL_SUITE_SEQUENTIAL = PASS — 2531 passed, 0 failed
git diff --check = PASS

PARALLEL FAILURE = ConnectionClosedException in Phase 8M
ISOLATED_TEST = PASS 1/1
PHASE_8M_FILE = PASS 9/9
FULL_SUITE_CONCURRENCY_1 = PASS 2531/2531
CLASSIFICATION = PARALLEL_TEST_RESOURCE_RACE_NOT_REPOSITORY_REGRESSION
```

Current-session Git, diff, and documentation checks are reported separately in
the final forensic report. No Flutter analyzer, formatter, or test execution is
required merely to validate this Markdown-only governance mutation, and none
may be represented as current-session execution unless actually rerun.

## 17. Governance closure markers

Local closure requires this document to be the only committed artifact, a
clean worktree and empty index after one normal documentation-only commit, no
tag creation, no remote mutation, and no production/test/dependency/database/
Supabase change.

```text
PASS_PHASE_108O_GOVERNANCE_LOCAL_READY

PHASE_108O_SCOPE_DISCOVERY = COMPLETE
PHASE_108O_GOVERNANCE_RECONCILIATION_LOCAL_CLOSURE = COMPLETE
PHASE_108O_GOVERNANCE_REMOTE_LOCK = NOT_STARTED
PHASE_108O_PLANNING = NOT_STARTED
PHASE_108O_IMPLEMENTATION = NOT_STARTED

PRODUCTION_CODE_CHANGED = NO
TEST_CODE_CHANGED = NO
DEPENDENCIES_CHANGED = NO
DATABASE_CHANGED = NO
SUPABASE_CHANGED = NO
REMOTE_MUTATION = NO
PHASE_108O_REMOTE_TAG_CREATED = NO

NEXT_AUTHORIZED_SESSION =
PHASE_108O_GOVERNANCE_REMOTE_LOCK
```
