import 'package:flutter/foundation.dart';
import 'package:grain_warehouse_erp_lite/core/auth/app_user.dart';
import 'package:grain_warehouse_erp_lite/core/suppliers/supplier.dart';
import 'package:grain_warehouse_erp_lite/core/suppliers/supplier_repository.dart';

class SupplierController extends ChangeNotifier {
  SupplierController({required SupplierRepository repository})
      : _repository = repository;

  final SupplierRepository _repository;

  List<Supplier> _suppliers = const [];
  String? _errorMessage;
  bool _isLoading = false;

  List<Supplier> get suppliers => List<Supplier>.unmodifiable(_suppliers);
  String? get errorMessage => _errorMessage;
  bool get isLoading => _isLoading;

  Future<void> loadSuppliers(AppUser user) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    _suppliers = await _repository.listSuppliers(
      includeInactive: user.permissions.canManageSuppliers,
    );

    _isLoading = false;
    notifyListeners();
  }

  Future<bool> createSupplier({
    required AppUser user,
    required SupplierDraft draft,
  }) async {
    if (!_canManageSuppliers(user)) {
      return false;
    }

    try {
      await _repository.createSupplier(draft);
      await loadSuppliers(user);
      return true;
    } catch (error) {
      _errorMessage = _messageForError(error);
      notifyListeners();
      return false;
    }
  }

  Future<bool> updateSupplier({
    required AppUser user,
    required String supplierId,
    required SupplierDraft draft,
  }) async {
    if (!_canManageSuppliers(user)) {
      return false;
    }

    try {
      await _repository.updateSupplier(supplierId: supplierId, draft: draft);
      await loadSuppliers(user);
      return true;
    } catch (error) {
      _errorMessage = _messageForError(error);
      notifyListeners();
      return false;
    }
  }

  Future<bool> setSupplierActive({
    required AppUser user,
    required String supplierId,
    required bool isActive,
  }) async {
    if (!_canManageSuppliers(user)) {
      return false;
    }

    try {
      await _repository.setSupplierActive(
        supplierId: supplierId,
        isActive: isActive,
      );
      await loadSuppliers(user);
      return true;
    } catch (error) {
      _errorMessage = _messageForError(error);
      notifyListeners();
      return false;
    }
  }

  bool _canManageSuppliers(AppUser user) {
    if (!user.canProceed) {
      _errorMessage = 'يجب تسجيل الدخول بمستخدم صالح.';
      notifyListeners();
      return false;
    }
    if (user.permissions.canManageSuppliers) {
      return true;
    }

    _errorMessage = 'لا يملك هذا المستخدم صلاحية إدارة الموردين.';
    notifyListeners();
    return false;
  }

  String _messageForError(Object error) {
    if (error is ArgumentError) {
      return 'تحقق من بيانات المورد.';
    }
    if (error is StateError) {
      return 'لا يمكن حفظ المورد بهذه البيانات.';
    }

    return 'تعذر حفظ بيانات المورد.';
  }
}
