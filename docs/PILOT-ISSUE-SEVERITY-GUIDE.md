# Pilot Issue Severity Guide

Use this guide to classify owner/client observations during the pilot. Severity describes business impact, not how difficult a fix may be.

## Critical
A critical issue blocks safe pilot use or creates a serious accounting, stock, or data integrity risk.

ERP examples:
- Inventory quantity becomes inconsistent with the accepted inventory movement records.
- Customer balance or supplier balance changes from the wrong transaction type.
- A purchase, sale, collection, supplier payment, or expense is saved with a wrong accounting effect.
- Backup restore corrupts or mixes data despite following the documented safe process.
- The owner cannot complete a core daily workflow at all.

Decision: stop the next release until the issue is investigated and fixed or explicitly ruled out.

## High
A high issue affects an important business workflow but has a workaround that does not risk accounting integrity.

ERP examples:
- A required owner workflow is confusing enough that repeated wrong operation is likely.
- A report screen opens but omits an important expected section needed for daily review.
- PDF export for an accepted business document fails while source records remain correct.
- A supported cancellation or reversal flow is unclear enough to create audit confusion.

Decision: prioritize for the next fix phase unless it is reclassified as training or documentation.

## Medium
A medium issue affects efficiency, clarity, or a secondary workflow, but daily operation can continue safely.

ERP examples:
- A filter or search behavior makes review slower but does not change records.
- A label is understandable to the developer but unclear to the owner.
- A checklist step needs more detail for a non-technical operator.
- A report is accurate but needs clearer grouping or wording.

Decision: schedule after critical and high items; documentation updates may be enough.

## Low
A low issue is minor and does not block operation, accounting review, or owner acceptance.

ERP examples:
- A message could be more specific, but the user can still complete the task.
- A non-critical owner note needs wording polish.
- A rarely used review screen needs a clearer title.
- A workflow takes more clicks than ideal but remains correct.

Decision: defer unless grouped with a related approved documentation or polish phase.

## Cosmetic
A cosmetic issue is visual or wording polish only and has no operational or accounting impact.

ERP examples:
- Spacing in a report preview could look cleaner.
- A heading could be shorter.
- A button label could be more elegant while still being clear.
- A document note could be formatted more neatly.

Decision: defer until a dedicated polish phase unless the change is bundled safely with owner documentation.

## Category Is Separate From Severity
After severity is assigned, classify the category separately:
- Bug.
- Training.
- Feature Request.
- Misuse.
- Not a Problem.

A severe-looking report may still become Training or Misuse if the system behaved according to the accepted rules.
