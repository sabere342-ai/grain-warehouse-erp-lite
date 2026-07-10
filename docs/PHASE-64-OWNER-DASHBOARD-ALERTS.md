# Phase 64 — Owner Dashboard Alerts & Read-Only Risk Signals

## Purpose
Add a read-only alerts/risk-signals section to the owner dashboard. The section surfaces customer balance alerts, supplier payable alerts, low-stock alerts, a backup reminder, and a trial reminder — all derived from existing repositories without mutation.

## Files Created
- `lib/features/dashboard/dashboard_alerts_section.dart`
  - `OwnerAlertData` — data class with static `load()` method
  - `OwnerAlertsSection` — widget that displays alerts in a `PremiumCard`
  - Internal private classes for customer, supplier, and stock alert items

## Files Modified
- `lib/features/dashboard/dashboard_screen.dart`
  - Added `OwnerAlertsSection` after the metrics grid (read-only section at bottom)

## Test File
- `test/phase64_owner_dashboard_alerts_test.dart` — 15 tests covering:
  - `OwnerAlertData.empty()` — returns empty data
  - Empty repositories → no alerts
  - Customer with balance > 0 → detected
  - Customer with zero balance → ignored
  - Supplier with payable > 0 → detected
  - Supplier with zero balance → ignored
  - Low stock (> 0 && <= 5 kg) → detected
  - Stock > 5 kg → ignored
  - Zero stock → ignored
  - Sorted descending by amount
  - All customers/suppliers returned (UI limits display via `.take(5)`)
  - Read-only — no repository mutation
  - Combined alerts

## Design Decisions
- **Read-only**: `OwnerAlertData.load()` accepts optional repository overrides (defaults to `AppRepositories`). No writes occur during loading.
- **Testability**: Repositories can be injected into `load()` for isolated unit tests.
- **No new schema**: All data is derived from existing `CustomerAccountRepository`, `SupplierAccountRepository`, `InventoryRepository`, `CustomerRepository`, `SupplierRepository`, and `ProductRepository`.
- **Low-stock threshold**: Fixed at `> 0 && <= 5` weight units. No formal reorder-point field exists in `Product`.
- **Static reminders**: Backup reminder and trial reminder are generic static text — no tracked backup metadata exists in the codebase.
- **Arabic labels**: All user-facing text is in Arabic.

## Widget Placement
The `OwnerAlertsSection` is placed after the metrics grid and before the disclaimer card at the bottom of the dashboard ListView. This avoids affecting existing dashboard UI tests that check for metric card text.

## Counts
- Pre-existing tests: 527
- New tests: 15
- Total: 542
