import 'package:flutter/foundation.dart';
import 'package:grain_warehouse_erp_lite/core/auth/app_user.dart';
import 'package:grain_warehouse_erp_lite/core/expenses/expense.dart';
import 'package:grain_warehouse_erp_lite/core/expenses/expense_repository.dart';

class ExpenseController extends ChangeNotifier {
  ExpenseController({required ExpenseRepository repository})
      : _repository = repository;

  final ExpenseRepository _repository;
  List<ExpenseRecord> _expenses = const [];
  String? _errorMessage;
  bool _isLoading = false;

  List<ExpenseRecord> get expenses =>
      List<ExpenseRecord>.unmodifiable(_expenses);
  String? get errorMessage => _errorMessage;
  bool get isLoading => _isLoading;

  Future<void> loadExpenses(AppUser user) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();
    _expenses = await _repository.listExpenses();
    _isLoading = false;
    notifyListeners();
  }

  Future<void> refreshAfterConfirmedProjection(AppUser user) =>
      loadExpenses(user);

  Future<bool> createExpense({
    required AppUser user,
    required ExpenseDraft draft,
  }) async {
    if (!_canCreate(user)) {
      return false;
    }
    try {
      await _repository.createExpense(draft);
      await loadExpenses(user);
      return true;
    } catch (error) {
      _errorMessage = _messageForError(error);
      notifyListeners();
      return false;
    }
  }

  Future<bool> reclassifyExpense({
    required AppUser user,
    required String expenseId,
    required ExpenseAccountingClassification classification,
    required String reason,
  }) async {
    try {
      await _repository.reclassifyExpense(
        user: user,
        expenseId: expenseId,
        classification: classification,
        reason: reason,
      );
      await loadExpenses(user);
      return true;
    } catch (error) {
      _errorMessage = _messageForError(error);
      notifyListeners();
      return false;
    }
  }

  bool _canCreate(AppUser user) {
    if (!user.canProceed) {
      _errorMessage = 'يجب تسجيل الدخول بمستخدم صالح.';
      notifyListeners();
      return false;
    }
    if (user.permissions.canCreateExpense) {
      return true;
    }
    _errorMessage = 'لا يملك هذا المستخدم صلاحية تسجيل المصروفات.';
    notifyListeners();
    return false;
  }

  String _messageForError(Object error) {
    if (error is ArgumentError || error is FormatException) {
      return 'تحقق من اسم المصروف والمبلغ.';
    }
    return 'تعذر حفظ المصروف.';
  }
}
