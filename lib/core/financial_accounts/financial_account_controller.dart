import 'package:flutter/foundation.dart';
import 'package:grain_warehouse_erp_lite/core/auth/app_user.dart';
import 'package:grain_warehouse_erp_lite/core/auth/user_role.dart';
import 'package:grain_warehouse_erp_lite/core/financial_accounts/financial_account.dart';
import 'package:grain_warehouse_erp_lite/core/financial_accounts/financial_account_entry.dart';
import 'package:grain_warehouse_erp_lite/core/financial_accounts/financial_account_repository.dart';
import 'package:grain_warehouse_erp_lite/core/financial_accounts/financial_transfer.dart';

class FinancialAccountController extends ChangeNotifier {
  FinancialAccountController({required FinancialAccountRepository repository})
      : _repository = repository;

  final FinancialAccountRepository _repository;
  List<FinancialAccountBalanceSummary> _balances = const [];
  FinancialAccountStatement? _statement;
  String? _errorMessage;
  bool _isLoading = false;

  List<FinancialAccountBalanceSummary> get balances =>
      List<FinancialAccountBalanceSummary>.unmodifiable(_balances);
  FinancialAccountStatement? get statement => _statement;
  String? get errorMessage => _errorMessage;
  bool get isLoading => _isLoading;

  Future<void> loadAccounts(AppUser user) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();
    _balances = await _repository.allAccountBalances(includeInactive: true);
    _isLoading = false;
    notifyListeners();
  }

  Future<void> loadStatement(
    AppUser user,
    String accountId, {
    DateTime? fromDate,
    DateTime? toDate,
  }) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();
    try {
      _statement = await _repository.statementForAccount(
        accountId,
        fromDate: fromDate,
        toDate: toDate,
      );
    } catch (error) {
      _errorMessage = 'تعذر تحميل كشف الحساب.';
    }
    _isLoading = false;
    notifyListeners();
  }

  Future<bool> createAccount({
    required AppUser user,
    required FinancialAccountDraft draft,
  }) async {
    if (!_canManage(user)) return false;
    try {
      await _repository.createAccount(draft);
      await loadAccounts(user);
      return true;
    } catch (error) {
      _errorMessage = _messageForError(error);
      notifyListeners();
      return false;
    }
  }

  Future<bool> deactivateAccount({
    required AppUser user,
    required String accountId,
  }) async {
    if (!_canManage(user)) return false;
    try {
      await _repository.deactivateAccount(accountId, user.id);
      await loadAccounts(user);
      return true;
    } catch (error) {
      _errorMessage = _messageForError(error);
      notifyListeners();
      return false;
    }
  }

  Future<bool> reactivateAccount({
    required AppUser user,
    required String accountId,
  }) async {
    if (!_canManage(user)) return false;
    try {
      await _repository.reactivateAccount(accountId, user.id);
      await loadAccounts(user);
      return true;
    } catch (error) {
      _errorMessage = _messageForError(error);
      notifyListeners();
      return false;
    }
  }

  Future<FinancialTransfer?> createTransfer({
    required AppUser user,
    required FinancialTransferDraft draft,
  }) async {
    if (!_canManage(user)) return null;
    try {
      final transfer =
          await _repository.createTransfer(user: user, draft: draft);
      await loadAccounts(user);
      return transfer;
    } catch (error) {
      _errorMessage = _messageForError(error);
      notifyListeners();
      return null;
    }
  }

  Future<FinancialTransfer?> reverseTransfer({
    required AppUser user,
    required String transferId,
    required String reason,
  }) async {
    if (!_canManage(user)) return null;
    try {
      final transfer = await _repository.reverseTransfer(
        user: user,
        transferId: transferId,
        reason: reason,
      );
      await loadAccounts(user);
      return transfer;
    } catch (error) {
      _errorMessage = _messageForError(error);
      notifyListeners();
      return null;
    }
  }

  Future<bool> updateNegativeBalancePolicy({
    required AppUser user,
    required String accountId,
    required bool allowNegativeBalance,
  }) async {
    if (!_canManage(user)) return false;
    try {
      await _repository.updateAccountPolicy(
        accountId: accountId,
        allowNegativeBalance: allowNegativeBalance,
        updatedByUserId: user.id,
      );
      await loadAccounts(user);
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
    if (user.role != UserRole.owner) {
      _errorMessage = 'إدارة الحسابات المالية متاحة للمالك فقط.';
      notifyListeners();
      return false;
    }
    return true;
  }

  String _messageForError(Object error) {
    if (error is StateError) {
      return error.message;
    }
    if (error is ArgumentError) {
      return 'تحقق من البيانات المدخلة.';
    }
    return 'حدث خطأ غير متوقع.';
  }
}
