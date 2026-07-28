# Phase 102J — Synthetic Inventory Package Validation

## Outcome

**Outcome A — PASSED: EXACT OWNER-APPROVED PACKAGE VALIDATED**

Phase 102J resumed from blocker-evidence commit
`3e2446b10b1e984422c2871a80f5ac9915e5cd04`. The owner-supplied workbook and
sidecar hash were moved from the repository root to the required ignored
`owner-input/` directory before any test database was created.

## Package identity

| Field | Observed result |
| --- | --- |
| Filename | `phase_102j_synthetic_inventory_test_package.xlsx` |
| Path | `owner-input/phase_102j_synthetic_inventory_test_package.xlsx` |
| Computed SHA-256 | `461F3EE16B2895E3AC898352384EA0D927A49688912A3B6DB4C7C62B96271DFC` |
| Sidecar declaration | Exact filename/hash pair matched |
| Size | 10,188 bytes |
| Data classification | `SYNTHETIC_TEST_DATA` |
| Row approval | `TEST_APPROVED_ONLY` |
| Intended environment | `TEST-SANDBOX` |

The workbook contains three expected worksheets. Its OOXML surface contains no
macro project, external links, connections, embedded objects, `customXml`,
hidden worksheets, hidden rows, or hidden columns.

## Row validation

The committed reader in `tool/phase102j_synthetic_inventory_package.dart`
fails closed on filename, SHA-256, sheet inventory, headers, hidden content,
classification, row approval, duplicate key, formula, exact qirsh conversion,
and control totals.

| Measure | Result |
| --- | ---: |
| Submitted rows | 12 |
| Validated rows | 12 |
| Rejected rows | 0 |
| Duplicate row IDs | 0 |
| Duplicate SKUs | 0 |
| Duplicate evidence references | 0 |
| Formula errors | 0 |
| Total quantity | 73,650 kg |
| Total valuation | 168,009,000 qirsh / 1,680,090.00 EGP |

The owner workbook and sidecar remain ignored by Git. No workbook was modified,
recreated, or exported by the implementation.
