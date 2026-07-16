import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:grain_warehouse_erp_lite/core/business_identity/business_identity.dart';
import 'package:grain_warehouse_erp_lite/core/business_identity/business_identity_repository.dart';
import 'package:grain_warehouse_erp_lite/core/audit/audit_log_repository.dart';
import 'package:grain_warehouse_erp_lite/core/catalog/product.dart';
import 'package:grain_warehouse_erp_lite/core/customer_accounts/customer_account_entry.dart';
import 'package:grain_warehouse_erp_lite/core/customer_accounts/customer_account_repository.dart';
import 'package:grain_warehouse_erp_lite/core/customer_accounts/customer_collection.dart';
import 'package:grain_warehouse_erp_lite/core/customer_accounts/customer_advance.dart';
import 'package:grain_warehouse_erp_lite/core/customers/customer.dart';
import 'package:grain_warehouse_erp_lite/core/customers/customer_repository.dart';
import 'package:grain_warehouse_erp_lite/core/expenses/expense.dart';
import 'package:grain_warehouse_erp_lite/core/expenses/expense_repository.dart';
import 'package:grain_warehouse_erp_lite/core/catalog/product_repository.dart';
import 'package:grain_warehouse_erp_lite/core/documents/cancellation_metadata.dart';
import 'package:grain_warehouse_erp_lite/core/documents/document_history.dart';
import 'package:grain_warehouse_erp_lite/core/financial_accounts/financial_account.dart';
import 'package:grain_warehouse_erp_lite/core/financial_accounts/financial_account_entry.dart';
import 'package:grain_warehouse_erp_lite/core/financial_accounts/financial_transfer.dart';
import 'package:grain_warehouse_erp_lite/core/financial_accounts/financial_closing.dart';
import 'package:grain_warehouse_erp_lite/core/financial_accounts/financial_account_repository.dart';
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

class BackupExportService {
  BackupExportService({
    required ProductRepository productRepository,
    required InventoryRepository inventoryRepository,
    required SupplierRepository supplierRepository,
    required PurchaseRepository purchaseRepository,
    required SaleRepository saleRepository,
    required DocumentHistoryRepository documentHistoryRepository,
    BusinessIdentityRepository? businessIdentityRepository,
    CustomerRepository? customerRepository,
    CustomerAccountRepository? customerAccountRepository,
    SupplierAccountRepository? supplierAccountRepository,
    ExpenseRepository? expenseRepository,
    AuditLogRepository? auditLogRepository,
    FinancialAccountRepository? financialAccountRepository,
    DateTime Function()? now,
  })  : _productRepository = productRepository,
        _inventoryRepository = inventoryRepository,
        _supplierRepository = supplierRepository,
        _purchaseRepository = purchaseRepository,
        _saleRepository = saleRepository,
        _documentHistoryRepository = documentHistoryRepository,
        _businessIdentityRepository = businessIdentityRepository,
        _customerRepository = customerRepository ?? LocalCustomerRepository(),
        _customerAccountRepository = customerAccountRepository,
        _supplierAccountRepository = supplierAccountRepository,
        _expenseRepository = expenseRepository ?? LocalExpenseRepository(),
        _auditLogRepository = auditLogRepository ?? LocalAuditLogRepository(),
        _financialAccountRepository = financialAccountRepository,
        _now = now;

  static const int backupVersion = 6;

  final ProductRepository _productRepository;
  final InventoryRepository _inventoryRepository;
  final SupplierRepository _supplierRepository;
  final PurchaseRepository _purchaseRepository;
  final SaleRepository _saleRepository;
  final DocumentHistoryRepository _documentHistoryRepository;
  final BusinessIdentityRepository? _businessIdentityRepository;
  final CustomerRepository _customerRepository;
  final CustomerAccountRepository? _customerAccountRepository;
  final SupplierAccountRepository? _supplierAccountRepository;
  final ExpenseRepository _expenseRepository;
  final AuditLogRepository _auditLogRepository;
  final FinancialAccountRepository? _financialAccountRepository;
  final DateTime Function()? _now;

  Future<BackupExportResult> createBackup() async {
    final generatedAt = (_now ?? DateTime.now)();
    final products = await _productRepository.listProducts(
      includeInactive: true,
    );
    final movements = await _inventoryRepository.listAllMovements();
    final suppliers = await _supplierRepository.listSuppliers(
      includeInactive: true,
    );
    final purchases = await _purchaseRepository.listPurchaseIntakes();
    final sales = await _saleRepository.listSales();
    final documentHistory = await _documentHistoryRepository.listHistory();
    final customers =
        await _customerRepository.listCustomers(includeInactive: true);
    final customerAccountEntries =
        await _customerAccountRepository?.listEntries() ??
            const <CustomerAccountEntry>[];
    final customerCollections =
        await _customerAccountRepository?.listCollections() ??
            const <CustomerCollectionRecord>[];
    final customerAdvances = await _customerAccountRepository?.listAdvances() ??
        const <CustomerAdvance>[];
    final customerAdvanceApplications =
        await _customerAccountRepository?.listAdvanceApplications() ??
            const <CustomerAdvanceApplication>[];
    final customerAdvanceRefunds =
        await _customerAccountRepository?.listAdvanceRefunds() ??
            const <CustomerAdvanceRefund>[];
    final supplierAccountEntries =
        await _supplierAccountRepository?.listEntries() ??
            const <SupplierAccountEntry>[];
    final supplierPayments = await _supplierAccountRepository?.listPayments() ??
        const <SupplierPaymentRecord>[];
    final supplierAdvances = await _supplierAccountRepository?.listAdvances() ??
        const <SupplierAdvance>[];
    final supplierAdvanceApplications =
        await _supplierAccountRepository?.listAdvanceApplications() ??
            const <SupplierAdvanceApplication>[];
    final supplierAdvanceRefunds =
        await _supplierAccountRepository?.listAdvanceRefunds() ??
            const <SupplierAdvanceRefund>[];
    final expenses = await _expenseRepository.listExpenses();
    final auditLogs = await _auditLogRepository.listLogs();
    final financialAccounts = await _financialAccountRepository?.listAccounts(
            includeInactive: true) ??
        const <FinancialAccount>[];
    final financialAccountEntries = await _listAllFinancialEntries();
    final financialTransfers =
        await _financialAccountRepository?.listTransfers() ??
            const <FinancialTransfer>[];
    final financialClosings =
        await _financialAccountRepository?.listClosings() ??
            const <FinancialClosing>[];
    final businessIdentity =
        await _businessIdentityRepository?.loadIdentity() ??
            BusinessIdentity.empty;

    final counts = BackupExportCounts(
      products: products.length,
      inventoryMovements: movements.length,
      suppliers: suppliers.length,
      purchases: purchases.length,
      sales: sales.length,
      documentHistory: documentHistory.length,
      customers: customers.length,
      customerLedgerEntries: customerAccountEntries.length,
      customerCollections: customerCollections.length,
      supplierLedgerEntries: supplierAccountEntries.length,
      supplierPayments: supplierPayments.length,
      expenses: expenses.length,
      auditLogs: auditLogs.length,
      financialAccounts: financialAccounts.length,
      financialAccountEntries: financialAccountEntries.length,
      financialTransfers: financialTransfers.length,
      financialClosings: financialClosings.length,
    );
    final fileName = BackupFileName.forGeneratedAt(generatedAt);

    final snapshotWithoutChecksum = <String, Object?>{
      'metadata': {
        'app': 'grain-warehouse-erp-lite',
        'backupVersion': backupVersion,
        'generatedAt': generatedAt.toUtc().toIso8601String(),
        'fileName': fileName,
        'restoreSupported': false,
        'warning':
            'هذه نسخة احتياطية للتصدير والحفظ. يمكن استرجاعها فقط إلى نظام فارغ بعد فحصها.',
      },
      'counts': counts.toJson(),
      'data': {
        'products': products.map(_productToJson).toList(growable: false),
        'inventoryMovements':
            movements.map(_movementToJson).toList(growable: false),
        'suppliers': suppliers.map(_supplierToJson).toList(growable: false),
        'purchases': purchases.map(_purchaseToJson).toList(growable: false),
        'sales': sales.map(_saleToJson).toList(growable: false),
        'documentHistory':
            documentHistory.map(_documentHistoryToJson).toList(growable: false),
        'customers': customers.map(_customerToJson).toList(growable: false),
        'customerAccountEntries': customerAccountEntries
            .map(_customerAccountEntryToJson)
            .toList(growable: false),
        'customerCollections': customerCollections
            .map(_customerCollectionToJson)
            .toList(growable: false),
        'customerAdvances': customerAdvances
            .map(_customerAdvanceToJson)
            .toList(growable: false),
        'customerAdvanceApplications': customerAdvanceApplications
            .map(_customerAdvanceApplicationToJson)
            .toList(growable: false),
        'customerAdvanceRefunds': customerAdvanceRefunds
            .map(_customerAdvanceRefundToJson)
            .toList(growable: false),
        'supplierAccountEntries': supplierAccountEntries
            .map(_supplierAccountEntryToJson)
            .toList(growable: false),
        'supplierPayments': supplierPayments
            .map(_supplierPaymentToJson)
            .toList(growable: false),
        'supplierAdvances': supplierAdvances
            .map(_supplierAdvanceToJson)
            .toList(growable: false),
        'supplierAdvanceApplications': supplierAdvanceApplications
            .map(_supplierAdvanceApplicationToJson)
            .toList(growable: false),
        'supplierAdvanceRefunds': supplierAdvanceRefunds
            .map(_supplierAdvanceRefundToJson)
            .toList(growable: false),
        'expenses': expenses.map(_expenseToJson).toList(growable: false),
        'auditLogs': auditLogs.map(_auditLogToJson).toList(growable: false),
        'financialAccounts': financialAccounts
            .map(_financialAccountToJson)
            .toList(growable: false),
        'financialAccountEntries': financialAccountEntries
            .map(_financialAccountEntryToJson)
            .toList(growable: false),
        'financialTransfers': financialTransfers
            .map(_financialTransferToJson)
            .toList(growable: false),
        'financialClosings': financialClosings
            .map(_financialClosingToJson)
            .toList(growable: false),
        'settings': {
          'businessIdentity': await _identityWithLogoJson(businessIdentity),
        },
      },
    };

    final bodyForChecksum =
        const JsonEncoder.withIndent('  ').convert(snapshotWithoutChecksum);
    final checksum = _adler32(bodyForChecksum);
    final snapshot = <String, Object?>{
      ...snapshotWithoutChecksum,
      'checksum': checksum,
      'checksumNote': 'فحص بسيط لاكتشاف تلف النسخ، وليس ميزة تشفير أو حماية.',
    };
    final jsonText = const JsonEncoder.withIndent('  ').convert(snapshot);
    BackupExportValidator.validateJsonText(jsonText);

    return BackupExportResult(
      jsonText: jsonText,
      counts: counts,
      generatedAt: generatedAt,
      backupVersion: backupVersion,
      checksum: checksum,
      fileName: fileName,
    );
  }

  Map<String, Object?> _productToJson(Product product) {
    return {
      'id': product.id,
      'name': product.name,
      'code': product.code,
      'unit': product.unit.name,
      'isActive': product.isActive,
      'defaultSalePricePiastersPerKg': product.defaultSalePricePiastersPerKg,
      'minimumSalePricePiastersPerKg': product.minimumSalePricePiastersPerKg,
      'referenceCostPricePiastersPerKg':
          product.referenceCostPricePiastersPerKg,
      'notes': product.notes,
      'createdAt': product.createdAt.toUtc().toIso8601String(),
      'updatedAt': product.updatedAt.toUtc().toIso8601String(),
    };
  }

  Map<String, Object?> _movementToJson(StockMovement movement) {
    return {
      'id': movement.id,
      'productId': movement.productId,
      'movementType': movement.movementType.name,
      'quantityKg': movement.quantityKg,
      'signedQuantityKg': movement.signedQuantityKg,
      'createdByUserId': movement.createdByUserId,
      'createdAt': movement.createdAt.toUtc().toIso8601String(),
      'note': movement.note,
      'isVoided': movement.isVoided,
      'reversedMovementId': movement.reversedMovementId,
      'originalDocumentId': movement.originalDocumentId,
    };
  }

  Map<String, Object?> _supplierToJson(Supplier supplier) {
    return {
      'id': supplier.id,
      'name': supplier.name,
      'phone': supplier.phone,
      'address': supplier.address,
      'notes': supplier.notes,
      'isActive': supplier.isActive,
      'createdAt': supplier.createdAt.toUtc().toIso8601String(),
      'updatedAt': supplier.updatedAt.toUtc().toIso8601String(),
    };
  }

  Map<String, Object?> _purchaseToJson(PurchaseIntake purchase) {
    return {
      'id': purchase.id,
      'supplierId': purchase.supplierId,
      'supplierName': purchase.supplierName,
      'supplierPhone': purchase.supplierPhone,
      'supplierAddress': purchase.supplierAddress,
      'productId': purchase.productId,
      'quantityKg': purchase.quantityKg,
      'entryUnit': purchase.entryUnit.name,
      'unitPricePiastersPerKg': purchase.unitPricePiastersPerKg,
      'totalAmountPiasters': purchase.totalAmountPiasters,
      'createdByUserId': purchase.createdByUserId,
      'createdAt': purchase.createdAt.toUtc().toIso8601String(),
      'stockMovementId': purchase.stockMovementId,
      'notes': purchase.notes,
      'isCancelled': purchase.isCancelled,
      'cancellation': _cancellationToJson(purchase.cancellation),
      'financialAccountId': purchase.financialAccountId,
      'paymentMethod': purchase.paymentMethod?.name,
    };
  }

  Map<String, Object?> _saleToJson(SaleRecord sale) {
    return {
      'id': sale.id,
      'productId': sale.productId,
      'quantityKg': sale.quantityKg,
      'salePriceQirshPerKg': sale.salePriceQirshPerKg,
      'totalQirsh': sale.totalQirsh,
      'createdByUserId': sale.createdByUserId,
      'createdByUserName': sale.createdByUserName,
      'createdAt': sale.createdAt.toUtc().toIso8601String(),
      'stockMovementId': sale.stockMovementId,
      'paymentMode': sale.paymentMode.name,
      'customerId': sale.customerId,
      'notes': sale.notes,
      'isCancelled': sale.isCancelled,
      'cancellation': _cancellationToJson(sale.cancellation),
      'paidAmountQirsh': sale.paidAmountQirsh,
      'items': sale.items.map(_saleItemToJson).toList(growable: false),
      'financialAccountId': sale.financialAccountId,
      'paymentMethod': sale.paymentMethod?.name,
      'paymentAllocations': sale.paymentAllocations
          .map(_salePaymentAllocationToJson)
          .toList(growable: false),
      'operationRequestId': sale.operationRequestId,
    };
  }

  Map<String, Object?> _salePaymentAllocationToJson(
    SalePaymentAllocation allocation,
  ) {
    return {
      'financialAccountId': allocation.financialAccountId,
      'amountQirsh': allocation.amountQirsh,
      'paymentMethod': allocation.paymentMethod.name,
    };
  }

  Map<String, Object?> _saleItemToJson(SaleLineItem item) {
    return {
      'productId': item.productId,
      'quantityKg': item.quantityKg,
      'salePriceQirshPerKg': item.salePriceQirshPerKg,
      'lineTotalQirsh': item.lineTotalQirsh,
    };
  }

  Map<String, Object?> _documentHistoryToJson(DocumentHistoryEntry entry) {
    return {
      'id': entry.id,
      'type': entry.type.name,
      'status': entry.status.name,
      'productId': entry.productId,
      'productName': entry.productName,
      'partyName': entry.partyName,
      'quantityKg': entry.quantityKg,
      'unitPricePiastersPerKg': entry.unitPricePiastersPerKg,
      'totalPiasters': entry.totalPiasters,
      'createdByUserId': entry.createdByUserId,
      'createdByUserName': entry.createdByUserName,
      'createdAt': entry.createdAt.toUtc().toIso8601String(),
      'notes': entry.notes,
      'isCancelled': entry.isCancelled,
      'cancellation': _cancellationToJson(entry.cancellation),
      'originalMovementId': entry.originalMovement?.id,
      'reversalMovementIds':
          entry.reversalMovements.map((movement) => movement.id).toList(),
    };
  }

  Map<String, Object?> _customerAccountEntryToJson(CustomerAccountEntry entry) {
    return {
      'id': entry.id,
      'customerId': entry.customerId,
      'date': entry.date.toUtc().toIso8601String(),
      'type': entry.type.name,
      'debitAmountQirsh': entry.debitAmountQirsh,
      'creditAmountQirsh': entry.creditAmountQirsh,
      'sourceDocumentType': entry.sourceDocumentType,
      'sourceDocumentId': entry.sourceDocumentId,
      'descriptionAr': entry.descriptionAr,
      'createdAt': entry.createdAt.toUtc().toIso8601String(),
      'createdByUserId': entry.createdByUserId,
    };
  }

  Map<String, Object?> _customerCollectionToJson(
      CustomerCollectionRecord collection) {
    return {
      'id': collection.id,
      'customerId': collection.customerId,
      'date': collection.date.toUtc().toIso8601String(),
      'amountQirsh': collection.amountQirsh,
      'createdAt': collection.createdAt.toUtc().toIso8601String(),
      'createdByUserId': collection.createdByUserId,
      'createdByUserName': collection.createdByUserName,
      'notes': collection.notes,
      'financialAccountId': collection.financialAccountId,
      'paymentMethod': collection.paymentMethod?.name,
      'settledAmountQirsh': collection.settledAmountQirsh,
      'advanceAmountQirsh': collection.advanceAmountQirsh,
      'cancellation': _customerCollectionCancellationToJson(
        collection.cancellation,
      ),
    };
  }

  Map<String, Object?> _supplierAccountEntryToJson(SupplierAccountEntry entry) {
    return {
      'id': entry.id,
      'supplierId': entry.supplierId,
      'date': entry.date.toUtc().toIso8601String(),
      'type': entry.type.name,
      'debitAmountQirsh': entry.debitAmountQirsh,
      'creditAmountQirsh': entry.creditAmountQirsh,
      'sourceDocumentType': entry.sourceDocumentType,
      'sourceDocumentId': entry.sourceDocumentId,
      'descriptionAr': entry.descriptionAr,
      'createdAt': entry.createdAt.toUtc().toIso8601String(),
      'createdByUserId': entry.createdByUserId,
    };
  }

  Map<String, Object?> _supplierPaymentToJson(SupplierPaymentRecord payment) {
    return {
      'id': payment.id,
      'supplierId': payment.supplierId,
      'date': payment.date.toUtc().toIso8601String(),
      'amountQirsh': payment.amountQirsh,
      'createdAt': payment.createdAt.toUtc().toIso8601String(),
      'createdByUserId': payment.createdByUserId,
      'createdByUserName': payment.createdByUserName,
      'notes': payment.notes,
      'financialAccountId': payment.financialAccountId,
      'paymentMethod': payment.paymentMethod?.name,
      'settledAmountQirsh': payment.settledAmountQirsh,
      'advanceAmountQirsh': payment.advanceAmountQirsh,
      'cancellation': _supplierPaymentCancellationToJson(payment.cancellation),
    };
  }

  Map<String, Object?> _customerAdvanceToJson(CustomerAdvance value) => {
        'id': value.id,
        'customerId': value.customerId,
        'sourceCollectionId': value.sourceCollectionId,
        'financialAccountId': value.financialAccountId,
        'amountQirsh': value.amountQirsh,
        'createdAt': value.createdAt.toUtc().toIso8601String(),
        'createdByUserId': value.createdByUserId,
        'ownerApprovalId': value.ownerApprovalId,
        'operationRequestId': value.operationRequestId,
        'paymentMethod': value.paymentMethod?.name,
        'reversedAt': value.reversedAt?.toUtc().toIso8601String(),
        'reversedByUserId': value.reversedByUserId,
      };

  Map<String, Object?> _customerAdvanceApplicationToJson(
          CustomerAdvanceApplication value) =>
      {
        'id': value.id,
        'advanceId': value.advanceId,
        'customerId': value.customerId,
        'amountQirsh': value.amountQirsh,
        'appliedAt': value.appliedAt.toUtc().toIso8601String(),
        'createdByUserId': value.createdByUserId,
        'operationRequestId': value.operationRequestId,
        'customerLedgerEntryId': value.customerLedgerEntryId,
        'reversedAt': value.reversedAt?.toUtc().toIso8601String(),
        'reversedByUserId': value.reversedByUserId,
        'reversalReason': value.reversalReason,
        'reversalLedgerEntryId': value.reversalLedgerEntryId,
      };

  Map<String, Object?> _customerAdvanceRefundToJson(
          CustomerAdvanceRefund value) =>
      {
        'id': value.id,
        'advanceId': value.advanceId,
        'customerId': value.customerId,
        'financialAccountId': value.financialAccountId,
        'amountQirsh': value.amountQirsh,
        'refundedAt': value.refundedAt.toUtc().toIso8601String(),
        'createdByUserId': value.createdByUserId,
        'operationRequestId': value.operationRequestId,
        'financialEntryId': value.financialEntryId,
        'reversedAt': value.reversedAt?.toUtc().toIso8601String(),
        'reversedByUserId': value.reversedByUserId,
        'reversalReason': value.reversalReason,
        'reversalFinancialEntryId': value.reversalFinancialEntryId,
      };

  Map<String, Object?> _supplierAdvanceToJson(SupplierAdvance value) => {
        'id': value.id,
        'supplierId': value.supplierId,
        'sourcePaymentId': value.sourcePaymentId,
        'financialAccountId': value.financialAccountId,
        'amountQirsh': value.amountQirsh,
        'createdAt': value.createdAt.toUtc().toIso8601String(),
        'createdByUserId': value.createdByUserId,
        'ownerApprovalId': value.ownerApprovalId,
        'operationRequestId': value.operationRequestId,
        'paymentMethod': value.paymentMethod?.name,
        'reversedAt': value.reversedAt?.toUtc().toIso8601String(),
        'reversedByUserId': value.reversedByUserId,
      };

  Map<String, Object?> _supplierAdvanceApplicationToJson(
          SupplierAdvanceApplication value) =>
      {
        'id': value.id,
        'advanceId': value.advanceId,
        'supplierId': value.supplierId,
        'amountQirsh': value.amountQirsh,
        'appliedAt': value.appliedAt.toUtc().toIso8601String(),
        'createdByUserId': value.createdByUserId,
        'operationRequestId': value.operationRequestId,
        'supplierLedgerEntryId': value.supplierLedgerEntryId,
        'reversedAt': value.reversedAt?.toUtc().toIso8601String(),
        'reversedByUserId': value.reversedByUserId,
        'reversalReason': value.reversalReason,
        'reversalLedgerEntryId': value.reversalLedgerEntryId,
      };

  Map<String, Object?> _supplierAdvanceRefundToJson(
          SupplierAdvanceRefund value) =>
      {
        'id': value.id,
        'advanceId': value.advanceId,
        'supplierId': value.supplierId,
        'financialAccountId': value.financialAccountId,
        'amountQirsh': value.amountQirsh,
        'refundedAt': value.refundedAt.toUtc().toIso8601String(),
        'createdByUserId': value.createdByUserId,
        'operationRequestId': value.operationRequestId,
        'financialEntryId': value.financialEntryId,
        'reversedAt': value.reversedAt?.toUtc().toIso8601String(),
        'reversedByUserId': value.reversedByUserId,
        'reversalReason': value.reversalReason,
        'reversalFinancialEntryId': value.reversalFinancialEntryId,
      };

  Map<String, Object?>? _customerCollectionCancellationToJson(
    CustomerCollectionCancellation? cancellation,
  ) =>
      cancellation == null
          ? null
          : {
              'id': cancellation.id,
              'originalCollectionId': cancellation.originalCollectionId,
              'cancelledAt': cancellation.cancelledAt.toUtc().toIso8601String(),
              'cancelledByUserId': cancellation.cancelledByUserId,
              'reason': cancellation.reason,
              'customerLedgerReversalEntryId':
                  cancellation.customerLedgerReversalEntryId,
              'financialAccountReversalEntryId':
                  cancellation.financialAccountReversalEntryId,
            };

  Map<String, Object?>? _supplierPaymentCancellationToJson(
    SupplierPaymentCancellation? cancellation,
  ) =>
      cancellation == null
          ? null
          : {
              'id': cancellation.id,
              'originalPaymentId': cancellation.originalPaymentId,
              'cancelledAt': cancellation.cancelledAt.toUtc().toIso8601String(),
              'cancelledByUserId': cancellation.cancelledByUserId,
              'reason': cancellation.reason,
              'supplierLedgerReversalEntryId':
                  cancellation.supplierLedgerReversalEntryId,
              'financialAccountReversalEntryId':
                  cancellation.financialAccountReversalEntryId,
            };

  Map<String, Object?> _customerToJson(Customer customer) {
    return {
      'id': customer.id,
      'name': customer.name,
      'phone': customer.phone,
      'notes': customer.notes,
      'isActive': customer.isActive,
      'createdAt': customer.createdAt.toUtc().toIso8601String(),
      'updatedAt': customer.updatedAt.toUtc().toIso8601String(),
    };
  }

  Map<String, Object?> _expenseToJson(ExpenseRecord expense) {
    return {
      'id': expense.id,
      'date': expense.date.toUtc().toIso8601String(),
      'category': expense.category,
      'amountQirsh': expense.amountQirsh,
      'notes': expense.notes,
      'createdAt': expense.createdAt.toUtc().toIso8601String(),
      'financialAccountId': expense.financialAccountId,
      'paymentMethod': expense.paymentMethod?.name,
    };
  }

  Map<String, Object?> _auditLogToJson(AuditLogEntry entry) {
    return {
      'id': entry.id,
      'timestamp': entry.timestamp.toUtc().toIso8601String(),
      'actionType': entry.actionType,
      'descriptionAr': entry.descriptionAr,
      'referenceId': entry.referenceId,
      'metadata': entry.metadata,
    };
  }

  Map<String, Object?>? _cancellationToJson(CancellationMetadata? metadata) {
    if (metadata == null) {
      return null;
    }

    return {
      'cancelledAt': metadata.cancelledAt.toUtc().toIso8601String(),
      'cancelledByUserId': metadata.cancelledByUserId,
      'cancellationReason': metadata.cancellationReason,
      'originalDocumentId': metadata.originalDocumentId,
      'reversalMovementIds': metadata.reversalMovementIds,
    };
  }

  Future<Map<String, Object?>> _identityWithLogoJson(
    BusinessIdentity identity,
  ) async {
    final json = identity.toJson();
    if (!identity.hasLogo || _businessIdentityRepository == null) {
      return json;
    }
    try {
      final logoBytes = await _businessIdentityRepository
          .loadLogoBytes(identity.logo!.managedFileName);
      if (logoBytes == null || logoBytes.isEmpty) {
        return json;
      }
      final hash = sha256.convert(logoBytes).toString();
      if (hash != identity.logo!.sha256) {
        return json;
      }
      return {
        ...json,
        'logo': {
          'mimeType': identity.logo!.mimeType,
          'base64Data': base64Encode(logoBytes),
          'sha256': hash,
          'byteLength': logoBytes.length,
          'width': identity.logo!.width,
          'height': identity.logo!.height,
        },
      };
    } catch (_) {
      return json;
    }
  }

  Future<List<FinancialAccountEntry>> _listAllFinancialEntries() async {
    final repo = _financialAccountRepository;
    if (repo == null) {
      return const <FinancialAccountEntry>[];
    }
    final accounts = await repo.listAccounts(includeInactive: true);
    final allEntries = <FinancialAccountEntry>[];
    for (final account in accounts) {
      final statement = await repo.statementForAccount(account.id);
      allEntries.addAll(statement.lines.map((l) => l.entry));
    }
    return allEntries;
  }

  Map<String, Object?> _financialAccountToJson(FinancialAccount account) {
    return {
      'id': account.id,
      'name': account.name,
      'type': account.type.name,
      'isActive': account.isActive,
      'allowNegativeBalance': account.allowNegativeBalance,
      'openingBalanceQirsh': account.openingBalanceQirsh,
      'openingBalanceDate':
          account.openingBalanceDate?.toUtc().toIso8601String(),
      'referenceInfo': account.referenceInfo,
      'notes': account.notes,
      'createdByUserId': account.createdByUserId,
      'createdAt': account.createdAt.toUtc().toIso8601String(),
    };
  }

  Map<String, Object?> _financialAccountEntryToJson(
      FinancialAccountEntry entry) {
    return {
      'id': entry.id,
      'accountId': entry.accountId,
      'direction': entry.direction.name,
      'amountQirsh': entry.amountQirsh,
      'sourceType': entry.sourceType.name,
      'sourceDocumentId': entry.sourceDocumentId,
      'sourceDocumentNumber': entry.sourceDocumentNumber,
      'effectiveDate': entry.effectiveDate.toUtc().toIso8601String(),
      'createdAt': entry.createdAt.toUtc().toIso8601String(),
      'createdByUserId': entry.createdByUserId,
      'reference': entry.reference,
      'note': entry.note,
      'reversalOf': entry.reversalOf,
      'correctionGroup': entry.correctionGroup,
      'approvedByUserId': entry.approvedByUserId,
      'negativeBalanceApprovalId': entry.negativeBalanceApprovalId,
    };
  }

  Map<String, Object?> _financialTransferToJson(FinancialTransfer value) => {
        'id': value.id,
        'displayNumber': value.displayNumber,
        'clientRequestId': value.clientRequestId,
        'transferReference': value.transferReference,
        'sourceAccountId': value.sourceAccountId,
        'destinationAccountId': value.destinationAccountId,
        'amountQirsh': value.amountQirsh,
        'effectiveDate': value.effectiveDate.toUtc().toIso8601String(),
        'createdAt': value.createdAt.toUtc().toIso8601String(),
        'createdByUserId': value.createdByUserId,
        'sourceEntryId': value.sourceEntryId,
        'destinationEntryId': value.destinationEntryId,
        'note': value.note,
        'negativeBalanceApprovalId': value.negativeBalanceApprovalId,
        'originalTransferId': value.originalTransferId,
        'reversalTransferId': value.reversalTransferId,
        'reversalReason': value.reversalReason,
      };

  Map<String, Object?> _financialClosingToJson(FinancialClosing value) => {
        'id': value.id,
        'kind': value.kind.name,
        'fromDate': value.fromDate.toUtc().toIso8601String(),
        'toDate': value.toDate.toUtc().toIso8601String(),
        'lines': value.lines
            .map((line) => {
                  'accountId': line.accountId,
                  'expectedBalanceQirsh': line.expectedBalanceQirsh,
                  'actualBalanceQirsh': line.actualBalanceQirsh,
                })
            .toList(growable: false),
        'createdAt': value.createdAt.toUtc().toIso8601String(),
        'createdByUserId': value.createdByUserId,
        'note': value.note,
        'reopenedAt': value.reopenedAt?.toUtc().toIso8601String(),
        'reopenedByUserId': value.reopenedByUserId,
        'reopenReason': value.reopenReason,
      };

  String _adler32(String input) {
    const modulus = 65521;
    var a = 1;
    var b = 0;

    for (final byte in utf8.encode(input)) {
      a = (a + byte) % modulus;
      b = (b + a) % modulus;
    }

    final value = (b << 16) | a;
    return value.toRadixString(16).padLeft(8, '0');
  }
}

class BackupExportResult {
  const BackupExportResult({
    required this.jsonText,
    required this.counts,
    required this.generatedAt,
    required this.backupVersion,
    required this.checksum,
    required this.fileName,
  });

  final String jsonText;
  final BackupExportCounts counts;
  final DateTime generatedAt;
  final int backupVersion;
  final String checksum;
  final String fileName;
}

class BackupExportCounts {
  const BackupExportCounts({
    required this.products,
    required this.inventoryMovements,
    required this.suppliers,
    required this.purchases,
    required this.sales,
    required this.documentHistory,
    required this.customers,
    required this.customerLedgerEntries,
    required this.customerCollections,
    this.supplierLedgerEntries = 0,
    this.supplierPayments = 0,
    required this.expenses,
    required this.auditLogs,
    this.financialAccounts = 0,
    this.financialAccountEntries = 0,
    this.financialTransfers = 0,
    this.financialClosings = 0,
  });

  final int products;
  final int inventoryMovements;
  final int suppliers;
  final int purchases;
  final int sales;
  final int documentHistory;
  final int customers;
  final int customerLedgerEntries;
  final int customerCollections;
  final int supplierLedgerEntries;
  final int supplierPayments;
  final int expenses;
  final int auditLogs;
  final int financialAccounts;
  final int financialAccountEntries;
  final int financialTransfers;
  final int financialClosings;

  Map<String, int> toJson() {
    return {
      'products': products,
      'inventoryMovements': inventoryMovements,
      'suppliers': suppliers,
      'purchases': purchases,
      'sales': sales,
      'documentHistory': documentHistory,
      'customers': customers,
      'customerLedgerEntries': customerLedgerEntries,
      'customerCollections': customerCollections,
      'supplierLedgerEntries': supplierLedgerEntries,
      'supplierPayments': supplierPayments,
      'expenses': expenses,
      'auditLogs': auditLogs,
      'financialAccounts': financialAccounts,
      'financialAccountEntries': financialAccountEntries,
      'financialTransfers': financialTransfers,
      'financialClosings': financialClosings,
    };
  }
}

class BackupFileName {
  const BackupFileName._();

  static String forGeneratedAt(DateTime generatedAt) {
    final local = generatedAt.toLocal();
    return 'grain-warehouse-backup-'
        '${_four(local.year)}${_two(local.month)}${_two(local.day)}-'
        '${_two(local.hour)}${_two(local.minute)}${_two(local.second)}.json';
  }

  static bool isSafeWindowsFileName(String fileName) {
    if (fileName.trim() != fileName || fileName.contains(' ')) {
      return false;
    }
    if (fileName.isEmpty || fileName.endsWith('.') || fileName.endsWith(' ')) {
      return false;
    }

    return !RegExp(r'[<>:"/\\|?*]').hasMatch(fileName);
  }

  static String _four(int value) {
    return value.toString().padLeft(4, '0');
  }

  static String _two(int value) {
    return value.toString().padLeft(2, '0');
  }
}

class BackupExportValidator {
  const BackupExportValidator._();

  static const _sensitiveKeys = {
    'password',
    'passwordhash',
    'token',
    'session',
    'secret',
  };

  static void validateJsonText(String jsonText) {
    final decoded = jsonDecode(jsonText);
    if (decoded is! Map<String, Object?>) {
      throw const BackupExportValidationException();
    }

    final metadata = decoded['metadata'];
    final counts = decoded['counts'];
    final data = decoded['data'];
    if (metadata is! Map<String, Object?> ||
        counts is! Map<String, Object?> ||
        data is! Map<String, Object?>) {
      throw const BackupExportValidationException();
    }
    if (metadata['restoreSupported'] != false) {
      throw const BackupExportValidationException();
    }
    if (_containsSensitiveKey(decoded)) {
      throw const BackupExportValidationException();
    }
  }

  static bool _containsSensitiveKey(Object? value) {
    if (value is Map) {
      for (final entry in value.entries) {
        final key = entry.key.toString().toLowerCase();
        if (_sensitiveKeys.contains(key)) {
          return true;
        }
        if (_containsSensitiveKey(entry.value)) {
          return true;
        }
      }
      return false;
    }
    if (value is Iterable) {
      return value.any(_containsSensitiveKey);
    }

    return false;
  }
}

class BackupExportValidationException implements Exception {
  const BackupExportValidationException();
}
