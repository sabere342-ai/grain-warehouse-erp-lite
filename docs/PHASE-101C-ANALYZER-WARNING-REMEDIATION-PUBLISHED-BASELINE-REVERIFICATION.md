# Phase 101C — Analyzer Warning Remediation and Published-Baseline Reverification

## Decision

**OUTCOME D — ANALYZER REMEDIATION INCOMPLETE**

The two authorized warnings were removed with the smallest correct test-only changes. The mandatory post-fix command still returned exit code `1` because 30 informational lints remain. Phase 101C forbids a general informational-lint cleanup, production-code changes, analyzer-configuration changes, and severity reduction, so verification stopped at the analyzer gate.

## Baseline

| Item | Value |
|------|-------|
| Repository | `C:/dev/multi-pos/grain-warehouse-erp-lite` |
| Starting branch | `phase-101b-customer-advances-refunds-navigation-presentation` |
| Phase 101C branch | `phase-101c-analyzer-warning-remediation-published-baseline-reverification` |
| Starting HEAD | `8557966f0a273ec305e1b7aee10d440dce28d708` |
| Phase 101B local tag target | `8557966f0a273ec305e1b7aee10d440dce28d708` |
| Remote Phase 100 branch target | `8557966f0a273ec305e1b7aee10d440dce28d708` |
| Remote Phase 101B tag target | `8557966f0a273ec305e1b7aee10d440dce28d708` |
| Toolchain | Flutter 3.24.5; Dart 3.5.4 |

## Dirty-Baseline Preservation

Only the three authorized Phase 100 documentation files were dirty before Phase 101C. Their pre-branch SHA-256 values were:

| File | SHA-256 |
|------|---------|
| `docs/PHASE-100-GENUINE-CLIENT-DEMO-EXECUTION-ACCEPTANCE.md` | `23649886775EE1992BFCDD24646ABE919224AAFE4CFCCFC94E4EBDA41C9F75A1` |
| `docs/CLIENT-DEMO-FINDINGS-REGISTER-AR.md` | `309E7B9C99DAF9B02100931AC941C5F2CF128DFAD25DF8168619DBF88B5EFE11` |
| `docs/CLIENT-COMMERCIAL-READINESS-DECISION-AR.md` | `091F2E67D92E477DD181388CEBBFF59B1A19147B2DD8413B0341C968919744E4` |

The hashes were unchanged immediately after creating and switching to the Phase 101C branch. No reset, restore, checkout of files, or stash was used. No additional dirty file existed before remediation.

## Warning Root Causes and Changes

### Warning 1 — unused import

- File: `test/phase101b_customer_advances_navigation_test.dart:11:8` before remediation.
- Analyzer: `unused_import` for `financial_account.dart`.
- Root cause: the test uses `LocalFinancialAccountRepository` and financial-account entry/repository types, but no declaration from `financial_account.dart`.
- Change: removed only the unused import.
- Behavior impact: none.

### Warning 2 — invalid override

- File: `test/phase90_push_route_screens_design_system_test.dart:222:33` before remediation.
- Analyzer: `override_on_non_overriding_member` on `entryById`.
- Root cause: `DocumentHistoryRepository` declares only `listHistory`; the test-double method `entryById` does not override an interface member.
- Change: removed only the invalid `@override` annotation.
- Behavior impact: none; the method body and test expectations are unchanged.

## Formatting

The `dart` wrapper timed out without output in the sandbox. The proven direct SDK fallback was used:

```text
C:\src\flutter\bin\cache\dart-sdk\bin\dart.exe format test\phase101b_customer_advances_navigation_test.dart test\phase90_push_route_screens_design_system_test.dart
```

Exit code: `0`. Review confirmed the combined test diff remained exactly two deletions, with no formatter churn.

## Analyzer Before and After

| Run | Command | Exit | Errors | Warnings | Infos |
|-----|---------|-----:|-------:|---------:|------:|
| Before | `flutter analyze --no-pub` | 1 | 0 | 2 | 30 |
| After | `flutter analyze --no-pub` | 1 | 0 | 0 | 30 |

The after-run removed both warnings but did not meet the explicit exit-code-zero gate. The 30 remaining infos are pre-existing: four in `dashboard_shell.dart`, one unused `_owner` test declaration, three Phase 91 const suggestions, and twenty-two Phase 96 const suggestions. Phase 101C did not create any new informational lint.

## Verification Gates

| Gate | Result | Detail |
|------|--------|--------|
| Preflight | PASS | Exact repository, HEAD, refs, remote, and authorized dirty baseline verified |
| Analyzer reproduction | PASS | Exact 2 warnings and 30 infos reproduced |
| Analyzer after remediation | **FAIL** | 0 errors, 0 warnings, 30 infos, exit code 1 |
| Focused Phase 101B test | NOT RUN | Stopped at failed analyzer gate |
| Focused Phase 90 test | NOT RUN | Stopped at failed analyzer gate |
| Full tests | NOT RUN | Stopped at failed analyzer gate |
| Diff check | PASS | `git diff --check`, exit code 0; CRLF conversion notices only |
| Windows release build | NOT RUN | Stopped at failed analyzer gate |
| Application launch | NOT RUN | Stopped at failed analyzer gate |
| Backup safety | NOT RUN | Stopped at failed analyzer gate |

## Scope Review

- Production code changed: NO.
- Dependencies changed: NO.
- Schema changed: NO.
- Backup format changed: NO.
- Tests skipped, removed, or behaviorally weakened: NO.
- Lint rules or severity changed: NO.
- Informational lints fixed: NO.

## Git Actions

- Phase 101C branch created locally: YES.
- Commit created: NO — forbidden because analyzer exit remained `1`.
- Tag created: NO.
- Push performed: NO.
- Remote refs modified: NO.

## Phase 100 Status

The technical baseline is not reverified. F-003 remains open. No client session occurred and no client acceptance was obtained.

```text
PHASE 100 REMAINS BLOCKED — GENUINE CLIENT SESSION AND ACCEPTANCE DECISION REQUIRED
```

## Post-Phase 101C Follow-up

Phase 101C remains historically classified as **OUTCOME D — ANALYZER REMEDIATION INCOMPLETE** because its own authorized scope ended with analyzer exit `1` and 30 infos. Phase 101D later received separate authorization, remediated those infos without weakening analyzer rules, and completed the full technical reverification. See `docs/PHASE-101D-COMPLETE-ANALYZER-INFORMATIONAL-LINT-REMEDIATION-FULL-TECHNICAL-REVERIFICATION.md`.
