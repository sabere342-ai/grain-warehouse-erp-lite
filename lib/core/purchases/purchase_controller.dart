import 'package:flutter/foundation.dart';
import 'package:grain_warehouse_erp_lite/core/auth/app_user.dart';
import 'package:grain_warehouse_erp_lite/core/catalog/product.dart';
import 'package:grain_warehouse_erp_lite/core/catalog/product_repository.dart';
import 'package:grain_warehouse_erp_lite/core/purchases/purchase_intake.dart';
import 'package:grain_warehouse_erp_lite/core/purchases/purchase_repository.dart';
import 'package:grain_warehouse_erp_lite/core/suppliers/supplier.dart';
import 'package:grain_warehouse_erp_lite/core/suppliers/supplier_repository.dart';

class PurchaseController extends ChangeNotifier {
  PurchaseController({
    required PurchaseRepository purchaseRepository,
    required SupplierRepository supplierRepository,
    required ProductRepository productRepository,
  })  : _purchaseRepository = purchaseRepository,
        _supplierRepository = supplierRepository,
        _productRepository = productRepository;

  final PurchaseRepository _purchaseRepository;
  final SupplierRepository _supplierRepository;
  final ProductRepository _productRepository;

  List<PurchaseIntake> _intakes = const [];
  List<Supplier> _suppliers = const [];
  List<Product> _products = const [];
  String? _errorMessage;
  bool _isLoading = false;

  List<PurchaseIntake> get intakes =>
      List<PurchaseIntake>.unmodifiable(_intakes);
  List<Supplier> get suppliers => List<Supplier>.unmodifiable(_suppliers);
  List<Product> get products => List<Product>.unmodifiable(_products);
  String? get errorMessage => _errorMessage;
  bool get isLoading => _isLoading;

  Future<void> load(AppUser user) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    _intakes = await _purchaseRepository.listPurchaseIntakes();
    _suppliers = await _supplierRepository.listSuppliers(
      includeInactive: user.permissions.canCreatePurchaseIntake,
    );
    _products = await _productRepository.listProducts(
      includeInactive: user.permissions.canCreatePurchaseIntake,
    );

    _isLoading = false;
    notifyListeners();
  }

  Future<bool> createPurchaseIntake({
    required AppUser user,
    required PurchaseIntakeDraft draft,
  }) async {
    if (!_canCreatePurchaseIntake(user)) {
      return false;
    }

    try {
      await _purchaseRepository.createPurchaseIntake(draft);
      await load(user);
      return true;
    } catch (error) {
      _errorMessage = _messageForError(error);
      notifyListeners();
      return false;
    }
  }

  Future<bool> cancelPurchaseIntake({
    required AppUser user,
    required String purchaseIntakeId,
    required String cancellationReason,
  }) async {
    if (!_canCancelPostedDocument(user)) {
      return false;
    }

    try {
      await _purchaseRepository.cancelPurchaseIntake(
        purchaseIntakeId: purchaseIntakeId,
        cancelledByUserId: user.id,
        cancellationReason: cancellationReason,
      );
      await load(user);
      return true;
    } catch (error) {
      _errorMessage = _messageForError(error);
      notifyListeners();
      return false;
    }
  }

  String supplierName(String supplierId) {
    for (final supplier in _suppliers) {
      if (supplier.id == supplierId) {
        return supplier.name;
      }
    }

    return 'مورد غير معروف';
  }

  String productName(String productId) {
    for (final product in _products) {
      if (product.id == productId) {
        return product.name;
      }
    }

    return 'صنف غير معروف';
  }

  bool _canCreatePurchaseIntake(AppUser user) {
    if (!user.canProceed) {
      _errorMessage = 'يجب تسجيل الدخول بمستخدم صالح.';
      notifyListeners();
      return false;
    }
    if (user.permissions.canCreatePurchaseIntake) {
      return true;
    }

    _errorMessage = 'لا يملك هذا المستخدم صلاحية تسجيل استلام شراء.';
    notifyListeners();
    return false;
  }

  bool _canCancelPostedDocument(AppUser user) {
    if (!user.canProceed) {
      _errorMessage = 'يجب تسجيل الدخول بمستخدم صالح.';
      notifyListeners();
      return false;
    }
    if (user.permissions.canCancelInvoice) {
      return true;
    }

    _errorMessage = 'لا يملك هذا المستخدم صلاحية إلغاء المستندات المرحلة.';
    notifyListeners();
    return false;
  }

  String _messageForError(Object error) {
    if (error is ArgumentError) {
      return 'تحقق من بيانات استلام الشراء.';
    }
    if (error is StateError) {
      return 'لا يمكن تسجيل استلام الشراء بهذه البيانات.';
    }

    return 'تعذر حفظ استلام الشراء.';
  }
}
