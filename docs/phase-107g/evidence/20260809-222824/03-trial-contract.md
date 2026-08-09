# Trial contract

- Duration: exactly `Duration(days: 14)` (14 × 24 elapsed hours).
- Start: first successful production infrastructure initialization followed by the first trial evaluation immediately before `runApp`.
- Active: `nowUtc < startedAtUtc + 14 days`.
- Expired: `nowUtc >= startedAtUtc + 14 days`.
- Time standard: UTC timestamps only.
- Rollback tolerance: `Duration.zero`.
- Rollback: `nowUtc < lastAcceptedRunAtUtc` persists `tamperDetected = true` and blocks access.
- Sticky state: rollback and first-observed expiry remain blocked after restart and later clock correction.
- Invalid state: parse, integrity, missing-companion, version, impossible-ordering, and I/O errors fail closed without crashing.
- Runtime checkpoints: every minute while active, or directly at expiry when less than one minute remains.
- Remaining days: display-only ceiling; it never controls access.
