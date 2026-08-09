# Phase 107C — Backup Restore Checksum Verification Report

## Executive Result

**Outcome A — FULL SUCCESS.** Restore now rejects missing, malformed, or
mismatched backup checksums before any restore mutation. A valid current backup
still restores, supported backup versions 1–8 remain compatible when they carry
their required valid checksum, and the complete verification and Windows release
gates pass.

## Baseline

- Branch: `codex/phase-107c-backup-restore-checksum-verification-contract`
- Baseline commit: `e74b3b462de0a2430d5437fc0fbaace00cfad900`
- Baseline subject: `PHASE 107B: make business data wipe atomic`
- Final commit: this report's single Phase 107C implementation commit (`HEAD`
  after Git finalization)
- Required subject: `PHASE 107C: verify backup checksum before restore`

The baseline worktree was clean and the baseline hash and subject were verified
before the branch was created.

## Existing Integrity Model

- Format: one UTF-8 JSON document; current backup version is 8.
- Supported restore versions: 1, 2, 3, 4, 5, 6, 7, and 8.
- Algorithm: Adler-32 with modulus 65,521 and the standard initial values
  `a = 1`, `b = 0`.
- Storage: top-level `checksum`; the descriptive top-level `checksumNote` is not
  integrity material.
- Hashed material: the top-level backup object before `checksum` and
  `checksumNote` are added. For verification, both keys are removed from the
  decoded envelope before recomputation.
- Canonical representation: Dart's two-space-indented JSON serialization,
  `JsonEncoder.withIndent('  ')`, preserving the constructed/decoded map order.
- Bytes and encoding: UTF-8 bytes of that serialized representation.
- Checksum encoding: exactly eight lowercase hexadecimal characters.
- Self-inclusion: neither `checksum` nor `checksumNote` is included.
- Missing-checksum policy: reject for every officially supported version 1–8.

`BackupChecksum` is now the single implementation used by export and restore,
so generation and verification cannot drift into separate algorithms.

## Restore Pipeline Before

`load → parse → structural/app/version validation → sensitive/business/count
validation → restore parsing and relationship validation → empty-system reads →
transaction snapshots → first mutation`

The preview displayed the stored checksum but did not validate its shape or
recompute it. Therefore a valid-shaped document whose business payload had been
changed could reach restore work without integrity proof.

## Restore Pipeline After

`load → parse → root/metadata/counts/data structural validation → app/version
validation → checksum presence/shape validation → recompute checksum → exact
deterministic comparison → sensitive/business/count validation → restore parsing
and relationship validation → empty-system reads → transaction snapshots → first
mutation`

The restore service already makes preview success a mandatory precondition. The
first write remains
`ProductRepository.restoreProductsIntoEmpty(...)` inside
`RepositoryTransaction.execute`; checksum failures return before parsing restore
models, empty-system reads, snapshot creation, or that transaction.

Failure reasons are explicit and stable:

- `backup-checksum-missing`
- `backup-checksum-malformed`
- `backup-checksum-mismatch`

## Failure Matrix

| Case | Expected | Result | Mutation |
| --- | --- | --- | --- |
| C1 valid v8 backup | Accept | PASS | Expected restore; sentinel = 1 |
| C2 payload tampered | Reject mismatch | PASS | None; sentinel = 0 |
| C3 checksum tampered | Reject mismatch | PASS | None; sentinel = 0 |
| C4 one ASCII byte changed | Reject mismatch | PASS | None; sentinel = 0 |
| C5 wrong length/non-hex/uppercase/non-string | Reject malformed | PASS | None; sentinel = 0 |
| C6 checksum absent on v1–v8 | Reject missing | PASS | None; sentinel = 0 |
| C7 populated-state preservation | Exact equality | PASS | None |
| C8 authentication preservation | Exact equality | PASS | None |
| C9 invalid checksum on empty system | Reject | PASS | None; sentinel = 0 |

The C1 test independently recomputes Adler-32 instead of treating the production
helper as its oracle. A test-only repository wrapper counts the first restore
write, without adding a production abstraction.

## State Preservation Evidence

For a populated target, C2/C7 snapshots every non-SQLite-internal table as
sorted complete row strings before restore and compares the full table map after
rejection. The maps are identical. The product repository's participating cache
state is captured separately and remains identical. The first-write sentinel is
zero.

C8 specifically compares the `auth_accounts` rows before and after rejection;
user, credential hash, owner role, activity state, and account identity remain
unchanged. C3/C9 repeats persistent-state equality on an already-empty business
system and proves emptiness cannot bypass checksum verification.

## Compatibility

Valid v8 export/restore succeeds and the independently computed checksum matches.
Supported v1–v8 fixtures remain previewable/restorable when they retain their
historical field shape and carry a checksum recomputed for that exact content.
Legacy-field compatibility fixtures that intentionally remove later fields were
corrected to refresh the checksum; no compatibility exception for a missing
checksum was invented. Backup version, schema, data mapping, and restore business
rules are unchanged.

Phase 107B remains green: successful wipe atomicity, F1–F4 rollback behavior,
and authentication preservation all pass within the focused and full suites.

## Security Boundary

Checksum detects accidental or unauthorized modification only according to the
existing integrity model. It does not provide confidentiality or cryptographic
authenticity if an attacker can rewrite both payload and checksum.

This phase adds no encryption, HMAC, signature, key management, or password
protection. Those remain future security-hardening concerns.

## Verification

- Formatting: PASS. Repository-wide `dart format .` scanned 422 files; the five
  later corrected legacy fixtures were formatted and a final repository-wide
  formatter check was performed before commit.
- Analyze: PASS. `flutter analyze` reported `No issues found!`.
- Focused tests: PASS. Backup export, restore preview/service, supported legacy
  backup, Phase 106 source freezes, and Phase 107B wipe regression groups pass.
- Phase 107C tests: PASS, 6 test bodies covering C1–C9.
- Full suite: PASS, 2,381 passed, 1 accepted historical skip, 0 failed.
- Windows release: PASS. The direct bundled Flutter-tool invocation built
  `build/windows/x64/runner/Release/grain_warehouse_erp_lite.exe` in 88.1s. The
  ordinary sandboxed batch wrapper could not acquire/start through its SDK lock
  path; after granting the required SDK lockfile access, the same Flutter build
  completed. Existing CMake deprecation and LNK4078 warnings were non-fatal.

## File Scope

### Production

Exactly three files:

- `lib/core/backup/backup_checksum.dart`: shared exact checksum contract.
- `lib/core/backup/backup_export.dart`: delegates existing generation to the
  shared contract.
- `lib/core/backup/backup_restore_preview.dart`: validates presence, encoding,
  and recomputed value before business validation or restore mutation.

### Tests

Twenty-four files: one dedicated Phase 107C runtime suite; eight historical
backup fixtures updated so intentional legacy field edits carry a valid checksum;
and fifteen Phase 106 source/lineage guards updated only to admit the three-file
Phase 107C production scope and current branch. No behavioral assertion was
weakened.

### Docs

- `docs/phase-107c/PHASE-107C-BACKUP-RESTORE-CHECKSUM-VERIFICATION-REPORT.md`

### Schema

Unchanged. Schema version remains 15; no migration or generated database file
changed.

### Dependencies

Unchanged. `pubspec.yaml` and `pubspec.lock` are unchanged.

### UI

Unchanged.

## Remaining Risk Register

Only the checksum finding is reclassified from Phase 107A:

- R0: 0, unchanged.
- R1: R1-002 is **CLOSED** by deterministic restore verification and mutation
  sentinel/state-preservation evidence. R1-001 was already closed by Phase 107B.
  R1-003 through R1-006 remain unchanged; open R1 count is now 4.
- R2: 7, unchanged (R2-001 through R2-007).
- R3: 7, unchanged (R3-001, R3-002, and R3-101 through R3-105).

## Git Lineage and Negative Scope Proof

The intended final tree is one commit after the verified Phase 107B baseline,
with `HEAD^` equal to that baseline and a clean worktree. No push, tag, merge,
rebase, schema change, dependency change, UI change, installer work, client
acceptance, authentication change, or product-catalog architecture change is
part of this phase.

## Recommended Next Atomic Phase

**Phase 107D — Current Governed Windows Package/Installer Artifact.** Close only
R1-003 by producing a current package/installer, manifest, and hashes from the
verified source. Keep fresh-profile runtime acceptance (R1-004), genuine-client
acceptance (R1-005), and client-document correction (R1-006) as separate later
phases.
