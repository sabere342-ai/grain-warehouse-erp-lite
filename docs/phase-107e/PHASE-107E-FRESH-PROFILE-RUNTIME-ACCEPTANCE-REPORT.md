# Phase 107E — Fresh-Profile Runtime Acceptance

## Final outcome

**Outcome A — FULL SUCCESS**

The exact governed Phase 107D Windows installer was installed and exercised
end-to-end under a genuinely new Windows user profile. First-owner bootstrap,
main-runtime navigation, clean shutdown, second launch, authentication, and
persisted state all passed. The accepted runtime did not use the source tree or
the developer toolchain.

**Closure decision: R1-004 CLOSED.** R1-005 and R1-006 remain open and
unchanged. No R2 or R3 item is changed by this phase.

## Baseline and canonical run

| Item | Result |
| --- | --- |
| Baseline | `d2103102f68ff7dbc1dec3ca5fc4b02d054be912` |
| Baseline subject | `PHASE 107D: govern Windows release package` |
| Branch | `codex/phase-107e-fresh-profile-runtime-acceptance` |
| Entry tree | Clean before branch creation |
| Canonical run ID | `20260809-204702` |
| Run date | 2026-08-09 |

An earlier launcher attempt (`20260809-200046`) was explicitly invalidated
because it inherited the interactive developer environment. Its process was
closed, the test account and profile were removed, and the account/profile were
created again before the canonical run. The sanitized failed-attempt record is
retained as `evidence/00-invalid-attempt.json`; it is not acceptance evidence.

## Fresh-profile identity and start state

| Item | Proven result |
| --- | --- |
| Windows user | `CodexGhalal107E` |
| SID | `S-1-5-21-2052787611-3211508837-1074070108-1032` |
| Profile path | `C:\Users\CodexGhalal107E` |
| Profile before user creation | Absent |
| Profile before initialization | Absent |
| Prior app data/database/preferences/backups | Absent |
| Prior install directory/registration/shortcuts/process | Absent |

This is an independent Windows account and profile, not a cleanup of the
developer profile. The pre-install snapshot is machine-readable in
`evidence/02-fresh-profile-prestate.json`.

## Frozen installer identity

| Item | Result |
| --- | --- |
| Artifact | `delivery/phase-107d/GrainWarehouseERP-1.0.0-windows-x64.exe` |
| Size | 14,998,748 bytes |
| SHA-256 | `ab67d04e205a78aa2d6e087ffd6f63655a80e5e2de10d7a603f959b073098659` |
| Manifest SHA-256 | `0377d97fd963edb09ea6257569725a04764fe52ba1ef82a6fcf4b52fe8a35dab` |
| Identity decision | Exact match with the accepted Phase 107D artifact |

The installer was not rebuilt or replaced. Its hash remained exact after all
107E source-build and regression work.

## Installation

The frozen installer was copied without mutation to a public staging directory
and executed under the fresh-user token. It exited `0` and installed to:

`C:\Users\CodexGhalal107E\AppData\Local\Programs\GrainWarehouseERPLite`

The installed executable was present with SHA-256
`54d80420979ca717c7969f46a43bbe8f14e7d41dfb89506ea6660c24a17f5826`.
The installed manifest matched the frozen manifest hash. The HKCU uninstall
registration and Start Menu shortcut were present. Final payload verification
matched all 21 declared files, with no mismatch and no undeclared extra file.

## First launch and fresh-state route

Source inspection established the canonical route: `AuthGate` sends a database
with no owner to `FirstOwnerSetupScreen`; successful `createFirstOwner` creates
and signs in the new owner.

The installed executable started as PID `10056` under the fresh user, from the
non-repository working directory
`C:\Users\Public\Documents\GralaPhase107E\runtime-cwd`. It produced a visible
top-level window titled `غلال`, did not exit immediately, and displayed the
first-owner setup route exactly as the source contract required. No startup
exception, crash dialog, or fatal exit was observed.

## Initial setup and authentication

The reachable setup form was completed with deterministic synthetic identity
data (`Phase 107E Owner`, phone `01070000107`). The password was generated at
runtime, never printed or committed, and the runtime-only credential material
and clipboard contents were cleared after use.

Creating the owner succeeded and navigated directly to the dashboard. No
exception, duplicate-bootstrap issue, freeze, or UI dead end occurred.

## Basic runtime smoke

From the installed runtime, the following areas opened without crash:

- Dashboard
- Products
- Inventory
- Sales
- Settings

This was deliberately navigation-only acceptance for R1-004. It does not claim
genuine-client scenario acceptance under R1-005 or client-document correctness
under R1-006.

## Clean exit, second launch, and persistence

The first window was closed using its top-level Close control; PID `10056` was
gone afterward. The fresh profile then contained the SQLite database and its
WAL/SHM companion files at:

`C:\Users\CodexGhalal107E\AppData\Roaming\Grala\Grala\grain_warehouse_erp.sqlite3`

The main database was 4,096 bytes with SHA-256
`6725e9c2f4d09abc3d8bd9d916bfc8012b91ef682f8ad5ecf54591ac7c4572df`.
The WAL SHA-256 was
`b26f7497b884c0592e4ba4fabb6fe03c824fbd84db824c3923dc21b58b0a1ef3`.

The same installed executable then started as PID `21676`. It correctly showed
the login route rather than repeating owner setup. Authentication with the
runtime-only credential succeeded and reached the dashboard. The second clean
close left no app process. The database and WAL hashes remained stable; the SHM
file changed as expected for transient SQLite shared-memory state. No manual
database edit was performed.

The observed application-support path is `%APPDATA%\Grala\Grala`, derived from
the packaged Windows metadata at runtime. It is scoped to the fresh user and is
outside the repository, build tree, developer profile, and machine-global data.

## Environment independence

Both launches used the executable under the fresh user's installed-programs
directory, not `flutter run`, a build-tree executable, or a source checkout.
The effective `APPDATA` and `LOCALAPPDATA` belonged to `CodexGhalal107E`; the
working directory was outside the repository. The worker used a controlled
fresh-user environment rather than inherited developer variables. No Flutter
SDK, Dart SDK, Visual Studio, developer PUB cache, developer home, repo-relative
asset, or absolute developer path was needed by the installed runtime.

## Verification

| Gate | Final result |
| --- | --- |
| `dart format --output=none --set-exit-if-changed .` | PASS — 422 files, 0 changed |
| `flutter analyze` | PASS — no issues |
| `flutter test` | PASS — 2381 passed, 1 skipped, 0 failed |
| `flutter build windows --release` | PASS — release executable built |
| Phase 107C checksum/restore | PASS — 6/6 |
| Phase 107D D1–D10 | PASS — 21 payload files, 45,895,436 bytes |
| Phase 107D negative controls | PASS — all three tamper cases rejected |
| Phase 106AJ/AK/AL/AM lineage guards | PASS — 35/35 |
| Phase 107E verifier | PASS — E1–E19 |
| `git diff --check` | PASS |

The first sandbox-constrained release-build invocation timed out without a
compiler result and left no build process. The approved unrestricted rerun
completed in 64.8 seconds (57.3 seconds build time) and exited `0`. The CMake
deprecation and LNK4078 messages were non-fatal warnings from the established
build graph.

Four historical lineage tests were mechanically extended to recognize the
exact Phase 107E branch. One `anyOf` invocation was converted to its equivalent
list overload because the matcher supports at most seven positional arguments.
No accepted branch was removed and no assertion was weakened.

## Scope

| Scope | Diff |
| --- | --- |
| Production (`lib/`, Windows runner, packaging) | Zero |
| Database schema/migrations | Zero |
| Dependencies/lockfiles | Zero |
| UI/behavior | Zero |
| Tests | Four lineage allow-list additions only |
| Phase deliverables | Deterministic harness, verifier, report, JSON/text evidence, and screenshots |

## Git result

The final repository state is designed and verified as one commit with subject
`PHASE 107E: accept fresh-profile installed runtime`, whose parent is
`d2103102f68ff7dbc1dec3ca5fc4b02d054be912`. At delivery, `HEAD` is that single
commit, the working tree is clean, and `git diff --check` passes. No push, tag,
merge, or rebase was performed.

## Risk register

| Severity | Before | After |
| --- | ---: | ---: |
| R0 | 0 | 0 |
| R1 | 3 | 2 |
| R2 | 7 | 7 |
| R3 | 7 | 7 |

The only risk transition is **R1-004: OPEN → CLOSED**. R1-005 (genuine client
acceptance) and R1-006 (client documentation) remain open and unchanged.

## Recommended next atomic phase

**Phase 107F — Genuine Client Acceptance (R1-005 only):** execute scenarios A–H
with a genuine user and record an explicit commercial acceptance decision. Do
not combine it with R1-006 documentation corrections. This recommendation is
not implemented in Phase 107E.
