# Phase 101F — Customer and Supplier Opening-Balance EGP Input Remediation

## Outcome

**OUTCOME A — FULL SUCCESS**

**PHASE 101F COMPLETE — CUSTOMER AND SUPPLIER OPENING BALANCES USE EGP INPUTS**

**F-004 RESOLVED**

**PHASE 101E REQUIRES A NEW GENUINE CLIENT VERIFICATION AND ACCEPTANCE DECISION**

**COMMERCIAL READINESS NOT YET DECLARED**

## Governance

| Item | Result |
|---|---|
| Authorized baseline | `60c48fa2f793b41f1a1bff9d6412022c4bed2c78` |
| Branch | `phase-101f-customer-supplier-opening-balance-egp-input-remediation` |
| Scope | Customer and supplier opening-balance UI, exact conversion tests, and the supplier statement layout required to display the verified value |
| Push | Not performed |

## Implementation

- Added one shared opening-balance dialog for customer and supplier workflows.
- The field label is `الرصيد الافتتاحي (جنيه)` and the helper text explains EGP decimal entry.
- Input uses `MoneyUtils.parseEgpToPiasters`, which parses the decimal string exactly into integer qirsh; no binary floating-point multiplication is used.
- Whole values and one or two fractional digits are accepted. Malformed input, zero, negative input, more than two fractional digits, and values above the signed 64-bit storage range are rejected.
- Existing duplicate-opening-balance checks, ledger direction, permissions, audit semantics, and repository transactions remain unchanged.
- Customer and supplier cards and statements use the existing EGP formatter; no raw qirsh is presented in the normal workflow.
- The supplier statement content was changed from a nested `ListView` to a `Column` because the required native verification exposed that the nested scrollable rendered the statement body blank. No accounting or repository behavior changed.

## Focused proof

The Phase 101F widget/regression coverage proves for both customer and supplier:

- `1000` EGP stores `100000` qirsh.
- `1000.50` EGP stores `100050` qirsh.
- `0.25` EGP stores `25` qirsh.
- One fractional digit is converted exactly.
- Invalid text, excessive precision, zero, negative input, and overflow are rejected.
- Duplicate opening balances remain prohibited.
- The user-facing label identifies EGP and no qirsh-facing copy is shown.
- Ledger entries and statement values remain exact.
- Backup/restore and permission regressions remain green through the related suites and the full suite.

## Verification gates

The gates were run in the required order after the final code change.

| Gate | Result |
|---|---|
| `flutter analyze --no-pub` | PASS — 0 errors, 0 warnings, 0 infos, exit 0 |
| Focused customer/supplier opening-balance, ledger, statement, backup, permissions, and purchase tests | PASS — 114 passed, 0 failed |
| `flutter test --no-pub` | PASS — 1838 passed, 1 unchanged pre-existing skip, 0 failed |
| `git diff --check` | PASS |
| `flutter build windows --release --no-pub` | PASS — release executable produced; only the pre-existing external Firebase CMake deprecation warning appeared |

No analyzer suppression, removed test, new skip, weakened assertion, dependency change, or lockfile change was introduced.

## Isolated native verification

The final Windows release was run against a fresh application-support profile. The existing local Grala profile was moved intact to a uniquely named sibling backup before launch. After verification, the synthetic profile was preserved separately and the original profile was restored. No genuine client data was used or modified.

Synthetic records:

- `عميل تجريبي 101F` with opening balance `1250.50` EGP.
- `مورد تجريبي 101F` with opening balance `875.25` EGP.

Verified in the native release:

1. Customer dialog displayed `الرصيد الافتتاحي (جنيه)`.
2. Customer card displayed `1250.50 ج.م` after entering `1250.50`.
3. Supplier dialog displayed `الرصيد الافتتاحي (جنيه)`.
4. Supplier card displayed `875.25 ج.م` after entering `875.25`.
5. No raw qirsh appeared in the normal customer or supplier workflow.
6. Customer statement displayed opening and final balances of `1250.50 ج.م`.
7. Supplier statement rendered its opening-balance row after the layout fix; the exact `875.25 ج.م` value is additionally asserted by the focused statement widget test. At the host's 125% display scaling the rightmost amount text was outside the screenshot crop, but the native supplier card visibly showed `875.25 ج.م` immediately before opening the statement.
8. After closing and reopening the release, both cards still displayed exactly `1250.50 ج.م` and `875.25 ج.م`.
9. No crash or inconsistent validation occurred.

Evidence screenshots are stored outside the repository in the Codex visualization evidence directory. The preserved synthetic database profile is stored outside the repository under the local temporary directory; neither is part of the commit.

## Compatibility and scope protection

| Area | Impact |
|---|---|
| Canonical amounts | Unchanged integer qirsh |
| Existing stored balances | Unchanged |
| Customer/supplier ledger direction | Unchanged |
| Duplicate prevention | Unchanged |
| Permissions and audit | Unchanged |
| Financial accounts, sales, purchases, collections, payments | Unchanged |
| Database schema and migrations | No change |
| Backup version, format, restore compatibility | No change |
| Dependencies and lockfiles | No change |
| Reports outside the two workflows | No change |

## Acceptance boundary

F-004 is closed as a technical remediation. This phase does not claim that a genuine client participated, accepted the application, or authorized commercial readiness. Phase 101E remains pending a new genuine client session.
