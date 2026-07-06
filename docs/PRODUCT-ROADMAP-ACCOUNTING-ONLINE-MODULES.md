# Product Roadmap - Accounting and Online Modules

These items are planning only. They are not implemented in Phase 30 and must not be added randomly.

The current target is one customer/user running a local desktop pilot. SaaS and licensing are deferred.

## Future phases

1. Visible pages readiness and UI consistency.
2. Cashbox foundation.
3. Customer credit/deferred sales.
4. Customer collections.
5. Supplier payment tracking.
6. Bank account tracking.
7. Electronic wallet tracking.
8. Financial reports.
9. Installer/customer-safe delivery.
10. Supabase architecture spike.
11. Supabase single-customer online model.
12. Supabase Auth and RLS policies.
13. Online read dashboard.
14. Phone access/read-only dashboard.
15. Mobile transaction support only after sync and security are proven.

## Rules

- Each module needs its own phase.
- Each phase needs focused tests.
- Each phase needs rollback thinking.
- Finance modules must not weaken current sales, purchase, inventory, pricing, backup, or restore behavior.
- Online work must start with architecture and security, not quick UI promises.
- SaaS/licensing is deferred until the single-customer product is coherent.
