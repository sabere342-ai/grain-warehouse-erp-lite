import 'package:grain_warehouse_erp_lite/core/inventory/inventory_attention_service.dart';
import 'package:grain_warehouse_erp_lite/features/ai_assistant/contracts/ai_tool.dart';
import 'package:grain_warehouse_erp_lite/features/ai_assistant/models/ai_execution_response.dart';
import 'package:grain_warehouse_erp_lite/features/ai_assistant/models/ai_intent.dart';
import 'package:grain_warehouse_erp_lite/features/ai_assistant/models/ai_parameter.dart';

/// Read-only inventory-attention projection through the approved service.
final class InventoryAttentionTool implements AiTool {
  const InventoryAttentionTool({required InventoryAttentionReader service})
      : _service = service;

  final InventoryAttentionReader _service;

  @override
  String get id => 'inventory_attention';

  @override
  String get name => 'تنبيهات المخزون';

  @override
  String get description => 'يعرض الأصناف النافدة أو منخفضة المخزون.';

  @override
  List<AiToolParameter> get parameters => const [];

  @override
  Future<AiToolResult> execute(
    Map<String, Object?> parameters, {
    required AiExecutionMode executionMode,
  }) async {
    if (parameters.isNotEmpty) {
      throw const AiToolValidationException(
        message: 'لا يقبل هذا الإجراء أي معاملات.',
        errors: [AiValidationError(field: 'parameters', message: 'غير مدعوم.')],
      );
    }
    if (executionMode != AiExecutionMode.readOnly) {
      throw const AiToolValidationException(
        message: 'يتطلب هذا الإجراء وضع القراءة فقط.',
        errors: [
          AiValidationError(field: 'executionMode', message: 'غير مدعوم.')
        ],
      );
    }

    final items = await _service.loadAttention();
    return AiToolResult(
      messages: [
        items.isEmpty
            ? 'لا توجد أصناف تحتاج إلى متابعة.'
            : 'تم العثور على ${items.length} صنف يحتاج إلى متابعة.',
      ],
      tables: [
        AiResponseTable(
          columns: const [
            'productId',
            'productName',
            'quantityKg',
            'attentionReason',
            'isActive',
          ],
          rows: items
              .map((item) => [
                    item.productId,
                    item.productName,
                    item.quantityKg,
                    item.type == InventoryAttentionType.outOfStock
                        ? 'outOfStock'
                        : 'lowStock',
                    item.isActive,
                  ])
              .toList(growable: false),
        ),
      ],
    );
  }
}
