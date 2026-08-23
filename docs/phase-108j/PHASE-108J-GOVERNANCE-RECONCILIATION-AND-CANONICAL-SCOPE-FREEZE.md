# Phase 108J — Governance Reconciliation and Canonical Scope Freeze

## 1. Status

This document is the additive, owner-directed governance reconciliation for the
Phase 108J identifier. It preserves the historical documents that disagreed,
records their disposition, and freezes only the scope identity that a later
planning session may plan. It is not a Phase 108J plan or implementation.

```text
PHASE_108J_GOVERNANCE_RECONCILIATION = COMPLETE
PHASE_108J_IMPLEMENTATION = NOT_STARTED
```

## 2. Repository / governing baseline

This reconciliation was prepared against the accepted Phase 108I baseline:

```text
REPOSITORY = C:/dev/multi-pos/grain-warehouse-erp-lite
BRANCH = codex/phase-108h-app-shell-runtime-ownership-boundary
BASELINE_COMMIT = 6896cbd73b271631cda9b31666ab200a6dcac76a
BASELINE_SUBJECT = Phase 108I: migrate second read-only UI query
BASELINE_PARENT = ca533e07dad7d36e2b17d0caa2c1740ee8fa9103
REMOTE = https://github.com/sabere342-ai/grain-warehouse-erp-lite.git
```

The accepted direct ancestry at that baseline is:

```text
db84293213d99a79b23bf25b81b565c380aa4655  Phase 108F
  -> 5c784d60e7879d18812893a9c9934856e680826e  Phase 108G
  -> f6ed0f8dc7fbb69c763115f4c66502b0d3dcb4c7  Phase 108H
  -> ca533e07dad7d36e2b17d0caa2c1740ee8fa9103  Phase 108I planning
  -> 6896cbd73b271631cda9b31666ab200a6dcac76a  Phase 108I implementation
```

The annotated Phase 108F, 108G, 108H, 108I-planning, and 108I-implementation
locks were verified without moving or recreating any tag. This artifact adds a
governance decision after that immutable baseline; it does not change the
meaning or contents of any accepted historical commit.

## 3. Problem statement

Accepted repository documents contain incompatible definitions of Phase 108J:

1. Phase 108A defines 108J as one atomic, idempotent, server-authoritative
   financial command slice, with expense posting as the candidate.
2. The Phase 108D main contract assigns purchase, expense, customer payment,
   supplier payment, and advance command families collectively to 108J.
3. Rows 7 and 9 of the Phase 108D architectural-violations register separately
   assign UnitOfWork/durable-outbox and durable pending-command lifecycle work
   to 108J.
4. The accepted Phase 108E–108I sequence evolved differently from both older
   numbered roadmaps.
5. A rejected divergent commit assigned a third read-only query migration to
   108J; that history is not authority.

Without an explicit precedence decision, a later 108J planning session could
select materially different work while citing an accepted source. This
document resolves that ambiguity without rewriting the historical sources.

## 4. Accepted authority sources

The authority order for the Phase 108J identifier is:

1. Owner decision
   `PHASE_108J_SCOPE_RECONCILIATION_DECISION_001` recorded in this artifact.
2. The Phase 108A Phase 108J entry in
   `docs/phase-108a/PHASE-108A-COMPREHENSIVE-REAUDIT-AND-REORDERED-ROADMAP.md`,
   reaffirmed by that owner decision.
3. This reconciliation artifact as the explicit precedence and disposition
   record.
4. Older accepted sources as historical evidence only where they conflict with
   the owner decision or this reconciliation.

The Phase 108D contract and register remain authoritative evidence of
architectural concerns and of what was recommended at that time. They are not
authoritative for the Phase 108J identifier where this artifact expressly
supersedes their numbering assignment.

```text
PHASE_108J_CANONICAL_AUTHORITY =
PHASE_108A_PHASE_108J_DEFINITION_AS_REAFFIRMED_BY_OWNER_DECISION
```

## 5. Governance conflict

The original Phase 108A entry says:

- title: `Server-Authoritative Financial Command Contract`;
- goal: implement one atomic idempotent command slice end to end;
- candidate: expense posting;
- scope: server transaction, idempotency/fingerprint/result, audit, and local
  committed-state projection;
- explicit non-goals: all financial flows and generic synchronization magic.

The later Phase 108D main contract instead recommends one Phase 108J covering
multiple command families. Its register also gives the 108J number to two
durable-outbox concerns. Those are real, recorded conflicts, not editorial
variants of the same scope.

The accepted Phase 108E–108I work then evolved incrementally around application
boundaries and read ownership rather than following either old identifier map
literally. Completion of those accepted phases cannot be used to pretend that
the semantic work attached to the old maps was completed under the same
numbers.

## 6. Owner decision

The owner decision is final for this reconciliation and is not reopened here:

```text
OWNER_DECISION_ID = PHASE_108J_SCOPE_RECONCILIATION_DECISION_001
OWNER_DECISION = PHASE_108A_DEFINITION_IS_CANONICAL_FOR_PHASE_108J
CANONICAL_PHASE_108J_SOURCE =
docs/phase-108a/PHASE-108A-COMPREHENSIVE-REAUDIT-AND-REORDERED-ROADMAP.md
CANONICAL_PHASE_108J_SCOPE =
ONE_ATOMIC_IDEMPOTENT_SERVER_AUTHORITATIVE_FINANCIAL_COMMAND_SLICE
PREFERRED_CANDIDATE = EXPENSE_POSTING
PHASE_108D_108J_DEFINITION = SUPERSEDED_AS_PHASE_108J_IDENTIFIER
PHASE_108D_REGISTER_ROWS_7_AND_9 = NOT_AUTHORITATIVE_FOR_PHASE_108J_IDENTIFIER
PHASE_108J_PLANNING = NOT_PART_OF_THIS_RECONCILIATION
PHASE_108J_IMPLEMENTATION = NOT_PART_OF_THIS_RECONCILIATION
```

This decision selects a canonical identifier and scope. It does not decide an
RPC shape, schema, migration, ledger redesign, synchronization system, or exact
implementation design.

## 7. Canonical Phase 108J definition

```text
PHASE_ID = 108J
PHASE_108J_CANONICAL_SCOPE =
ONE_ATOMIC_IDEMPOTENT_SERVER_AUTHORITATIVE_FINANCIAL_COMMAND_SLICE
PHASE_108J_DEFAULT_CANDIDATE = EXPENSE_POSTING
PHASE_108J_CANONICAL_SCOPE = FROZEN
```

The eventual Phase 108J planning session may plan exactly one small vertical
financial-command slice. Expense posting is the default candidate, subject to
the prerequisite audit in Section 10; changing the candidate would require an
explicit, governance-compatible justification within planning and must still
preserve the one-slice boundary.

Where applicable and verified in planning, the slice must address:

- one server-authoritative financial mutation;
- one atomic server transaction boundary;
- idempotency, request fingerprinting, and durable-result or equivalent
  replay-safe behavior;
- audit behavior;
- local projection/cache consequences;
- a remote adapter/function boundary;
- authorization and RLS implications;
- retry and replay behavior;
- rollback and failure behavior;
- focused verification.

These are semantic planning obligations, not frozen implementation choices.

```text
ALL_FINANCIAL_FLOWS_IN_ONE_PHASE = FORBIDDEN
GENERIC_SYNC_SYSTEM = OUT_OF_SCOPE
MULTIPLE_UNRELATED_FINANCIAL_COMMAND_FAMILIES = OUT_OF_SCOPE
EXACT_IMPLEMENTATION_DESIGN = NOT_FROZEN
```

## 8. Superseded / remapped definitions

The Phase 108D main-contract recommendation that grouped purchase commands,
expense commands, customer payments, supplier payments, and advances under
Phase 108J is superseded only as an assignment of the **108J identifier**.

```text
PHASE_108D_MAIN_108J_ASSIGNMENT =
SUPERSEDED_AS_PHASE_108J_IDENTIFIER
VALID_FUTURE_WORK = YES
FIXED_FUTURE_PHASE_NUMBER = NO
REQUIRES_FUTURE_SCOPE_DISCOVERY = YES
```

The underlying work is neither rejected nor silently renumbered. This
reconciliation does not create 108K, 108L, or any other new assignment for it.
Any future phase identity requires separate scope discovery and authorization.

## 9. Treatment of Phase 108D register rows 7/9

Rows 7 and 9 of
`docs/phase-108d/evidence/architectural-violations.tsv` respectively record:

- `V0-06`: a UnitOfWork boundary and durable outbox in response to the current
  repository snapshot/rollback mechanism;
- `V0-08`: durable outbox and lifecycle persistence in response to the absence
  of a durable pending-command store.

Their architectural concerns remain preserved unless later evidence shows that
they were completed or superseded. Their Phase 108J numbering does not remain
authoritative.

```text
PHASE_108D_REGISTER_ROWS_7_9_PHASE_108J_ASSIGNMENT =
SUPERSEDED_AS_PHASE_108J_IDENTIFIER
VALID_ARCHITECTURAL_CONCERNS =
PRESERVED_UNLESS_ALREADY_COMPLETED_OR_SUPERSEDED
PHASE_108J_ASSIGNMENT = SUPERSEDED
NEW_PHASE_ASSIGNMENT = UNRESOLVED_AND_OUT_OF_SCOPE
```

No generic outbox implementation is authorized by this document. Planning may
consider only a minimal enabler if the prerequisite audit proves it necessary
and it remains inside the single atomic Phase 108J slice.

## 10. Treatment of original semantic prerequisites

The Phase 108A 108J entry named dependencies on its then-defined 108H–108I and
on closure of `FIN-001`. The eventual accepted phases bearing the numbers 108H
and 108I performed different work. Numeric completion is therefore not proof
of semantic prerequisite completion.

```text
NUMERIC_PREDECESSOR_PHASES_108H_AND_108I = COMPLETE
ORIGINAL_108A_SEMANTIC_PREREQUISITES_FOR_108J =
NOT_PROVEN_COMPLETE_BY_PHASE_NUMBER_ALONE
ORIGINAL_PHASE_108A_108H_108I_SEMANTIC_PREREQUISITES =
REQUIRE_REVALIDATION_DURING_PHASE_108J_PLANNING
```

The Phase 108J planning session must begin with a current-code, test, and
configuration prerequisite audit. It must include `FIN-001` and every semantic
dependency actually required by the proposed one-slice design. It must not
infer Supabase auth/RLS, cloud catalog reads, an outbox, sale-command migration,
RPC infrastructure, or any other capability from phase numbers alone.

Planning must reach exactly one evidence-backed result:

```text
A. PREREQUISITES_SATISFIED_BY_CURRENT_ARCHITECTURE

B. MISSING_PREREQUISITE_MUST_BE_INCLUDED_AS_MINIMAL_ENABLER
   only if the result remains one atomic governance-compatible 108J slice

C. PHASE_108J_PLANNING_BLOCKED_BY_MISSING_PREREQUISITE
```

This reconciliation neither performs that audit nor implements a missing
prerequisite.

## 11. Preservation of actual Phase 108E–108I history

The accepted sequence is preserved on its own terms:

| Phase | Accepted work |
|---|---|
| 108E | Application boundary and central composition-root work |
| 108F | Audit-log read-only UI query migration |
| 108G | Session and business-context boundary |
| 108H | App-shell runtime ownership boundary |
| 108I | Second read-only UI query migration for document history |

In the accepted Phase 108I path,
`DocumentHistoryScreen -> ApplicationScope.of(context).queries.documentHistory
-> LoadDocumentHistoryQueryHandler -> shared DocumentHistoryRepository`.
That implementation is evidence of the actual Phase 108I scope; it does not
redefine Phase 108J as a third query migration.

These phases are not characterized as mistakes. This reconciliation resolves
only the future use of the 108J identifier and leaves their commits, tags,
documents, code, and acceptance evidence unchanged.

## 12. Authorized next session

The next authorized **phase-content** session is planning only:

```text
NEXT_AUTHORIZED_SESSION = PHASE_108J_PLANNING
```

That planning session must begin with the prerequisite audit in Section 10 and
must not perform implementation. The local reconciliation commit must first be
handled by the separately authorized governance remote-lock workflow; this
document itself does not authorize pushing, tagging, deployment, planning, or
implementation during the reconciliation session.

```text
IMMEDIATE_POST_RECONCILIATION_WORKFLOW =
PHASE_108J_GOVERNANCE_RECONCILIATION_REMOTE_LOCK
```

## 13. Explicitly forbidden interpretations

This artifact must not be interpreted as authority to:

- implement Phase 108J;
- plan or migrate all financial commands together;
- build a generic synchronization or outbox system;
- select exact RPC APIs, database schemas, RLS policy sets, migration strategy,
  ledger redesign, or cross-entity offline-conflict strategy;
- migrate purchase, sale, payment, advance, or a third read-only query family;
- claim that Supabase, RLS, cloud reads, RPCs, durable outbox, or any semantic
  prerequisite exists without current repository evidence;
- assign superseded work to a newly invented phase number;
- treat rejected or divergent history as governance authority;
- merge, cherry-pick, copy, or otherwise revive the rejected 108J query scope.

## 14. Governance invariants

1. The owner decision and the reaffirmed Phase 108A 108J definition control the
   Phase 108J identifier.
2. Historical disagreement remains visible in the original sources and in this
   record.
3. Accepted Phase 108E–108I history remains immutable and valid.
4. Phase numbers do not prove completion of differently defined semantic work.
5. Phase 108J remains one atomic financial-command slice.
6. Expense posting remains the default candidate, not an implementation
   authorization.
7. Broad Phase 108D command work and register rows 7/9 retain no fixed new phase
   number.
8. Rejected histories remain isolated.
9. No source, test, schema, migration, dependency, generated database, platform,
   or Supabase change belongs to this reconciliation.
10. Remote locking and Phase 108J planning require separate sessions.

## 15. Evidence references

Primary repository evidence:

- `docs/phase-108a/PHASE-108A-COMPREHENSIVE-REAUDIT-AND-REORDERED-ROADMAP.md`,
  Phase 108J entry, lines 533–543 at the accepted baseline;
- `docs/phase-108d/PHASE-108D-APPLICATION-COMMAND-QUERY-BOUNDARY-AND-COMPOSITION-ROOT-CONTRACT-FREEZE.md`,
  migration dependency graph and recommended atomic follow-up phases;
- `docs/phase-108d/evidence/architectural-violations.tsv`, rows 7 and 9
  (`V0-06` and `V0-08`);
- `docs/phase-108e/PHASE-108E-APPLICATION-BOUNDARY-AND-CENTRAL-COMPOSITION-ROOT.md`;
- `docs/phase-108f/PHASE-108F-FIRST-READ-ONLY-UI-QUERY-MIGRATION.md`;
- `docs/phase-108i/PHASE-108I-SECOND-READ-ONLY-UI-QUERY-MIGRATION-PLAN.md`;
- `MASTER-PROJECT-EXECUTION-PLAN-AR.md`;
- `docs/NEXT-PHASE-DECISION-GATE.md`.

Lock evidence verified for this reconciliation:

| Lock | Annotated tag object | Peeled commit |
|---|---|---|
| Phase 108F | `df5b895ea266384084f0fbec4b97b510cec5dcb5` | `db84293213d99a79b23bf25b81b565c380aa4655` |
| Phase 108G | `54947c27c348c30b66ff2c02584eb6027cf9a325` | `5c784d60e7879d18812893a9c9934856e680826e` |
| Phase 108H | `6bd7e338dd9fd64ddfea8845faffbe9102ec09f1` | `f6ed0f8dc7fbb69c763115f4c66502b0d3dcb4c7` |
| Phase 108I planning | `74164b8e342f2ebc372c3429fe2862b7af254c89` | `ca533e07dad7d36e2b17d0caa2c1740ee8fa9103` |
| Phase 108I implementation | `182afda332b3c427b09a04f2652fb606d826e30f` | `6896cbd73b271631cda9b31666ab200a6dcac76a` |

Rejected/divergent evidence remains non-authoritative:

- `56921729ea927ee7ff45ca67d774847e65c5d499`;
- `d61cf78ca9573d42ae4cc40219489a1c6c651bb3`;
- `3b871e4c8836b3a40026c9945bc763f521155143`,
  `PHASE 108J: freeze third read-only UI query migration candidate`.

The generic `docs/NEXT-PHASE-DECISION-GATE.md` records pilot evidence rules and
does not assign a Phase 108J scope. It therefore required no historical rewrite
or pointer edit for this narrowly scoped reconciliation.

## 16. Closure declaration

The conflict is reconciled by explicit owner authority while preserving the
truth of every older accepted definition and the actual Phase 108E–108I
evolution. Phase 108J now has one deterministic canonical scope for a later
planning session; no implementation has started and no superseded work has
been silently renumbered.

```text
PHASE_108J_GOVERNANCE_RECONCILIATION = COMPLETE
PHASE_108J_CANONICAL_AUTHORITY = PHASE_108A_PHASE_108J_DEFINITION_AS_REAFFIRMED_BY_OWNER_DECISION
PHASE_108J_CANONICAL_SCOPE = ONE_ATOMIC_IDEMPOTENT_SERVER_AUTHORITATIVE_FINANCIAL_COMMAND_SLICE
PHASE_108J_DEFAULT_CANDIDATE = EXPENSE_POSTING
PHASE_108D_MAIN_108J_ASSIGNMENT = SUPERSEDED_AS_PHASE_108J_IDENTIFIER
PHASE_108D_REGISTER_ROWS_7_9_PHASE_108J_ASSIGNMENT = SUPERSEDED_AS_PHASE_108J_IDENTIFIER
ORIGINAL_PHASE_108A_108H_108I_SEMANTIC_PREREQUISITES = REQUIRE_REVALIDATION_DURING_PHASE_108J_PLANNING
PHASE_108J_IMPLEMENTATION = NOT_STARTED
NEXT_AUTHORIZED_SESSION = PHASE_108J_PLANNING
```
