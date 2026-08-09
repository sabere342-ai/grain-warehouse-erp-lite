# Architecture discovery

- Startup entry: `lib/main.dart`; Flutter binding, Firebase, and production repositories initialize before `runApp`.
- Database initialization: `AppRepositories.initializeProduction()` opens the one Drift `FoundationDatabase` through `openProductionDatabase()`.
- Authentication gate: `AuthGate` selects checking, first-owner setup, login, or dashboard from `AuthController` state.
- First-owner setup: `FirstOwnerSetupScreen`, reached only through `AuthGate` when no owner exists.
- Saved session: `AuthController.initialize()` asks the durable auth repository for `currentUser()` before checking owner existence.
- Navigation: `MaterialApp` owns named login/setup/dashboard routes; `DashboardShell` owns business navigation.
- Existing local settings: theme and business identity use per-user files; the database uses `getApplicationSupportDirectory()`.
- Best global trial gate: a root widget outside the complete `GrainWarehouseApp`, so no `MaterialApp` route or restored session exists when blocked.
- Best independent trial storage: `trial_runtime` under the application-support directory, outside Drift and business backups.
- Clock: injectable `TrialClock`; production uses `DateTime.now().toUtc()`.
- Active UI: small non-interactive overlay badge.
- Blocked UI: standalone Arabic `MaterialApp`; the business application child is not built.
