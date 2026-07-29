import 'package:grain_warehouse_erp_lite/core/catalog/product_catalog_read_repository.dart';
import 'package:grain_warehouse_erp_lite/core/documents/cancellation_metadata.dart';
import 'package:grain_warehouse_erp_lite/core/inventory/inventory_repository.dart';
import 'package:grain_warehouse_erp_lite/core/inventory/stock_movement.dart';
import 'package:grain_warehouse_erp_lite/core/purchases/purchase_repository.dart';
import 'package:grain_warehouse_erp_lite/core/sales/sale_repository.dart';

enum DocumentHistoryType {
  purchaseIntake,
  sale;

  String get labelAr {
    switch (this) {
      case DocumentHistoryType.purchaseIntake:
        return 'استلام شراء';
      case DocumentHistoryType.sale:
        return 'بيع';
    }
  }
}

enum DocumentHistoryStatus {
  active,
  cancelled;

  String get labelAr {
    switch (this) {
      case DocumentHistoryStatus.active:
        return 'نشط';
      case DocumentHistoryStatus.cancelled:
        return 'ملغي';
    }
  }
}

class DocumentHistoryFilter {
  const DocumentHistoryFilter({
    this.from,
    this.to,
    this.type,
    this.status,
    this.query,
    this.productName,
  });

  final DateTime? from;
  final DateTime? to;
  final DocumentHistoryType? type;
  final DocumentHistoryStatus? status;
  final String? query;
  final String? productName;
}

class DocumentHistoryEntry {
  const DocumentHistoryEntry({
    required this.id,
    required this.type,
    required this.productId,
    required this.productName,
    required this.quantityKg,
    required this.createdByUserId,
    required this.createdAt,
    required this.originalMovement,
    required this.reversalMovements,
    this.createdByUserName,
    this.partyName,
    this.unitPricePiastersPerKg,
    this.totalPiasters,
    this.notes,
    this.cancellation,
  });

  final String id;
  final DocumentHistoryType type;
  final String productId;
  final String productName;
  final String? partyName;
  final int quantityKg;
  final int? unitPricePiastersPerKg;
  final int? totalPiasters;
  final String createdByUserId;
  final String? createdByUserName;
  final DateTime createdAt;
  final String? notes;
  final CancellationMetadata? cancellation;
  final StockMovement? originalMovement;
  final List<StockMovement> reversalMovements;

  bool get isCancelled => cancellation != null;

  DocumentHistoryStatus get status => isCancelled
      ? DocumentHistoryStatus.cancelled
      : DocumentHistoryStatus.active;
}

abstract class DocumentHistoryRepository {
  Future<List<DocumentHistoryEntry>> listHistory({
    DocumentHistoryFilter filter = const DocumentHistoryFilter(),
  });
}

class LocalDocumentHistoryRepository implements DocumentHistoryRepository {
  const LocalDocumentHistoryRepository({
    required PurchaseRepository purchaseRepository,
    required SaleRepository saleRepository,
    required ProductCatalogReadRepository productCatalogReadRepository,
    required InventoryRepository inventoryRepository,
  })  : _purchaseRepository = purchaseRepository,
        _saleRepository = saleRepository,
        _productCatalogReadRepository = productCatalogReadRepository,
        _inventoryRepository = inventoryRepository;

  final PurchaseRepository _purchaseRepository;
  final SaleRepository _saleRepository;
  final ProductCatalogReadRepository _productCatalogReadRepository;
  final InventoryRepository _inventoryRepository;

  @override
  Future<List<DocumentHistoryEntry>> listHistory({
    DocumentHistoryFilter filter = const DocumentHistoryFilter(),
  }) async {
    final productNames = await _productNamesById();
    final movements = await _inventoryRepository.listAllMovements();
    final entries = <DocumentHistoryEntry>[
      ...await _purchaseEntries(productNames, movements),
      ...await _saleEntries(productNames, movements),
    ];

    entries.sort((left, right) => right.createdAt.compareTo(left.createdAt));
    return List<DocumentHistoryEntry>.unmodifiable(
      entries.where((entry) => _matchesFilter(entry, filter)),
    );
  }

  Future<Map<String, String>> _productNamesById() async {
    final products = await _productCatalogReadRepository.listProductCatalog(
      includeInactive: true,
    );
    return {
      for (final product in products) product.id: product.name,
    };
  }

  Future<List<DocumentHistoryEntry>> _purchaseEntries(
    Map<String, String> productNames,
    List<StockMovement> movements,
  ) async {
    final intakes = await _purchaseRepository.listPurchaseIntakes();
    return [
      for (final intake in intakes)
        DocumentHistoryEntry(
          id: intake.id,
          type: DocumentHistoryType.purchaseIntake,
          productId: intake.productId,
          productName: productNames[intake.productId] ?? 'صنف غير معروف',
          quantityKg: intake.quantityKg,
          unitPricePiastersPerKg: intake.unitPricePiastersPerKg,
          totalPiasters: intake.totalAmountPiasters,
          createdByUserId: intake.createdByUserId,
          createdAt: intake.createdAt,
          notes: intake.notes,
          cancellation: intake.cancellation,
          originalMovement: _findMovement(movements, intake.stockMovementId),
          reversalMovements: _findReversalMovements(
            movements,
            intake.cancellation,
          ),
        ),
    ];
  }

  Future<List<DocumentHistoryEntry>> _saleEntries(
    Map<String, String> productNames,
    List<StockMovement> movements,
  ) async {
    final sales = await _saleRepository.listSales();
    return [
      for (final sale in sales) ...[
        DocumentHistoryEntry(
          id: sale.id,
          type: DocumentHistoryType.sale,
          productId: sale.productId,
          productName: sale.isMultiItem
              ? '\u0641\u0627\u062a\u0648\u0631\u0629 ${sale.items.length} \u0623\u0635\u0646\u0627\u0641'
              : (productNames[sale.productId] ??
                  '\u0635\u0646\u0641 \u063a\u064a\u0631 \u0645\u0639\u0631\u0648\u0641'),
          quantityKg: sale.quantityKg,
          unitPricePiastersPerKg: sale.salePriceQirshPerKg,
          totalPiasters: sale.totalQirsh,
          createdByUserId: sale.createdByUserId,
          createdByUserName: sale.createdByUserName,
          createdAt: sale.createdAt,
          notes: sale.notes,
          cancellation: sale.cancellation,
          originalMovement: _findMovement(movements, sale.stockMovementId),
          reversalMovements: _findReversalMovements(
            movements,
            sale.cancellation,
          ),
        ),
      ],
    ];
  }

  StockMovement? _findMovement(
    List<StockMovement> movements,
    String movementId,
  ) {
    for (final movement in movements) {
      if (movement.id == movementId) {
        return movement;
      }
    }

    return null;
  }

  List<StockMovement> _findReversalMovements(
    List<StockMovement> movements,
    CancellationMetadata? cancellation,
  ) {
    if (cancellation == null) {
      return const [];
    }

    final reversalIds = cancellation.reversalMovementIds.toSet();
    return List<StockMovement>.unmodifiable(
      movements.where((movement) => reversalIds.contains(movement.id)),
    );
  }

  bool _matchesFilter(
    DocumentHistoryEntry entry,
    DocumentHistoryFilter filter,
  ) {
    if (filter.from != null && entry.createdAt.isBefore(filter.from!)) {
      return false;
    }
    if (filter.to != null && entry.createdAt.isAfter(filter.to!)) {
      return false;
    }
    if (filter.type != null && entry.type != filter.type) {
      return false;
    }
    if (filter.status != null && entry.status != filter.status) {
      return false;
    }
    if (!_containsNormalized(entry.productName, filter.productName)) {
      return false;
    }
    if (!_matchesSearch(entry, filter.query)) {
      return false;
    }

    return true;
  }

  bool _matchesSearch(DocumentHistoryEntry entry, String? query) {
    final normalized = _normalized(query);
    if (normalized.isEmpty) {
      return true;
    }

    return _normalized(entry.id).contains(normalized);
  }

  bool _containsNormalized(String value, String? query) {
    final normalized = _normalized(query);
    if (normalized.isEmpty) {
      return true;
    }

    return _normalized(value).contains(normalized);
  }

  String _normalized(String? value) {
    return value?.trim().toLowerCase() ?? '';
  }
}
