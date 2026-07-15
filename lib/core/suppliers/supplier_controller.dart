import 'package:flutter/foundation.dart';
import 'package:grain_warehouse_erp_lite/core/auth/app_user.dart';
import 'package:grain_warehouse_erp_lite/core/financial_accounts/financial_account_entry.dart';
import 'package:grain_warehouse_erp_lite/core/supplier_accounts/supplier_account_repository.dart';
import 'package:grain_warehouse_erp_lite/core/supplier_accounts/supplier_payment.dart';
import 'package:grain_warehouse_erp_lite/core/suppliers/supplier.dart';
import 'package:grain_warehouse_erp_lite/core/suppliers/supplier_repository.dart';

class SupplierController extends ChangeNotifier {
  SupplierController({
    required SupplierRepository repository,
    SupplierAccountRepository? accountRepository,
  })  : _repository = repository,
        _accountRepository = accountRepository;

  final SupplierRepository _repository;
  final SupplierAccountRepository? _accountRepository;

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

  Future<bool> recordPayment({
    required AppUser user,
    required String supplierId,
    required DateTime date,
    required int amountQirsh,
    String? notes,
    String? financialAccountId,
    PaymentMethod? paymentMethod,
    String? operationRequestId,
    String? overpaymentApprovalId,
    String? negativeBalanceApprovalId,
  }) async {
    if (!_canManageSuppliers(user)) {
      return false;
    }
    final repository = _accountRepository;
    if (repository == null) {
      _errorMessage = 'تعذر تسجيل الدفعة لأن سجل الموردين غير متاح.';
      notifyListeners();
      return false;
    }
    try {
      await repository.createPayment(
        SupplierPaymentDraft(
          supplierId: supplierId,
          date: date,
          amountQirsh: amountQirsh,
          createdByUserId: user.id,
          createdByUserName: user.name,
          notes: notes,
          financialAccountId: financialAccountId,
          paymentMethod: paymentMethod,
          operationRequestId: operationRequestId,
          overpaymentApprovalId: overpaymentApprovalId,
          negativeBalanceApprovalId: negativeBalanceApprovalId,
        ),
      );
      await loadSuppliers(user);
      return true;
    } catch (error) {
      _errorMessage = _paymentMessageForError(error);
      notifyListeners();
      return false;
    }
  }

  String _paymentMessageForError(Object error) {
    if (error is ArgumentError) {
      return 'اكتب مبلغ الدفع بشكل صحيح ويجب أن يكون أكبر من صفر.';
    }
    if (error is StateError) {
      final msg = error.message;
      if (msg.contains('balance changed')) {
        return 'تغيّر رصيد المورد أثناء الدفع. أعد المحاولة.';
      }
      if (msg.contains('overpayment requires') || msg.contains('approval') ||
          msg.contains('بيانات الموافقة')) {
        return 'الرصيد غير كافٍ. تحقق من رصيد الحساب المالي.';
      }
      if (msg.contains('الرصيد')) {
        return 'الرصيد غير كافٍ. تحقق من رصيد الحساب المالي.';
      }
      return 'لا يمكن تسجيل هذا الدفع بالبيانات المدخلة.';
    }
    return 'تعذر تسجيل الدفعة.';
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
