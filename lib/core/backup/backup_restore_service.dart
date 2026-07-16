import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:grain_warehouse_erp_lite/core/auth/app_user.dart';
import 'package:grain_warehouse_erp_lite/core/financial_accounts/repository_transaction.dart';
import 'package:grain_warehouse_erp_lite/core/audit/audit_log_repository.dart';
import 'package:grain_warehouse_erp_lite/core/backup/backup_restore_preview.dart';
import 'package:grain_warehouse_erp_lite/core/business_identity/business_identity.dart';
import 'package:grain_warehouse_erp_lite/core/business_identity/business_identity_repository.dart';
import 'package:grain_warehouse_erp_lite/core/customer_accounts/customer_account_entry.dart';
import 'package:grain_warehouse_erp_lite/core/customer_accounts/customer_account_repository.dart';
import 'package:grain_warehouse_erp_lite/core/customer_accounts/customer_collection.dart';
import 'package:grain_warehouse_erp_lite/core/customer_accounts/customer_advance.dart';
import 'package:grain_warehouse_erp_lite/core/catalog/grain_unit.dart';
import 'package:grain_warehouse_erp_lite/core/catalog/product.dart';
import 'package:grain_warehouse_erp_lite/core/catalog/product_repository.dart';
import 'package:grain_warehouse_erp_lite/core/customers/customer.dart';
import 'package:grain_warehouse_erp_lite/core/customers/customer_repository.dart';
import 'package:grain_warehouse_erp_lite/core/documents/cancellation_metadata.dart';
import 'package:grain_warehouse_erp_lite/core/expenses/expense.dart';
import 'package:grain_warehouse_erp_lite/core/expenses/expense_repository.dart';
import 'package:grain_warehouse_erp_lite/core/documents/document_history.dart';
import 'package:grain_warehouse_erp_lite/core/financial_accounts/financial_account.dart';
import 'package:grain_warehouse_erp_lite/core/financial_accounts/financial_account_entry.dart';
import 'package:grain_warehouse_erp_lite/core/financial_accounts/financial_account_repository.dart';
import 'package:grain_warehouse_erp_lite/core/financial_accounts/financial_transfer.dart';
import 'package:grain_warehouse_erp_lite/core/financial_accounts/financial_closing.dart';
import 'package:grain_warehouse_erp_lite/core/inventory/inventory_repository.dart';
import 'package:grain_warehouse_erp_lite/core/inventory/stock_movement.dart';
import 'package:grain_warehouse_erp_lite/core/purchases/purchase_intake.dart';
import 'package:grain_warehouse_erp_lite/core/purchases/purchase_repository.dart';
import 'package:grain_warehouse_erp_lite/core/sales/sale_record.dart';
import 'package:grain_warehouse_erp_lite/core/sales/sale_repository.dart';
import 'package:grain_warehouse_erp_lite/core/supplier_accounts/supplier_account_entry.dart';
import 'package:grain_warehouse_erp_lite/core/supplier_accounts/supplier_account_repository.dart';
import 'package:grain_warehouse_erp_lite/core/supplier_accounts/supplier_payment.dart';
import 'package:grain_warehouse_erp_lite/core/supplier_accounts/supplier_advance.dart';
import 'package:grain_warehouse_erp_lite/core/suppliers/supplier.dart';
import 'package:grain_warehouse_erp_lite/core/suppliers/supplier_repository.dart';

class BackupRestoreService {
  BackupRestoreService({
    required ProductDataRepository productRepository,
    required DurableInventoryRepository inventoryRepository,
    required SupplierDataRepository supplierRepository,
    required DurablePurchaseRepository purchaseRepository,
    required DurableSaleRepository saleRepository,
    required DocumentHistoryRepository documentHistoryRepository,
    BusinessIdentityRepository? businessIdentityRepository,
    CustomerDataRepository? customerRepository,
    LocalCustomerAccountRepository? customerAccountRepository,
    LocalSupplierAccountRepository? supplierAccountRepository,
    DurableExpenseRepository? expenseRepository,
    DurableAuditLogRepository? auditLogRepository,
    LocalFinancialAccountRepository? financialAccountRepository,
    BackupRestorePreviewService previewService =
        const BackupRestorePreviewService(),
  })  : _productRepository = productRepository,
        _inventoryRepository = inventoryRepository,
        _supplierRepository = supplierRepository,
        _purchaseRepository = purchaseRepository,
        _saleRepository = saleRepository,
        _documentHistoryRepository = documentHistoryRepository,
        _businessIdentityRepository = businessIdentityRepository,
        _customerRepository = customerRepository ?? LocalCustomerRepository(),
        _customerAccountRepository = customerAccountRepository ??
            LocalCustomerAccountRepository(
                customerRepository:
                    customerRepository ?? LocalCustomerRepository()),
        _supplierAccountRepository = supplierAccountRepository ??
            LocalSupplierAccountRepository(
                supplierRepository: supplierRepository),
        _expenseRepository = expenseRepository ?? LocalExpenseRepository(),
        _auditLogRepository = auditLogRepository ?? LocalAuditLogRepository(),
        _financialAccountRepository =
            financialAccountRepository ?? LocalFinancialAccountRepository(),
        _previewService = previewService;

  final ProductDataRepository _productRepository;
  final DurableInventoryRepository _inventoryRepository;
  final SupplierDataRepository _supplierRepository;
  final DurablePurchaseRepository _purchaseRepository;
  final DurableSaleRepository _saleRepository;
  final DocumentHistoryRepository _documentHistoryRepository;
  final BusinessIdentityRepository? _businessIdentityRepository;
  final CustomerDataRepository _customerRepository;
  final LocalCustomerAccountRepository _customerAccountRepository;
  final LocalSupplierAccountRepository _supplierAccountRepository;
  final DurableExpenseRepository _expenseRepository;
  final DurableAuditLogRepository _auditLogRepository;
  final LocalFinancialAccountRepository _financialAccountRepository;
  final BackupRestorePreviewService _previewService;

  Future<BackupRestoreResult> restoreToEmpty({
    required AppUser? user,
    required String jsonText,
  }) async {
    if (user?.permissions.canExportBackups != true) {
      return const BackupRestoreResult.failure(
        message: 'هذه الأداة متاحة للمالك فقط.',
        technicalReason: 'not-owner',
      );
    }

    final preview = _previewService.preview(jsonText);
    if (!preview.isValid) {
      return BackupRestoreResult.failure(
        message: preview.message,
        technicalReason: preview.technicalReason ?? 'invalid-preview',
      );
    }

    try {
      final decoded = jsonDecode(jsonText) as Map<String, Object?>;
      final data = decoded['data'] as Map<String, Object?>;
      final restored = _parseBackupData(data);
      _validateRelationships(restored);
      final emptyCheck = await _checkEmptySystem();
      if (emptyCheck != null) {
        return BackupRestoreResult.failure(
          message: emptyCheck,
          technicalReason: 'system-not-empty',
        );
      }

      final snapshots = <SnapshotHolder>[
        _productRepository.createTransactionSnapshot(),
        _supplierRepository.createTransactionSnapshot(),
        _inventoryRepository.createTransactionSnapshot(),
        _purchaseRepository.createTransactionSnapshot(),
        _saleRepository.createTransactionSnapshot(),
        _customerRepository.createTransactionSnapshot(),
        _customerAccountRepository.createTransactionSnapshot(),
        _supplierAccountRepository.createTransactionSnapshot(),
        _expenseRepository.createTransactionSnapshot(),
        _auditLogRepository.createTransactionSnapshot(),
        _financialAccountRepository.createTransactionSnapshot(),
      ];

      await RepositoryTransaction.execute(snapshots, () async {
        await _productRepository.restoreProductsIntoEmpty(restored.products);
        await _supplierRepository.restoreSuppliersIntoEmpty(restored.suppliers);
        await _inventoryRepository
            .restoreMovementsIntoEmpty(restored.movements);
        await _purchaseRepository.restorePurchaseIntakesIntoEmpty(
          restored.purchases,
        );
        await _saleRepository.restoreSalesIntoEmpty(restored.sales);
        await _customerRepository.restoreCustomersIntoEmpty(restored.customers);
        await _customerAccountRepository.restoreCustomerAccountsIntoEmpty(
          entries: restored.customerAccountEntries,
          collections: restored.customerCollections,
          advances: restored.customerAdvances,
          applications: restored.customerAdvanceApplications,
          refunds: restored.customerAdvanceRefunds,
        );
        await _supplierAccountRepository.restoreSupplierAccountsIntoEmpty(
          entries: restored.supplierAccountEntries,
          payments: restored.supplierPayments,
          advances: restored.supplierAdvances,
          applications: restored.supplierAdvanceApplications,
          refunds: restored.supplierAdvanceRefunds,
        );
        await _expenseRepository.restoreExpensesIntoEmpty(restored.expenses);
        await _auditLogRepository.restoreAuditLogsIntoEmpty(restored.auditLogs);
        await _financialAccountRepository.restoreFinancialAccountsIntoEmpty(
          accounts: restored.financialAccounts,
          entries: restored.financialAccountEntries,
          transfers: restored.financialTransfers,
          closings: restored.financialClosings,
        );
        if (_businessIdentityRepository != null) {
          await _businessIdentityRepository.saveIdentity(
            restored.businessIdentity,
          );
        }
      });

      final warnings = <String>[
        'تم الاسترجاع إلى نظام كان فارغا فقط.',
        'لم يتم استرجاع مستخدمين أو كلمات مرور أو جلسات دخول.',
      ];
      if (restored.logoRestoreWarning != null) {
        warnings.add(restored.logoRestoreWarning!);
      }
      return BackupRestoreResult.success(
        counts: preview.summary!.counts,
        metadata: preview.summary!,
        warnings: warnings,
      );
    } catch (_) {
      return const BackupRestoreResult.failure(
        message:
            'تعذر استرجاع النسخة الاحتياطية. لم يتم تنفيذ العملية إذا كانت البيانات غير صالحة.',
        technicalReason: 'restore-failed',
      );
    }
  }

  Future<String?> _checkEmptySystem() async {
    final products =
        await _productRepository.listProducts(includeInactive: true);
    final movements = await _inventoryRepository.listAllMovements();
    final suppliers = await _supplierRepository.listSuppliers(
      includeInactive: true,
    );
    final purchases = await _purchaseRepository.listPurchaseIntakes();
    final sales = await _saleRepository.listSales();
    final history = await _documentHistoryRepository.listHistory();
    final customers =
        await _customerRepository.listCustomers(includeInactive: true);
    final customerAccountEntries =
        await _customerAccountRepository.listEntries();
    final customerCollections =
        await _customerAccountRepository.listCollections();
    final supplierAccountEntries =
        await _supplierAccountRepository.listEntries();
    final supplierPayments = await _supplierAccountRepository.listPayments();
    final expenses = await _expenseRepository.listExpenses();
    final auditLogs = await _auditLogRepository.listLogs();
    final financialAccounts =
        await _financialAccountRepository.listAccounts(includeInactive: true);

    if (products.isNotEmpty ||
        movements.isNotEmpty ||
        suppliers.isNotEmpty ||
        purchases.isNotEmpty ||
        sales.isNotEmpty ||
        history.isNotEmpty ||
        customers.isNotEmpty ||
        customerAccountEntries.isNotEmpty ||
        customerCollections.isNotEmpty ||
        supplierAccountEntries.isNotEmpty ||
        supplierPayments.isNotEmpty ||
        expenses.isNotEmpty ||
        auditLogs.isNotEmpty ||
        financialAccounts.isNotEmpty) {
      return 'النظام الحالي ليس فارغا. لا يمكن استرجاع النسخة لأن النظام يحتوي على بيانات حالية. الاسترجاع في هذه المرحلة متاح فقط على نظام فارغ لحماية بيانات المخزن من الاستبدال أو التكرار.';
    }

    return null;
  }

  _RestoredBackupData _parseBackupData(Map<String, Object?> data) {
    final products = _list(data, 'products').map(_parseProduct).toList();
    final suppliers = _list(data, 'suppliers').map(_parseSupplier).toList();
    final movements =
        _list(data, 'inventoryMovements').map(_parseMovement).toList();
    final purchases = _list(data, 'purchases').map(_parsePurchase).toList();
    final sales = _list(data, 'sales').map(_parseSale).toList();
    final customers =
        _optionalList(data, 'customers').map(_parseCustomer).toList();
    final customerAccountEntries = _optionalList(data, 'customerAccountEntries')
        .map(_parseCustomerAccountEntry)
        .toList();
    final customerCollections = _optionalList(data, 'customerCollections')
        .map(_parseCustomerCollection)
        .toList();
    final customerAdvances = _optionalList(data, 'customerAdvances')
        .map(_parseCustomerAdvance)
        .toList();
    final customerAdvanceApplications =
        _optionalList(data, 'customerAdvanceApplications')
            .map(_parseCustomerAdvanceApplication)
            .toList();
    final customerAdvanceRefunds = _optionalList(data, 'customerAdvanceRefunds')
        .map(_parseCustomerAdvanceRefund)
        .toList();
    final supplierAccountEntries = _optionalList(data, 'supplierAccountEntries')
        .map(_parseSupplierAccountEntry)
        .toList();
    final supplierPayments = _optionalList(data, 'supplierPayments')
        .map(_parseSupplierPayment)
        .toList();
    final supplierAdvances = _optionalList(data, 'supplierAdvances')
        .map(_parseSupplierAdvance)
        .toList();
    final supplierAdvanceApplications =
        _optionalList(data, 'supplierAdvanceApplications')
            .map(_parseSupplierAdvanceApplication)
            .toList();
    final supplierAdvanceRefunds = _optionalList(data, 'supplierAdvanceRefunds')
        .map(_parseSupplierAdvanceRefund)
        .toList();
    final expenses =
        _optionalList(data, 'expenses').map(_parseExpense).toList();
    final auditLogs =
        _optionalList(data, 'auditLogs').map(_parseAuditLog).toList();
    final financialAccounts = _optionalList(data, 'financialAccounts')
        .map(_parseFinancialAccount)
        .toList();
    final financialAccountEntries =
        _optionalList(data, 'financialAccountEntries')
            .map(_parseFinancialAccountEntry)
            .toList();
    final financialTransfers = _optionalList(data, 'financialTransfers')
        .map(_parseFinancialTransfer)
        .toList();
    final financialClosings = _optionalList(data, 'financialClosings')
        .map(_parseFinancialClosing)
        .toList();
    final settings = data['settings'];
    final settingsMap =
        settings is Map<String, Object?> ? settings : <String, Object?>{};
    final identityJson = settingsMap['businessIdentity'];
    final identityMap = identityJson is Map<String, Object?>
        ? identityJson
        : <String, Object?>{};
    final logoPayload = identityMap['logo'];

    LogoMetadata? restoredLogo;
    if (logoPayload is Map<String, Object?> &&
        _businessIdentityRepository != null) {
      restoredLogo = _restoreLogoPayload(
        logoPayload,
        _businessIdentityRepository,
      );
    }

    final baseIdentity = BusinessIdentity.fromJson(identityJson);
    final businessIdentity = restoredLogo != null
        ? baseIdentity.copyWith(logo: restoredLogo)
        : baseIdentity;

    return _RestoredBackupData(
      products: products,
      suppliers: suppliers,
      movements: movements,
      purchases: purchases,
      sales: sales,
      customers: customers,
      customerAccountEntries: customerAccountEntries,
      customerCollections: customerCollections,
      customerAdvances: customerAdvances,
      customerAdvanceApplications: customerAdvanceApplications,
      customerAdvanceRefunds: customerAdvanceRefunds,
      supplierAccountEntries: supplierAccountEntries,
      supplierPayments: supplierPayments,
      supplierAdvances: supplierAdvances,
      supplierAdvanceApplications: supplierAdvanceApplications,
      supplierAdvanceRefunds: supplierAdvanceRefunds,
      expenses: expenses,
      auditLogs: auditLogs,
      financialAccounts: financialAccounts,
      financialAccountEntries: financialAccountEntries,
      financialTransfers: financialTransfers,
      financialClosings: financialClosings,
      businessIdentity: businessIdentity,
      documentHistoryCount: _list(data, 'documentHistory').length,
      logoRestoreWarning: _logoRestoreWarning,
    );
  }

  List<Object?> _list(Map<String, Object?> data, String key) {
    final value = data[key];
    if (value is! List<Object?>) {
      throw StateError('Invalid backup list: $key');
    }
    return value;
  }

  List<Object?> _optionalList(Map<String, Object?> data, String key) {
    final value = data[key];
    if (value == null) {
      return const [];
    }
    if (value is! List<Object?>) {
      throw StateError('Invalid backup list: $key');
    }
    return value;
  }

  Product _parseProduct(Object? value) {
    final map = _map(value);
    return Product(
      id: _string(map, 'id'),
      name: _string(map, 'name'),
      code: _optionalString(map, 'code'),
      unit: GrainUnit.values.byName(_string(map, 'unit')),
      isActive: _bool(map, 'isActive'),
      defaultSalePricePiastersPerKg:
          _optionalInt(map, 'defaultSalePricePiastersPerKg'),
      minimumSalePricePiastersPerKg:
          _optionalInt(map, 'minimumSalePricePiastersPerKg'),
      referenceCostPricePiastersPerKg:
          _optionalInt(map, 'referenceCostPricePiastersPerKg'),
      notes: _optionalString(map, 'notes'),
      createdAt: _date(map, 'createdAt'),
      updatedAt: _date(map, 'updatedAt'),
    );
  }

  Supplier _parseSupplier(Object? value) {
    final map = _map(value);
    return Supplier(
      id: _string(map, 'id'),
      name: _string(map, 'name'),
      phone: _optionalString(map, 'phone'),
      address: _optionalString(map, 'address'),
      notes: _optionalString(map, 'notes'),
      isActive: _bool(map, 'isActive'),
      createdAt: _date(map, 'createdAt'),
      updatedAt: _date(map, 'updatedAt'),
    );
  }

  StockMovement _parseMovement(Object? value) {
    final map = _map(value);
    return StockMovement(
      id: _string(map, 'id'),
      productId: _string(map, 'productId'),
      movementType:
          StockMovementType.values.byName(_string(map, 'movementType')),
      quantityKg: _int(map, 'quantityKg'),
      createdByUserId: _string(map, 'createdByUserId'),
      createdAt: _date(map, 'createdAt'),
      note: _optionalString(map, 'note'),
      isVoided: _optionalBool(map, 'isVoided') ?? false,
      reversedMovementId: _optionalString(map, 'reversedMovementId'),
      originalDocumentId: _optionalString(map, 'originalDocumentId'),
    );
  }

  PurchaseIntake _parsePurchase(Object? value) {
    final map = _map(value);
    return PurchaseIntake(
      id: _string(map, 'id'),
      supplierId: _string(map, 'supplierId'),
      supplierName: _optionalString(map, 'supplierName'),
      supplierPhone: _optionalString(map, 'supplierPhone'),
      supplierAddress: _optionalString(map, 'supplierAddress'),
      productId: _string(map, 'productId'),
      quantityKg: _int(map, 'quantityKg'),
      entryUnit: GrainUnit.values.byName(_string(map, 'entryUnit')),
      unitPricePiastersPerKg: _int(map, 'unitPricePiastersPerKg'),
      totalAmountPiasters: _int(map, 'totalAmountPiasters'),
      createdByUserId: _string(map, 'createdByUserId'),
      createdAt: _date(map, 'createdAt'),
      stockMovementId: _string(map, 'stockMovementId'),
      notes: _optionalString(map, 'notes'),
      cancellation: _parseCancellation(map['cancellation']),
      financialAccountId: _optionalString(map, 'financialAccountId'),
      paymentMethod: _optionalPaymentMethod(map),
    );
  }

  SaleRecord _parseSale(Object? value) {
    final map = _map(value);
    final paymentMode = SalePaymentMode.values.byName(
      _optionalString(map, 'paymentMode') ?? SalePaymentMode.cash.name,
    );
    final items =
        _optionalList(map, 'items').map(_parseSaleItem).toList(growable: false);
    final paymentAllocations = _optionalList(map, 'paymentAllocations')
        .map(_parseSalePaymentAllocation)
        .toList(growable: false);
    return SaleRecord(
      id: _string(map, 'id'),
      productId: _string(map, 'productId'),
      quantityKg: _int(map, 'quantityKg'),
      salePriceQirshPerKg: _int(map, 'salePriceQirshPerKg'),
      totalQirsh: _int(map, 'totalQirsh'),
      createdByUserId: _string(map, 'createdByUserId'),
      createdByUserName: _optionalString(map, 'createdByUserName'),
      createdAt: _date(map, 'createdAt'),
      stockMovementId: _string(map, 'stockMovementId'),
      paymentMode: paymentMode,
      customerId: _optionalString(map, 'customerId'),
      notes: _optionalString(map, 'notes'),
      cancellation: _parseCancellation(map['cancellation']),
      items: items,
      paidAmountQirsh: _optionalInt(map, 'paidAmountQirsh'),
      financialAccountId: _optionalString(map, 'financialAccountId'),
      paymentMethod: _optionalPaymentMethod(map),
      paymentAllocations: paymentAllocations,
      operationRequestId: _optionalString(map, 'operationRequestId'),
    );
  }

  SalePaymentAllocation _parseSalePaymentAllocation(Object? value) {
    final map = _map(value);
    return SalePaymentAllocation(
      financialAccountId: _string(map, 'financialAccountId'),
      amountQirsh: _int(map, 'amountQirsh'),
      paymentMethod: PaymentMethod.values.byName(_string(map, 'paymentMethod')),
    );
  }

  CustomerCollectionCancellation? _parseCustomerCollectionCancellation(
    Object? value,
  ) {
    if (value == null) return null;
    final map = _map(value);
    return CustomerCollectionCancellation(
      id: _string(map, 'id'),
      originalCollectionId: _string(map, 'originalCollectionId'),
      cancelledAt: _date(map, 'cancelledAt'),
      cancelledByUserId: _string(map, 'cancelledByUserId'),
      reason: _string(map, 'reason'),
      customerLedgerReversalEntryId:
          _string(map, 'customerLedgerReversalEntryId'),
      financialAccountReversalEntryId:
          _optionalString(map, 'financialAccountReversalEntryId'),
    );
  }

  SupplierPaymentCancellation? _parseSupplierPaymentCancellation(
    Object? value,
  ) {
    if (value == null) return null;
    final map = _map(value);
    return SupplierPaymentCancellation(
      id: _string(map, 'id'),
      originalPaymentId: _string(map, 'originalPaymentId'),
      cancelledAt: _date(map, 'cancelledAt'),
      cancelledByUserId: _string(map, 'cancelledByUserId'),
      reason: _string(map, 'reason'),
      supplierLedgerReversalEntryId:
          _string(map, 'supplierLedgerReversalEntryId'),
      financialAccountReversalEntryId:
          _optionalString(map, 'financialAccountReversalEntryId'),
    );
  }

  SaleLineItem _parseSaleItem(Object? value) {
    final map = _map(value);
    return SaleLineItem(
      productId: _string(map, 'productId'),
      quantityKg: _int(map, 'quantityKg'),
      salePriceQirshPerKg: _int(map, 'salePriceQirshPerKg'),
      lineTotalQirsh: _int(map, 'lineTotalQirsh'),
    );
  }

  CustomerAccountEntry _parseCustomerAccountEntry(Object? value) {
    final map = _map(value);
    return CustomerAccountEntry(
      id: _string(map, 'id'),
      customerId: _string(map, 'customerId'),
      date: _date(map, 'date'),
      type: CustomerAccountEntryType.values.byName(_string(map, 'type')),
      debitAmountQirsh: _int(map, 'debitAmountQirsh'),
      creditAmountQirsh: _int(map, 'creditAmountQirsh'),
      sourceDocumentType: _string(map, 'sourceDocumentType'),
      sourceDocumentId: _string(map, 'sourceDocumentId'),
      descriptionAr: _string(map, 'descriptionAr'),
      createdAt: _date(map, 'createdAt'),
      createdByUserId: _string(map, 'createdByUserId'),
    );
  }

  CustomerCollectionRecord _parseCustomerCollection(Object? value) {
    final map = _map(value);
    return CustomerCollectionRecord(
      id: _string(map, 'id'),
      customerId: _string(map, 'customerId'),
      date: _date(map, 'date'),
      amountQirsh: _int(map, 'amountQirsh'),
      createdAt: _date(map, 'createdAt'),
      createdByUserId: _string(map, 'createdByUserId'),
      createdByUserName: _optionalString(map, 'createdByUserName'),
      notes: _optionalString(map, 'notes'),
      financialAccountId: _optionalString(map, 'financialAccountId'),
      paymentMethod: _optionalPaymentMethod(map),
      settledAmountQirsh: _optionalInt(map, 'settledAmountQirsh'),
      advanceAmountQirsh: _optionalInt(map, 'advanceAmountQirsh') ?? 0,
      cancellation: _parseCustomerCollectionCancellation(map['cancellation']),
    );
  }

  Customer _parseCustomer(Object? value) {
    final map = _map(value);
    return Customer(
      id: _string(map, 'id'),
      name: _string(map, 'name'),
      phone: _optionalString(map, 'phone'),
      notes: _optionalString(map, 'notes'),
      isActive: _bool(map, 'isActive'),
      createdAt: _date(map, 'createdAt'),
      updatedAt: _date(map, 'updatedAt'),
    );
  }

  CustomerAdvance _parseCustomerAdvance(Object? value) {
    final map = _map(value);
    return CustomerAdvance(
      id: _string(map, 'id'),
      customerId: _string(map, 'customerId'),
      sourceCollectionId: _string(map, 'sourceCollectionId'),
      financialAccountId: _string(map, 'financialAccountId'),
      amountQirsh: _int(map, 'amountQirsh'),
      createdAt: _date(map, 'createdAt'),
      createdByUserId: _string(map, 'createdByUserId'),
      ownerApprovalId: _string(map, 'ownerApprovalId'),
      operationRequestId: _string(map, 'operationRequestId'),
      paymentMethod: _optionalPaymentMethod(map),
      reversedAt: map['reversedAt'] == null ? null : _date(map, 'reversedAt'),
      reversedByUserId: _optionalString(map, 'reversedByUserId'),
    );
  }

  CustomerAdvanceApplication _parseCustomerAdvanceApplication(Object? value) {
    final map = _map(value);
    return CustomerAdvanceApplication(
      id: _string(map, 'id'),
      advanceId: _string(map, 'advanceId'),
      customerId: _string(map, 'customerId'),
      amountQirsh: _int(map, 'amountQirsh'),
      appliedAt: _date(map, 'appliedAt'),
      createdByUserId: _string(map, 'createdByUserId'),
      operationRequestId: _string(map, 'operationRequestId'),
      customerLedgerEntryId: _string(map, 'customerLedgerEntryId'),
      reversedAt: map['reversedAt'] == null ? null : _date(map, 'reversedAt'),
      reversedByUserId: _optionalString(map, 'reversedByUserId'),
      reversalReason: _optionalString(map, 'reversalReason'),
      reversalLedgerEntryId: _optionalString(map, 'reversalLedgerEntryId'),
    );
  }

  CustomerAdvanceRefund _parseCustomerAdvanceRefund(Object? value) {
    final map = _map(value);
    return CustomerAdvanceRefund(
      id: _string(map, 'id'),
      advanceId: _string(map, 'advanceId'),
      customerId: _string(map, 'customerId'),
      financialAccountId: _string(map, 'financialAccountId'),
      amountQirsh: _int(map, 'amountQirsh'),
      refundedAt: _date(map, 'refundedAt'),
      createdByUserId: _string(map, 'createdByUserId'),
      operationRequestId: _string(map, 'operationRequestId'),
      financialEntryId: _string(map, 'financialEntryId'),
      reversedAt: map['reversedAt'] == null ? null : _date(map, 'reversedAt'),
      reversedByUserId: _optionalString(map, 'reversedByUserId'),
      reversalReason: _optionalString(map, 'reversalReason'),
      reversalFinancialEntryId:
          _optionalString(map, 'reversalFinancialEntryId'),
    );
  }

  SupplierAccountEntry _parseSupplierAccountEntry(Object? value) {
    final map = _map(value);
    return SupplierAccountEntry(
      id: _string(map, 'id'),
      supplierId: _string(map, 'supplierId'),
      date: _date(map, 'date'),
      type: SupplierAccountEntryType.values.byName(_string(map, 'type')),
      debitAmountQirsh: _int(map, 'debitAmountQirsh'),
      creditAmountQirsh: _int(map, 'creditAmountQirsh'),
      sourceDocumentType: _string(map, 'sourceDocumentType'),
      sourceDocumentId: _string(map, 'sourceDocumentId'),
      descriptionAr: _string(map, 'descriptionAr'),
      createdAt: _date(map, 'createdAt'),
      createdByUserId: _string(map, 'createdByUserId'),
    );
  }

  SupplierPaymentRecord _parseSupplierPayment(Object? value) {
    final map = _map(value);
    return SupplierPaymentRecord(
      id: _string(map, 'id'),
      supplierId: _string(map, 'supplierId'),
      date: _date(map, 'date'),
      amountQirsh: _int(map, 'amountQirsh'),
      createdAt: _date(map, 'createdAt'),
      createdByUserId: _string(map, 'createdByUserId'),
      createdByUserName: _optionalString(map, 'createdByUserName'),
      notes: _optionalString(map, 'notes'),
      financialAccountId: _optionalString(map, 'financialAccountId'),
      paymentMethod: _optionalPaymentMethod(map),
      settledAmountQirsh: _optionalInt(map, 'settledAmountQirsh'),
      advanceAmountQirsh: _optionalInt(map, 'advanceAmountQirsh') ?? 0,
      cancellation: _parseSupplierPaymentCancellation(map['cancellation']),
    );
  }

  SupplierAdvance _parseSupplierAdvance(Object? value) {
    final map = _map(value);
    return SupplierAdvance(
      id: _string(map, 'id'),
      supplierId: _string(map, 'supplierId'),
      sourcePaymentId: _string(map, 'sourcePaymentId'),
      financialAccountId: _string(map, 'financialAccountId'),
      amountQirsh: _int(map, 'amountQirsh'),
      createdAt: _date(map, 'createdAt'),
      createdByUserId: _string(map, 'createdByUserId'),
      ownerApprovalId: _string(map, 'ownerApprovalId'),
      operationRequestId: _string(map, 'operationRequestId'),
      paymentMethod: _optionalPaymentMethod(map),
      reversedAt: map['reversedAt'] == null ? null : _date(map, 'reversedAt'),
      reversedByUserId: _optionalString(map, 'reversedByUserId'),
    );
  }

  SupplierAdvanceApplication _parseSupplierAdvanceApplication(Object? value) {
    final map = _map(value);
    return SupplierAdvanceApplication(
      id: _string(map, 'id'),
      advanceId: _string(map, 'advanceId'),
      supplierId: _string(map, 'supplierId'),
      amountQirsh: _int(map, 'amountQirsh'),
      appliedAt: _date(map, 'appliedAt'),
      createdByUserId: _string(map, 'createdByUserId'),
      operationRequestId: _string(map, 'operationRequestId'),
      supplierLedgerEntryId: _string(map, 'supplierLedgerEntryId'),
      reversedAt: map['reversedAt'] == null ? null : _date(map, 'reversedAt'),
      reversedByUserId: _optionalString(map, 'reversedByUserId'),
      reversalReason: _optionalString(map, 'reversalReason'),
      reversalLedgerEntryId: _optionalString(map, 'reversalLedgerEntryId'),
    );
  }

  SupplierAdvanceRefund _parseSupplierAdvanceRefund(Object? value) {
    final map = _map(value);
    return SupplierAdvanceRefund(
      id: _string(map, 'id'),
      advanceId: _string(map, 'advanceId'),
      supplierId: _string(map, 'supplierId'),
      financialAccountId: _string(map, 'financialAccountId'),
      amountQirsh: _int(map, 'amountQirsh'),
      refundedAt: _date(map, 'refundedAt'),
      createdByUserId: _string(map, 'createdByUserId'),
      operationRequestId: _string(map, 'operationRequestId'),
      financialEntryId: _string(map, 'financialEntryId'),
      reversedAt: map['reversedAt'] == null ? null : _date(map, 'reversedAt'),
      reversedByUserId: _optionalString(map, 'reversedByUserId'),
      reversalReason: _optionalString(map, 'reversalReason'),
      reversalFinancialEntryId:
          _optionalString(map, 'reversalFinancialEntryId'),
    );
  }

  ExpenseRecord _parseExpense(Object? value) {
    final map = _map(value);
    return ExpenseRecord(
      id: _string(map, 'id'),
      date: _date(map, 'date'),
      category: _string(map, 'category'),
      amountQirsh: _int(map, 'amountQirsh'),
      notes: _optionalString(map, 'notes'),
      createdAt: _date(map, 'createdAt'),
      financialAccountId: _optionalString(map, 'financialAccountId'),
      paymentMethod: _optionalPaymentMethod(map),
    );
  }

  AuditLogEntry _parseAuditLog(Object? value) {
    final map = _map(value);
    return AuditLogEntry(
      id: _string(map, 'id'),
      timestamp: _date(map, 'timestamp'),
      actionType: _string(map, 'actionType'),
      descriptionAr: _string(map, 'descriptionAr'),
      referenceId: _optionalString(map, 'referenceId'),
      metadata: map['metadata'] == null
          ? const <String, Object?>{}
          : Map<String, Object?>.from(_map(map['metadata'])),
    );
  }

  FinancialAccount _parseFinancialAccount(Object? value) {
    final map = _map(value);
    final openingBalanceDateStr = _optionalString(map, 'openingBalanceDate');
    return FinancialAccount(
      id: _string(map, 'id'),
      name: _string(map, 'name'),
      type: FinancialAccountType.values.byName(_string(map, 'type')),
      isActive: _optionalBool(map, 'isActive') ?? true,
      allowNegativeBalance: _optionalBool(map, 'allowNegativeBalance') ?? false,
      openingBalanceQirsh: _optionalInt(map, 'openingBalanceQirsh') ?? 0,
      openingBalanceDate: openingBalanceDateStr != null
          ? DateTime.parse(openingBalanceDateStr)
          : null,
      referenceInfo: _optionalString(map, 'referenceInfo'),
      notes: _optionalString(map, 'notes'),
      createdByUserId: _string(map, 'createdByUserId'),
      createdAt: _date(map, 'createdAt'),
    );
  }

  FinancialAccountEntry _parseFinancialAccountEntry(Object? value) {
    final map = _map(value);
    return FinancialAccountEntry(
      id: _string(map, 'id'),
      accountId: _string(map, 'accountId'),
      direction: FinancialAccountEntryDirection.values
          .byName(_string(map, 'direction')),
      amountQirsh: _int(map, 'amountQirsh'),
      sourceType:
          FinancialAccountEntrySource.values.byName(_string(map, 'sourceType')),
      sourceDocumentId: _string(map, 'sourceDocumentId'),
      sourceDocumentNumber: _optionalString(map, 'sourceDocumentNumber'),
      effectiveDate: _date(map, 'effectiveDate'),
      createdAt: _date(map, 'createdAt'),
      createdByUserId: _string(map, 'createdByUserId'),
      reference: _optionalString(map, 'reference'),
      note: _optionalString(map, 'note'),
      reversalOf: _optionalString(map, 'reversalOf'),
      correctionGroup: _optionalString(map, 'correctionGroup'),
      approvedByUserId: _optionalString(map, 'approvedByUserId'),
      negativeBalanceApprovalId:
          _optionalString(map, 'negativeBalanceApprovalId'),
    );
  }

  FinancialTransfer _parseFinancialTransfer(Object? value) {
    final map = _map(value);
    return FinancialTransfer(
      id: _string(map, 'id'),
      displayNumber: _string(map, 'displayNumber'),
      clientRequestId: _string(map, 'clientRequestId'),
      transferReference: _string(map, 'transferReference'),
      sourceAccountId: _string(map, 'sourceAccountId'),
      destinationAccountId: _string(map, 'destinationAccountId'),
      amountQirsh: _int(map, 'amountQirsh'),
      effectiveDate: _date(map, 'effectiveDate'),
      createdAt: _date(map, 'createdAt'),
      createdByUserId: _string(map, 'createdByUserId'),
      sourceEntryId: _string(map, 'sourceEntryId'),
      destinationEntryId: _string(map, 'destinationEntryId'),
      note: _optionalString(map, 'note'),
      negativeBalanceApprovalId:
          _optionalString(map, 'negativeBalanceApprovalId'),
      originalTransferId: _optionalString(map, 'originalTransferId'),
      reversalTransferId: _optionalString(map, 'reversalTransferId'),
      reversalReason: _optionalString(map, 'reversalReason'),
    );
  }

  FinancialClosing _parseFinancialClosing(Object? value) {
    final map = _map(value);
    final rawLines = map['lines'];
    if (rawLines is! List<Object?>) {
      throw StateError('Invalid financial closing lines.');
    }
    return FinancialClosing(
      id: _string(map, 'id'),
      kind: FinancialClosingKind.values.byName(_string(map, 'kind')),
      fromDate: _date(map, 'fromDate'),
      toDate: _date(map, 'toDate'),
      lines: rawLines.map((raw) {
        final line = _map(raw);
        return FinancialClosingLine(
            accountId: _string(line, 'accountId'),
            expectedBalanceQirsh: _int(line, 'expectedBalanceQirsh'),
            actualBalanceQirsh: _int(line, 'actualBalanceQirsh'));
      }).toList(growable: false),
      createdAt: _date(map, 'createdAt'),
      createdByUserId: _string(map, 'createdByUserId'),
      note: _optionalString(map, 'note'),
      reopenedAt: map['reopenedAt'] == null ? null : _date(map, 'reopenedAt'),
      reopenedByUserId: _optionalString(map, 'reopenedByUserId'),
      reopenReason: _optionalString(map, 'reopenReason'),
    );
  }

  CancellationMetadata? _parseCancellation(Object? value) {
    if (value == null) {
      return null;
    }
    final map = _map(value);
    final reversalIds = map['reversalMovementIds'];
    if (reversalIds is! List<Object?>) {
      throw StateError('Invalid cancellation reversal ids.');
    }
    return CancellationMetadata(
      cancelledAt: _date(map, 'cancelledAt'),
      cancelledByUserId: _string(map, 'cancelledByUserId'),
      cancellationReason: _string(map, 'cancellationReason'),
      originalDocumentId: _string(map, 'originalDocumentId'),
      reversalMovementIds: reversalIds.map((id) => id as String).toList(),
    );
  }

  void _validateRelationships(_RestoredBackupData data) {
    final productIds = data.products.map((product) => product.id).toSet();
    final supplierIds = data.suppliers.map((supplier) => supplier.id).toSet();
    final movementIds = data.movements.map((movement) => movement.id).toSet();
    final financialAccountIds =
        data.financialAccounts.map((account) => account.id).toSet();

    if (productIds.length != data.products.length ||
        supplierIds.length != data.suppliers.length ||
        movementIds.length != data.movements.length) {
      throw StateError('Duplicate backup ids.');
    }
    for (final movement in data.movements) {
      if (!productIds.contains(movement.productId)) {
        throw StateError('Movement references missing product.');
      }
      final reversedMovementId = movement.reversedMovementId;
      if (reversedMovementId != null &&
          !movementIds.contains(reversedMovementId)) {
        throw StateError('Movement references missing reversed movement.');
      }
    }
    for (final purchase in data.purchases) {
      if (!productIds.contains(purchase.productId) ||
          !supplierIds.contains(purchase.supplierId) ||
          !movementIds.contains(purchase.stockMovementId) ||
          purchase.totalAmountPiasters !=
              purchase.quantityKg * purchase.unitPricePiastersPerKg) {
        throw StateError('Invalid purchase relationship.');
      }
      _validateCancellationReferences(purchase.cancellation, movementIds);
      _validateFinancialAccountReference(
          purchase.financialAccountId, financialAccountIds);
    }
    for (final sale in data.sales) {
      if (!productIds.contains(sale.productId) ||
          !movementIds.contains(sale.stockMovementId)) {
        throw StateError('Invalid sale relationship.');
      }
      if (sale.items.isNotEmpty) {
        var computedTotal = 0;
        for (final item in sale.items) {
          if (!productIds.contains(item.productId)) {
            throw StateError('Sale item references missing product.');
          }
          computedTotal += item.lineTotalQirsh;
        }
        if (computedTotal != sale.totalQirsh) {
          throw StateError('Invalid sale total vs items total.');
        }
      } else {
        if (sale.totalQirsh != sale.quantityKg * sale.salePriceQirshPerKg) {
          throw StateError('Invalid sale relationship.');
        }
      }
      _validateCancellationReferences(sale.cancellation, movementIds);
      _validateFinancialAccountReference(
          sale.financialAccountId, financialAccountIds);
      final allocationAccountIds = <String>{};
      var allocationTotal = 0;
      for (final allocation in sale.paymentAllocations) {
        if (!financialAccountIds.contains(allocation.financialAccountId) ||
            allocation.amountQirsh <= 0 ||
            !allocationAccountIds.add(allocation.financialAccountId)) {
          throw StateError('Invalid sale payment allocation relationship.');
        }
        allocationTotal += allocation.amountQirsh;
      }
      if (allocationTotal != 0 &&
          allocationTotal != sale.effectivePaidAmountQirsh) {
        throw StateError('Sale payment allocations do not match paid amount.');
      }
    }
    for (final collection in data.customerCollections) {
      _validateFinancialAccountReference(
          collection.financialAccountId, financialAccountIds);
    }
    for (final payment in data.supplierPayments) {
      _validateFinancialAccountReference(
          payment.financialAccountId, financialAccountIds);
    }
    for (final expense in data.expenses) {
      _validateFinancialAccountReference(
          expense.financialAccountId, financialAccountIds);
    }
    final advanceIds = <String>{};
    for (final advance in data.customerAdvances) {
      if (!advanceIds.add(advance.id)) {
        throw StateError('Duplicate customer advance id.');
      }
      _validateFinancialAccountReference(
          advance.financialAccountId, financialAccountIds);
      if (!data.customerCollections
          .any((c) => c.id == advance.sourceCollectionId)) {
        throw StateError('Customer advance references missing collection.');
      }
    }
    for (final application in data.customerAdvanceApplications) {
      if (!advanceIds.contains(application.advanceId)) {
        throw StateError(
            'Customer advance application references missing advance.');
      }
    }
    for (final refund in data.customerAdvanceRefunds) {
      if (!advanceIds.contains(refund.advanceId)) {
        throw StateError('Customer advance refund references missing advance.');
      }
      _validateFinancialAccountReference(
          refund.financialAccountId, financialAccountIds);
    }
    final supplierAdvanceIds = <String>{};
    for (final advance in data.supplierAdvances) {
      if (!supplierAdvanceIds.add(advance.id)) {
        throw StateError('Duplicate supplier advance id.');
      }
      _validateFinancialAccountReference(
          advance.financialAccountId, financialAccountIds);
      if (!data.supplierPayments.any((p) => p.id == advance.sourcePaymentId)) {
        throw StateError('Supplier advance references missing payment.');
      }
    }
    for (final application in data.supplierAdvanceApplications) {
      if (!supplierAdvanceIds.contains(application.advanceId)) {
        throw StateError(
            'Supplier advance application references missing advance.');
      }
    }
    for (final refund in data.supplierAdvanceRefunds) {
      if (!supplierAdvanceIds.contains(refund.advanceId)) {
        throw StateError('Supplier advance refund references missing advance.');
      }
      _validateFinancialAccountReference(
          refund.financialAccountId, financialAccountIds);
    }
    if (data.documentHistoryCount !=
        data.purchases.length + data.sales.length) {
      throw StateError('Document history count does not match documents.');
    }
  }

  void _validateCancellationReferences(
    CancellationMetadata? cancellation,
    Set<String> movementIds,
  ) {
    if (cancellation == null) {
      return;
    }
    for (final movementId in cancellation.reversalMovementIds) {
      if (!movementIds.contains(movementId)) {
        throw StateError('Cancellation references missing reversal movement.');
      }
    }
  }

  Map<String, Object?> _map(Object? value) {
    if (value is Map<String, Object?>) {
      return value;
    }
    throw StateError('Invalid backup record.');
  }

  String _string(Map<String, Object?> map, String key) {
    final value = map[key];
    if (value is String && value.trim().isNotEmpty) {
      return value;
    }
    throw StateError('Missing string field: $key');
  }

  String? _optionalString(Map<String, Object?> map, String key) {
    final value = map[key];
    if (value == null) {
      return null;
    }
    if (value is String) {
      return value;
    }
    throw StateError('Invalid string field: $key');
  }

  void _validateFinancialAccountReference(
      String? accountId, Set<String> financialAccountIds) {
    if (accountId != null &&
        accountId.isNotEmpty &&
        !financialAccountIds.contains(accountId)) {
      throw StateError('Transaction references missing financial account.');
    }
  }

  PaymentMethod? _optionalPaymentMethod(Map<String, Object?> map) {
    final name = _optionalString(map, 'paymentMethod');
    return name == null ? null : PaymentMethod.values.byName(name);
  }

  int _int(Map<String, Object?> map, String key) {
    final value = map[key];
    if (value is int) {
      return value;
    }
    throw StateError('Missing int field: $key');
  }

  int? _optionalInt(Map<String, Object?> map, String key) {
    final value = map[key];
    if (value == null) {
      return null;
    }
    if (value is int) {
      return value;
    }
    throw StateError('Invalid int field: $key');
  }

  bool _bool(Map<String, Object?> map, String key) {
    final value = map[key];
    if (value is bool) {
      return value;
    }
    throw StateError('Missing bool field: $key');
  }

  bool? _optionalBool(Map<String, Object?> map, String key) {
    final value = map[key];
    if (value == null) {
      return null;
    }
    if (value is bool) {
      return value;
    }
    throw StateError('Invalid bool field: $key');
  }

  DateTime _date(Map<String, Object?> map, String key) {
    return DateTime.parse(_string(map, key));
  }

  String? _logoRestoreWarning;

  LogoMetadata? _restoreLogoPayload(
    Map<String, Object?> payload,
    BusinessIdentityRepository repository,
  ) {
    try {
      final mimeType = payload['mimeType'] as String? ?? '';
      final base64Data = payload['base64Data'] as String? ?? '';
      final claimedSha256 = payload['sha256'] as String?;
      final width = payload['width'] as int? ?? 0;
      final height = payload['height'] as int? ?? 0;

      if (mimeType != 'image/png' && mimeType != 'image/jpeg') {
        _logoRestoreWarning = 'شعار غير مدعوم ($mimeType). تم تجاهل الشعار.';
        return null;
      }

      if (base64Data.isEmpty) {
        _logoRestoreWarning = 'بيانات الشعار فارغة. تم تجاهل الشعار.';
        return null;
      }

      Uint8List bytes;
      try {
        bytes = base64Decode(base64Data);
      } catch (_) {
        _logoRestoreWarning = 'بيانات الشعار تالفة (Base64). تم تجاهل الشعار.';
        return null;
      }

      if (bytes.isEmpty) {
        _logoRestoreWarning = 'ملف الشعار فارغ بعد الفك. تم تجاهل الشعار.';
        return null;
      }

      if (bytes.length > 1024 * 1024) {
        _logoRestoreWarning =
            'حجم الشعار يتجاوز الحد الأقصى (${bytes.length} bytes). تم تجاهل الشعار.';
        return null;
      }

      if (claimedSha256 != null) {
        final actualHash = sha256.convert(bytes).toString();
        if (actualHash != claimedSha256) {
          _logoRestoreWarning =
              'بيانات الشعار تختلف عن البصمة. تم تجاهل الشعار.';
          return null;
        }
      }

      final savedMetadata = _synchronousLogoSave(bytes, mimeType, repository);
      if (savedMetadata == null) {
        _logoRestoreWarning = 'تعذر حفظ الشعار. تم تجاهل الشعار.';
        return null;
      }

      return LogoMetadata(
        managedFileName: savedMetadata.managedFileName,
        mimeType: mimeType,
        sha256: savedMetadata.sha256,
        byteLength: savedMetadata.byteLength,
        width: width > 0 ? width : savedMetadata.width,
        height: height > 0 ? height : savedMetadata.height,
      );
    } catch (_) {
      _logoRestoreWarning = 'خطأ غير متوقع أثناء استرجاع الشعار. تم تجاهله.';
      return null;
    }
  }

  LogoMetadata? _synchronousLogoSave(
    Uint8List bytes,
    String mimeType,
    BusinessIdentityRepository repository,
  ) {
    try {
      final hash = sha256.convert(bytes).toString();
      final ext = mimeType == 'image/png' ? 'png' : 'jpg';
      final fileName = 'logo_${hash.substring(0, 16)}.$ext';
      final dir = Directory(repository.managedLogosDirectory);
      dir.createSync(recursive: true);
      final filePath = '${dir.path}${Platform.pathSeparator}$fileName';
      final tempPath = '$filePath.tmp';
      final tempFile = File(tempPath);
      tempFile.writeAsBytesSync(bytes, flush: true);
      final finalFile = File(filePath);
      if (finalFile.existsSync()) {
        tempFile.deleteSync();
      } else {
        tempFile.renameSync(filePath);
      }
      final verified = File(filePath);
      if (!verified.existsSync()) return null;
      final verifiedBytes = verified.readAsBytesSync();
      if (verifiedBytes.length != bytes.length) return null;
      return LogoMetadata(
        managedFileName: fileName,
        mimeType: mimeType,
        sha256: hash,
        byteLength: verifiedBytes.length,
        width: 0,
        height: 0,
      );
    } catch (_) {
      return null;
    }
  }
}

class BackupRestoreResult {
  const BackupRestoreResult._({
    required this.success,
    required this.message,
    required this.warnings,
    this.counts,
    this.metadata,
    this.technicalReason,
  });

  factory BackupRestoreResult.success({
    required BackupRestorePreviewCounts counts,
    required BackupRestorePreviewSummary metadata,
    required List<String> warnings,
  }) {
    return BackupRestoreResult._(
      success: true,
      message: 'تم استرجاع النسخة الاحتياطية بنجاح.',
      counts: counts,
      metadata: metadata,
      warnings: warnings,
    );
  }

  const factory BackupRestoreResult.failure({
    required String message,
    required String technicalReason,
  }) = BackupRestoreResultFailure;

  final bool success;
  final String message;
  final BackupRestorePreviewCounts? counts;
  final BackupRestorePreviewSummary? metadata;
  final List<String> warnings;
  final String? technicalReason;
}

class BackupRestoreResultFailure extends BackupRestoreResult {
  const BackupRestoreResultFailure({
    required super.message,
    required super.technicalReason,
  }) : super._(
          success: false,
          warnings: const [],
        );
}

class _RestoredBackupData {
  const _RestoredBackupData({
    required this.products,
    required this.suppliers,
    required this.movements,
    required this.purchases,
    required this.sales,
    required this.customers,
    required this.customerAccountEntries,
    required this.customerCollections,
    required this.customerAdvances,
    required this.customerAdvanceApplications,
    required this.customerAdvanceRefunds,
    required this.supplierAccountEntries,
    required this.supplierPayments,
    required this.supplierAdvances,
    required this.supplierAdvanceApplications,
    required this.supplierAdvanceRefunds,
    required this.expenses,
    required this.auditLogs,
    required this.financialAccounts,
    required this.financialAccountEntries,
    required this.financialTransfers,
    required this.financialClosings,
    required this.businessIdentity,
    required this.documentHistoryCount,
    this.logoRestoreWarning,
  });

  final List<Product> products;
  final List<Supplier> suppliers;
  final List<StockMovement> movements;
  final List<PurchaseIntake> purchases;
  final List<SaleRecord> sales;
  final List<Customer> customers;
  final List<CustomerAccountEntry> customerAccountEntries;
  final List<CustomerCollectionRecord> customerCollections;
  final List<CustomerAdvance> customerAdvances;
  final List<CustomerAdvanceApplication> customerAdvanceApplications;
  final List<CustomerAdvanceRefund> customerAdvanceRefunds;
  final List<SupplierAccountEntry> supplierAccountEntries;
  final List<SupplierPaymentRecord> supplierPayments;
  final List<SupplierAdvance> supplierAdvances;
  final List<SupplierAdvanceApplication> supplierAdvanceApplications;
  final List<SupplierAdvanceRefund> supplierAdvanceRefunds;
  final List<ExpenseRecord> expenses;
  final List<AuditLogEntry> auditLogs;
  final List<FinancialAccount> financialAccounts;
  final List<FinancialAccountEntry> financialAccountEntries;
  final List<FinancialTransfer> financialTransfers;
  final List<FinancialClosing> financialClosings;
  final BusinessIdentity businessIdentity;
  final int documentHistoryCount;
  final String? logoRestoreWarning;
}
