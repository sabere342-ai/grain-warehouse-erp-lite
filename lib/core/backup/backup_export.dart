import 'dart:convert';

import 'package:grain_warehouse_erp_lite/core/catalog/product.dart';
import 'package:grain_warehouse_erp_lite/core/catalog/product_repository.dart';
import 'package:grain_warehouse_erp_lite/core/documents/cancellation_metadata.dart';
import 'package:grain_warehouse_erp_lite/core/documents/document_history.dart';
import 'package:grain_warehouse_erp_lite/core/inventory/inventory_repository.dart';
import 'package:grain_warehouse_erp_lite/core/inventory/stock_movement.dart';
import 'package:grain_warehouse_erp_lite/core/purchases/purchase_intake.dart';
import 'package:grain_warehouse_erp_lite/core/purchases/purchase_repository.dart';
import 'package:grain_warehouse_erp_lite/core/sales/sale_record.dart';
import 'package:grain_warehouse_erp_lite/core/sales/sale_repository.dart';
import 'package:grain_warehouse_erp_lite/core/suppliers/supplier.dart';
import 'package:grain_warehouse_erp_lite/core/suppliers/supplier_repository.dart';

class BackupExportService {
  const BackupExportService({
    required ProductRepository productRepository,
    required InventoryRepository inventoryRepository,
    required SupplierRepository supplierRepository,
    required PurchaseRepository purchaseRepository,
    required SaleRepository saleRepository,
    required DocumentHistoryRepository documentHistoryRepository,
    DateTime Function()? now,
  })  : _productRepository = productRepository,
        _inventoryRepository = inventoryRepository,
        _supplierRepository = supplierRepository,
        _purchaseRepository = purchaseRepository,
        _saleRepository = saleRepository,
        _documentHistoryRepository = documentHistoryRepository,
        _now = now;

  static const int backupVersion = 1;

  final ProductRepository _productRepository;
  final InventoryRepository _inventoryRepository;
  final SupplierRepository _supplierRepository;
  final PurchaseRepository _purchaseRepository;
  final SaleRepository _saleRepository;
  final DocumentHistoryRepository _documentHistoryRepository;
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

    final counts = BackupExportCounts(
      products: products.length,
      inventoryMovements: movements.length,
      suppliers: suppliers.length,
      purchases: purchases.length,
      sales: sales.length,
      documentHistory: documentHistory.length,
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
            'هذه نسخة تصدير فقط. الاسترجاع غير متاح في هذه المرحلة لتجنب مسح البيانات بالخطأ.',
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
      'notes': sale.notes,
      'isCancelled': sale.isCancelled,
      'cancellation': _cancellationToJson(sale.cancellation),
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
  });

  final int products;
  final int inventoryMovements;
  final int suppliers;
  final int purchases;
  final int sales;
  final int documentHistory;

  Map<String, int> toJson() {
    return {
      'products': products,
      'inventoryMovements': inventoryMovements,
      'suppliers': suppliers,
      'purchases': purchases,
      'sales': sales,
      'documentHistory': documentHistory,
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
