import 'package:flutter/foundation.dart';
import 'package:grain_warehouse_erp_lite/core/auth/app_user.dart';
import 'package:grain_warehouse_erp_lite/core/catalog/product.dart';
import 'package:grain_warehouse_erp_lite/core/catalog/product_repository.dart';
import 'package:grain_warehouse_erp_lite/core/inventory/inventory_repository.dart';
import 'package:grain_warehouse_erp_lite/core/inventory/stock_movement.dart';
import 'package:grain_warehouse_erp_lite/core/audit/audit_log_repository.dart';
import 'package:grain_warehouse_erp_lite/core/financial_accounts/financial_account_repository.dart';
import 'package:grain_warehouse_erp_lite/core/financial_accounts/repository_transaction.dart';
import 'package:grain_warehouse_erp_lite/core/inventory_valuation/inventory_valuation.dart';
import 'package:grain_warehouse_erp_lite/core/inventory_valuation/inventory_valuation_repository.dart';

class InventoryController extends ChangeNotifier {
  InventoryController({
    required InventoryRepository inventoryRepository,
    required ProductRepository productRepository,
    InventoryValuationRepository? inventoryValuationRepository,
    FinancialAccountRepository? financialAccountRepository,
    AuditLogRepository? auditLogRepository,
  })  : _inventoryRepository = inventoryRepository,
        _productRepository = productRepository,
        _inventoryValuationRepository = inventoryValuationRepository,
        _financialAccountRepository = financialAccountRepository,
        _auditLogRepository = auditLogRepository;

  final InventoryRepository _inventoryRepository;
  final ProductRepository _productRepository;
  final InventoryValuationRepository? _inventoryValuationRepository;
  final FinancialAccountRepository? _financialAccountRepository;
  final AuditLogRepository? _auditLogRepository;

  List<Product> _products = const [];
  List<StockMovement> _movements = const [];
  Map<String, int> _balancesKg = const {};
  Set<String> _productsWithOpeningBalance = const {};
  String? _errorMessage;
  bool _isLoading = false;
  bool _isProfitabilityActivated = false;

  List<Product> get products => List<Product>.unmodifiable(_products);
  List<StockMovement> get movements =>
      List<StockMovement>.unmodifiable(_movements);
  Map<String, int> get balancesKg => Map<String, int>.unmodifiable(_balancesKg);
  String? get errorMessage => _errorMessage;
  bool get isLoading => _isLoading;
  bool get isProfitabilityActivated => _isProfitabilityActivated;

  Future<void> load(AppUser user) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    _products = await _productRepository.listProducts(
      includeInactive: user.permissions.canCreateStockAdjustment,
    );
    _movements = await _inventoryRepository.listAllMovements();
    _balancesKg = await _inventoryRepository.allProductBalancesKg(
      activeProductsOnly: !user.permissions.canCreateStockAdjustment,
    );
    _isProfitabilityActivated = user.permissions.canViewFinancialReports &&
        (await _inventoryValuationRepository?.getActivation())?.isActivated ==
            true;
    _productsWithOpeningBalance = _movements
        .where((movement) =>
            movement.movementType == StockMovementType.openingBalance &&
            !movement.isVoided)
        .map((movement) => movement.productId)
        .toSet();

    _isLoading = false;
    notifyListeners();
  }

  Future<bool> createOpeningBalance({
    required AppUser user,
    required String productId,
    required int quantityKg,
    String? note,
  }) {
    return _createMovement(
      user: user,
      productId: productId,
      movementType: StockMovementType.openingBalance,
      quantityKg: quantityKg,
      note: note,
    );
  }

  Future<bool> createManualIncrease({
    required AppUser user,
    required String productId,
    required int quantityKg,
    String? note,
    int? unitCostQirshPerKg,
    String? evidenceReference,
    bool isStocktake = false,
  }) {
    return _createMovement(
      user: user,
      productId: productId,
      movementType: StockMovementType.manualIncrease,
      quantityKg: quantityKg,
      note: note,
      unitCostQirshPerKg: unitCostQirshPerKg,
      evidenceReference: evidenceReference,
      isStocktake: isStocktake,
    );
  }

  Future<bool> createManualDecrease({
    required AppUser user,
    required String productId,
    required int quantityKg,
    String? note,
    bool isStocktake = false,
  }) {
    return _createMovement(
      user: user,
      productId: productId,
      movementType: StockMovementType.manualDecrease,
      quantityKg: quantityKg,
      note: note,
      isStocktake: isStocktake,
    );
  }

  int balanceForProduct(String productId) {
    return _balancesKg[productId] ?? 0;
  }

  bool hasOpeningBalance(String productId) {
    return _productsWithOpeningBalance.contains(productId);
  }

  List<StockMovement> movementsForProduct(String productId) {
    return _movements
        .where((movement) => movement.productId == productId)
        .toList(growable: false);
  }

  Future<bool> _createMovement({
    required AppUser user,
    required String productId,
    required StockMovementType movementType,
    required int quantityKg,
    String? note,
    int? unitCostQirshPerKg,
    String? evidenceReference,
    bool isStocktake = false,
  }) async {
    if (!_canCreateStockMovement(user)) {
      return false;
    }

    try {
      final now = DateTime.now();
      await _financialAccountRepository?.ensureDateIsOpen(now);
      final valuation = _inventoryValuationRepository;
      final activation = await valuation?.getActivation();
      final reason = note?.trim() ?? '';
      if (activation?.isActivated == true &&
          movementType == StockMovementType.openingBalance) {
        throw StateError(
            'Opening balances are frozen after profitability activation.');
      }
      if (activation?.isActivated == true && reason.isEmpty) {
        throw ArgumentError('Adjustment reason is required.');
      }
      if (activation?.isActivated == true &&
          movementType == StockMovementType.manualIncrease &&
          (unitCostQirshPerKg == null ||
              unitCostQirshPerKg <= 0 ||
              (evidenceReference?.trim().isEmpty ?? true))) {
        throw ArgumentError('Surplus cost and trusted evidence are required.');
      }
      final snapshots = <SnapshotHolder>[
        _requiredSnapshot(_inventoryRepository, 'inventory'),
      ];
      if (valuation != null) {
        snapshots.add(_requiredSnapshot(valuation, 'inventory valuation'));
      }
      if (_auditLogRepository != null) {
        snapshots.add(_requiredSnapshot(_auditLogRepository, 'audit'));
      }
      await RepositoryTransaction.execute(snapshots, () async {
        final movement = await _inventoryRepository.createMovement(
          StockMovementDraft(
            productId: productId,
            movementType: movementType,
            quantityKg: quantityKg,
            createdByUserId: user.id,
            note: note,
          ),
        );
        if (movementType == StockMovementType.manualIncrease) {
          await valuation?.recordValuedIncrease(
            productId: productId,
            quantityKg: quantityKg,
            unitCostQirshPerKg: unitCostQirshPerKg ?? 0,
            type: isStocktake
                ? InventoryValuationEventType.stocktakeSurplus
                : InventoryValuationEventType.manualIncrease,
            sourceDocumentId: movement.id,
            effectiveDate: now,
            createdByUserId: user.id,
            reason: reason,
            evidenceReference: evidenceReference?.trim() ?? '',
          );
        } else if (movementType == StockMovementType.manualDecrease) {
          await valuation?.recordDecrease(
            productId: productId,
            quantityKg: quantityKg,
            type: isStocktake
                ? InventoryValuationEventType.stocktakeShortage
                : InventoryValuationEventType.manualDecrease,
            sourceDocumentId: movement.id,
            effectiveDate: now,
            createdByUserId: user.id,
            reason: reason,
          );
        }
        await _auditLogRepository?.record(AuditLogDraft(
          actionType: isStocktake
              ? 'inventory.stocktake.adjusted'
              : 'inventory.manual.adjusted',
          descriptionAr:
              'تسوية مخزون ${movementType.name}: $quantityKg كجم. السبب: $reason',
          referenceId: movement.id,
          actorId: user.id,
        ));
      });
      await load(user);
      return true;
    } catch (error) {
      _errorMessage = _messageForError(error);
      notifyListeners();
      return false;
    }
  }

  SnapshotHolder _requiredSnapshot(Object repository, String name) {
    if (repository is! TransactionSnapshotProvider) {
      throw StateError(
          'Inventory $name repository cannot participate in a transaction.');
    }
    return repository.createTransactionSnapshot();
  }

  bool _canCreateStockMovement(AppUser user) {
    if (!user.canProceed) {
      _errorMessage = 'يجب تسجيل الدخول بمستخدم صالح.';
      notifyListeners();
      return false;
    }
    if (user.permissions.canCreateStockAdjustment) {
      return true;
    }

    _errorMessage = 'لا يملك هذا المستخدم صلاحية تعديل المخزون.';
    notifyListeners();
    return false;
  }

  String _messageForError(Object error) {
    if (error is ArgumentError) {
      return 'تحقق من بيانات حركة المخزون.';
    }
    if (error is StateError) {
      return 'لا يمكن تنفيذ حركة المخزون لهذا الصنف.';
    }

    return 'تعذر حفظ حركة المخزون.';
  }
}
