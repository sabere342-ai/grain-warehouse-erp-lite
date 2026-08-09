# Phase 107G — 14-Day Local Trial Enforcement

## Final Outcome

**Outcome A — FULL SUCCESS**

The application now enforces a local 14-day trial from first successful runtime, blocks all application routes at exact expiry or after clock rollback/corrupt metadata, and preserves all customer business data.

## Baseline

`7b4da07e1e58d6cafa47e51c05cf15e4bfaac6d8`

The starting tree was clean, the subject was `PHASE 107F: govern client backup and data-path documentation`, and 107E was an ancestor. Work proceeded on `codex/phase-107g-14-day-local-trial-enforcement`.

## Trial Contract

```text
Duration: 14 × 24 hours (Duration(days: 14))
Start rule: first trial evaluation after successful infrastructure initialization and immediately before runApp
Expiry rule: active when now < start + 14d; expired when now >= start + 14d
UTC: all stored and evaluated timestamps
Rollback tolerance: Duration.zero
Tamper policy: detected rollback is persistent/sticky
Expiry policy: first-observed expiry is persistent/sticky
Invalid-state policy: fail closed to controlled Arabic UI; never create a replacement trial
Runtime policy: checkpoint every minute, scheduling directly to expiry inside the final minute
```

## Implementation Architecture

```text
Clock: injectable TrialClock; SystemTrialClock returns DateTime.now().toUtc()
Storage: FileTrialStateStore under application-support/trial_runtime
Trial service: deterministic TrialService state evaluation and persistence
Startup enforcement: evaluate after repositories and before runApp
Global gate: TrialAppGate wraps the complete GrainWarehouseApp/MaterialApp
Active UI: small non-interactive remaining-days badge
Blocked UI: standalone Arabic expiry or verification screen; business child is not built
```

The root gate is above authentication, owner setup, restored sessions, named routes, and the dashboard shell. Consequently, valid credentials, a saved session, direct navigation, or owner setup cannot bypass a blocked trial.

## Persistence

Metadata is stored in the existing per-user application-support location, in an independent `trial_runtime` directory. It is not stored in Drift or any business table.

The store uses an initialization sentinel plus an encoded state envelope with a deterministic SHA-256 integrity marker. This detects casual edits, missing companions, and partial corruption. The marker is not represented as commercial cryptographic DRM. Flushed temporary replacement files reduce partial-write exposure, and every read/parse/I/O failure blocks without crashing.

Persisted values are:

- state version;
- immutable `trialStartedAtUtc`;
- `lastAcceptedRunAtUtc`;
- sticky `tamperDetected`;
- sticky `expired`.

## Exact Boundary

For `T0 = 2026-08-10T10:00:00Z`:

- `T0 + 13d 23h 59m 59s`: active;
- `T0 + 14d`: expired;
- later than `T0 + 14d`: expired;
- open application crossing the boundary: re-evaluated and blocked without restart.

The display uses a ceiling of the positive remaining duration. Internal access always uses timestamps.

## Rollback Protection

Tolerance is zero. Equality with the last accepted run is valid; one microsecond earlier is detected once the start timestamp is no longer in the future. A detected rollback writes `tamperDetected = true`. Restart and later clock correction remain blocked. The immutable trial start and business database are unchanged.

## Bypass Protection

- Login success cannot build the dashboard when expired.
- A saved authenticated session cannot build a business screen when expired.
- Owner setup cannot initialize or reset trial state and cannot build the dashboard when blocked.
- Direct named business routes remain inside the root gate.
- Normal restart preserves the original trial start.
- Open runtime checkpoints update last accepted time and enforce expiry/rollback without requiring restart.

## Data Preservation

The integration fixture uses a real in-memory `FoundationDatabase` and production Drift repositories. It creates representative owner, product, inventory, customer, supplier, and purchase rows. Serialized snapshots before and after expiry were identical. Snapshots before and after rollback detection plus sticky restart were also identical.

Trial enforcement performs application access control only. It issues no business `DELETE`, `DROP`, wipe, reset, replacement, auth mutation, or encryption operation.

## Regression

```text
Trial tests: 36 passed; 0 skipped; 0 failed
Negative controls: N1-N4 PASS; negativeControlsAllPass=true
flutter test: 2417 passed; 1 skipped; 0 failed
flutter analyze: no issues
Windows release build: PASS
107B: PASS — atomic wipe tests
107C: PASS — checksum/restore tests
107D: PASS — D1-D10 governed package verifier
107E: PASS — E1-E19 evidence verifier
107F: PASS — documentation/evidence unchanged
```

The initial full-suite run exposed 16 historical executable guards whose branch lists ended at 107E or whose old scope assertions treated every future `lib/` change as an old Phase 106 change. The guards were maintained to recognize the governed 107G branch and exclude only `lib/main.dart`, `lib/core/trial/**`, and `lib/features/trial/**` from their historical diff calculations. Their original historical assertions and all historical evidence remain intact. The final full-suite rerun passed.

## Frozen Installer

```text
Path: delivery/phase-107d/GrainWarehouseERP-1.0.0-windows-x64.exe
Expected SHA: ab67d04e205a78aa2d6e087ffd6f63655a80e5e2de10d7a603f959b073098659
Before SHA: ab67d04e205a78aa2d6e087ffd6f63655a80e5e2de10d7a603f959b073098659
After SHA: ab67d04e205a78aa2d6e087ffd6f63655a80e5e2de10d7a603f959b073098659
Match: true
```

No final customer trial installer or delivery ZIP was created.

## Diff

```text
Production: main startup composition plus new trial clock/state/store/service
UI: one new root gate with active badge and blocked Arabic screens
Test support: Phase 107G suite plus historical executable guard compatibility
Schema: 0
Dependencies: 0
Backup: 0
Restore: 0
Accounting: 0
Installer: 0
```

## Acceptance Gates

| Gate | Result |
| --- | --- |
| G1 — baseline provenance | PASS |
| G2 — first-runtime initialization | PASS |
| G3 — exact 14-day duration | PASS |
| G4 — immutable trial start | PASS |
| G5 — restart persistence | PASS |
| G6 — owner setup cannot reset | PASS |
| G7 — login cannot bypass | PASS |
| G8 — saved session cannot bypass | PASS |
| G9 — just-before-expiry active | PASS |
| G10 — exact expiry blocked | PASS |
| G11 — post-expiry restart blocked | PASS |
| G12 — rollback detected | PASS |
| G13 — rollback sticky | PASS |
| G14 — invalid state fails closed | PASS |
| G15 — corruption never creates fresh trial | PASS |
| G16 — business data preserved at expiry | PASS |
| G17 — business data preserved on tamper | PASS |
| G18 — backup contract unchanged | PASS |
| G19 — restore contract unchanged | PASS |
| G20 — accounting unchanged | PASS |
| G21 — schema unchanged | PASS |
| G22 — dependencies unchanged | PASS |
| G23 — 107D installer unchanged | PASS |
| G24 — 107F documentation preserved | PASS |
| G25 — trial suite | PASS |
| G26 — full Flutter suite | PASS |
| G27 — analyzer | PASS |
| G28 — Windows release build | PASS |
| G29 — critical regressions | PASS |
| G30 — diff check | PASS |
| G31 — single governed commit | PASS — verified in post-commit handoff |
| G32 — final tree clean | PASS — verified in post-commit handoff |
| G33 — no push/tag/merge/rebase | PASS |

## Known Limitation

> هذه الحماية مصممة لفترة تجربة محلية قصيرة لعميل موثوق نسبيًا. وهي لا تمثل DRM قويًا أو نظام licensing تجاريًا مقاومًا للهندسة العكسية أو administrator-level tampering.

An administrator can remove both local metadata files or patch the executable. VM snapshot rollback and forensic tampering are outside this phase. Full uninstall/reinstall acceptance belongs to Phase 107H.

## Evidence

Run directory: `docs/phase-107g/evidence/20260809-222824/`

## Next Phase

Phase 107H — Governed 14-Day Trial Windows Package Acceptance. It was not started.
