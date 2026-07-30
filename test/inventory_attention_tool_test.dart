import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:grain_warehouse_erp_lite/core/catalog/product_catalog_read_repository.dart';
import 'package:grain_warehouse_erp_lite/core/inventory/inventory_attention_service.dart';
import 'package:grain_warehouse_erp_lite/core/inventory/inventory_repository.dart';
import 'package:grain_warehouse_erp_lite/core/inventory/stock_movement.dart';
import 'package:grain_warehouse_erp_lite/features/ai_assistant/ai_assistant.dart';

void main() {
  test('registered inventory action returns a successful empty table',
      () async {
    final tool = InventoryAttentionTool(
      service: InventoryAttentionService(
        productCatalogReadRepository: _Products(),
        inventoryRepository: _Inventory(),
      ),
    );
    final service = AiExecutionService(registry: AiToolRegistry([tool]));

    final response = await service.execute(const AiIntent(
      name: 'inventory_attention',
      confidence: 1,
      parameters: {},
      executionMode: AiExecutionMode.readOnly,
    ));

    expect(response.isSuccess, isTrue);
    expect(response.tables.single.rows, isEmpty);
  });

  test('tool is read-only and uses a service boundary', () async {
    final source = await File(
            'lib/features/ai_assistant/tools/inventory_attention_tool.dart')
        .readAsString();
    expect(source, contains('InventoryAttentionReader'));
    expect(source, isNot(contains('_repository')));
    expect(source, isNot(contains('inventory_repository.dart')));
    expect(source, isNot(contains('product_repository.dart')));
  });

  test('wrong mode returns a structured validation failure', () async {
    final tool = InventoryAttentionTool(
      service: InventoryAttentionService(
        productCatalogReadRepository: _Products(),
        inventoryRepository: _Inventory(),
      ),
    );
    final response = await AiExecutionService(registry: AiToolRegistry([tool]))
        .execute(const AiIntent(
      name: 'inventory_attention',
      confidence: 1,
      parameters: {},
      executionMode: AiExecutionMode.execute,
    ));
    expect(response.status, AiResponseStatus.validationFailure);
  });

  test('service errors become safe structured failures', () async {
    final response = await AiExecutionService(
      registry:
          AiToolRegistry([InventoryAttentionTool(service: _FailingReader())]),
    ).execute(const AiIntent(
      name: 'inventory_attention',
      confidence: 1,
      parameters: {},
      executionMode: AiExecutionMode.readOnly,
    ));

    expect(response.status, AiResponseStatus.failure);
    expect(response.messages.single,
        'The requested operation could not be completed.');
  });
}

final class _Products implements ProductCatalogReadRepository {
  @override
  Future<List<ProductCatalogReadModel>> listProductCatalog({
    required bool includeInactive,
  }) async =>
      const [];
}

final class _Inventory implements InventoryRepository {
  @override
  Future<Map<String, int>> allProductBalancesKg(
          {bool activeProductsOnly = false}) async =>
      const {};
  @override
  Future<StockMovement> createMovement(StockMovementDraft draft) =>
      throw UnimplementedError();
  @override
  Future<int> currentStockKg(String productId) => throw UnimplementedError();
  @override
  Future<bool> hasOpeningBalance(String productId) =>
      throw UnimplementedError();
  @override
  Future<List<StockMovement>> listAllMovements() => throw UnimplementedError();
  @override
  Future<List<StockMovement>> listMovementsByProduct(String productId) =>
      throw UnimplementedError();
}

final class _FailingReader implements InventoryAttentionReader {
  @override
  Future<List<InventoryAttentionItem>> loadAttention() =>
      Future<List<InventoryAttentionItem>>.error(
          StateError('internal failure'));
}
