import 'package:flutter/foundation.dart';
import 'package:grain_warehouse_erp_lite/core/auth/app_user.dart';
import 'package:grain_warehouse_erp_lite/core/customer_accounts/customer_account_entry.dart';
import 'package:grain_warehouse_erp_lite/core/customer_accounts/customer_account_repository.dart';
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
      if (msg.contains('overpayment requires') ||
          msg.contains('approval')) {
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
}
