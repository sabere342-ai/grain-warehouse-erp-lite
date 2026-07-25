import 'package:flutter/foundation.dart';
import 'package:grain_warehouse_erp_lite/core/auth/app_user.dart';
import 'package:grain_warehouse_erp_lite/core/catalog/product.dart';
import 'package:grain_warehouse_erp_lite/core/catalog/product_repository.dart';
import 'package:grain_warehouse_erp_lite/core/inventory/inventory_repository.dart';
import 'package:grain_warehouse_erp_lite/core/inventory/stock_movement.dart';

class InventoryController extends ChangeNotifier {
  InventoryController({
    required InventoryRepository inventoryRepository,
    required ProductRepository productRepository,
  })  : _inventoryRepository = inventoryRepository,
        _productRepository = productRepository;

  final InventoryRepository _inventoryRepository;
  final ProductRepository _productRepository;

  List<Product> _products = const [];
  List<StockMovement> _movements = const [];
  Map<String, int> _balancesKg = const {};
  Set<String> _productsWithOpeningBalance = const {};
  String? _errorMessage;
  bool _isLoading = false;

  List<Product> get products => List<Product>.unmodifiable(_products);
  List<StockMovement> get movements =>
      List<StockMovement>.unmodifiable(_movements);
  Map<String, int> get balancesKg => Map<String, int>.unmodifiable(_balancesKg);
  String? get errorMessage => _errorMessage;
  bool get isLoading => _isLoading;

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
  }) {
    return _createMovement(
      user: user,
      productId: productId,
      movementType: StockMovementType.manualIncrease,
      quantityKg: quantityKg,
      note: note,
    );
  }

  Future<bool> createManualDecrease({
    required AppUser user,
    required String productId,
    required int quantityKg,
    String? note,
  }) {
    return _createMovement(
      user: user,
      productId: productId,
      movementType: StockMovementType.manualDecrease,
      quantityKg: quantityKg,
      note: note,
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
  }) async {
    if (!_canCreateStockMovement(user)) {
      return false;
    }

    try {
      await _inventoryRepository.createMovement(
        StockMovementDraft(
          productId: productId,
          movementType: movementType,
          quantityKg: quantityKg,
          createdByUserId: user.id,
          note: note,
        ),
      );
      await load(user);
      return true;
    } catch (error) {
      _errorMessage = _messageForError(error);
      notifyListeners();
      return false;
    }
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
