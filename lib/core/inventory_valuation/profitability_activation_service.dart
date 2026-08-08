import 'package:grain_warehouse_erp_lite/core/audit/audit_log_repository.dart';
import 'package:grain_warehouse_erp_lite/core/auth/app_user.dart';
import 'package:grain_warehouse_erp_lite/core/auth/user_role.dart';
import 'package:grain_warehouse_erp_lite/core/catalog/product_catalog_read_repository.dart';
import 'package:grain_warehouse_erp_lite/core/financial_accounts/repository_transaction.dart';
import 'package:grain_warehouse_erp_lite/core/inventory/inventory_repository.dart';
import 'package:grain_warehouse_erp_lite/core/inventory_valuation/inventory_valuation.dart';
import 'package:grain_warehouse_erp_lite/core/inventory_valuation/inventory_valuation_repository.dart';

class ProfitabilityActivationService {
  ProfitabilityActivationService({
    required ProductCatalogReadRepository productCatalogReadRepository,
    required InventoryRepository inventoryRepository,
    required DurableInventoryValuationRepository valuationRepository,
    required AuditLogRepository auditLogRepository,
    Future<void> Function(DateTime value)? ensureDateOpen,
    DateTime Function()? clock,
  })  : _productCatalogReadRepository = productCatalogReadRepository,
        _inventoryRepository = inventoryRepository,
        _valuationRepository = valuationRepository,
        _auditLogRepository = auditLogRepository,
        _ensureDateOpen = ensureDateOpen,
        _clock = clock ?? DateTime.now;

  final ProductCatalogReadRepository _productCatalogReadRepository;
  final InventoryRepository _inventoryRepository;
  final DurableInventoryValuationRepository _valuationRepository;
  final AuditLogRepository _auditLogRepository;
  final Future<void> Function(DateTime value)? _ensureDateOpen;
  final DateTime Function() _clock;

  Future<void> activate({
    required AppUser user,
    required DateTime activationDate,
    required String evidenceNote,
    required List<OpeningValuationInput> openings,
  }) async {
    _ensureOwner(user);
    final now = _clock();
    if (activationDate.isAfter(now)) {
      throw ArgumentError('Activation date cannot be in the future.');
    }
    final note = evidenceNote.trim();
    if (note.isEmpty) {
      throw ArgumentError('Activation evidence note is required.');
    }
    await _ensureDateOpen?.call(activationDate);
    final products = await _productCatalogReadRepository.listProductCatalog(
      includeInactive: true,
    );
    final inputByProduct = <String, OpeningValuationInput>{};
    for (final input in openings) {
      final id = input.productId.trim();
      if (id.isEmpty || inputByProduct.containsKey(id)) {
        throw ArgumentError('Opening product ids must be present and unique.');
      }
      inputByProduct[id] = input;
    }
    if (inputByProduct.length != products.length) {
      throw StateError('Every existing product requires an opening decision.');
    }
    final productIds = products.map((product) => product.id).toSet();
    if (!inputByProduct.keys.every(productIds.contains)) {
      throw StateError('Opening valuation references an unknown product.');
    }
    for (final product in products) {
      final input = inputByProduct[product.id]!;
      final actualQuantity =
          await _inventoryRepository.currentStockKg(product.id);
      if (input.quantityKg != actualQuantity) {
        throw StateError(
          'Opening quantity does not match the approved physical inventory.',
        );
      }
      if (actualQuantity > 0 && input.unitCostQirshPerKg <= 0) {
        throw StateError('Every stocked product requires a trustworthy cost.');
      }
      if (input.evidenceReference.trim().isEmpty) {
        throw StateError('Every product requires an evidence reference.');
      }
    }

    final snapshots = <SnapshotHolder>[
      _valuationRepository.createTransactionSnapshot(),
    ];
    final audit = _auditLogRepository;
    if (audit is! TransactionSnapshotProvider) {
      throw StateError('Audit repository cannot join activation transaction.');
    }
    snapshots.add(
      (audit as TransactionSnapshotProvider).createTransactionSnapshot(),
    );
    await RepositoryTransaction.execute(snapshots, () async {
      await _valuationRepository.activate(
        activationDate: activationDate,
        approvedByUserId: user.id,
        evidenceNote: note,
        openings:
            products.map((product) => inputByProduct[product.id]!).toList(),
      );
      await audit.record(AuditLogDraft(
        actionType: 'profitability.activated',
        descriptionAr: 'تم اعتماد مخزون بداية الربحية وتاريخ التفعيل.',
        actorId: user.id,
        referenceId: 'profitability-activation',
        metadata: {
          'activationDate': activationDate.toIso8601String(),
          'productCount': products.length,
          'evidenceNote': note,
        },
      ));
    });
  }

  void _ensureOwner(AppUser user) {
    if (!user.canProceed || user.role != UserRole.owner) {
      throw StateError('Profitability activation is owner-only.');
    }
  }
}
