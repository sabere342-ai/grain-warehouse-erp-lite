# Phase 56 - Owner Pilot Observation and Issue Triage

## Phase Goal
Create a professional process for receiving, classifying, prioritizing, and deciding on owner/client observations during the pilot period.

This phase does not fix bugs and does not add features. It defines how pilot feedback should be captured and triaged before any future implementation decision.

## Scope
- Documentation-only pilot observation process.
- Issue intake rules for owner/client feedback.
- Severity guide for pilot findings.
- Decision rules for whether an observation becomes a bug fix, training update, documentation update, or backlog item.
- Empty triage log template with no fake data.

## Out of Scope
- No production business logic change.
- No schema change.
- No repository implementation pattern change.
- No accounting logic change.
- No inventory logic change.
- No sales or purchase logic change.
- No reports change.
- No backup/restore change.
- No delivery package change.
- No UI change.
- No test change.
- No cloud sync, mobile app, or multi-device sync.

## What the Owner Should Observe
During the pilot, the owner should observe real usage without changing the system manually outside the application:

- Can the owner complete the expected daily workflow?
- Are purchases, sales, collections, supplier payments, expenses, inventory, and reports understandable?
- Do accounting balances match the source records the owner entered?
- Does inventory move in the expected direction after purchases, sales, and supported adjustments?
- Are owner-facing documents and reports clear enough for review?
- Are error messages understandable and actionable?
- Does any visible page appear incomplete, misleading, or non-functional?
- Does the owner need training or wording clarification to use a supported workflow correctly?

## How to Record Observations
Each observation should be recorded in:

`docs/PILOT-ISSUE-TRIAGE-LOG.md`

Every row should include:
- Date.
- Version or package tag.
- Reporter name or role.
- Application area.
- Short factual description.
- Severity.
- Category.
- Root cause if known.
- Action.
- Planned phase if action is needed.
- Closed status.

Good observation notes should include:
- The exact screen or workflow.
- The input values used when relevant.
- What the owner expected.
- What actually happened.
- A screenshot if available.
- Whether the issue can be repeated.

## When an Observation Is a Bug
Treat the observation as a bug when the application behaves contrary to an existing accepted requirement, documented behavior, or accounting source-of-truth rule.

Examples:
- A purchase does not increase inventory.
- A credit sale does not affect the customer balance as expected.
- A customer collection changes a supplier balance.
- A report displays totals inconsistent with source records.
- A supported action saves incorrect values.
- A visible page blocks a documented pilot workflow.

## When an Observation Is Training
Treat the observation as training when the application works as designed, but the owner or operator needs clearer explanation or practice.

Examples:
- The owner does not know which screen should be used for supplier payment.
- The owner expects backup restore to merge into existing data, while the documented rule says restore is only safe into an empty system.
- The user does not understand the difference between a daily report and source records.
- The operator enters the wrong payment mode because the workflow was not explained.

Training observations should usually update owner instructions, checklists, or onboarding notes instead of production code.

## When an Observation Is a Feature Request
Treat the observation as a feature request when the owner asks for new behavior not currently promised by the pilot.

Examples:
- Requesting mobile access.
- Requesting live sync across multiple devices.
- Requesting automatic WhatsApp sending.
- Requesting a new report not currently included.
- Requesting a new approval workflow.
- Requesting cloud backup or remote login.

Feature requests should go to a backlog and should not be implemented during the pilot triage phase unless explicitly approved as a future phase.

## When an Observation Is Misuse
Treat the observation as misuse when the system behaves correctly but the result comes from unsupported or incorrect operation.

Examples:
- Restoring a backup over existing data despite the empty-system rule.
- Running copied data folders on two machines as if they were live-synced.
- Entering test data as real customer data before owner acceptance.
- Editing generated files or local data outside the application.
- Using a workflow with incomplete required business data.

Misuse should be handled with training, clearer warnings, or operational rules.

## When an Observation Is Not a Problem
Treat the observation as not a problem when it matches a known limitation, documented non-goal, or expected local-only behavior.

Examples:
- No cloud sync is available in the current version.
- No mobile app is available in the current version.
- Multi-device live sync is not available.
- Backup restore is restricted to an empty system.
- PDF export exists, but physical printing is not claimed as a direct app feature.
- Reports are read-only projections and do not replace source records.

These items can be logged for awareness, but they should not block the pilot unless the owner changes the accepted scope.

## Phase 56 Acceptance
Phase 56 is accepted when:
- The triage process is documented.
- The empty issue log exists.
- Severity levels are defined.
- Decision rules are documented.
- Handoff and owner-facing notes reference the pilot feedback process.
- No production code, schema, tests, delivery package, or business behavior changed.

## Next Recommended Phase
Phase 57 - Review Actual Pilot Feedback and Decide Fix/Training/Backlog Actions.
