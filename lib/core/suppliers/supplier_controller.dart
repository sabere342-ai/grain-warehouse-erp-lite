import 'package:flutter/foundation.dart';
import 'package:grain_warehouse_erp_lite/core/auth/app_user.dart';
import 'package:grain_warehouse_erp_lite/core/auth/user_role.dart';
import 'package:grain_warehouse_erp_lite/core/financial_accounts/financial_account_entry.dart';
import 'package:grain_warehouse_erp_lite/core/supplier_accounts/supplier_account_repository.dart';
import 'package:grain_warehouse_erp_lite/core/supplier_accounts/supplier_advance.dart';
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

  Future<List<SupplierAdvanceSummary>> advancesForSupplier(
    String supplierId,
  ) async {
    final repository = _accountRepository;
    if (repository == null) {
      throw StateError('سجل سلف الموردين غير متاح.');
    }
    final advances = await repository.listAdvances();
    final applications = await repository.listAdvanceApplications();
    final refunds = await repository.listAdvanceRefunds();
    final supplierAdvances = advances
        .where((advance) => advance.supplierId == supplierId)
        .toList(growable: false)
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
    final result = <SupplierAdvanceSummary>[];
    for (final advance in supplierAdvances) {
      final appliedQirsh = applications
          .where((value) => value.advanceId == advance.id && !value.isReversed)
          .fold<int>(0, (total, value) => total + value.amountQirsh);
      final refundedQirsh = refunds
          .where((value) => value.advanceId == advance.id && !value.isReversed)
          .fold<int>(0, (total, value) => total + value.amountQirsh);
      result.add(SupplierAdvanceSummary(
        advance: advance,
        appliedQirsh: appliedQirsh,
        refundedQirsh: refundedQirsh,
        remainingQirsh: await repository.remainingAdvanceQirsh(advance.id),
        refunds: refunds
            .where((value) => value.advanceId == advance.id)
            .toList(growable: false),
      ));
    }
    return List<SupplierAdvanceSummary>.unmodifiable(result);
  }

  Future<SupplierAdvanceActionResult> reverseSupplierAdvanceRefund({
    required AppUser user,
    required SupplierAdvanceRefund refund,
    required String reason,
    required String operationRequestId,
    String? approvalId,
  }) async {
    if (!user.canProceed || user.role != UserRole.owner) {
      return const SupplierAdvanceActionResult.failure(
        'هذه العملية متاحة للمالك فقط.',
      );
    }
    final repository = _accountRepository;
    if (repository == null) {
      return const SupplierAdvanceActionResult.failure(
          'سجل سلف الموردين غير متاح.');
    }
    try {
      await repository.reverseAdvanceRefund(
        user: user,
        refundId: refund.id,
        reason: reason,
        operationRequestId: operationRequestId,
        overpaymentApprovalId: approvalId,
      );
      return const SupplierAdvanceActionResult.success();
    } on StateError catch (error) {
      if (error.message == 'SUPPLIER_REFUND_REVERSAL_APPROVAL_REQUIRED') {
        return const SupplierAdvanceActionResult.approvalRequired();
      }
      return SupplierAdvanceActionResult.failure(error.message);
    } on Object {
      return const SupplierAdvanceActionResult.failure(
        'تعذر عكس استرداد سلفة المورد.',
      );
    }
  }

  Future<SupplierAdvanceActionResult> applySupplierAdvance({
    required AppUser user,
    required SupplierAdvance advance,
    required int amountQirsh,
    required DateTime date,
    required String operationRequestId,
  }) async {
    if (!_canManageSuppliers(user)) {
      return SupplierAdvanceActionResult.failure(
        _errorMessage ?? 'لا يملك هذا المستخدم صلاحية تنفيذ العملية.',
      );
    }
    final repository = _accountRepository;
    if (repository == null) {
      return const SupplierAdvanceActionResult.failure(
        'سجل سلف الموردين غير متاح.',
      );
    }
    try {
      await repository.applyAdvance(SupplierAdvanceApplicationDraft(
        advanceId: advance.id,
        supplierId: advance.supplierId,
        amountQirsh: amountQirsh,
        date: date,
        createdByUserId: user.id,
        operationRequestId: operationRequestId,
      ));
      return const SupplierAdvanceActionResult.success();
    } catch (error) {
      return SupplierAdvanceActionResult.failure(
        _supplierAdvanceMessage(error, isApplication: true),
      );
    }
  }

  Future<SupplierAdvanceActionResult> refundSupplierAdvance({
    required AppUser user,
    required SupplierAdvance advance,
    required int amountQirsh,
    required DateTime date,
    required String operationRequestId,
    required String financialAccountId,
    PaymentMethod? paymentMethod,
  }) async {
    if (!_canManageSuppliers(user)) {
      return SupplierAdvanceActionResult.failure(
        _errorMessage ?? 'لا يملك هذا المستخدم صلاحية تنفيذ العملية.',
      );
    }
    final repository = _accountRepository;
    if (repository == null) {
      return const SupplierAdvanceActionResult.failure(
        'سجل سلف الموردين غير متاح.',
      );
    }
    try {
      await repository.refundAdvance(SupplierAdvanceRefundDraft(
        advanceId: advance.id,
        amountQirsh: amountQirsh,
        date: date,
        createdByUserId: user.id,
        operationRequestId: operationRequestId,
        financialAccountId: financialAccountId,
        paymentMethod: paymentMethod,
      ));
      return const SupplierAdvanceActionResult.success();
    } catch (error) {
      return SupplierAdvanceActionResult.failure(
        _supplierAdvanceMessage(error, isApplication: false),
      );
    }
  }

  String _supplierAdvanceMessage(Object error, {required bool isApplication}) {
    if (error is ArgumentError) {
      return 'المبلغ غير صالح ويجب أن يكون أكبر من صفر.';
    }
    if (error is StateError) {
      final message = error.message;
      if (message.contains('exceeds')) {
        return isApplication
            ? 'المبلغ يتجاوز الرصيد المتاح أو ذمة المورد الحالية.'
            : 'المبلغ يتجاوز الرصيد المتاح من السلفة.';
      }
      if (message.contains('original financial account')) {
        return 'يجب استرداد السلفة إلى الحساب المالي الأصلي.';
      }
      if (message.contains('payload mismatch')) {
        return 'تغيّرت بيانات المحاولة. أغلق النافذة وابدأ محاولة جديدة.';
      }
    }
    return isApplication
        ? 'تعذر تطبيق السلفة. راجع البيانات وحاول مرة أخرى.'
        : 'تعذر استرداد المبلغ. راجع البيانات وحاول مرة أخرى.';
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
      if (msg.contains('overpayment requires') ||
          msg.contains('approval') ||
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

class SupplierAdvanceSummary {
  const SupplierAdvanceSummary({
    required this.advance,
    required this.appliedQirsh,
    required this.refundedQirsh,
    required this.remainingQirsh,
    this.refunds = const [],
  });

  final SupplierAdvance advance;
  final int appliedQirsh;
  final int refundedQirsh;
  final int remainingQirsh;
  final List<SupplierAdvanceRefund> refunds;

  bool get canAct => !advance.isReversed && remainingQirsh > 0;

  String get statusLabelAr {
    if (advance.isReversed) return 'معكوسة';
    if (remainingQirsh == 0 && refundedQirsh == advance.amountQirsh) {
      return 'مستردة';
    }
    if (remainingQirsh == 0) return 'مستهلكة';
    if (remainingQirsh < advance.amountQirsh) return 'مستخدمة جزئيًا';
    return 'متاحة';
  }
}

class SupplierAdvanceActionResult {
  const SupplierAdvanceActionResult._(
      this.isSuccess, this.requiresApproval, this.message);
  const SupplierAdvanceActionResult.success() : this._(true, false, null);
  const SupplierAdvanceActionResult.approvalRequired()
      : this._(false, true, null);
  const SupplierAdvanceActionResult.failure(String message)
      : this._(false, false, message);

  final bool isSuccess;
  final bool requiresApproval;
  final String? message;
}
