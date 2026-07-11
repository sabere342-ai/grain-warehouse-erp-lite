# Post-Phase 81 Next-Scope Governance Audit

## Objective

Determine whether the repository establishes a unique official next phase after Phase 81, and if not, identify all valid candidates with evidence-based priority ranking.

## Baseline

- **Latest commit:** `841301d` — Phase 81: Transaction-Level Financial Backup/Restore Contract Remediation
- **Tag:** `phase-81-transaction-level-financial-backup-restore-contract-remediation` points to HEAD
- **Working tree:** Clean
- **Test baseline:** 784/784 passing

## Stage 1 — Evidence Search

### Searched Terms

| Term | Matches | Files |
|------|---------|-------|
| `Phase 82` | 0 | — |
| `next phase` | 2 | NEXT-PHASE-DECISION-GATE.md (generic table), DEVELOPER-HANDOFF-NOTES.md (historical) |
| `DC-U002` | 18 | Roadmap, Decision Register, Phase 78, Handoff Notes, Requirements Matrix |
| `DC-U007` | 18 | Roadmap, Decision Register, Phase 78, Handoff Notes, Requirements Matrix |
| `DC-U008` | 14 | Roadmap, Decision Register, Phase 78, Handoff Notes, Requirements Matrix |
| `DC-U014` | 8 | Decision Register, Phase 74, Phase 75, Handoff Notes |
| `split payment` | 60 | Roadmap, Decision Register, Phase 78, Handoff Notes, Financial Gap Audit |
| `negative balance` | 18 | Decision Register, Phase 78, Handoff Notes, Phase 77 |
| `overpayment` | 38 | Roadmap, Decision Register, Phase 78, Handoff Notes, Financial Gap Audit |
| `refund` | 38 | Roadmap, Decision Register, Phase 78, Handoff Notes, Financial Gap Audit |
| `cancellation` | 318 | Extensive coverage across all documents |
| `CAN-005` | 11 | Roadmap, Requirements Matrix |
| `CAN-006` | 11 | Roadmap, Requirements Matrix |

### Key Finding

**No reference to "Phase 82" exists anywhere in the repository.** No document assigns a specific phase number or title to any work after Phase 81.

## Stage 2 — Candidate Matrix

### Candidate 1: DC-U007 — Negative-Balance Controls

| Attribute | Evidence |
|-----------|----------|
| **Decision status** | Adopted by Phase 78; Decision Register still shows `REQUIRES OWNER DECISION` (documentation inconsistency) |
| **Decision content** | Per-account Boolean `allowNegativeBalance`; owner-only toggle; owner approval required for each negative-balance operation; non-owner operations blocked when balance insufficient; owner can override with audit trail |
| **Current gap** | No `allowNegativeBalance` field on `FinancialAccount` model. Balance CAN go negative through expense/outflow entries. Transfer checks balance but expenses/supplier payments do not. |
| **Integrity impact** | HIGH — Expenses and supplier payments can create negative balances without any guard. Existing negative historical balances are permitted by generic entries. |
| **Dependencies** | None (self-contained) |
| **Complexity** | Medium — requires new field on FinancialAccount, balance validation on expense/supplier-payment paths, owner-approval UI |
| **Roadmap position** | Listed as remaining gap in DEVELOPER-HANDOFF-NOTES.md and MASTER-PRODUCT-ROADMAP.md |

### Candidate 2: DC-U014 — Transfer Insufficient Balance

| Attribute | Evidence |
|-----------|----------|
| **Decision status** | CLOSED — `OWNER DECISION RECORDED — Phase 75` in Decision Register |
| **Decision content** | Block a new transfer when the source account has insufficient balance. Transfer-only rule; does not change legacy financial-operation rules. |
| **Current gap** | Transfer already has balance check (Phase 76). Decision is CLOSED in register. No code gap exists for transfers. |
| **Integrity impact** | LOW — Existing transfer implementation already blocks insufficient balance. Decision is documented and implemented. |
| **Dependencies** | Intersects with DC-U007 (negative balance policy for non-transfer operations) |
| **Complexity** | Low — decision already closed; no further action needed for transfers |
| **Roadmap position** | CLOSED in Decision Register; implemented in Phase 76 |

### Candidate 3: CAN-005/CAN-006 — Collection/Payment Cancellation

| Attribute | Evidence |
|-----------|----------|
| **Decision status** | NOT IMPLEMENTED (Master Roadmap `- [ ]`) |
| **Decision content** | Collection cancellation with customer ledger reversal (CAN-005); Payment cancellation with supplier ledger reversal (CAN-006) |
| **Current gap** | Sale cancellation reverses customer ledger (Phase 59). Purchase cancellation reverses supplier ledger. But collection cancellation does NOT reverse customer ledger. Payment cancellation does NOT reverse supplier ledger. Asymmetric with sale/purchase cancellation behavior. |
| **Integrity impact** | MEDIUM — Missing accounting symmetry. Collection/payment cancellations leave stale ledger entries. |
| **Dependencies** | ACC-007 (financial accounts) ✅ implemented |
| **Complexity** | Medium — requires new cancellation logic for collections/payments with FA entry reversal |
| **Roadmap position** | Listed as `- [ ]` in MASTER-PRODUCT-ROADMAP.md lines 244-245 |

### Candidate 4: DC-U002 — Split Payments

| Attribute | Evidence |
|-----------|----------|
| **Decision status** | Adopted by Phase 78; Decision Register still shows `REQUIRES OWNER DECISION` (documentation inconsistency) |
| **Decision content** | Max 3–5 payment methods per invoice; per-account owner configuration; partial payments allowed; no new financial-account creation during split; single-account fallback for full payments |
| **Current gap** | No split payment model, allocation, or multi-account-per-invoice support. `SaleDraft` accepts single `financialAccountId` only. `SalePaymentMode.partial` enum exists but unimplemented. |
| **Integrity impact** | LOW — Current single-account behavior is correct for full payments. Split is a feature enhancement, not an integrity fix. |
| **Dependencies** | Requires data model change (new allocation table or model fields) |
| **Complexity** | HIGH — affects all transaction types, requires new data model, UI, backup contract |
| **Roadmap position** | Listed as remaining gap in DEVELOPER-HANDOFF-NOTES.md |

### Candidate 5: DC-U008 — Overpayments, Advances, Refunds

| Attribute | Evidence |
|-----------|----------|
| **Decision status** | Adopted by Phase 78; Decision Register still shows `REQUIRES OWNER DECISION` (documentation inconsistency) |
| **Decision content** | Owner approval per overpayment operation; recorded as customer/supplier credit or advance; no editing of original collection/payment document; refund via separate compensating entry from same account |
| **Current gap** | Overpayment blocked for sales (`SaleRepository` throws), customer collections (`StateError`), supplier payments (`StateError`). No refund concept exists. No advance balance tracking. |
| **Integrity impact** | LOW — Current blocking behavior is safe (throws rather than allowing incorrect state). Overpayment is an enhancement, not an integrity fix. |
| **Dependencies** | Requires new refund model, advance balance tracking, owner-approval workflow |
| **Complexity** | HIGH — new models, new UI, new accounting flows |
| **Roadmap position** | Listed as remaining gap in DEVELOPER-HANDOFF-NOTES.md |

### Candidate 6: Cloud Sync / Multi-Device / Mobile

| Attribute | Evidence |
|-----------|----------|
| **Decision status** | Deferred, not cancelled |
| **Decision content** | Full cloud sync, multi-device, mobile support |
| **Current gap** | Requires local stability proof first (MASTER-PRODUCT-ROADMAP.md line 298: "No Cloud/Mobile before the local model is fully proven in production") |
| **Integrity impact** | N/A — Infrastructure enhancement, not accounting integrity |
| **Dependencies** | Requires proven production use of local model |
| **Complexity** | VERY HIGH — 10+ phases estimated |
| **Roadmap position** | Listed as future scope in MASTER-PRODUCT-ROADMAP.md |

## Stage 3 — Priority Ranking

Ranked by: roadmap ordering → integrity impact → dependencies → visible workflows → backup → cloud → reporting → cosmetic.

| Rank | Candidate | Integrity | Complexity | Dependencies | Evidence |
|------|-----------|-----------|------------|--------------|----------|
| 1 | DC-U007 (Negative balance) | HIGH | Medium | None | Expenses/supplier payments can create negative balances without guard. Existing negative historical balances permitted. Affects all financial operations. Adopted by Phase 78 but not implemented. |
| 2 | CAN-005/CAN-006 (Collection/Payment cancellation) | MEDIUM | Medium | ACC-007 ✅ | Missing accounting symmetry. Collection/payment cancellations leave stale ledger entries. Not implemented per Master Roadmap. |
| 3 | DC-U002 (Split payments) | LOW | HIGH | Data model change | Feature enhancement. Current single-account behavior correct for full payments. Adopted by Phase 78 but not implemented. |
| 4 | DC-U008 (Overpayments/refunds) | LOW | HIGH | New models | Current blocking behavior is safe. Enhancement, not integrity fix. Adopted by Phase 78 but not implemented. |
| 5 | Cloud Sync / Multi-Device / Mobile | N/A | VERY HIGH | Production proof | Infrastructure. Deferred pending local stability. |

## Stage 4 — Governance Outcome

### Outcome: C — Multiple Valid Candidates, Unordered

**Evidence:**
- No document assigns "Phase 82" or any specific phase number after Phase 81
- No document explicitly orders DC-U002, DC-U007, DC-U008, or CAN-005/CAN-006 relative to each other
- DC-U002, DC-U007, DC-U008 were adopted by Phase 78 but the Decision Register still shows them as `REQUIRES OWNER DECISION` (documentation inconsistency)
- CAN-005/CAN-006 are in the Master Roadmap as `- [ ]` (not implemented) with no owner decision or implementation phase assigned
- DC-U014 is CLOSED in the Decision Register (`OWNER DECISION RECORDED — Phase 75`) and implemented in Phase 76
- The NEXT-PHASE-DECISION-GATE.md provides routing rules but does not assign a specific phase

### Documentation Inconsistency Found

The Decision Register (`ROADMAP-DECISION-REGISTER.md`) was not updated after Phase 78 adopted DC-U002, DC-U007, and DC-U008. The register still shows these as `REQUIRES OWNER DECISION`, while Phase 78 formally adopted them with specific implementation details. This inconsistency is noted but not corrected in this audit to preserve the register's current state.

### Recommendation (Not Assignment)

Based on integrity evidence, **DC-U007 (Negative-balance controls)** is recommended as the next implementation phase:

1. **Highest integrity impact** — Expenses and supplier payments can currently create negative balances without any guard
2. **Self-contained** — No dependencies on other candidates
3. **Foundation for reports** — Phase 79 reports note that DC-U007 affects report interpretation (negative balances must be shown correctly, not zero-clamped)
4. **Owner decision already adopted** — DC-U007 was adopted by Phase 78; only implementation is missing

### What This Audit Does NOT Do

- Does not assign a phase number (no "Phase 82")
- Does not create a commit or tag
- Does not modify any code or documentation beyond the 4 governance files
- Does not weaken the 784/784 test baseline
- Does not override the NEXT-PHASE-DECISION-GATE.md routing rules
- Does not describe any scope as IMPLEMENTED or COMPLETE merely because an owner decision was adopted

### Next Action

Await owner decision on which candidate to implement next. If owner selects DC-U007, the implementation phase should:
1. Add `allowNegativeBalance` field to `FinancialAccount` model
2. Add balance validation to expense and supplier-payment paths
3. Add owner-approval UI for negative-balance operations
4. Add audit trail for negative-balance overrides
5. Update backup contract to preserve `allowNegativeBalance`
6. Update reports to correctly show negative balances
