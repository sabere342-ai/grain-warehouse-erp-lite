import 'package:flutter/foundation.dart';
import 'package:grain_warehouse_erp_lite/core/auth/app_user.dart';
import 'package:grain_warehouse_erp_lite/core/catalog/product.dart';
import 'package:grain_warehouse_erp_lite/core/catalog/product_repository.dart';
import 'package:grain_warehouse_erp_lite/core/sales/sale_record.dart';
import 'package:grain_warehouse_erp_lite/core/sales/sale_repository.dart';

class SaleController extends ChangeNotifier {
  SaleController({
    required SaleRepository saleRepository,
    required ProductRepository productRepository,
  })  : _saleRepository = saleRepository,
        _productRepository = productRepository;

  final SaleRepository _saleRepository;
  final ProductRepository _productRepository;

  List<SaleRecord> _sales = const [];
  List<Product> _products = const [];
  String? _errorMessage;
  bool _isLoading = false;

  List<SaleRecord> get sales => List<SaleRecord>.unmodifiable(_sales);
  List<Product> get products => List<Product>.unmodifiable(_products);
  String? get errorMessage => _errorMessage;
  bool get isLoading => _isLoading;

  Future<void> load(AppUser user) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    _sales = await _saleRepository.listSales();
    _products = await _productRepository.listProducts(includeInactive: false);

    _isLoading = false;
    notifyListeners();
  }

  Future<bool> createSale({
    required AppUser user,
    required String productId,
    required int quantityKg,
    required int salePriceQirshPerKg,
    String? notes,
  }) async {
    if (!_canCreateSale(user)) {
      return false;
    }

    try {
      await _saleRepository.createSale(
        SaleDraft(
          productId: productId,
          quantityKg: quantityKg,
          salePriceQirshPerKg: salePriceQirshPerKg,
          createdByUserId: user.id,
          createdByUserName: user.name,
          notes: notes,
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

  String productName(String productId) {
    for (final product in _products) {
      if (product.id == productId) {
        return product.name;
      }
    }

    return 'صنف غير معروف';
  }

  bool _canCreateSale(AppUser user) {
    if (!user.canProceed) {
      _errorMessage = 'يجب تسجيل الدخول بمستخدم صالح.';
      notifyListeners();
      return false;
    }
    if (user.permissions.canCreateSale) {
      return true;
    }

    _errorMessage = 'لا يملك هذا المستخدم صلاحية تسجيل البيع.';
    notifyListeners();
    return false;
  }

  String _messageForError(Object error) {
    if (error is ArgumentError) {
      return 'تحقق من بيانات البيع.';
    }
    if (error is StateError) {
      return 'لا يمكن تسجيل البيع لهذه الكمية أو الصنف.';
    }

    return 'تعذر حفظ البيع.';
  }
}
