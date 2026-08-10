# Product Read inventory at Phase 108A

Current truth remains **24 governed consumers: 19 migrated, 5 remaining**.
There are 20 catalog-backed calls because PRC-109 owns two calls, and six
legacy calls because PRC-114 owns two. No production consumer remains legacy.

| ID | Consumer | Calls | Layer | Current classification | Timing decision |
| --- | --- | ---: | --- | --- | --- |
| PRC-114 | `LocalInventoryRepository` balance enumeration and lookup | 2 | Infrastructure/test fallback | Remaining | Can remain temporarily; migrate or retire with local-data-source refactor |
| PRC-115 | `LocalPurchaseRepository` product validation | 1 | Infrastructure/test fallback | Remaining | Can remain temporarily; migrate during Cloud repository refactor |
| PRC-116 | Synthetic profitability activation emptiness guard | 1 | Explicit synthetic test tool | Remaining | Can remain temporarily; preserve as deliberate test-only exception or migrate with its fixture |
| PRC-117 | `_LegacyProductCatalogReadRepository` compatibility adapter | 1 | Composition compatibility | Remaining | Should migrate during Cloud refactor; retire before a remote catalog is production-authoritative |
| PRC-118 | Drift product rollback snapshot self-read | 1 | Infrastructure rollback semantics | Remaining | Can remain temporarily; reassess when local snapshots become cache/outbox transactions |

Decision: do not spend five isolated phases merely to reach zero. Production
reads are already migrated. PRC-114/115/117 should be handled with the upcoming
repository/composition refactor, while PRC-116/118 may remain explicit local
infrastructure exceptions until their owning mechanisms change. This avoids
editing fallback code twice before and during Cloud work.
