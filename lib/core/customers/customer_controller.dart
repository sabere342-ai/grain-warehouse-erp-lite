import 'package:flutter/foundation.dart';
import 'package:grain_warehouse_erp_lite/core/auth/app_user.dart';
import 'package:grain_warehouse_erp_lite/core/auth/user_role.dart';
import 'package:grain_warehouse_erp_lite/core/customer_accounts/customer_account_entry.dart';
import 'package:grain_warehouse_erp_lite/core/customer_accounts/customer_account_repository.dart';
import 'package:grain_warehouse_erp_lite/core/customer_accounts/customer_advance.dart';
import 'package:grain_warehouse_erp_lite/core/customer_accounts/customer_collection.dart';
import 'package:grain_warehouse_erp_lite/core/customers/customer.dart';
import 'package:grain_warehouse_erp_lite/core/customers/customer_repository.dart';
import 'package:grain_warehouse_erp_lite/core/financial_accounts/financial_account_entry.dart';

class CustomerController extends ChangeNotifier {
  CustomerController({
    required CustomerRepository repository,
    CustomerAccountRepository? accountRepository,
  })  : _repository = repository,
        _accountRepository = accountRepository;

  final CustomerRepository _repository;
  final CustomerAccountRepository? _accountRepository;
  List<Customer> _customers = const [];
  Map<String, int> _balancesByCustomerId = const {};
  Set<String> _customersWithOpeningBalance = const {};
  String? _errorMessage;
  bool _isLoading = false;

  List<Customer> get customers => List<Customer>.unmodifiable(_customers);
  Map<String, int> get balancesByCustomerId =>
      Map<String, int>.unmodifiable(_balancesByCustomerId);
  String? get errorMessage => _errorMessage;
  bool get isLoading => _isLoading;
  Set<String> get customersWithOpeningBalance =>
      Set<String>.unmodifiable(_customersWithOpeningBalance);

  int balanceForCustomer(String customerId) {
    return _balancesByCustomerId[customerId] ?? 0;
  }

  bool hasOpeningBalanceForCustomer(String customerId) =>
      _customersWithOpeningBalance.contains(customerId);

  Future<void> loadCustomers(AppUser user) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();
    _customers = await _repository.listCustomers(
      includeInactive: user.permissions.canAccessSettings,
    );
    _balancesByCustomerId =
        await _accountRepository?.balancesByCustomerId() ?? const {};
    _customersWithOpeningBalance = await _loadCustomersWithOpeningBalance();
    _isLoading = false;
    notifyListeners();
  }

  Future<CustomerStatement> statementForCustomer(String customerId) async {
    final repository = _accountRepository;
    if (repository == null) {
      return CustomerStatement(
        customerId: customerId,
        lines: const [],
        finalBalanceQirsh: 0,
      );
    }
    return repository.statementForCustomer(customerId);
  }

  Future<List<CustomerAdvanceSummary>> advancesForCustomer(
    String customerId,
  ) async {
    final repository = _accountRepository;
    if (repository == null) {
      throw StateError('سجل سلف العملاء غير متاح.');
    }
    final advances = await repository.listAdvances();
    final applications = await repository.listAdvanceApplications();
    final refunds = await repository.listAdvanceRefunds();
    final customerAdvances = advances
        .where((advance) => advance.customerId == customerId)
        .toList(growable: false)
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
    final result = <CustomerAdvanceSummary>[];
    for (final advance in customerAdvances) {
      final appliedQirsh = applications
          .where(
            (application) =>
                application.advanceId == advance.id && !application.isReversed,
          )
          .fold<int>(0, (total, value) => total + value.amountQirsh);
      final refundedQirsh = refunds
          .where(
            (refund) => refund.advanceId == advance.id && !refund.isReversed,
          )
          .fold<int>(0, (total, value) => total + value.amountQirsh);
      result.add(
        CustomerAdvanceSummary(
          advance: advance,
          appliedQirsh: appliedQirsh,
          refundedQirsh: refundedQirsh,
          remainingQirsh: await repository.remainingAdvanceQirsh(advance.id),
          refunds: refunds
              .where((value) => value.advanceId == advance.id)
              .toList(growable: false),
        ),
      );
    }
    return List<CustomerAdvanceSummary>.unmodifiable(result);
  }

  Future<CustomerAdvanceActionResult> reverseCustomerAdvanceRefund({
    required AppUser user,
    required CustomerAdvanceRefund refund,
    required String reason,
    required String operationRequestId,
  }) async {
    if (!user.canProceed || user.role != UserRole.owner) {
      return const CustomerAdvanceActionResult.failure(
        'هذه العملية متاحة للمالك فقط.',
      );
    }
    final repository = _accountRepository;
    if (repository == null) {
      return const CustomerAdvanceActionResult.failure(
          'سجل سلف العملاء غير متاح.');
    }
    try {
      await repository.reverseAdvanceRefund(
        user: user,
        refundId: refund.id,
        reason: reason,
        operationRequestId: operationRequestId,
      );
      await loadCustomers(user);
      return const CustomerAdvanceActionResult.success();
    } on Object catch (error) {
      return CustomerAdvanceActionResult.failure(
        error is StateError ? error.message : 'تعذر عكس استرداد سلفة العميل.',
      );
    }
  }

  Future<CustomerAdvanceActionResult> applyCustomerAdvance({
    required AppUser user,
    required CustomerAdvance advance,
    required int amountQirsh,
    required DateTime date,
    required String operationRequestId,
  }) async {
    if (!_canManage(user)) {
      return CustomerAdvanceActionResult.failure(
        _errorMessage ?? 'لا يملك هذا المستخدم صلاحية تنفيذ العملية.',
      );
    }
    final repository = _accountRepository;
    if (repository == null) {
      return const CustomerAdvanceActionResult.failure(
        'سجل سلف العملاء غير متاح.',
      );
    }
    try {
      await repository.applyAdvance(
        CustomerAdvanceApplicationDraft(
          advanceId: advance.id,
          customerId: advance.customerId,
          amountQirsh: amountQirsh,
          date: date,
          createdByUserId: user.id,
          operationRequestId: operationRequestId,
        ),
      );
      await loadCustomers(user);
      return const CustomerAdvanceActionResult.success();
    } catch (error) {
      final message = _advanceApplicationMessageForError(error);
      _errorMessage = message;
      notifyListeners();
      return CustomerAdvanceActionResult.failure(message);
    }
  }

  Future<CustomerAdvanceActionResult> refundCustomerAdvance({
    required AppUser user,
    required CustomerAdvance advance,
    required int amountQirsh,
    required DateTime date,
    required String operationRequestId,
    required String financialAccountId,
    PaymentMethod? paymentMethod,
    String? negativeBalanceApprovalId,
  }) async {
    if (!_canManage(user)) {
      return CustomerAdvanceActionResult.failure(
        _errorMessage ?? 'لا يملك هذا المستخدم صلاحية تنفيذ العملية.',
      );
    }
    final repository = _accountRepository;
    if (repository == null) {
      return const CustomerAdvanceActionResult.failure(
        'سجل سلف العملاء غير متاح.',
      );
    }
    try {
      await repository.refundAdvance(
        CustomerAdvanceRefundDraft(
          advanceId: advance.id,
          amountQirsh: amountQirsh,
          date: date,
          createdByUserId: user.id,
          operationRequestId: operationRequestId,
          financialAccountId: financialAccountId,
          paymentMethod: paymentMethod,
          negativeBalanceApprovalId: negativeBalanceApprovalId,
        ),
      );
      await loadCustomers(user);
      return const CustomerAdvanceActionResult.success();
    } catch (error) {
      if (error is StateError &&
          error.message.contains('يتطلب موافقة المالك على الرصيد السالب')) {
        return const CustomerAdvanceActionResult.approvalRequired();
      }
      final message = _advanceRefundMessageForError(error);
      _errorMessage = message;
      notifyListeners();
      return CustomerAdvanceActionResult.failure(message);
    }
  }

  Future<bool> recordCollection({
    required AppUser user,
    required String customerId,
    required DateTime date,
    required int amountQirsh,
    String? notes,
    String? financialAccountId,
    PaymentMethod? paymentMethod,
    String? operationRequestId,
    String? overpaymentApprovalId,
  }) async {
    if (!_canManage(user)) {
      return false;
    }
    final repository = _accountRepository;
    if (repository == null) {
      _errorMessage = 'تعذر تسجيل التحصيل لأن سجل العملاء غير متاح.';
      notifyListeners();
      return false;
    }
    try {
      await repository.createCollection(
        CustomerCollectionDraft(
          customerId: customerId,
          date: date,
          amountQirsh: amountQirsh,
          createdByUserId: user.id,
          createdByUserName: user.name,
          notes: notes,
          financialAccountId: financialAccountId,
          paymentMethod: paymentMethod,
          operationRequestId: operationRequestId,
          overpaymentApprovalId: overpaymentApprovalId,
        ),
      );
      await loadCustomers(user);
      return true;
    } catch (error) {
      _errorMessage = _collectionMessageForError(error);
      notifyListeners();
      return false;
    }
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

  Future<bool> recordOpeningBalance({
    required AppUser user,
    required String customerId,
    required int amountQirsh,
  }) async {
    if (!_canManage(user)) {
      return false;
    }
    final repository = _accountRepository;
    if (repository == null) {
      _errorMessage = 'تعذر تسجيل الرصيد الافتتاحي لأن سجل العملاء غير متاح.';
      notifyListeners();
      return false;
    }
    try {
      await repository.createOpeningBalanceEntry(
        customerId: customerId,
        amountQirsh: amountQirsh,
        createdByUserId: user.id,
      );
      await loadCustomers(user);
      return true;
    } catch (error) {
      _errorMessage = _openingBalanceMessageForError(error);
      notifyListeners();
      return false;
    }
  }

  Future<Set<String>> _loadCustomersWithOpeningBalance() async {
    final repository = _accountRepository;
    if (repository == null) return const {};
    final customers = _customers;
    final result = <String>{};
    for (final customer in customers) {
      if (await repository.hasOpeningBalanceEntry(customer.id)) {
        result.add(customer.id);
      }
    }
    return result;
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

  String _collectionMessageForError(Object error) {
    if (error is ArgumentError) {
      return 'اكتب مبلغ التحصيل بشكل صحيح ويجب أن يكون أكبر من صفر.';
    }
    if (error is StateError) {
      final msg = error.message;
      if (msg.contains('balance changed')) {
        return 'تغيّر رصيد العميل أثناء التحصيل. أعد المحاولة.';
      }
      if (msg.contains('overpayment requires') || msg.contains('approval')) {
        return 'يجب اختيار حساب مالي وموافقة المالك لتسجيل السلفة.';
      }
      return 'لا يمكن تسجيل هذا التحصيل بالبيانات المدخلة.';
    }
    return 'تعذر تسجيل التحصيل.';
  }

  String _openingBalanceMessageForError(Object error) {
    if (error is ArgumentError) {
      return 'اكتب مبلغ الرصيد الافتتاحي بشكل صحيح ويجب أن يكون أكبر من صفر.';
    }
    if (error is StateError) {
      if (error.message.contains('already exists')) {
        return 'الرصيد الافتتاحي موجود مسبقا لهذا العميل.';
      }
      if (error.message.contains('has transactions')) {
        return 'لا يمكن إضافة رصيد افتتاحي بعد وجود مشتريات أو تحصيلات للعميل.';
      }
      return 'لا يمكن تسجيل الرصيد الافتتاحي بهذه البيانات.';
    }
    return 'تعذر تسجيل الرصيد الافتتاحي.';
  }

  String _advanceApplicationMessageForError(Object error) {
    if (error is ArgumentError) {
      return 'المبلغ غير صالح ويجب أن يكون أكبر من صفر.';
    }
    if (error is StateError) {
      final message = error.message;
      if (message.contains('exceeds')) {
        return 'المبلغ يتجاوز الرصيد المتاح أو ذمة العميل الحالية.';
      }
      if (message.contains('does not belong') ||
          message.contains('not found')) {
        return 'السلفة غير متاحة لهذا العميل.';
      }
      if (message.contains('payload mismatch')) {
        return 'تغيّرت بيانات المحاولة. أغلق النافذة وابدأ محاولة جديدة.';
      }
    }
    return 'تعذر تطبيق السلفة. راجع البيانات وحاول مرة أخرى.';
  }

  String _advanceRefundMessageForError(Object error) {
    if (error is ArgumentError) {
      return 'المبلغ غير صالح ويجب أن يكون أكبر من صفر.';
    }
    if (error is StateError) {
      final message = error.message;
      if (message.contains('exceeds')) {
        return 'المبلغ يتجاوز الرصيد المتاح من السلفة.';
      }
      if (message.contains('original financial account')) {
        return 'يجب رد السلفة من الحساب المالي الأصلي.';
      }
      if (message.contains('الموافقة') || message.contains('تفويض')) {
        return 'تعذر اعتماد رد السلفة. اطلب اعتمادًا جديدًا وحاول مرة أخرى.';
      }
      if (message.contains('payload mismatch')) {
        return 'تغيّرت بيانات المحاولة. أغلق النافذة وابدأ محاولة جديدة.';
      }
    }
    return 'تعذر رد السلفة. راجع البيانات وحاول مرة أخرى.';
  }
}

class CustomerAdvanceSummary {
  const CustomerAdvanceSummary({
    required this.advance,
    required this.appliedQirsh,
    required this.refundedQirsh,
    required this.remainingQirsh,
    this.refunds = const [],
  });

  final CustomerAdvance advance;
  final int appliedQirsh;
  final int refundedQirsh;
  final int remainingQirsh;
  final List<CustomerAdvanceRefund> refunds;

  bool get canAct => !advance.isReversed && remainingQirsh > 0;

  String get statusLabelAr {
    if (advance.isReversed) return 'معكوسة';
    if (remainingQirsh == 0 && refundedQirsh == advance.amountQirsh) {
      return 'مردودة';
    }
    if (remainingQirsh == 0) return 'مستهلكة';
    if (remainingQirsh < advance.amountQirsh) return 'مستخدمة جزئيًا';
    return 'متاحة';
  }
}

enum CustomerAdvanceActionStatus { success, approvalRequired, failure }

class CustomerAdvanceActionResult {
  const CustomerAdvanceActionResult._(this.status, this.message);

  const CustomerAdvanceActionResult.success()
      : this._(CustomerAdvanceActionStatus.success, null);

  const CustomerAdvanceActionResult.approvalRequired()
      : this._(CustomerAdvanceActionStatus.approvalRequired, null);

  const CustomerAdvanceActionResult.failure(String message)
      : this._(CustomerAdvanceActionStatus.failure, message);

  final CustomerAdvanceActionStatus status;
  final String? message;

  bool get isSuccess => status == CustomerAdvanceActionStatus.success;
  bool get requiresApproval =>
      status == CustomerAdvanceActionStatus.approvalRequired;
}
