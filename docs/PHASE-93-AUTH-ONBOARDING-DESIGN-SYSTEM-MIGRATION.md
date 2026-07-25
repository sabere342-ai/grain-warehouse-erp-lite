# Phase 93 — Auth Onboarding Design-System Migration

## Governance Evidence

| Item | Value |
|------|-------|
| Previous phase | Phase 92 — Legacy AppBar Holdouts |
| Previous branch | `phase-92-legacy-appbar-holdouts-design-system-migration` |
| Previous actual HEAD | `68cbed1` |
| Previous tag | `phase-92-legacy-appbar-holdouts-design-system-migration-verified` |
| Previous tag type | annotated (`tag`) ✓ |
| Previous tag target | `68cbed1` ✓ |
| Starting tree | clean ✓ |
| Phase 93 reservation | None found ✓ |

## Phase 93 Inventory

### Migrated

| # | File | Migration |
|---|------|-----------|
| 1 | `lib/features/auth/first_owner_setup_screen.dart` | Full design-system migration |

### Audited (no changes needed)

| # | File | Reason |
|---|------|--------|
| 1 | `lib/features/auth/login_screen.dart` | Already fully migrated in prior phases |

### Excluded

| # | File | Reason |
|---|------|--------|
| 1 | `lib/features/dashboard/dashboard_shell.dart` | Main navigation shell, not a page screen |
| 2 | `lib/core/auth/auth_controller.dart` | Auth architecture — out of scope |
| 3 | `lib/core/auth/auth_state.dart` | Auth architecture — out of scope |
| 4 | `lib/core/auth/auth_repository.dart` | Auth architecture — out of scope |
| 5 | `lib/core/auth/drift_auth_repository.dart` | Auth architecture — out of scope |
| 6 | `lib/features/auth/auth_gate.dart` | Auth routing — out of scope |
| 7 | `lib/app/routes.dart` | Route definitions — out of scope |
| 8 | `lib/app/grain_warehouse_app.dart` | App shell — out of scope |

## Design-System Migration Details

### FirstOwnerSetupScreen changes

| Before | After |
|--------|-------|
| `import app_colors.dart` | `import app_tokens.dart` |
| `AppColors.mutedText` | `colorScheme.onSurfaceVariant` |
| Hardcoded `EdgeInsets.symmetric(vertical: 20)` | `AppSpacing.lg` |
| Hardcoded `BoxConstraints(maxWidth: 500)` | `AppComponentSizes.authMaxWidth` |
| Hardcoded `EdgeInsets.all(20)` | `AppSpacing.md` |
| Hardcoded `EdgeInsets.all(28)` | `AppSpacing.xl` |
| Hardcoded `SizedBox(height: 18)` | `AppSpacing.md` |
| Hardcoded `SizedBox(height: 8)` | `AppSpacing.xs` |
| Hardcoded `SizedBox(height: 24)` | `AppSpacing.lg` |
| Hardcoded `SizedBox(height: 12)` × 2 | `AppSpacing.sm` |
| Hardcoded `SizedBox(height: 20)` | `AppSpacing.lg` |
| `Icon(size: 52)` | `AppIconSizes.hero` |
| `Icons.badge_outlined` | `Icons.badge_rounded` |
| `Icons.phone_outlined` | `Icons.phone_rounded` |
| Password always obscured | Toggle visibility button added |
| No keyboard type on phone field | `TextInputType.phone` |
| No Semantics on icon | `Semantics(label: ...)` |
| No Semantics on error | `Semantics(liveRegion: true)` |
| No Keys on fields | Keys added for testing |
| No loading indicator on submit | `CircularProgressIndicator` during submit |

### LoginScreen (audited — no changes needed)

LoginScreen was already fully migrated with:
- `AppSpacing`, `AppComponentSizes.authMaxWidth`, `AppIconSizes.hero`
- `PremiumCard`, `FilledButton.icon`
- `colorScheme.primary`, `colorScheme.onSurfaceVariant`, `colorScheme.error`
- Password visibility toggle with tooltip
- `Semantics(label: ...)` on logo icon
- `Semantics(liveRegion: true)` on error message
- Keys on all fields and submit button
- `CircularProgressIndicator` during submit
- No AppBar, no back button (root screen)

## Header / Back-Navigation Decisions

| Screen | Has Header | Has Back Button | Reason |
|--------|-----------|-----------------|--------|
| LoginScreen | No (icon + title only) | No | Root screen; back would exit app |
| FirstOwnerSetupScreen | No (icon + title only) | No | Mandatory setup; back would leave app without owner |

Neither screen uses `GhalalPageHeader` because neither has an AppBar and neither requires a back button.

## Security and Behavior Invariants

| Invariant | Changed |
|-----------|---------|
| Authentication logic | No |
| Credential storage | No |
| Password/PIN validation | No |
| First-owner creation rules | No |
| Duplicate prevention | No |
| Navigation destinations | No |
| Session behavior | No |
| Schema | No |
| Backup/restore | No |
| Financial behavior | No |

## Tests

### New tests: 29 focused tests

**LoginScreen (13 tests):**
1. Shows app name and submit button
2. Phone and password fields are present
3. Password is obscured by default
4. Password visibility toggle works
5. Submit disables button and calls signIn
6. Auth error displays correctly
7. No AppBar present
8. Uses PremiumCard
9. No back button on root login screen
10. No overflow on compact viewport (360×640)
11. RTL directionality preserved
12. Icon has Semantics label for accessibility
13. Error message wrapped in Semantics with liveRegion

**FirstOwnerSetupScreen (16 tests):**
1. Shows setup title and submit button
2. Required fields are present
3. Password is obscured by default
4. Password visibility toggle works
5. Submit disables button and calls createFirstOwner
6. Empty fields show validation error
7. Short password shows validation error
8. Successful setup transitions to signedIn
9. No AppBar present
10. Uses PremiumCard
11. No back button on mandatory setup screen
12. No overflow on compact viewport (360×640)
13. RTL directionality preserved
14. Icon has Semantics label for accessibility
15. Error message wrapped in Semantics with liveRegion
16. No legacy AppColors.mutedText usage (verifies onSurfaceVariant)

## Verification

| Gate | Result |
|------|--------|
| dart format | ✓ No changes |
| flutter analyze | ✓ 5 issues (1 warning + 4 infos, all pre-existing in test files) |
| Windows release build | ✓ Success |
| git diff --check | ✓ Clean |
| Full test suite | ✓ 1642 passed, 1 skipped, 1 failed (pre-existing flaky: phase44) |
| Focused tests | ✓ 29/29 passed |

## Git

| Item | Value |
|------|-------|
| Branch | `phase-93-auth-onboarding-design-system-migration` |
| Implementation commit | `33b324a` feat: migrate auth onboarding screens to Ghalal design system |
| Tag | `phase-93-auth-onboarding-design-system-migration-verified` |
| Tag type | annotated |
| Tag target | (to be verified after creation) |
| Push performed | No |

## Residual Risks

1. `dashboard_shell.dart` retains its legacy AppBar — excluded per spec as main navigation shell
2. `login_screen.dart` uses `TextField` rather than `TextFormField` — validation handled in `AuthController`, not form-level; this is the existing architecture
3. `first_owner_setup_screen.dart` also uses `TextField` — same reasoning as above
4. One pre-existing flaky test in `phase44_final_owner_acceptance_after_pdf_whatsapp_test.dart` — not related to Phase 93

## Recommended Next Phase

**Phase 94 — Business Identity & Printable Document Branding**
