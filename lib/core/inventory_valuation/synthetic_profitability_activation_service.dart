import 'dart:convert';

import 'package:grain_warehouse_erp_lite/core/audit/audit_log_repository.dart';
import 'package:grain_warehouse_erp_lite/core/auth/app_user.dart';
import 'package:grain_warehouse_erp_lite/core/auth/user_role.dart';
import 'package:grain_warehouse_erp_lite/core/catalog/grain_unit.dart';
import 'package:grain_warehouse_erp_lite/core/catalog/product.dart';
import 'package:grain_warehouse_erp_lite/core/catalog/product_repository.dart';
import 'package:grain_warehouse_erp_lite/core/financial_accounts/repository_transaction.dart';
import 'package:grain_warehouse_erp_lite/core/inventory/inventory_repository.dart';
import 'package:grain_warehouse_erp_lite/core/inventory/stock_movement.dart';
import 'package:grain_warehouse_erp_lite/core/inventory_valuation/inventory_valuation.dart';
import 'package:grain_warehouse_erp_lite/core/inventory_valuation/inventory_valuation_repository.dart';

/// Deliberately not wired into production application repositories or screens.
/// It exists only for an owner-approved, isolated synthetic trial database.
class SyntheticProfitabilityActivationService {
  SyntheticProfitabilityActivationService({
    required ProductDataRepository productRepository,
    required DurableInventoryRepository inventoryRepository,
    required DurableInventoryValuationRepository valuationRepository,
    required DurableAuditLogRepository auditLogRepository,
    required String databaseIdentity,
    DateTime Function()? clock,
  })  : _productRepository = productRepository,
        _inventoryRepository = inventoryRepository,
        _valuationRepository = valuationRepository,
        _syntheticValuationRepository = valuationRepository
                is SyntheticTestInventoryValuationRepository
            ? valuationRepository as SyntheticTestInventoryValuationRepository
            : throw ArgumentError(
                'Valuation repository does not support synthetic tests.'),
        _auditLogRepository = auditLogRepository,
        _databaseIdentity = databaseIdentity,
        _clock = clock ?? DateTime.now;

  static const requiredDatabaseIdentity = 'PHASE-102J-TEST-SANDBOX';
  static const dataClassification = 'SYNTHETIC_TEST_DATA';

  final ProductDataRepository _productRepository;
  final DurableInventoryRepository _inventoryRepository;
  final DurableInventoryValuationRepository _valuationRepository;
  final SyntheticTestInventoryValuationRepository _syntheticValuationRepository;
  final DurableAuditLogRepository _auditLogRepository;
  final String _databaseIdentity;
  final DateTime Function() _clock;

  Future<SyntheticActivationResult> activate({
    required AppUser user,
    required DateTime activationDate,
    required String packageId,
    required String packageSha256,
    required List<SyntheticInventoryRow> rows,
  }) async {
    _validateAuthorityAndBoundary(user);
    final normalizedPackageId = packageId.trim();
    final normalizedHash = packageSha256.trim().toUpperCase();
    _validatePackageMetadata(normalizedPackageId, normalizedHash);
    _validateRows(rows);

    final currentActivation = await _valuationRepository.getActivation();
    if (currentActivation.isSyntheticTestActivated) {
      final metadata = _decodeEvidence(currentActivation.evidenceNote);
      if (metadata['databaseIdentity'] == requiredDatabaseIdentity &&
          metadata['packageId'] == normalizedPackageId &&
          metadata['packageSha256'] == normalizedHash) {
        return SyntheticActivationResult(
          importedRows: 0,
          duplicateRows: rows.length,
          activation: currentActivation,
          packageSha256: normalizedHash,
        );
      }
      throw StateError(
          'The synthetic sandbox is activated from another package.');
    }
    if (!currentActivation.isNotActivated) {
      throw StateError(
          'A production profitability activation cannot be replaced.');
    }
    if (activationDate.isAfter(_clock())) {
      throw ArgumentError('Activation date cannot be in the future.');
    }
    if ((await _productRepository.listProducts(includeInactive: true))
            .isNotEmpty ||
        (await _inventoryRepository.listAllMovements()).isNotEmpty ||
        (await _valuationRepository.listStates()).isNotEmpty ||
        (await _valuationRepository.listEvents()).isNotEmpty) {
      throw StateError(
          'Synthetic activation requires a new empty sandbox database.');
    }

    final evidenceNote = jsonEncode({
      'dataClassification': dataClassification,
      'databaseIdentity': requiredDatabaseIdentity,
      'packageId': normalizedPackageId,
      'packageSha256': normalizedHash,
      'rowCount': rows.length,
    });
    late ProfitabilityActivation activation;
    await RepositoryTransaction.execute(
      [
        _productRepository.createTransactionSnapshot(),
        _inventoryRepository.createTransactionSnapshot(),
        _valuationRepository.createTransactionSnapshot(),
        _auditLogRepository.createTransactionSnapshot(),
      ],
      () async {
        final openings = <OpeningValuationInput>[];
        for (final row in rows) {
          final product = await _productRepository.createProduct(ProductDraft(
            name: row.productNameAr,
            code: row.sku,
            unit: GrainUnit.kilogram,
            referenceCostPricePiastersPerKg: row.unitCostQirshPerKg,
            notes: '$dataClassification | ${row.rowId}',
          ));
          await _inventoryRepository.createMovement(StockMovementDraft(
            productId: product.id,
            movementType: StockMovementType.openingBalance,
            quantityKg: row.quantityKg,
            createdByUserId: user.id,
            note: '$dataClassification | ${row.evidenceReference}',
            originalDocumentId: normalizedPackageId,
          ));
          openings.add(OpeningValuationInput(
            productId: product.id,
            quantityKg: row.quantityKg,
            unitCostQirshPerKg: row.unitCostQirshPerKg,
            evidenceReference: row.evidenceReference,
          ));
        }
        await _syntheticValuationRepository.activateSyntheticForTest(
          activationDate: activationDate,
          approvedByUserId: user.id,
          evidenceNote: evidenceNote,
          openings: openings,
        );
        await _auditLogRepository.record(AuditLogDraft(
          actionType: 'profitability.synthetic_test_activated',
          descriptionAr:
              'تم تفعيل الربحية على بيانات اصطناعية داخل قاعدة اختبار معزولة فقط.',
          actorId: user.id,
          referenceId: normalizedPackageId,
          metadata: {
            'dataClassification': dataClassification,
            'databaseIdentity': requiredDatabaseIdentity,
            'packageSha256': normalizedHash,
            'rowCount': rows.length,
          },
        ));
        activation = await _valuationRepository.getActivation();
      },
    );
    return SyntheticActivationResult(
      importedRows: rows.length,
      duplicateRows: 0,
      activation: activation,
      packageSha256: normalizedHash,
    );
  }

  void _validateAuthorityAndBoundary(AppUser user) {
    if (!user.canProceed || user.role != UserRole.owner) {
      throw StateError('Synthetic profitability activation is owner-only.');
    }
    if (_databaseIdentity.trim() != requiredDatabaseIdentity) {
      throw StateError(
          'Synthetic activation is forbidden outside the approved sandbox.');
    }
  }

  void _validatePackageMetadata(String packageId, String packageSha256) {
    if (packageId.isEmpty) throw ArgumentError('Package id is required.');
    if (!RegExp(r'^[0-9A-F]{64}$').hasMatch(packageSha256)) {
      throw ArgumentError(
          'Package SHA-256 must be a 64-character hexadecimal value.');
    }
  }

  void _validateRows(List<SyntheticInventoryRow> rows) {
    if (rows.isEmpty) {
      throw ArgumentError('Synthetic inventory rows are required.');
    }
    final rowIds = <String>{};
    final skus = <String>{};
    final evidence = <String>{};
    for (final row in rows) {
      if (row.rowId.trim().isEmpty || !rowIds.add(row.rowId.trim())) {
        throw ArgumentError('Synthetic row ids must be present and unique.');
      }
      if (row.sku.trim().isEmpty || !skus.add(row.sku.trim().toUpperCase())) {
        throw ArgumentError('Synthetic SKUs must be present and unique.');
      }
      if (row.productNameAr.trim().isEmpty ||
          row.quantityKg <= 0 ||
          row.unitCostQirshPerKg <= 0 ||
          row.totalValueQirsh != row.quantityKg * row.unitCostQirshPerKg ||
          row.evidenceReference.trim().isEmpty ||
          !evidence.add(row.evidenceReference.trim())) {
        throw ArgumentError(
            'Synthetic inventory row is incomplete or inconsistent.');
      }
    }
  }

  Map<String, Object?> _decodeEvidence(String? value) {
    if (value == null || value.trim().isEmpty) return const {};
    final decoded = jsonDecode(value);
    return decoded is Map<String, Object?> ? decoded : const {};
  }
}

class SyntheticInventoryRow {
  const SyntheticInventoryRow({
    required this.rowId,
    required this.sku,
    required this.productNameAr,
    required this.quantityKg,
    required this.unitCostQirshPerKg,
    required this.totalValueQirsh,
    required this.evidenceReference,
  });

  final String rowId;
  final String sku;
  final String productNameAr;
  final int quantityKg;
  final int unitCostQirshPerKg;
  final int totalValueQirsh;
  final String evidenceReference;
}

class SyntheticActivationResult {
  const SyntheticActivationResult({
    required this.importedRows,
    required this.duplicateRows,
    required this.activation,
    required this.packageSha256,
  });

  final int importedRows;
  final int duplicateRows;
  final ProfitabilityActivation activation;
  final String packageSha256;
}
