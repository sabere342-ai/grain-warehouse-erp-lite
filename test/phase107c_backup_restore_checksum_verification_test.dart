import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:grain_warehouse_erp_lite/core/audit/drift_audit_log_repository.dart';
import 'package:grain_warehouse_erp_lite/core/auth/app_user.dart';
import 'package:grain_warehouse_erp_lite/core/auth/auth_repository.dart';
import 'package:grain_warehouse_erp_lite/core/auth/user_role.dart';
import 'package:grain_warehouse_erp_lite/core/backup/backup_export.dart';
import 'package:grain_warehouse_erp_lite/core/backup/backup_restore_service.dart';
import 'package:grain_warehouse_erp_lite/core/catalog/drift_product_catalog_read_repository.dart';
import 'package:grain_warehouse_erp_lite/core/catalog/drift_product_repository.dart';
import 'package:grain_warehouse_erp_lite/core/catalog/grain_unit.dart';
import 'package:grain_warehouse_erp_lite/core/catalog/product.dart';
import 'package:grain_warehouse_erp_lite/core/customer_accounts/drift_customer_account_repository.dart';
import 'package:grain_warehouse_erp_lite/core/customers/drift_customer_repository.dart';
import 'package:grain_warehouse_erp_lite/core/documents/document_history.dart';
import 'package:grain_warehouse_erp_lite/core/expenses/drift_expense_repository.dart';
import 'package:grain_warehouse_erp_lite/core/financial_accounts/drift_financial_account_repository.dart';
import 'package:grain_warehouse_erp_lite/core/financial_accounts/negative_balance_approval_repository.dart';
import 'package:grain_warehouse_erp_lite/core/financial_accounts/negative_balance_approval_request_repository.dart';
import 'package:grain_warehouse_erp_lite/core/financial_accounts/negative_balance_approval_service.dart';
import 'package:grain_warehouse_erp_lite/core/inventory/drift_inventory_repository.dart';
import 'package:grain_warehouse_erp_lite/core/inventory_valuation/drift_inventory_valuation_repository.dart';
import 'package:grain_warehouse_erp_lite/core/persistence/database_opener.dart';
import 'package:grain_warehouse_erp_lite/core/persistence/foundation_database.dart'
    show FoundationDatabase;
import 'package:grain_warehouse_erp_lite/core/purchases/drift_purchase_repository.dart';
import 'package:grain_warehouse_erp_lite/core/sales/drift_sale_repository.dart';
import 'package:grain_warehouse_erp_lite/core/supplier_accounts/drift_supplier_account_repository.dart';
import 'package:grain_warehouse_erp_lite/core/suppliers/drift_supplier_repository.dart';

final _owner = AppUser(
  id: 'owner-107c',
  phone: '01000000107',
  name: 'Phase 107C owner',
  role: UserRole.owner,
  isActive: true,
  createdAt: DateTime.utc(2026, 8, 9),
  updatedAt: DateTime.utc(2026, 8, 9),
);

void main() {
  group('Phase 107C backup restore checksum verification', () {
    test('C1 valid v8 backup checksum matches and restore succeeds', () async {
      final source = await _Fixture.create(populated: true);
      final jsonText = (await source.export.createBackup()).jsonText;
      await source.close();
      final target = await _Fixture.create(populated: false);
      addTearDown(target.close);
      final decoded = jsonDecode(jsonText) as Map<String, Object?>;

      expect(decoded['checksum'], _independentChecksum(decoded));

      final result = await target.restore.restoreToEmpty(
        user: _owner,
        jsonText: jsonText,
      );

      expect(result.success, isTrue);
      expect(await target.products.listProducts(), hasLength(1));
      expect(target.products.restoreMutationCalls, 1);
    });

    test('C2 C7 C8 payload tampering preserves SQLite cache and authentication',
        () async {
      final source = await _Fixture.create(populated: true);
      final tampered = await source.decodedBackup();
      await source.close();
      final target = await _Fixture.create(populated: true);
      addTearDown(target.close);
      final product = ((tampered['data'] as Map<String, Object?>)['products']
              as List<Object?>)
          .single as Map<String, Object?>;
      product['name'] = 'Tampered wheat';
      final persistedBefore = await target.persistentSnapshot();
      final cacheBefore = await target.cacheSnapshot();
      final authBefore = await target.authRows();

      final result = await target.restore.restoreToEmpty(
        user: _owner,
        jsonText: jsonEncode(tampered),
      );

      expect(result.success, isFalse);
      expect(result.technicalReason, 'backup-checksum-mismatch');
      expect(target.products.restoreMutationCalls, 0);
      expect(await target.persistentSnapshot(), persistedBefore);
      expect(await target.cacheSnapshot(), cacheBefore);
      expect(await target.authRows(), authBefore);
    });

    test('C3 C9 checksum tampering is rejected on an empty system', () async {
      final source = await _Fixture.create(populated: true);
      final tampered = await source.decodedBackup();
      await source.close();
      final target = await _Fixture.create(populated: false);
      addTearDown(target.close);
      final checksum = tampered['checksum']! as String;
      tampered['checksum'] =
          '${checksum[0] == '0' ? '1' : '0'}${checksum.substring(1)}';
      final persistedBefore = await target.persistentSnapshot();

      final result = await target.restore.restoreToEmpty(
        user: _owner,
        jsonText: jsonEncode(tampered),
      );

      expect(result.success, isFalse);
      expect(result.technicalReason, 'backup-checksum-mismatch');
      expect(target.products.restoreMutationCalls, 0);
      expect(await target.persistentSnapshot(), persistedBefore);
    });

    test('C4 a single ASCII-byte payload change is rejected', () async {
      final source = await _Fixture.create(populated: true);
      final tampered = await source.decodedBackup();
      await source.close();
      final target = await _Fixture.create(populated: false);
      addTearDown(target.close);
      final product = ((tampered['data'] as Map<String, Object?>)['products']
              as List<Object?>)
          .single as Map<String, Object?>;
      expect(product['code'], 'A');
      product['code'] = 'B';

      final result = await target.restore.restoreToEmpty(
        user: _owner,
        jsonText: jsonEncode(tampered),
      );

      expect(result.success, isFalse);
      expect(result.technicalReason, 'backup-checksum-mismatch');
      expect(target.products.restoreMutationCalls, 0);
    });

    test('C5 malformed checksum forms are rejected before mutation', () async {
      final source = await _Fixture.create(populated: true);
      final validBackup = await source.decodedBackup();
      await source.close();

      for (final malformed in ['abc', 'zzzzzzzz', 'ABCDEF12', 12345678]) {
        final target = await _Fixture.create(populated: false);
        final backup =
            jsonDecode(jsonEncode(validBackup)) as Map<String, Object?>;
        backup['checksum'] = malformed;

        final result = await target.restore.restoreToEmpty(
          user: _owner,
          jsonText: jsonEncode(backup),
        );

        expect(result.success, isFalse, reason: '$malformed');
        expect(
          result.technicalReason,
          'backup-checksum-malformed',
          reason: '$malformed',
        );
        expect(target.products.restoreMutationCalls, 0);
        await target.close();
      }
    });

    test('C6 missing checksum is rejected for supported v1 through v8',
        () async {
      final source = await _Fixture.create(populated: true);
      final validBackup = await source.decodedBackup();
      await source.close();

      for (var version = 1; version <= 8; version++) {
        final target = await _Fixture.create(populated: false);
        final backup =
            jsonDecode(jsonEncode(validBackup)) as Map<String, Object?>;
        (backup['metadata'] as Map<String, Object?>)['backupVersion'] = version;
        backup.remove('checksum');

        final result = await target.restore.restoreToEmpty(
          user: _owner,
          jsonText: jsonEncode(backup),
        );

        expect(result.success, isFalse, reason: 'backup v$version');
        expect(
          result.technicalReason,
          'backup-checksum-missing',
          reason: 'backup v$version',
        );
        expect(target.products.restoreMutationCalls, 0);
        await target.close();
      }
    });
  });
}

String _independentChecksum(Map<String, Object?> envelope) {
  final payload = <String, Object?>{
    for (final entry in envelope.entries)
      if (entry.key != 'checksum' && entry.key != 'checksumNote')
        entry.key: entry.value,
  };
  final serialized = const JsonEncoder.withIndent('  ').convert(payload);
  const modulus = 65521;
  var a = 1;
  var b = 0;
  for (final byte in utf8.encode(serialized)) {
    a = (a + byte) % modulus;
    b = (b + a) % modulus;
  }
  return ((b << 16) | a).toRadixString(16).padLeft(8, '0');
}

class _Fixture {
  _Fixture({
    required this.database,
    required this.products,
    required this.export,
    required this.restore,
  });

  final FoundationDatabase database;
  final _MutationCountingProductRepository products;
  final BackupExportService export;
  final BackupRestoreService restore;

  static Future<_Fixture> create({required bool populated}) async {
    final database = openInMemoryTestDatabase();
    await database.customStatement('''
      INSERT INTO auth_accounts (
        id, phone_normalized, name, role, is_active, created_at, updated_at,
        credential_scheme, credential_salt, credential_verifier,
        credential_parameters_json, credential_updated_at
      ) VALUES (
        'owner-107c', '01000000107', 'Phase 107C owner', 'owner', 1, 0, 0,
        'test', X'00', X'00', '{}', 0
      )
    ''');
    final auditLogs = DriftAuditLogRepository(database);
    final products = _MutationCountingProductRepository(database);
    final catalog = DriftProductCatalogReadRepository(database);
    final customers = DriftCustomerRepository(
      database,
      auditLogRepository: auditLogs,
    );
    final suppliers = DriftSupplierRepository(database);
    final financialAccounts = await DriftFinancialAccountRepository.open(
      database,
      auditLogRepository: auditLogs,
    );
    final approvals = NegativeBalanceApprovalService(
      authRepository: LocalAuthRepository.empty(),
      approvalRepository: LocalNegativeBalanceApprovalRepository(),
      auditLogRepository: auditLogs,
    );
    final customerAccounts = DriftCustomerAccountRepository(
      database,
      customerRepository: customers,
      auditLogRepository: auditLogs,
      financialAccountRepository: financialAccounts,
      negativeBalanceApprovalService: approvals,
    );
    final supplierAccounts = DriftSupplierAccountRepository(
      database,
      supplierRepository: suppliers,
      auditLogRepository: auditLogs,
      financialAccountRepository: financialAccounts,
      negativeBalanceApprovalService: approvals,
    );
    final inventory = DriftInventoryRepository(
      database,
      productCatalogReadRepository: catalog,
    );
    final valuation = DriftInventoryValuationRepository(database);
    final purchases = DriftPurchaseRepository(
      database,
      supplierRepository: suppliers,
      productCatalogReadRepository: catalog,
      inventoryRepository: inventory,
      inventoryValuationRepository: valuation,
    );
    final sales = DriftSaleRepository(
      database,
      productCatalogReadRepository: catalog,
      inventoryRepository: inventory,
      inventoryValuationRepository: valuation,
      financialAccountRepository: financialAccounts,
    );
    final history = LocalDocumentHistoryRepository(
      purchaseRepository: purchases,
      saleRepository: sales,
      productCatalogReadRepository: catalog,
      inventoryRepository: inventory,
    );
    final expenses = DriftExpenseRepository(
      database,
      auditLogRepository: auditLogs,
      financialAccountRepository: financialAccounts,
    );
    final approvalRequests =
        DriftNegativeBalanceApprovalRequestRepository(database);
    final export = BackupExportService(
      productCatalogReadRepository: catalog,
      inventoryRepository: inventory,
      supplierRepository: suppliers,
      purchaseRepository: purchases,
      saleRepository: sales,
      documentHistoryRepository: history,
      customerRepository: customers,
      customerAccountRepository: customerAccounts,
      supplierAccountRepository: supplierAccounts,
      expenseRepository: expenses,
      auditLogRepository: auditLogs,
      financialAccountRepository: financialAccounts,
      negativeBalanceApprovalRequestRepository: approvalRequests,
      inventoryValuationRepository: valuation,
      now: () => DateTime.utc(2026, 8, 9, 12),
    );
    final restore = BackupRestoreService(
      productRepository: products,
      productCatalogReadRepository: catalog,
      inventoryRepository: inventory,
      supplierRepository: suppliers,
      purchaseRepository: purchases,
      saleRepository: sales,
      documentHistoryRepository: history,
      customerRepository: customers,
      customerAccountRepository: customerAccounts,
      supplierAccountRepository: supplierAccounts,
      expenseRepository: expenses,
      auditLogRepository: auditLogs,
      financialAccountRepository: financialAccounts,
      negativeBalanceApprovalRequestRepository: approvalRequests,
      inventoryValuationRepository: valuation,
    );
    final fixture = _Fixture(
      database: database,
      products: products,
      export: export,
      restore: restore,
    );
    if (populated) {
      await products.createProduct(
        const ProductDraft(
          name: 'Phase 107C wheat',
          code: 'A',
          unit: GrainUnit.kilogram,
        ),
      );
    }
    return fixture;
  }

  Future<Map<String, Object?>> decodedBackup() async {
    return jsonDecode((await export.createBackup()).jsonText)
        as Map<String, Object?>;
  }

  Future<Map<String, List<String>>> persistentSnapshot() async {
    final tables = await database
        .customSelect(
          "SELECT name FROM sqlite_master WHERE type = 'table' "
          "AND name NOT LIKE 'sqlite_%' ORDER BY name",
        )
        .get();
    final snapshot = <String, List<String>>{};
    for (final tableRow in tables) {
      final table = tableRow.data['name']! as String;
      final rows = await database.customSelect('SELECT * FROM "$table"').get();
      snapshot[table] = rows
          .map(
            (row) => row.data.entries
                .map((entry) => '${entry.key}=${entry.value}')
                .join('|'),
          )
          .toList()
        ..sort();
    }
    return snapshot;
  }

  Future<Map<String, Object?>> cacheSnapshot() async => {
        'products': (await products.listProducts())
            .map((product) => '${product.id}:${product.name}:${product.code}')
            .toList(),
      };

  Future<List<String>> authRows() async =>
      (await database.customSelect('SELECT * FROM auth_accounts').get())
          .map((row) => row.data.toString())
          .toList();

  Future<void> close() => database.close();
}

class _MutationCountingProductRepository extends DriftProductRepository {
  _MutationCountingProductRepository(super.database);

  int restoreMutationCalls = 0;

  @override
  Future<void> restoreProductsIntoEmpty(List<Product> products) async {
    restoreMutationCalls++;
    await super.restoreProductsIntoEmpty(products);
  }
}
