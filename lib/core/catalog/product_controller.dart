import 'package:flutter/foundation.dart';
import 'package:grain_warehouse_erp_lite/core/auth/app_user.dart';
import 'package:grain_warehouse_erp_lite/core/catalog/product.dart';
import 'package:grain_warehouse_erp_lite/core/catalog/product_repository.dart';

class ProductController extends ChangeNotifier {
  ProductController({required ProductRepository repository})
      : _repository = repository;

  final ProductRepository _repository;
  List<Product> _products = const [];
  String? _errorMessage;
  bool _isLoading = false;

  List<Product> get products => List<Product>.unmodifiable(_products);
  String? get errorMessage => _errorMessage;
  bool get isLoading => _isLoading;

  Future<void> loadProducts(AppUser user) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    _products = await _repository.listProducts(
      includeInactive: user.permissions.canManageProducts,
    );
    _isLoading = false;
    notifyListeners();
  }

  Future<bool> createProduct({
    required AppUser user,
    required ProductDraft draft,
  }) async {
    if (!_canManageProducts(user)) {
      return false;
    }

    try {
      await _repository.createProduct(draft);
      await loadProducts(user);
      return true;
    } catch (error) {
      _errorMessage = _messageForError(error);
      notifyListeners();
      return false;
    }
  }

  Future<bool> updateProduct({
    required AppUser user,
    required String productId,
    required ProductDraft draft,
  }) async {
    if (!_canManageProducts(user)) {
      return false;
    }

    try {
      await _repository.updateProduct(productId: productId, draft: draft);
      await loadProducts(user);
      return true;
    } catch (error) {
      _errorMessage = _messageForError(error);
      notifyListeners();
      return false;
    }
  }

  Future<bool> setProductActive({
    required AppUser user,
    required String productId,
    required bool isActive,
  }) async {
    if (!_canManageProducts(user)) {
      return false;
    }

    try {
      await _repository.setProductActive(
        productId: productId,
        isActive: isActive,
      );
      await loadProducts(user);
      return true;
    } catch (error) {
      _errorMessage = _messageForError(error);
      notifyListeners();
      return false;
    }
  }

  bool _canManageProducts(AppUser user) {
    if (user.permissions.canManageProducts) {
      return true;
    }

    _errorMessage = 'لا يملك هذا المستخدم صلاحية إدارة الأصناف.';
    notifyListeners();
    return false;
  }

  String _messageForError(Object error) {
    if (error is ArgumentError) {
      return 'تحقق من بيانات الصنف المدخلة.';
    }
    if (error is StateError) {
      return 'يوجد صنف بنفس الاسم أو الكود.';
    }

    return 'تعذر حفظ بيانات الصنف.';
  }
}
