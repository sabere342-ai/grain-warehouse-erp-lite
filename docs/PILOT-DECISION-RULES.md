# Pilot Decision Rules

These rules decide what happens after an owner/client observation is recorded during the pilot.

## Accounting or Balance Issue
If the observation may affect accounting correctness, customer balances, supplier balances, inventory quantity, source records, or report truthfulness:

Stop the next release until the issue is investigated.

Do not treat it as cosmetic.
Do not hide it with wording.
Do not change data manually to make the symptom disappear.

Allowed actions:
- Reproduce the issue.
- Check source records.
- Classify severity.
- Plan a dedicated fix phase if confirmed.

## Inventory Issue
If the observation may affect stock quantity, stock movement history, stock-taking behavior, or adjustment reporting:

Treat it as at least High until proven otherwise.

If accounting balances are also affected, treat it as Critical.

## Cosmetic Issue
If the observation is visual polish only and does not affect operation, accounting, inventory, reports, or data safety:

Defer it.

Cosmetic issues should not delay pilot acceptance unless the owner explicitly makes the visual issue a delivery condition.

## Training Issue
If the application behaved as designed but the user misunderstood the workflow:

Update owner guidance, onboarding notes, or checklist wording only.

Do not change production behavior unless repeated training failures prove that the workflow itself is unsafe or misleading.

## Feature Request
If the owner asks for behavior not included in the current pilot scope:

Put it in the backlog.

Do not implement it during triage.
Do not mix it with bug fixes.
Do not describe it as already supported.

Examples:
- Cloud sync.
- Mobile app.
- Multi-device live sync.
- New reports.
- New approval flows.
- Automatic messaging.

## Incorrect Input or Unsupported Operation
If the issue was caused by wrong entry, skipped required steps, manual file editing, or unsupported use:

Do not classify it as a bug.

Record it as Misuse or Training, then decide whether warnings or documentation need improvement.

## Known Limitation or Non-Goal
If the observation is already documented as a limitation or non-goal:

Classify it as Not a Problem unless the owner changes the accepted scope.

Examples:
- Current version is local Windows only.
- No cloud sync.
- No mobile app.
- No multi-device live sync.
- Restore is safe only into an empty system.

## Release Decision
Before any future release:
- All Critical items must be closed or explicitly ruled out.
- High items must have an accepted fix, training decision, or deferral reason.
- Medium items must be reviewed and assigned.
- Low and Cosmetic items may be deferred.
- Feature Requests must be separated from bug fixes.
- Misuse and Training items should update owner instructions where needed.

## Documentation Rule
If the resolution changes what the owner should do, update documentation.

If the resolution changes what the software does, it must be handled in a future implementation phase with normal verification.
