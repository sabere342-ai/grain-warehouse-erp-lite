import 'package:flutter/foundation.dart';
import 'package:grain_warehouse_erp_lite/core/auth/app_user.dart';
import 'package:grain_warehouse_erp_lite/core/customers/customer.dart';
import 'package:grain_warehouse_erp_lite/core/customers/customer_repository.dart';

class CustomerController extends ChangeNotifier {
  CustomerController({required CustomerRepository repository})
      : _repository = repository;

  final CustomerRepository _repository;
  List<Customer> _customers = const [];
  String? _errorMessage;
  bool _isLoading = false;

  List<Customer> get customers => List<Customer>.unmodifiable(_customers);
  String? get errorMessage => _errorMessage;
  bool get isLoading => _isLoading;

  Future<void> loadCustomers(AppUser user) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();
    _customers = await _repository.listCustomers(
      includeInactive: user.permissions.canAccessSettings,
    );
    _isLoading = false;
    notifyListeners();
  }

  Future<bool> createCustomer({
    required AppUser user,
    required CustomerDraft draft,
  }) async {
    if (!_canManage(user)) {
      return false;
    }
    try {
      await _repository.createCustomer(draft);
      await loadCustomers(user);
      return true;
    } catch (error) {
      _errorMessage = _messageForError(error);
      notifyListeners();
      return false;
    }
  }

  Future<bool> updateCustomer({
    required AppUser user,
    required String customerId,
    required CustomerDraft draft,
  }) async {
    if (!_canManage(user)) {
      return false;
    }
    try {
      await _repository.updateCustomer(customerId: customerId, draft: draft);
      await loadCustomers(user);
      return true;
    } catch (error) {
      _errorMessage = _messageForError(error);
      notifyListeners();
      return false;
    }
  }

  Future<bool> setCustomerActive({
    required AppUser user,
    required String customerId,
    required bool isActive,
  }) async {
    if (!_canManage(user)) {
      return false;
    }
    try {
      await _repository.setCustomerActive(
        customerId: customerId,
        isActive: isActive,
      );
      await loadCustomers(user);
      return true;
    } catch (error) {
      _errorMessage = _messageForError(error);
      notifyListeners();
      return false;
    }
  }

  bool _canManage(AppUser user) {
    if (!user.canProceed) {
      _errorMessage = 'يجب تسجيل الدخول بمستخدم صالح.';
      notifyListeners();
      return false;
    }
    if (user.permissions.canCreateCustomerPayment ||
        user.permissions.canAccessSettings) {
      return true;
    }
    _errorMessage = 'لا يملك هذا المستخدم صلاحية إدارة العملاء.';
    notifyListeners();
    return false;
  }

  String _messageForError(Object error) {
    if (error is ArgumentError) {
      return 'تحقق من بيانات العميل.';
    }
    if (error is StateError) {
      return 'لا يمكن حفظ العميل بهذه البيانات.';
    }
    return 'تعذر حفظ بيانات العميل.';
  }
}
