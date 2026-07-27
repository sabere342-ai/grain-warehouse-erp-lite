import 'package:grain_warehouse_erp_lite/core/catalog/product.dart';
import 'package:grain_warehouse_erp_lite/core/catalog/product_repository.dart';
import 'package:grain_warehouse_erp_lite/core/documents/cancellation_metadata.dart';
import 'package:grain_warehouse_erp_lite/core/financial_accounts/financial_account_entry.dart';
import 'package:grain_warehouse_erp_lite/core/financial_accounts/financial_account_repository.dart';
import 'package:grain_warehouse_erp_lite/core/financial_accounts/payment_routing_policy.dart';
import 'package:grain_warehouse_erp_lite/core/inventory/inventory_repository.dart';
import 'package:grain_warehouse_erp_lite/core/inventory/stock_movement.dart';
import 'package:grain_warehouse_erp_lite/core/purchases/purchase_intake.dart';
import 'package:grain_warehouse_erp_lite/core/supplier_accounts/supplier_account_repository.dart';
import 'package:grain_warehouse_erp_lite/core/suppliers/supplier.dart';
import 'package:grain_warehouse_erp_lite/core/suppliers/supplier_repository.dart';
import 'package:grain_warehouse_erp_lite/core/audit/audit_log_repository.dart';
import 'package:grain_warehouse_erp_lite/core/financial_accounts/repository_transaction.dart';
import 'package:grain_warehouse_erp_lite/core/inventory_valuation/inventory_valuation_repository.dart';

abstract class PurchaseRepository {
  Future<PurchaseIntake> createPurchaseIntake(PurchaseIntakeDraft draft);

  Future<PurchaseIntake> cancelPurchaseIntake({
    required String purchaseIntakeId,
    required String cancelledByUserId,
    required String cancellationReason,
  });

  Future<List<PurchaseIntake>> listPurchaseIntakes();
}

abstract class DurablePurchaseRepository
    implements PurchaseRepository, TransactionSnapshotProvider {
  Future<void> restorePurchaseIntakesIntoEmpty(List<PurchaseIntake> intakes);

  Future<void> clearForOwnerDataWipe();
}

class LocalPurchaseRepository implements DurablePurchaseRepository {
  LocalPurchaseRepository({
    required SupplierRepository supplierRepository,
    required ProductRepository productRepository,
    required InventoryRepository inventoryRepository,
    SupplierAccountRepository? supplierAccountRepository,
    FinancialAccountRepository? financialAccountRepository,
    AuditLogRepository? auditLogRepository,
    InventoryValuationRepository? inventoryValuationRepository,
  })  : _supplierRepository = supplierRepository,
        _productRepository = productRepository,
        _inventoryRepository = inventoryRepository,
        _supplierAccountRepository = supplierAccountRepository,
        _financialAccountRepository = financialAccountRepository,
        _inventoryValuationRepository = inventoryValuationRepository,
        _auditLogRepository = auditLogRepository ?? LocalAuditLogRepository();

  final SupplierRepository _supplierRepository;
  final ProductRepository _productRepository;
  final InventoryRepository _inventoryRepository;
  final SupplierAccountRepository? _supplierAccountRepository;
  final FinancialAccountRepository? _financialAccountRepository;
  final InventoryValuationRepository? _inventoryValuationRepository;
  final AuditLogRepository _auditLogRepository;
  final List<PurchaseIntake> _intakes = [];
  final Map<String, String> _purchaseRequestIntakeIds = {};
  int _generatedIdCounter = 0;

  @override
  Future<PurchaseIntake> createPurchaseIntake(
    PurchaseIntakeDraft draft,
  ) async {
    final supplier = await _validateSupplier(draft.supplierId);
    final product = await _validateProduct(draft.productId);
    _validateDraft(draft);
    await _validateNewPaymentRoute(draft);

    final now = DateTime.now();
    await _financialAccountRepository?.ensureDateIsOpen(now);
    final intake = PurchaseIntake(
      id: _generatePurchaseIntakeId(now),
      supplierId: supplier.id,
      supplierName:
          _normalizedOptionalText(draft.supplierName ?? supplier.name),
      supplierPhone:
          _normalizedOptionalText(draft.supplierPhone ?? supplier.phone),
      supplierAddress:
          _normalizedOptionalText(draft.supplierAddress ?? supplier.address),
      productId: product.id,
      quantityKg: draft.quantityKg,
      entryUnit: draft.entryUnit,
      unitPricePiastersPerKg: draft.unitPricePiastersPerKg,
      totalAmountPiasters: draft.totalAmountPiasters,
      createdByUserId: draft.createdByUserId.trim(),
      createdAt: now,
      stockMovementId: 'pending',
      notes: _normalizedOptionalText(draft.notes),
      financialAccountId: draft.financialAccountId,
      paymentMethod: draft.paymentMethod,
      paymentMode: draft.paymentMode,
      paidAmountQirsh: draft.paidAmountQirsh,
      negativeBalanceApprovalId: draft.negativeBalanceApprovalId,
    );

    if (!intake.hasValidId) {
      throw StateError('Purchase intake id is required.');
    }

    final snapshots = <SnapshotHolder>[createTransactionSnapshot()];
    snapshots.add(_requiredSnapshot(_inventoryRepository, 'inventory'));
    if (_supplierAccountRepository != null) {
      snapshots.add(_requiredSnapshot(_supplierAccountRepository, 'supplier'));
    }
    if (_financialAccountRepository != null) {
      snapshots
          .add(_requiredSnapshot(_financialAccountRepository, 'financial'));
    }
    if (_inventoryValuationRepository != null) {
      snapshots
          .add(_requiredSnapshot(_inventoryValuationRepository, 'valuation'));
    }
    if (_auditLogRepository is! TransactionSnapshotProvider) {
      throw StateError(
          'Purchase audit repository cannot participate in a transaction.');
    }
    snapshots.add((_auditLogRepository as TransactionSnapshotProvider)
        .createTransactionSnapshot());

    return RepositoryTransaction.execute(snapshots, () async {
      final requestId = _normalizedOptionalText(draft.operationRequestId);
      if (requestId != null &&
          _purchaseRequestIntakeIds.containsKey(requestId)) {
        final existing = _intakes.firstWhere(
          (value) => value.id == _purchaseRequestIntakeIds[requestId],
          orElse: () => throw StateError(
            'Purchase replay record is unavailable.',
          ),
        );
        if (_purchaseFingerprintForIntake(existing) !=
            _purchaseFingerprint(draft)) {
          throw StateError('Purchase request payload does not match replay.');
        }
        return existing;
      }

      final movement = await _inventoryRepository.createMovement(
        StockMovementDraft(
          productId: intake.productId,
          movementType: StockMovementType.purchaseIntake,
          quantityKg: intake.quantityKg,
          createdByUserId: intake.createdByUserId,
          note: 'استلام شراء ${intake.id}',
          originalDocumentId: intake.id,
        ),
      );

      final postedIntake = intake.copyWith(stockMovementId: movement.id);
      await _inventoryValuationRepository?.recordPurchase(
        productId: postedIntake.productId,
        quantityKg: postedIntake.quantityKg,
        unitCostQirshPerKg: postedIntake.unitPricePiastersPerKg,
        sourceDocumentId: postedIntake.id,
        effectiveDate: postedIntake.createdAt,
        createdByUserId: postedIntake.createdByUserId,
      );
      _intakes.add(postedIntake);
      if (postedIntake.outstandingAmountQirsh > 0) {
        await _supplierAccountRepository?.createPurchaseEntry(
          purchase: postedIntake,
        );
      }

      final faRepo = _financialAccountRepository;
      if (faRepo != null &&
          postedIntake.financialAccountId != null &&
          postedIntake.financialAccountId!.isNotEmpty &&
          postedIntake.paymentMode != PurchasePaymentMode.credit) {
        final paidAmount = postedIntake.effectivePaidAmountQirsh;
        if (paidAmount > 0) {
          await faRepo.createEntry(
            accountId: postedIntake.financialAccountId!,
            direction: FinancialAccountEntryDirection.outflow,
            amountQirsh: paidAmount,
            sourceType: FinancialAccountEntrySource.purchasePayment,
            sourceDocumentId: postedIntake.id,
            effectiveDate: postedIntake.createdAt,
            createdByUserId: postedIntake.createdByUserId,
            reference: 'دفعة مشتريات - استلام ${postedIntake.id}',
            note: postedIntake.paymentMode == PurchasePaymentMode.partial
                ? 'دفع جزئي'
                : 'دفعة كاملة',
            paymentMethod: postedIntake.paymentMethod,
            approvedByUserId: draft.approvedByUserId,
            negativeBalanceApprovalId: draft.negativeBalanceApprovalId,
            approvalSourceDocumentId: draft.operationRequestId,
          );
        }
      }
      await _auditLogRepository.record(
        AuditLogDraft(
          actionType: 'purchase.created',
          descriptionAr: 'ØªÙ… ØªØ³Ø¬ÙŠÙ„ Ø§Ø³ØªÙ„Ø§Ù… Ø´Ø±Ø§Ø¡.',
          referenceId: postedIntake.id,
        ),
      );
      if (requestId != null) {
        _purchaseRequestIntakeIds[requestId] = postedIntake.id;
      }

      return postedIntake;
    });
  }

  @override
  Future<PurchaseIntake> cancelPurchaseIntake({
    required String purchaseIntakeId,
    required String cancelledByUserId,
    required String cancellationReason,
  }) async {
    final intakeIndex =
        _intakes.indexWhere((intake) => intake.id == purchaseIntakeId);
    if (intakeIndex < 0) {
      throw StateError('Purchase intake was not found.');
    }

    final intake = _intakes[intakeIndex];
    if (intake.isCancelled) {
      return intake;
    }
    final userId = cancelledByUserId.trim();
    if (userId.isEmpty) {
      throw ArgumentError.value(
        cancelledByUserId,
        'cancelledByUserId',
        'Cancelled by user id is required.',
      );
    }
    final reason = _normalizedOptionalText(cancellationReason);
    if (reason == null) {
      throw ArgumentError.value(
        cancellationReason,
        'cancellationReason',
        'Cancellation reason is required.',
      );
    }
    await _validatePurchaseCancellationStock(intake);
    final cancelledAt = DateTime.now();
    await _financialAccountRepository?.ensureDateIsOpen(cancelledAt);
    if (_inventoryValuationRepository != null &&
        !await _inventoryValuationRepository
            .canDirectlyCancelPurchase(intake.id)) {
      throw StateError(
          'Purchase is already mixed or used; record a current-dated correction instead.');
    }

    final snapshots = <SnapshotHolder>[createTransactionSnapshot()];
    snapshots.add(_requiredSnapshot(_inventoryRepository, 'inventory'));
    if (_supplierAccountRepository != null) {
      snapshots.add(_requiredSnapshot(_supplierAccountRepository, 'supplier'));
    }
    if (_financialAccountRepository != null) {
      snapshots
          .add(_requiredSnapshot(_financialAccountRepository, 'financial'));
    }
    if (_inventoryValuationRepository != null) {
      snapshots
          .add(_requiredSnapshot(_inventoryValuationRepository, 'valuation'));
    }
    snapshots.add(_requiredSnapshot(_auditLogRepository, 'audit'));

    return RepositoryTransaction.execute(snapshots, () async {
      final reversal = await _inventoryRepository.createMovement(
        StockMovementDraft(
          productId: intake.productId,
          movementType: StockMovementType.purchaseCancellation,
          quantityKg: intake.quantityKg,
          createdByUserId: userId,
          note: 'إلغاء استلام شراء ${intake.id}: $reason',
          reversedMovementId: intake.stockMovementId,
          originalDocumentId: intake.id,
        ),
      );
      await _inventoryValuationRepository?.reversePurchase(
        originalPurchaseDocumentId: intake.id,
        sourceDocumentId: intake.id,
        effectiveDate: cancelledAt,
        createdByUserId: userId,
        reason: reason,
      );
      final cancelled = intake.copyWith(
        cancellation: CancellationMetadata(
          cancelledAt: cancelledAt,
          cancelledByUserId: userId,
          cancellationReason: reason,
          originalDocumentId: intake.id,
          reversalMovementIds: [reversal.id],
        ),
      );
      _intakes[intakeIndex] = cancelled;
      if (cancelled.outstandingAmountQirsh > 0) {
        await _supplierAccountRepository?.reversePurchaseEntry(
          cancelledPurchase: cancelled,
          cancelledByUserId: userId,
          cancellationReason: reason,
        );
      }

      final faRepo = _financialAccountRepository;
      if (faRepo != null &&
          cancelled.financialAccountId != null &&
          cancelled.financialAccountId!.isNotEmpty &&
          cancelled.paymentMode != PurchasePaymentMode.credit) {
        final paidAmount = cancelled.effectivePaidAmountQirsh;
        if (paidAmount > 0) {
          await faRepo.createEntry(
            accountId: cancelled.financialAccountId!,
            direction: FinancialAccountEntryDirection.inflow,
            amountQirsh: paidAmount,
            sourceType: FinancialAccountEntrySource.cancellationReversal,
            sourceDocumentId: cancelled.id,
            effectiveDate: DateTime.now(),
            createdByUserId: userId,
            reversalOf: cancelled.id,
            reference: 'عكس إلغاء استلام شراء ${cancelled.id}',
            note: 'إلغاء استلام شراء: $reason',
            paymentMethod: cancelled.paymentMethod,
          );
        }
      }
      await _auditLogRepository.record(
        AuditLogDraft(
          actionType: 'purchase.cancelled',
          descriptionAr: 'تم إلغاء استلام شراء.',
          referenceId: cancelled.id,
        ),
      );
      return cancelled;
    });
  }

  Future<void> _validatePurchaseCancellationStock(PurchaseIntake intake) async {
    final currentStock = await _inventoryRepository.currentStockKg(
      intake.productId,
    );
    if (currentStock < intake.quantityKg) {
      throw StateError(
        'Purchase cancellation would make stock negative for product '
        '${intake.productId}.',
      );
    }
  }

  @override
  Future<List<PurchaseIntake>> listPurchaseIntakes() async {
    return List<PurchaseIntake>.unmodifiable(_intakes);
  }

  @override
  Future<void> restorePurchaseIntakesIntoEmpty(
    List<PurchaseIntake> intakes,
  ) async {
    if (_intakes.isNotEmpty) {
      throw StateError('Purchase repository is not empty.');
    }
    _validateUniqueRestoredIntakes(intakes);
    _intakes.addAll(intakes);
  }

  @override
  Future<void> clearForOwnerDataWipe() async {
    _intakes.clear();
    _purchaseRequestIntakeIds.clear();
    _generatedIdCounter = 0;
  }

  @override
  SnapshotHolder createTransactionSnapshot() {
    return ObjectStateSnapshot<
        (List<PurchaseIntake>, Map<String, String>, int)>(
      captureState: () => (
        List<PurchaseIntake>.from(_intakes),
        Map<String, String>.from(_purchaseRequestIntakeIds),
        _generatedIdCounter,
      ),
      restoreState: (state) {
        _intakes
          ..clear()
          ..addAll(state.$1);
        _purchaseRequestIntakeIds
          ..clear()
          ..addAll(state.$2);
        _generatedIdCounter = state.$3;
      },
    );
  }

  Future<Supplier> _validateSupplier(String supplierId) async {
    if (supplierId.trim().isEmpty) {
      throw ArgumentError.value(
        supplierId,
        'supplierId',
        'Supplier id is required.',
      );
    }

    final suppliers =
        await _supplierRepository.listSuppliers(includeInactive: true);
    for (final supplier in suppliers) {
      if (supplier.id == supplierId) {
        if (!supplier.isActive) {
          throw StateError('Inactive supplier cannot be used.');
        }

        return supplier;
      }
    }

    throw StateError('Supplier was not found.');
  }

  Future<Product> _validateProduct(String productId) async {
    if (productId.trim().isEmpty) {
      throw ArgumentError.value(
        productId,
        'productId',
        'Product id is required.',
      );
    }

    final products =
        await _productRepository.listProducts(includeInactive: true);
    for (final product in products) {
      if (product.id == productId) {
        if (!product.isActive) {
          throw StateError('Inactive product cannot be used.');
        }

        return product;
      }
    }

    throw StateError('Product was not found.');
  }

  void _validateDraft(PurchaseIntakeDraft draft) {
    if (draft.createdByUserId.trim().isEmpty) {
      throw ArgumentError.value(
        draft.createdByUserId,
        'createdByUserId',
        'Created by user id is required.',
      );
    }
    if (draft.quantityKg <= 0) {
      throw ArgumentError.value(
        draft.quantityKg,
        'quantityKg',
        'Quantity must be positive.',
      );
    }
    if (draft.unitPricePiastersPerKg <= 0) {
      throw ArgumentError.value(
        draft.unitPricePiastersPerKg,
        'unitPricePiastersPerKg',
        'Unit price must be positive.',
      );
    }
    final paid = draft.paidAmountQirsh;
    if (draft.paymentMode == PurchasePaymentMode.credit &&
        paid != null &&
        paid != 0) {
      throw ArgumentError.value(
        paid,
        'paidAmountQirsh',
        'Credit purchases cannot include an immediate payment.',
      );
    }
    if (draft.paymentMode == PurchasePaymentMode.credit &&
        (draft.financialAccountId?.trim().isNotEmpty == true ||
            draft.paymentMethod != null ||
            draft.negativeBalanceApprovalId?.trim().isNotEmpty == true)) {
      throw ArgumentError(
        'Credit purchases cannot include a payment route or approval.',
      );
    }
    if (draft.paymentMode == PurchasePaymentMode.paid &&
        paid != null &&
        paid != draft.totalAmountPiasters) {
      throw ArgumentError.value(
        paid,
        'paidAmountQirsh',
        'Paid purchases must settle the full total.',
      );
    }
    if (draft.paymentMode == PurchasePaymentMode.partial &&
        (paid == null || paid <= 0 || paid >= draft.totalAmountPiasters)) {
      throw ArgumentError.value(
        paid,
        'paidAmountQirsh',
        'Partial purchase payment must be positive and below the total.',
      );
    }
  }

  Future<void> _validateNewPaymentRoute(PurchaseIntakeDraft draft) async {
    if (draft.paymentMode == PurchasePaymentMode.credit ||
        draft.effectivePaidAmountQirsh <= 0) {
      return;
    }
    final accountId = _normalizedOptionalText(draft.financialAccountId);
    if (accountId == null) {
      throw StateError('الحساب المالي مطلوب لسداد الشراء.');
    }
    final paymentMethod = draft.paymentMethod;
    if (paymentMethod == null) {
      throw StateError('طريقة الدفع مطلوبة لسداد الشراء.');
    }
    final repository = _financialAccountRepository;
    if (repository == null) {
      throw StateError('مستودع الحسابات المالية غير مهيأ لسداد الشراء.');
    }
    final account = await repository.accountById(accountId);
    PaymentRoutingPolicy.validateAccount(
      account: account,
      paymentMethod: paymentMethod,
    );
  }

  void _validateUniqueRestoredIntakes(List<PurchaseIntake> intakes) {
    final ids = <String>{};
    for (final intake in intakes) {
      if (!intake.hasValidId || !ids.add(intake.id)) {
        throw StateError('Invalid purchase intake id.');
      }
      if (intake.supplierId.trim().isEmpty ||
          intake.productId.trim().isEmpty ||
          intake.quantityKg <= 0 ||
          intake.unitPricePiastersPerKg <= 0 ||
          intake.totalAmountPiasters <= 0 ||
          intake.createdByUserId.trim().isEmpty ||
          intake.stockMovementId.trim().isEmpty) {
        throw StateError('Invalid purchase intake data.');
      }
    }
  }

  String _generatePurchaseIntakeId(DateTime now) {
    _generatedIdCounter++;
    return 'pin-${now.microsecondsSinceEpoch}-$_generatedIdCounter';
  }

  SnapshotHolder _requiredSnapshot(Object repository, String name) {
    if (repository is! TransactionSnapshotProvider) {
      throw StateError(
          'Purchase $name repository cannot participate in a transaction.');
    }
    return repository.createTransactionSnapshot();
  }

  String _purchaseFingerprint(PurchaseIntakeDraft draft) {
    return [
      draft.supplierId.trim(),
      draft.productId.trim(),
      draft.quantityKg,
      draft.unitPricePiastersPerKg,
      draft.paymentMode.name,
      draft.effectivePaidAmountQirsh,
      draft.financialAccountId?.trim() ?? '',
      draft.paymentMethod?.name ?? '',
      draft.negativeBalanceApprovalId?.trim() ?? '',
      draft.createdByUserId.trim(),
    ].join('|');
  }

  String _purchaseFingerprintForIntake(PurchaseIntake intake) {
    return [
      intake.supplierId.trim(),
      intake.productId.trim(),
      intake.quantityKg,
      intake.unitPricePiastersPerKg,
      intake.paymentMode.name,
      intake.effectivePaidAmountQirsh,
      intake.financialAccountId?.trim() ?? '',
      intake.paymentMethod?.name ?? '',
      intake.negativeBalanceApprovalId?.trim() ?? '',
      intake.createdByUserId.trim(),
    ].join('|');
  }

  String? _normalizedOptionalText(String? value) {
    final normalized = value?.trim();
    if (normalized == null || normalized.isEmpty) {
      return null;
    }

    return normalized;
  }
}
