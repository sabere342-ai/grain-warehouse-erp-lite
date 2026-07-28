# Phase 104G Audit-Log Runtime Smoke Evidence

Execution timestamp: 2026-07-29T01:04:40+03:00 through 2026-07-29T01:12:45+03:00.

Time zone: Africa/Cairo (UTC+03:00).

Commit: Runtime candidate based on `543c69ab3ecdf49948e7e6c6f1abdc63a7a5e06c` plus the uncommitted Phase 104G changes; final commit recorded in the phase report.

Executable path: `C:\dev\multi-pos\grain-warehouse-erp-lite\build\windows\x64\runner\Release\grain_warehouse_erp_lite.exe`.

Executable SHA-256: `5EC48761335E72E799B2F34BE2B148E7D5B43867C2CB411DA49E75DB3B63C72C`.

Executable size: 784,384 bytes. The rebuilt Dart AOT payload at `data\app.so` was 11,781,024 bytes and was modified at 2026-07-29T01:08:54.968+03:00.

Runtime environment: Windows AMD64 interactive session 4, Flutter 3.24.5, Dart 3.5.4. The release bundle was built successfully with `flutter.bat build windows --release --no-pub` (exit code 0, 127.8 seconds).

User/role: A read-only preflight confirmed one active local owner account. Sign-in was blocked before the first GUI frame, and no credential was recorded or exposed.

Database: Existing local controlled Grala database. A read-only preflight recorded counts only (one owner and 43 audit rows) and showed smoke-like local data. No database reset, mutation, or customer-identifying value was performed or recorded. A process-local APPDATA isolation attempt did not redirect Flutter's Windows known-folder path.

Audit screen load: **Blocked.** The release process remained alive and responsive, but it never created a top-level window or first Flutter frame, so the real navigation path could not be reached.

Write-to-read visibility: **Blocked in GUI runtime.** Behavioral Phase 104G tests cover both Local and Drift public write-to-read paths, but those tests are not represented as GUI evidence.

Restart persistence: **Blocked in GUI runtime.** No runtime audit write could be created before restart.

Navigation: **Blocked.** Sign-in, audit navigation, back navigation, and screen reopening could not be exercised because no top-level window appeared.

Runtime errors: No process crash was observed. The Flutter-attached release launch logged only the expected unconfigured-Firebase `UnsupportedError`, which `FirebaseBootstrap` catches. No exception, cast error, or type mismatch was logged, but absence of a first frame prevents a runtime-screen success claim.

Audit entry creation: **Blocked.** No GUI operation could be performed; the local database was deliberately left unchanged.

Limitations: **SAFE BLOCKED.** Three release launches were attempted: direct `Start-Process` (PID 7048), Flutter-attached release launch (PID 24224), and Explorer-brokered launch (PID 11304). Each process remained alive and responsive for at least 25 seconds but reported `MainWindowHandle = 0`; Win32 top-level-window enumeration also found no window. The Flutter-attached run built successfully and logged the caught Firebase configuration notice, then produced no first frame. Consequently empty/list rendering, Arabic description/date/reference display, write visibility, persistence, and navigation are not claimed as runtime passes. No screenshots or video were captured because there was no application window to capture.

## Step results

| Step | Result | Evidence |
|---|---|---|
| Release build | Pass | Exit code 0; fresh `data\app.so` timestamp 2026-07-29T01:08:54.968+03:00 |
| Process launch without crash | Pass | Three responsive release processes observed |
| First Flutter frame | Blocked | No top-level window; `MainWindowHandle = 0` |
| Owner sign-in | Blocked | No GUI surface |
| Audit screen via real navigation | Blocked | No GUI surface |
| Empty or populated list rendering | Blocked | No GUI surface |
| Runtime audit write and refresh | Blocked | No GUI surface; database left unchanged |
| Ordering, Arabic description, date/time, reference | Blocked | No GUI surface |
| Close/reopen persistence | Blocked | No runtime write to persist |
| Back navigation and presentation behavior | Blocked | No GUI surface |
