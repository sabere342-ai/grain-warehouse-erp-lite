import 'dart:convert';

import 'package:grain_warehouse_erp_lite/core/auth/app_user.dart';
import 'package:grain_warehouse_erp_lite/core/audit/audit_log_repository.dart';
import 'package:grain_warehouse_erp_lite/core/backup/backup_restore_preview.dart';
import 'package:grain_warehouse_erp_lite/core/customer_accounts/customer_account_entry.dart';
import 'package:grain_warehouse_erp_lite/core/customer_accounts/customer_account_repository.dart';
import 'package:grain_warehouse_erp_lite/core/customer_accounts/customer_collection.dart';
import 'package:grain_warehouse_erp_lite/core/catalog/grain_unit.dart';
import 'package:grain_warehouse_erp_lite/core/catalog/product.dart';
import 'package:grain_warehouse_erp_lite/core/catalog/product_repository.dart';
import 'package:grain_warehouse_erp_lite/core/customers/customer.dart';
import 'package:grain_warehouse_erp_lite/core/customers/customer_repository.dart';
import 'package:grain_warehouse_erp_lite/core/documents/cancellation_metadata.dart';
import 'package:grain_warehouse_erp_lite/core/expenses/expense.dart';
import 'package:grain_warehouse_erp_lite/core/expenses/expense_repository.dart';
import 'package:grain_warehouse_erp_lite/core/documents/document_history.dart';
import 'package:grain_warehouse_erp_lite/core/inventory/inventory_repository.dart';
import 'package:grain_warehouse_erp_lite/core/inventory/stock_movement.dart';
import 'package:grain_warehouse_erp_lite/core/purchases/purchase_intake.dart';
import 'package:grain_warehouse_erp_lite/core/purchases/purchase_repository.dart';
import 'package:grain_warehouse_erp_lite/core/sales/sale_record.dart';
import 'package:grain_warehouse_erp_lite/core/sales/sale_repository.dart';
import 'package:grain_warehouse_erp_lite/core/suppliers/supplier.dart';
import 'package:grain_warehouse_erp_lite/core/suppliers/supplier_repository.dart';

class BackupRestoreService {
  BackupRestoreService({
    required LocalProductRepository productRepository,
    required LocalInventoryRepository inventoryRepository,
    required LocalSupplierRepository supplierRepository,
    required LocalPurchaseRepository purchaseRepository,
    required LocalSaleRepository saleRepository,
    required DocumentHistoryRepository documentHistoryRepository,
    LocalCustomerRepository? customerRepository,
    LocalCustomerAccountRepository? customerAccountRepository,
    LocalExpenseRepository? expenseRepository,
    LocalAuditLogRepository? auditLogRepository,
    BackupRestorePreviewService previewService =
        const BackupRestorePreviewService(),
  })  : _productRepository = productRepository,
        _inventoryRepository = inventoryRepository,
        _supplierRepository = supplierRepository,
        _purchaseRepository = purchaseRepository,
        _saleRepository = saleRepository,
        _documentHistoryRepository = documentHistoryRepository,
        _customerRepository = customerRepository ?? LocalCustomerRepository(),
        _customerAccountRepository = customerAccountRepository ?? LocalCustomerAccountRepository(customerRepository: customerRepository ?? LocalCustomerRepository()),
        _expenseRepository = expenseRepository ?? LocalExpenseRepository(),
        _auditLogRepository = auditLogRepository ?? LocalAuditLogRepository(),
        _previewService = previewService;

  final LocalProductRepository _productRepository;
  final LocalInventoryRepository _inventoryRepository;
  final LocalSupplierRepository _supplierRepository;
  final LocalPurchaseRepository _purchaseRepository;
  final LocalSaleRepository _saleRepository;
  final DocumentHistoryRepository _documentHistoryRepository;
  final LocalCustomerRepository _customerRepository;
  final LocalCustomerAccountRepository _customerAccountRepository;
  final LocalExpenseRepository _expenseRepository;
  final LocalAuditLogRepository _auditLogRepository;
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

      // The current in-memory repositories do not expose transactions.
      // All data is fully parsed and validated before this point, and the
      // empty-system guard is checked immediately before these writes.
      await _productRepository.restoreProductsIntoEmpty(restored.products);
      await _supplierRepository.restoreSuppliersIntoEmpty(restored.suppliers);
      await _inventoryRepository.restoreMovementsIntoEmpty(restored.movements);
      await _purchaseRepository.restorePurchaseIntakesIntoEmpty(
        restored.purchases,
      );
      await _saleRepository.restoreSalesIntoEmpty(restored.sales);
      await _customerRepository.restoreCustomersIntoEmpty(restored.customers);
      await _customerAccountRepository.restoreCustomerAccountsIntoEmpty(
        entries: restored.customerAccountEntries,
        collections: restored.customerCollections,
      );
      await _expenseRepository.restoreExpensesIntoEmpty(restored.expenses);
      await _auditLogRepository.restoreAuditLogsIntoEmpty(restored.auditLogs);

      return BackupRestoreResult.success(
        counts: preview.summary!.counts,
        metadata: preview.summary!,
        warnings: const [
          'تم الاسترجاع إلى نظام كان فارغا فقط.',
          'لم يتم استرجاع مستخدمين أو كلمات مرور أو جلسات دخول.',
        ],
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
    final customers = await _customerRepository.listCustomers(includeInactive: true);
    final customerAccountEntries = await _customerAccountRepository.listEntries();
    final customerCollections = await _customerAccountRepository.listCollections();
    final expenses = await _expenseRepository.listExpenses();
    final auditLogs = await _auditLogRepository.listLogs();

    if (products.isNotEmpty ||
        movements.isNotEmpty ||
        suppliers.isNotEmpty ||
        purchases.isNotEmpty ||
        sales.isNotEmpty ||
        history.isNotEmpty ||
        customers.isNotEmpty ||
        customerAccountEntries.isNotEmpty ||
        customerCollections.isNotEmpty ||
        expenses.isNotEmpty ||
        auditLogs.isNotEmpty) {
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
    final customers = _optionalList(data, 'customers').map(_parseCustomer).toList();
    final customerAccountEntries = _optionalList(data, 'customerAccountEntries').map(_parseCustomerAccountEntry).toList();
    final customerCollections = _optionalList(data, 'customerCollections').map(_parseCustomerCollection).toList();
    final expenses = _optionalList(data, 'expenses').map(_parseExpense).toList();
    final auditLogs = _optionalList(data, 'auditLogs').map(_parseAuditLog).toList();

    return _RestoredBackupData(
      products: products,
      suppliers: suppliers,
      movements: movements,
      purchases: purchases,
      sales: sales,
      customers: customers,
      customerAccountEntries: customerAccountEntries,
      customerCollections: customerCollections,
      expenses: expenses,
      auditLogs: auditLogs,
      documentHistoryCount: _list(data, 'documentHistory').length,
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
    );
  }

  SaleRecord _parseSale(Object? value) {
    final map = _map(value);
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
      paymentMode: SalePaymentMode.values.byName(
        _optionalString(map, 'paymentMode') ?? SalePaymentMode.cash.name,
      ),
      customerId: _optionalString(map, 'customerId'),
      notes: _optionalString(map, 'notes'),
      cancellation: _parseCancellation(map['cancellation']),
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

  ExpenseRecord _parseExpense(Object? value) {
    final map = _map(value);
    return ExpenseRecord(
      id: _string(map, 'id'),
      date: _date(map, 'date'),
      category: _string(map, 'category'),
      amountQirsh: _int(map, 'amountQirsh'),
      notes: _optionalString(map, 'notes'),
      createdAt: _date(map, 'createdAt'),
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
    }
    for (final sale in data.sales) {
      if (!productIds.contains(sale.productId) ||
          !movementIds.contains(sale.stockMovementId) ||
          sale.totalQirsh != sale.quantityKg * sale.salePriceQirshPerKg) {
        throw StateError('Invalid sale relationship.');
      }
      _validateCancellationReferences(sale.cancellation, movementIds);
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
    required this.expenses,
    required this.auditLogs,
    required this.documentHistoryCount,
  });

  final List<Product> products;
  final List<Supplier> suppliers;
  final List<StockMovement> movements;
  final List<PurchaseIntake> purchases;
  final List<SaleRecord> sales;
  final List<Customer> customers;
  final List<CustomerAccountEntry> customerAccountEntries;
  final List<CustomerCollectionRecord> customerCollections;
  final List<ExpenseRecord> expenses;
  final List<AuditLogEntry> auditLogs;
  final int documentHistoryCount;
}
