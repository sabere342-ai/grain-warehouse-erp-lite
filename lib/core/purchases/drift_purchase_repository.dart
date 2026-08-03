import 'dart:convert';

import 'package:drift/drift.dart';
import 'package:grain_warehouse_erp_lite/core/audit/audit_log_repository.dart';
import 'package:grain_warehouse_erp_lite/core/catalog/grain_unit.dart';
import 'package:grain_warehouse_erp_lite/core/catalog/product_catalog_read_repository.dart';
import 'package:grain_warehouse_erp_lite/core/documents/cancellation_metadata.dart';
import 'package:grain_warehouse_erp_lite/core/financial_accounts/financial_account_entry.dart';
import 'package:grain_warehouse_erp_lite/core/financial_accounts/financial_account_repository.dart';
import 'package:grain_warehouse_erp_lite/core/financial_accounts/payment_routing_policy.dart';
import 'package:grain_warehouse_erp_lite/core/financial_accounts/repository_transaction.dart';
import 'package:grain_warehouse_erp_lite/core/inventory/inventory_repository.dart';
import 'package:grain_warehouse_erp_lite/core/inventory/stock_movement.dart';
import 'package:grain_warehouse_erp_lite/core/inventory_valuation/inventory_valuation_repository.dart';
import 'package:grain_warehouse_erp_lite/core/persistence/foundation_database.dart'
    as db;
import 'package:grain_warehouse_erp_lite/core/purchases/purchase_intake.dart';
import 'package:grain_warehouse_erp_lite/core/purchases/purchase_repository.dart';
import 'package:grain_warehouse_erp_lite/core/supplier_accounts/supplier_account_repository.dart';
import 'package:grain_warehouse_erp_lite/core/suppliers/supplier.dart';
import 'package:grain_warehouse_erp_lite/core/suppliers/supplier_repository.dart';

class DriftPurchaseRepository implements DurablePurchaseRepository {
  DriftPurchaseRepository(
    this._database, {
    required SupplierRepository supplierRepository,
    required ProductCatalogReadRepository productCatalogReadRepository,
    required InventoryRepository inventoryRepository,
    SupplierAccountRepository? supplierAccountRepository,
    FinancialAccountRepository? financialAccountRepository,
    AuditLogRepository? auditLogRepository,
    InventoryValuationRepository? inventoryValuationRepository,
  })  : _supplierRepository = supplierRepository,
        _productCatalogReadRepository = productCatalogReadRepository,
        _inventoryRepository = inventoryRepository,
        _supplierAccountRepository = supplierAccountRepository,
        _financialAccountRepository = financialAccountRepository,
        _inventoryValuationRepository = inventoryValuationRepository,
        _auditLogRepository = auditLogRepository ?? LocalAuditLogRepository();

  static const _sequenceKey = 'purchases';
  final db.FoundationDatabase _database;
  final SupplierRepository _supplierRepository;
  final ProductCatalogReadRepository _productCatalogReadRepository;
  final InventoryRepository _inventoryRepository;
  final SupplierAccountRepository? _supplierAccountRepository;
  final FinancialAccountRepository? _financialAccountRepository;
  final InventoryValuationRepository? _inventoryValuationRepository;
  final AuditLogRepository _auditLogRepository;

  @override
  Future<PurchaseIntake> createPurchaseIntake(PurchaseIntakeDraft draft) async {
    final supplier = await _validateSupplier(draft.supplierId);
    final product = await _validateProduct(draft.productId);
    _validateDraft(draft);
    await _validateNewPaymentRoute(draft);
    final requestId = _optional(draft.operationRequestId);
    final fingerprint = _fingerprint(draft);
    if (requestId != null) {
      final existing = await (_database.select(_database.purchases)
            ..where((row) => row.operationRequestId.equals(requestId)))
          .getSingleOrNull();
      if (existing != null) {
        if (existing.requestFingerprint != fingerprint) {
          throw StateError('Purchase request payload does not match replay.');
        }
        return _toDomain(existing);
      }
    }

    final snapshots = _transactionSnapshots();
    return RepositoryTransaction.execute(snapshots, () async {
      if (requestId != null) {
        final replay = await (_database.select(_database.purchases)
              ..where((row) => row.operationRequestId.equals(requestId)))
            .getSingleOrNull();
        if (replay != null) {
          if (replay.requestFingerprint != fingerprint) {
            throw StateError('Purchase request payload does not match replay.');
          }
          return _toDomain(replay);
        }
      }
      final now = DateTime.now();
      await _financialAccountRepository?.ensureDateIsOpen(now);
      final sequence = await _takeSequence();
      var intake = PurchaseIntake(
        id: 'pin-${now.microsecondsSinceEpoch}-$sequence',
        supplierId: supplier.id,
        supplierName: _optional(draft.supplierName ?? supplier.name),
        supplierPhone: _optional(draft.supplierPhone ?? supplier.phone),
        supplierAddress: _optional(draft.supplierAddress ?? supplier.address),
        productId: product.id,
        quantityKg: draft.quantityKg,
        entryUnit: draft.entryUnit,
        unitPricePiastersPerKg: draft.unitPricePiastersPerKg,
        totalAmountPiasters: draft.totalAmountPiasters,
        createdByUserId: draft.createdByUserId.trim(),
        createdAt: now,
        stockMovementId: 'pending',
        notes: _optional(draft.notes),
        financialAccountId: _optional(draft.financialAccountId),
        paymentMethod: draft.paymentMethod,
        paymentMode: draft.paymentMode,
        paidAmountQirsh: draft.paidAmountQirsh,
        negativeBalanceApprovalId: _optional(draft.negativeBalanceApprovalId),
      );
      final movement = await _inventoryRepository.createMovement(
        StockMovementDraft(
          productId: intake.productId,
          movementType: StockMovementType.purchaseIntake,
          quantityKg: intake.quantityKg,
          createdByUserId: intake.createdByUserId,
          note: 'Purchase intake ${intake.id}',
          originalDocumentId: intake.id,
        ),
      );
      intake = intake.copyWith(stockMovementId: movement.id);
      await _inventoryValuationRepository?.recordPurchase(
        productId: intake.productId,
        quantityKg: intake.quantityKg,
        unitCostQirshPerKg: intake.unitPricePiastersPerKg,
        sourceDocumentId: intake.id,
        effectiveDate: intake.createdAt,
        createdByUserId: intake.createdByUserId,
      );
      await _database.into(_database.purchases).insert(
            _companion(intake, requestId: requestId, fingerprint: fingerprint),
          );
      if (intake.outstandingAmountQirsh > 0) {
        await _supplierAccountRepository?.createPurchaseEntry(purchase: intake);
      }
      await _createFinancialPayment(intake, draft);
      await _auditLogRepository.record(AuditLogDraft(
        actionType: 'purchase.created',
        descriptionAr: 'Purchase intake recorded.',
        referenceId: intake.id,
      ));
      return intake;
    });
  }

  @override
  Future<PurchaseIntake> cancelPurchaseIntake({
    required String purchaseIntakeId,
    required String cancelledByUserId,
    required String cancellationReason,
  }) async {
    final row = await (_database.select(_database.purchases)
          ..where((value) => value.id.equals(purchaseIntakeId)))
        .getSingleOrNull();
    if (row == null) throw StateError('Purchase intake was not found.');
    final intake = _toDomain(row);
    if (intake.isCancelled) return intake;
    final userId = cancelledByUserId.trim();
    final reason = _optional(cancellationReason);
    if (userId.isEmpty) {
      throw ArgumentError('Cancelled by user id is required.');
    }
    if (reason == null) throw ArgumentError('Cancellation reason is required.');
    if (await _inventoryRepository.currentStockKg(intake.productId) <
        intake.quantityKg) {
      throw StateError('Purchase cancellation would make stock negative.');
    }
    final cancelledAt = DateTime.now();
    await _financialAccountRepository?.ensureDateIsOpen(cancelledAt);
    if (_inventoryValuationRepository != null &&
        !await _inventoryValuationRepository
            .canDirectlyCancelPurchase(intake.id)) {
      throw StateError(
          'Purchase is already mixed or used; record a current-dated correction instead.');
    }
    return RepositoryTransaction.execute(_transactionSnapshots(), () async {
      final reversal = await _inventoryRepository.createMovement(
        StockMovementDraft(
          productId: intake.productId,
          movementType: StockMovementType.purchaseCancellation,
          quantityKg: intake.quantityKg,
          createdByUserId: userId,
          note: 'Cancel purchase ${intake.id}: $reason',
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
      await (_database.update(_database.purchases)
            ..where((value) => value.id.equals(intake.id)))
          .write(_companion(
        cancelled,
        requestId: row.operationRequestId,
        fingerprint: row.requestFingerprint,
      ));
      if (cancelled.outstandingAmountQirsh > 0) {
        await _supplierAccountRepository?.reversePurchaseEntry(
          cancelledPurchase: cancelled,
          cancelledByUserId: userId,
          cancellationReason: reason,
        );
      }
      await _createFinancialReversal(cancelled, userId, reason);
      await _auditLogRepository.record(AuditLogDraft(
        actionType: 'purchase.cancelled',
        descriptionAr: 'Purchase intake cancelled.',
        referenceId: intake.id,
      ));
      return cancelled;
    });
  }

  @override
  Future<List<PurchaseIntake>> listPurchaseIntakes() async {
    final query = _database.select(_database.purchases)
      ..orderBy([
        (row) => OrderingTerm.asc(row.createdAt),
        (row) => OrderingTerm.asc(row.id),
      ]);
    return (await query.get()).map(_toDomain).toList(growable: false);
  }

  @override
  Future<void> restorePurchaseIntakesIntoEmpty(List<PurchaseIntake> intakes) {
    return _database.transaction(() async {
      if (await _database.purchases.count().getSingle() != 0) {
        throw StateError('Purchase repository is not empty.');
      }
      final ids = <String>{};
      for (final intake in intakes) {
        if (!intake.hasValidId || !ids.add(intake.id)) {
          throw StateError('Invalid purchase intake id.');
        }
        if (intake.quantityKg <= 0 ||
            intake.unitPricePiastersPerKg <= 0 ||
            intake.totalAmountPiasters !=
                intake.quantityKg * intake.unitPricePiastersPerKg) {
          throw StateError('Invalid purchase intake data.');
        }
        await _validateSupplierExists(intake.supplierId);
        await _validateProductExists(intake.productId);
      }
      for (final intake in intakes) {
        await _database.into(_database.purchases).insert(_companion(intake));
      }
      var maximum = 0;
      for (final intake in intakes) {
        final value = int.tryParse(intake.id.split('-').last) ?? 0;
        if (value > maximum) maximum = value;
      }
      await _setNextSequence(maximum + 1);
    });
  }

  @override
  Future<void> clearForOwnerDataWipe() => _database.transaction(() async {
        await _database.delete(_database.purchases).go();
        await (_database.delete(_database.repositorySequences)
              ..where((row) => row.repository.equals(_sequenceKey)))
            .go();
      });

  @override
  SnapshotHolder createTransactionSnapshot() => _DriftPurchaseSnapshot(this);

  List<SnapshotHolder> _transactionSnapshots() {
    final result = <SnapshotHolder>[createTransactionSnapshot()];
    result.add(_requiredSnapshot(_inventoryRepository, 'inventory'));
    if (_supplierAccountRepository != null) {
      result.add(_requiredSnapshot(_supplierAccountRepository, 'supplier'));
    }
    if (_financialAccountRepository != null) {
      result.add(_requiredSnapshot(_financialAccountRepository, 'financial'));
    }
    if (_inventoryValuationRepository != null) {
      result.add(_requiredSnapshot(_inventoryValuationRepository, 'valuation'));
    }
    result.add(_requiredSnapshot(_auditLogRepository, 'audit'));
    return result;
  }

  SnapshotHolder _requiredSnapshot(Object repository, String name) {
    if (repository is! TransactionSnapshotProvider) {
      throw StateError(
          'Purchase $name repository cannot participate in a transaction.');
    }
    return repository.createTransactionSnapshot();
  }

  Future<int> _takeSequence() async {
    return _database.transaction(() async {
      final row = await (_database.select(_database.repositorySequences)
            ..where((value) => value.repository.equals(_sequenceKey)))
          .getSingleOrNull();
      final value = row?.nextValue ?? 1;
      await _setNextSequence(value + 1);
      return value;
    });
  }

  Future<void> _setNextSequence(int value) => _database
      .into(_database.repositorySequences)
      .insertOnConflictUpdate(db.RepositorySequencesCompanion.insert(
        repository: _sequenceKey,
        nextValue: value,
      ));

  Future<Supplier> _validateSupplier(String id) async {
    final suppliers =
        await _supplierRepository.listSuppliers(includeInactive: true);
    final supplier = suppliers.where((value) => value.id == id).firstOrNull;
    if (supplier == null) throw StateError('Supplier was not found.');
    if (!supplier.isActive) {
      throw StateError('Inactive supplier cannot be used.');
    }
    return supplier;
  }

  Future<ProductCatalogReadModel> _validateProduct(String id) async {
    final products = await _productCatalogReadRepository.listProductCatalog(
      includeInactive: true,
    );
    final product = products.where((value) => value.id == id).firstOrNull;
    if (product == null) throw StateError('Product was not found.');
    if (!product.isActive) throw StateError('Inactive product cannot be used.');
    return product;
  }

  Future<void> _validateSupplierExists(String id) async {
    final values =
        await _supplierRepository.listSuppliers(includeInactive: true);
    if (!values.any((value) => value.id == id)) {
      throw StateError('Supplier was not found.');
    }
  }

  Future<void> _validateProductExists(String id) async {
    final values = await _productCatalogReadRepository.listProductCatalog(
      includeInactive: true,
    );
    if (!values.any((value) => value.id == id)) {
      throw StateError('Product was not found.');
    }
  }

  void _validateDraft(PurchaseIntakeDraft draft) {
    if (draft.createdByUserId.trim().isEmpty ||
        draft.quantityKg <= 0 ||
        draft.unitPricePiastersPerKg <= 0) {
      throw ArgumentError('Invalid purchase intake draft.');
    }
    final paid = draft.paidAmountQirsh;
    if (draft.paymentMode == PurchasePaymentMode.credit &&
        paid != null &&
        paid != 0) {
      throw ArgumentError(
          'Credit purchases cannot include an immediate payment.');
    }
    if (draft.paymentMode == PurchasePaymentMode.credit &&
        (draft.financialAccountId?.trim().isNotEmpty == true ||
            draft.paymentMethod != null ||
            draft.negativeBalanceApprovalId?.trim().isNotEmpty == true)) {
      throw ArgumentError(
          'Credit purchases cannot include a payment route or approval.');
    }
    if (draft.paymentMode == PurchasePaymentMode.paid &&
        paid != null &&
        paid != draft.totalAmountPiasters) {
      throw ArgumentError('Paid purchases must settle the full total.');
    }
    if (draft.paymentMode == PurchasePaymentMode.partial &&
        (paid == null || paid <= 0 || paid >= draft.totalAmountPiasters)) {
      throw ArgumentError(
          'Partial purchase payment must be positive and below the total.');
    }
  }

  Future<void> _validateNewPaymentRoute(PurchaseIntakeDraft draft) async {
    if (draft.paymentMode == PurchasePaymentMode.credit ||
        draft.effectivePaidAmountQirsh <= 0) return;
    final accountId = _optional(draft.financialAccountId);
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
        account: account, paymentMethod: paymentMethod);
  }

  Future<void> _createFinancialPayment(
      PurchaseIntake intake, PurchaseIntakeDraft draft) async {
    final repository = _financialAccountRepository;
    if (repository == null ||
        intake.financialAccountId == null ||
        intake.paymentMode == PurchasePaymentMode.credit ||
        intake.effectivePaidAmountQirsh <= 0) return;
    await repository.createEntry(
      accountId: intake.financialAccountId!,
      direction: FinancialAccountEntryDirection.outflow,
      amountQirsh: intake.effectivePaidAmountQirsh,
      sourceType: FinancialAccountEntrySource.purchasePayment,
      sourceDocumentId: intake.id,
      effectiveDate: intake.createdAt,
      createdByUserId: intake.createdByUserId,
      paymentMethod: intake.paymentMethod,
      approvedByUserId: draft.approvedByUserId,
      negativeBalanceApprovalId: draft.negativeBalanceApprovalId,
      approvalSourceDocumentId: draft.operationRequestId,
    );
  }

  Future<void> _createFinancialReversal(
      PurchaseIntake intake, String userId, String reason) async {
    final repository = _financialAccountRepository;
    if (repository == null ||
        intake.financialAccountId == null ||
        intake.paymentMode == PurchasePaymentMode.credit ||
        intake.effectivePaidAmountQirsh <= 0) return;
    await repository.createEntry(
      accountId: intake.financialAccountId!,
      direction: FinancialAccountEntryDirection.inflow,
      amountQirsh: intake.effectivePaidAmountQirsh,
      sourceType: FinancialAccountEntrySource.cancellationReversal,
      sourceDocumentId: intake.id,
      effectiveDate: DateTime.now(),
      createdByUserId: userId,
      reversalOf: intake.id,
      note: reason,
      paymentMethod: intake.paymentMethod,
    );
  }

  db.PurchasesCompanion _companion(PurchaseIntake value,
      {String? requestId, String? fingerprint}) {
    final cancellation = value.cancellation;
    return db.PurchasesCompanion(
      id: Value(value.id),
      supplierId: Value(value.supplierId),
      supplierName: Value(value.supplierName),
      supplierPhone: Value(value.supplierPhone),
      supplierAddress: Value(value.supplierAddress),
      productId: Value(value.productId),
      quantityKg: Value(value.quantityKg),
      entryUnit: Value(value.entryUnit.name),
      unitPricePiastersPerKg: Value(value.unitPricePiastersPerKg),
      totalAmountPiasters: Value(value.totalAmountPiasters),
      createdByUserId: Value(value.createdByUserId),
      createdAt: Value(value.createdAt),
      stockMovementId: Value(value.stockMovementId),
      notes: Value(value.notes),
      financialAccountId: Value(value.financialAccountId),
      paymentMethod: Value(value.paymentMethod?.name),
      paymentMode: Value(value.paymentMode.name),
      paidAmountQirsh: Value(value.paidAmountQirsh),
      negativeBalanceApprovalId: Value(value.negativeBalanceApprovalId),
      operationRequestId: Value(requestId),
      requestFingerprint: Value(fingerprint),
      cancelledAt: Value(cancellation?.cancelledAt),
      cancelledByUserId: Value(cancellation?.cancelledByUserId),
      cancellationReason: Value(cancellation?.cancellationReason),
      reversalMovementIds: Value(cancellation == null
          ? null
          : jsonEncode(cancellation.reversalMovementIds)),
    );
  }

  PurchaseIntake _toDomain(db.Purchase row) => PurchaseIntake(
        id: row.id,
        supplierId: row.supplierId,
        supplierName: row.supplierName,
        supplierPhone: row.supplierPhone,
        supplierAddress: row.supplierAddress,
        productId: row.productId,
        quantityKg: row.quantityKg,
        entryUnit: GrainUnit.values.byName(row.entryUnit),
        unitPricePiastersPerKg: row.unitPricePiastersPerKg,
        totalAmountPiasters: row.totalAmountPiasters,
        createdByUserId: row.createdByUserId,
        createdAt: row.createdAt,
        stockMovementId: row.stockMovementId,
        notes: row.notes,
        financialAccountId: row.financialAccountId,
        paymentMethod: row.paymentMethod == null
            ? null
            : PaymentMethod.values.byName(row.paymentMethod!),
        paymentMode: PurchasePaymentMode.values.byName(row.paymentMode),
        paidAmountQirsh: row.paidAmountQirsh,
        negativeBalanceApprovalId: row.negativeBalanceApprovalId,
        cancellation: row.cancelledAt == null
            ? null
            : CancellationMetadata(
                cancelledAt: row.cancelledAt!,
                cancelledByUserId: row.cancelledByUserId!,
                cancellationReason: row.cancellationReason!,
                originalDocumentId: row.id,
                reversalMovementIds:
                    (jsonDecode(row.reversalMovementIds!) as List)
                        .cast<String>()),
      );

  String _fingerprint(PurchaseIntakeDraft draft) => [
        draft.supplierId.trim(),
        draft.productId.trim(),
        draft.quantityKg,
        draft.unitPricePiastersPerKg,
        draft.paymentMode.name,
        draft.effectivePaidAmountQirsh,
        draft.financialAccountId?.trim() ?? '',
        draft.paymentMethod?.name ?? '',
        draft.negativeBalanceApprovalId?.trim() ?? '',
        draft.createdByUserId.trim()
      ].join('|');
  String? _optional(String? value) {
    final result = value?.trim();
    return result == null || result.isEmpty ? null : result;
  }
}

class _DriftPurchaseSnapshot extends SnapshotHolder {
  _DriftPurchaseSnapshot(this.repository);
  final DriftPurchaseRepository repository;
  List<PurchaseIntake>? values;
  @override
  Future<void> capture() async =>
      values = await repository.listPurchaseIntakes();
  @override
  Future<void> rollback() async {
    final state = values;
    if (state == null) return;
    await repository.clearForOwnerDataWipe();
    await repository.restorePurchaseIntakesIntoEmpty(state);
  }
}
