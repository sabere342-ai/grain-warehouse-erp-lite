# BUILD-02: Read-only inventory attention

BUILD-02 adds the deterministic `inventory_attention` AI action without a chat
UI, natural-language parsing, network access, or write operation.

## Canonical policy and boundary

`InventoryAttentionService` is a read-only application/domain facade over the
existing `ProductRepository` and `InventoryRepository` abstractions. It does
not access a database directly. Its product set is the repository-supplied set
including inactive products. Its authoritative quantity is the existing
inventory balance map.

- `outOfStock`: quantity in kilograms is `<= 0`
- `lowStock`: quantity in kilograms is `> 0 && <= 5`
- normal stock: omitted

Records are ordered by type (`outOfStock` first), quantity, name, then ID.
The dashboard alert section delegates to this service and only displays the
`lowStock` subset; the dashboard aggregate count includes all attention items.

## AI action

Tool ID: `inventory_attention`.

It has no parameters and requires `executionMode: readOnly`. It returns a
successful empty table when there are no attention records. The table columns
are `productId`, `productName`, `quantityKg`, `attentionReason`, and
`isActive`. Tool failures are safely converted by `AiExecutionService`; no
internal exception details are exposed.

Example structured intent:

```json
{
  "toolId": "inventory_attention",
  "parameters": {},
  "executionMode": "readOnly"
}
```

## Safeguards and exclusions

The AI tool imports only the approved service, not repository, database,
persistence, storage, or UI-global paths. The source-boundary test is a
maintainable safeguard, not a replacement for code review. No schema,
migration, backup, accounting, inventory write, navigation, or UI redesign is
included.

Focused tests cover classifications, threshold edges, deterministic ordering,
minimum-price independence, empty results, tool mode validation, and the tool
dependency boundary.

## Verification status

Windows release verification passed on 2026-07-18 using:

```powershell
C:\src\flutter\bin\flutter.bat build windows --release --no-pub -v
```

The command completed with exit code `0` and produced
`build\windows\x64\runner\Release\grain_warehouse_erp_lite.exe` (785,408
bytes; 2026-07-18 19:01:30 +03:00). No cache remediation was required.

The initial diagnostic invocation was intentionally verbose and persisted to
`.build-diagnostics/flutter-windows-release-20260718-182903.log`; it could not
enter Flutter because the restricted execution sandbox could not open
`C:\src\flutter\bin\cache\flutter.bat.lock` for writing. The successful
foreground diagnostic build is recorded in
`.build-diagnostics/flutter-windows-release-elevated-20260718-190013.log`.
That environment-only access restriction occurred before Flutter, CMake, or
MSBuild began, and required no application source change.

- `flutter analyze --no-pub`: passed with no issues.
- Focused tests: `ai_execution_service_test.dart` (7),
  `inventory_attention_service_test.dart` (3), and
  `inventory_attention_tool_test.dart` (4) all passed.
- Dashboard regression: `phase64_owner_dashboard_alerts_test.dart` passed
  (15 tests).
- Full suite: 1,299 passed, 0 failed, 1 skipped.
- `git diff --check`: passed.
- The credential-dependent skip in
  `test/phase9a_inflows_outflows_reports_test.dart:552` remains unchanged.
- No schema, migration, accounting or inventory write-path, or backup-contract
  changes were made.
- The unrelated advances-and-refunds report file remained unstaged and
  preserved.

Non-blocking environment warnings were unchanged: Flutter doctor reports that
Android Studio is not installed and cannot determine the VS Code version; the
native build reports a Firebase CMake deprecation warning and one MSVCRT
`LNK4078` linker warning.
