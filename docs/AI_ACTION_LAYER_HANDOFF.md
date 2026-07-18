# AI Action Layer handoff

Delivered an isolated execution foundation under `lib/features/ai_assistant`.
No application composition or UI behavior was changed, so no business command
is exposed until a reviewed tool is deliberately registered.

The registry is the security allow-list. Keep it immutable and compose it from
explicit tool instances. Each tool must call an existing controller, preserving
its permissions, validation, transactions, audit paths, and financial rules.

Run `flutter analyze` and `flutter test test/ai_execution_service_test.dart`
after changes. The module has no persistence dependencies and does not affect
backup or restore formats.

## BUILD-02 inventory attention integration

`inventory_attention` is a read-only tool that receives an explicitly injected
`InventoryAttentionService`. The tool has no repository, database, persistence,
or UI-global imports. It requires `AiExecutionMode.readOnly` and returns a
structured table with `productId`, `productName`, `quantityKg`,
`attentionReason`, and `isActive`.

The service is the canonical product-level inventory-attention boundary. It
reads existing product and inventory repository abstractions, classifies stock
as `outOfStock` when quantity is `<= 0` and `lowStock` when quantity is
`> 0 && <= 5`, and returns deterministic immutable records. Dashboard consumers
delegate to the same service; no inventory, accounting, or backup contract is
changed.
