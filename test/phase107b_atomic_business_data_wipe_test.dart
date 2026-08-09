import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:grain_warehouse_erp_lite/core/audit/audit_log_repository.dart';
import 'package:grain_warehouse_erp_lite/core/audit/drift_audit_log_repository.dart';
import 'package:grain_warehouse_erp_lite/core/auth/app_user.dart';
import 'package:grain_warehouse_erp_lite/core/auth/auth_repository.dart';
import 'package:grain_warehouse_erp_lite/core/auth/user_role.dart';
import 'package:grain_warehouse_erp_lite/core/backup/backup_export.dart';
import 'package:grain_warehouse_erp_lite/core/backup/backup_file_writer.dart';
import 'package:grain_warehouse_erp_lite/core/backup/backup_restore_preview.dart';
import 'package:grain_warehouse_erp_lite/core/backup/business_data_wipe_service.dart';
import 'package:grain_warehouse_erp_lite/core/catalog/drift_product_catalog_read_repository.dart';
import 'package:grain_warehouse_erp_lite/core/catalog/drift_product_repository.dart';
import 'package:grain_warehouse_erp_lite/core/catalog/grain_unit.dart';
import 'package:grain_warehouse_erp_lite/core/catalog/product.dart';
import 'package:grain_warehouse_erp_lite/core/customer_accounts/drift_customer_account_repository.dart';
import 'package:grain_warehouse_erp_lite/core/customers/customer.dart';
import 'package:grain_warehouse_erp_lite/core/customers/drift_customer_repository.dart';
import 'package:grain_warehouse_erp_lite/core/documents/document_history.dart';
import 'package:grain_warehouse_erp_lite/core/expenses/drift_expense_repository.dart';
import 'package:grain_warehouse_erp_lite/core/expenses/expense.dart';
import 'package:grain_warehouse_erp_lite/core/financial_accounts/drift_financial_account_repository.dart';
import 'package:grain_warehouse_erp_lite/core/financial_accounts/financial_account.dart';
import 'package:grain_warehouse_erp_lite/core/financial_accounts/financial_account_entry.dart';
import 'package:grain_warehouse_erp_lite/core/financial_accounts/negative_balance_approval_repository.dart';
import 'package:grain_warehouse_erp_lite/core/financial_accounts/negative_balance_approval_request.dart';
import 'package:grain_warehouse_erp_lite/core/financial_accounts/negative_balance_approval_request_repository.dart';
import 'package:grain_warehouse_erp_lite/core/financial_accounts/negative_balance_approval_service.dart';
import 'package:grain_warehouse_erp_lite/core/inventory/drift_inventory_repository.dart';
import 'package:grain_warehouse_erp_lite/core/inventory_valuation/drift_inventory_valuation_repository.dart';
import 'package:grain_warehouse_erp_lite/core/inventory_valuation/inventory_valuation.dart';
import 'package:grain_warehouse_erp_lite/core/persistence/database_opener.dart';
import 'package:grain_warehouse_erp_lite/core/persistence/foundation_database.dart';
import 'package:grain_warehouse_erp_lite/core/purchases/drift_purchase_repository.dart';
import 'package:grain_warehouse_erp_lite/core/purchases/purchase_intake.dart';
import 'package:grain_warehouse_erp_lite/core/sales/drift_sale_repository.dart';
import 'package:grain_warehouse_erp_lite/core/sales/sale_record.dart';
import 'package:grain_warehouse_erp_lite/core/supplier_accounts/drift_supplier_account_repository.dart';
import 'package:grain_warehouse_erp_lite/core/suppliers/drift_supplier_repository.dart';
import 'package:grain_warehouse_erp_lite/core/suppliers/supplier.dart';

const _rollbackReason = 'business-data-wipe-rolled-back';

final _owner = AppUser(
  id: 'owner-107b',
  phone: '01000000107',
  name: 'Phase 107B owner',
  role: UserRole.owner,
  isActive: true,
  createdAt: DateTime.utc(2026, 8, 9),
  updatedAt: DateTime.utc(2026, 8, 9),
);

void main() {
  group('Phase 107B atomic business-data wipe', () {
    test('populated durable state is wiped and owner authentication survives',
        () async {
      final fixture = await _Fixture.create(populated: true);
      addTearDown(fixture.close);
      final ownerBefore = await fixture.authRows();

      final result = await fixture.service().wipeBusinessData(
            user: _owner,
            confirmationText: BusinessDataWipeService.confirmationPhrase,
          );

      expect(result.success, isTrue);
      expect(result.technicalReason, isNull);
      expect(result.wipedCounts!.products, 1);
      expect(result.wipedCounts!.inventoryMovements, 2);
      expect(result.wipedCounts!.suppliers, 1);
      expect(result.wipedCounts!.purchases, 1);
      expect(result.wipedCounts!.sales, 1);
      expect(result.wipedCounts!.customers, 1);
      expect(result.wipedCounts!.expenses, 1);
      expect(result.wipedCounts!.auditLogs, greaterThanOrEqualTo(1));
      await fixture.expectBusinessStateEmpty();
      expect(await fixture.authRows(), ownerBefore);
    });

    test(
        'already-empty durable state succeeds truthfully and deterministically',
        () async {
      final fixture = await _Fixture.create(populated: false);
      addTearDown(fixture.close);
      final before = await fixture.persistentSnapshot();

      final result = await fixture.service().wipeBusinessData(
            user: _owner,
            confirmationText: BusinessDataWipeService.confirmationPhrase,
          );

      expect(result.success, isTrue);
      expect(
        [
          result.wipedCounts!.products,
          result.wipedCounts!.inventoryMovements,
          result.wipedCounts!.suppliers,
          result.wipedCounts!.purchases,
          result.wipedCounts!.sales,
          result.wipedCounts!.documentHistory,
          result.wipedCounts!.customers,
          result.wipedCounts!.expenses,
          result.wipedCounts!.auditLogs,
        ],
        everyElement(0),
      );
      await fixture.expectBusinessStateEmpty();
      expect((await fixture.persistentSnapshot())['auth_accounts'],
          before['auth_accounts']);
    });

    for (final testCase in const [
      (
        name: 'F1 before the first delete',
        step: BusinessDataWipeStep.negativeBalanceApprovalRequests,
      ),
      (
        name: 'F2 after one completed delete',
        step: BusinessDataWipeStep.auditLogs,
      ),
      (
        name: 'F3 in the middle of the delete sequence',
        step: BusinessDataWipeStep.purchases,
      ),
      (
        name: 'F4 immediately before the final delete',
        step: BusinessDataWipeStep.financialAccounts,
      ),
    ]) {
      test('${testCase.name} rolls back the complete persistent state',
          () async {
        final fixture = await _Fixture.create(populated: true);
        addTearDown(fixture.close);
        final before = await fixture.persistentSnapshot();
        final cachedBefore = await fixture.cachedStateSnapshot();

        final result =
            await fixture.service(failAt: testCase.step).wipeBusinessData(
                  user: _owner,
                  confirmationText: BusinessDataWipeService.confirmationPhrase,
                );

        expect(result.success, isFalse);
        expect(result.technicalReason, _rollbackReason);
        expect(result.message,
            contains('\u0627\u0644\u062a\u0631\u0627\u062c\u0639'));
        expect(
            result.message, isNot(contains('\u0628\u0646\u062c\u0627\u062d')));
        expect(await fixture.persistentSnapshot(), before);
        expect(await fixture.cachedStateSnapshot(), cachedBefore);
      });
    }
  });

  test('production composition governs the wipe with FoundationDatabase', () {
    final composition =
        File('lib/app/app_repositories.dart').readAsStringSync();
    final service = File('lib/core/backup/business_data_wipe_service.dart')
        .readAsStringSync();

    expect(
      composition,
      contains('transactionRunner: (operation) => '
          'database.inTransaction(operation)'),
    );
    expect(service, contains('RepositoryTransaction.execute('));
    expect(service, contains('_transactionSnapshots()'));
    expect(
      RegExp(r'BusinessDataWipeStep\.[a-zA-Z]+,').allMatches(service),
      hasLength(BusinessDataWipeStep.values.length),
    );
  });
}

class _Fixture {
  _Fixture({
    required this.database,
    required this.products,
    required this.catalog,
    required this.inventory,
    required this.suppliers,
    required this.purchases,
    required this.sales,
    required this.history,
    required this.customers,
    required this.customerAccounts,
    required this.supplierAccounts,
    required this.expenses,
    required this.auditLogs,
    required this.financialAccounts,
    required this.approvalRequests,
    required this.inventoryValuation,
    required this.backupExport,
  });

  final FoundationDatabase database;
  final DriftProductRepository products;
  final DriftProductCatalogReadRepository catalog;
  final DriftInventoryRepository inventory;
  final DriftSupplierRepository suppliers;
  final DriftPurchaseRepository purchases;
  final DriftSaleRepository sales;
  final LocalDocumentHistoryRepository history;
  final DriftCustomerRepository customers;
  final DriftCustomerAccountRepository customerAccounts;
  final DriftSupplierAccountRepository supplierAccounts;
  final DriftExpenseRepository expenses;
  final DriftAuditLogRepository auditLogs;
  final DriftFinancialAccountRepository financialAccounts;
  final DriftNegativeBalanceApprovalRequestRepository approvalRequests;
  final DriftInventoryValuationRepository inventoryValuation;
  final BackupExportService backupExport;

  static Future<_Fixture> create({required bool populated}) async {
    final database = openInMemoryTestDatabase();
    await database.customStatement('''
      INSERT INTO auth_accounts (
        id, phone_normalized, name, role, is_active, created_at, updated_at,
        credential_scheme, credential_salt, credential_verifier,
        credential_parameters_json, credential_updated_at
      ) VALUES (
        'owner-107b', '01000000107', 'Phase 107B owner', 'owner', 1, 0, 0,
        'test', X'00', X'00', '{}', 0
      )
    ''');

    final auditLogs = DriftAuditLogRepository(database);
    final products = DriftProductRepository(database);
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
    final inventoryValuation = DriftInventoryValuationRepository(database);
    final purchases = DriftPurchaseRepository(
      database,
      supplierRepository: suppliers,
      productCatalogReadRepository: catalog,
      inventoryRepository: inventory,
      inventoryValuationRepository: inventoryValuation,
    );
    final sales = DriftSaleRepository(
      database,
      productCatalogReadRepository: catalog,
      inventoryRepository: inventory,
      inventoryValuationRepository: inventoryValuation,
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
    final backupExport = BackupExportService(
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
      inventoryValuationRepository: inventoryValuation,
      now: () => DateTime.utc(2026, 8, 9, 12),
    );
    final fixture = _Fixture(
      database: database,
      products: products,
      catalog: catalog,
      inventory: inventory,
      suppliers: suppliers,
      purchases: purchases,
      sales: sales,
      history: history,
      customers: customers,
      customerAccounts: customerAccounts,
      supplierAccounts: supplierAccounts,
      expenses: expenses,
      auditLogs: auditLogs,
      financialAccounts: financialAccounts,
      approvalRequests: approvalRequests,
      inventoryValuation: inventoryValuation,
      backupExport: backupExport,
    );
    if (populated) {
      await fixture._seedBusinessState();
      final preview = const BackupRestorePreviewService()
          .preview((await backupExport.createBackup()).jsonText);
      if (!preview.isValid) {
        throw StateError(
          'Invalid Phase 107B fixture backup: '
          '${preview.technicalReason} ${preview.message}',
        );
      }
    }
    return fixture;
  }

  BusinessDataWipeService service({BusinessDataWipeStep? failAt}) =>
      BusinessDataWipeService(
        backupExportService: backupExport,
        backupFileWriter: const _MemoryBackupFileWriter(),
        productRepository: products,
        productCatalogReadRepository: catalog,
        inventoryRepository: inventory,
        supplierRepository: suppliers,
        purchaseRepository: purchases,
        saleRepository: sales,
        documentHistoryRepository: history,
        transactionRunner: (operation) => database.inTransaction(operation),
        customerRepository: customers,
        customerAccountRepository: customerAccounts,
        supplierAccountRepository: supplierAccounts,
        expenseRepository: expenses,
        auditLogRepository: auditLogs,
        financialAccountRepository: financialAccounts,
        negativeBalanceApprovalRequestRepository: approvalRequests,
        inventoryValuationRepository: inventoryValuation,
        stepHook: (step) {
          if (step == failAt) throw StateError('Injected failure at $step');
        },
      );

  Future<void> _seedBusinessState() async {
    final product = await products.createProduct(
      const ProductDraft(
        name: 'Phase 107B wheat',
        unit: GrainUnit.kilogram,
        referenceCostPricePiastersPerKg: 500,
        defaultSalePricePiastersPerKg: 700,
      ),
    );
    final supplier = await suppliers.createSupplier(
      const SupplierDraft(name: 'Phase 107B supplier', phone: '01110700107'),
    );
    final customer = await customers.createCustomer(
      const CustomerDraft(
        name: 'Phase 107B customer',
        phone: '01210700107',
        isActive: true,
      ),
    );
    final account = await financialAccounts.createAccount(
      const FinancialAccountDraft(
        name: 'Phase 107B treasury',
        type: FinancialAccountType.treasury,
        allowNegativeBalance: true,
        createdByUserId: 'owner-107b',
      ),
    );
    await financialAccounts.setOpeningBalance(
      accountId: account.id,
      amountQirsh: 100000,
      effectiveDate: DateTime.utc(2026, 8, 1),
      createdByUserId: 'owner-107b',
    );
    final purchase = await purchases.createPurchaseIntake(
      PurchaseIntakeDraft(
        supplierId: supplier.id,
        productId: product.id,
        quantityKg: 1000,
        entryUnit: GrainUnit.kilogram,
        unitPricePiastersPerKg: 500,
        createdByUserId: 'owner-107b',
      ),
    );
    await inventoryValuation.activate(
      activationDate: DateTime.utc(2026, 8, 8),
      approvedByUserId: 'owner-107b',
      evidenceNote: 'Phase 107B rollback fixture',
      openings: [
        OpeningValuationInput(
          productId: product.id,
          quantityKg: purchase.quantityKg,
          unitCostQirshPerKg: purchase.unitPricePiastersPerKg,
          evidenceReference: 'phase-107b-fixture',
        ),
      ],
    );
    await sales.createSale(
      SaleDraft(
        productId: product.id,
        quantityKg: 250,
        salePriceQirshPerKg: 750,
        createdByUserId: 'owner-107b',
        paymentMode: SalePaymentMode.credit,
        customerId: customer.id,
      ),
    );
    await expenses.createExpense(
      ExpenseDraft(
        date: DateTime.utc(2026, 8, 9),
        category: 'Transport',
        amountQirsh: 12500,
        createdByUserId: 'owner-107b',
        operationRequestId: 'phase-107b-expense',
        accountingClassification: ExpenseAccountingClassification.operating,
        financialAccountId: account.id,
        paymentMethod: PaymentMethod.cash,
      ),
    );
    await approvalRequests.createRequest(
      NegativeBalanceApprovalRequestDraft(
        idempotencyKey: 'phase-107b-request',
        operationType: NegativeBalanceApprovalRequestOperationType.expense,
        financialAccountId: account.id,
        paymentMethod: PaymentMethod.cash,
        amountQirsh: 500,
        sourceDocumentId: 'phase-107b-request',
        payloadJson: jsonEncode({'amountQirsh': 500}),
        payloadFingerprint: 'phase-107b-fingerprint',
        requesterActorId: 'employee-107b',
        balanceAtRequestQirsh: 0,
        expectedBalanceAtRequestQirsh: -500,
        deficitAtRequestQirsh: 500,
        reason: 'Phase 107B rollback fixture',
      ),
    );
    await auditLogs.record(
      const AuditLogDraft(
        actionType: 'phase107b.fixture',
        descriptionAr: 'Phase 107B rollback fixture',
        actorId: 'owner-107b',
        referenceId: 'phase-107b',
      ),
    );
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
          .map((row) => row.data.entries
              .map((entry) => '${entry.key}=${entry.value}')
              .join('|'))
          .toList()
        ..sort();
    }
    return snapshot;
  }

  Future<Map<String, Object>> cachedStateSnapshot() async => {
        'sales': (await sales.listSales()).map((value) => value.id).toList(),
        'valuation': (await inventoryValuation.listEvents())
            .map((value) => value.id)
            .toList(),
        'accounts':
            (await financialAccounts.listAccounts(includeInactive: true))
                .map((value) => value.id)
                .toList(),
        'accountBalances': {
          for (final account
              in await financialAccounts.listAccounts(includeInactive: true))
            account.id:
                await financialAccounts.currentBalanceForAccount(account.id),
        },
      };

  Future<List<String>> authRows() async =>
      (await database.customSelect('SELECT * FROM auth_accounts').get())
          .map((row) => row.data.toString())
          .toList();

  Future<void> expectBusinessStateEmpty() async {
    expect(await products.listProducts(), isEmpty);
    expect(await inventory.listAllMovements(), isEmpty);
    expect(await suppliers.listSuppliers(), isEmpty);
    expect(await purchases.listPurchaseIntakes(), isEmpty);
    expect(await sales.listSales(), isEmpty);
    expect(await history.listHistory(), isEmpty);
    expect(await customers.listCustomers(), isEmpty);
    expect(await customerAccounts.listEntries(), isEmpty);
    expect(await supplierAccounts.listEntries(), isEmpty);
    expect(await expenses.listExpenses(), isEmpty);
    expect(await auditLogs.exportStoredAuditLogs(), isEmpty);
    expect(
        await financialAccounts.listAccounts(includeInactive: true), isEmpty);
    expect(await approvalRequests.listAll(), isEmpty);
    expect(await approvalRequests.listTransitions(), isEmpty);
    expect(await inventoryValuation.listStates(), isEmpty);
    expect(await inventoryValuation.listEvents(), isEmpty);
    expect((await inventoryValuation.getActivation()).isActivated, isFalse);
  }

  Future<void> close() => database.close();
}

class _MemoryBackupFileWriter implements BackupFileWriter {
  const _MemoryBackupFileWriter();

  @override
  Future<BackupFileSaveResult> save({
    required String fileName,
    required String jsonText,
  }) async =>
      BackupFileSaveResult(
        fileName: fileName,
        filePath: 'C:\\phase-107b\\$fileName',
        folderPath: 'C:\\phase-107b',
      );
}
