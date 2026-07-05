import 'package:flutter/foundation.dart';
import 'package:grain_warehouse_erp_lite/core/auth/app_user.dart';
import 'package:grain_warehouse_erp_lite/core/reports/daily_activity_report.dart';
import 'package:grain_warehouse_erp_lite/core/reports/report_repository.dart';

class ReportController extends ChangeNotifier {
  ReportController({required ReportRepository repository})
      : _repository = repository;

  final ReportRepository _repository;

  DailyActivityReport? _report;
  DateTime _selectedDate = DateTime.now();
  String? _errorMessage;
  bool _isLoading = false;

  DailyActivityReport? get report => _report;
  DateTime get selectedDate => _selectedDate;
  String? get errorMessage => _errorMessage;
  bool get isLoading => _isLoading;

  Future<bool> loadDailyActivity({
    required AppUser user,
    DateTime? selectedDate,
  }) async {
    if (!_canViewReports(user)) {
      return false;
    }

    _isLoading = true;
    _errorMessage = null;
    if (selectedDate != null) {
      _selectedDate = selectedDate;
    }
    notifyListeners();

    try {
      _report = await _repository.dailyActivityReport(
        selectedDate: _selectedDate,
      );
      _isLoading = false;
      notifyListeners();
      return true;
    } catch (error) {
      _isLoading = false;
      _errorMessage = 'تعذر تحميل التقرير.';
      notifyListeners();
      return false;
    }
  }

  bool _canViewReports(AppUser user) {
    if (!user.canProceed) {
      _errorMessage = 'يجب تسجيل الدخول بمستخدم صالح.';
      notifyListeners();
      return false;
    }
    if (user.permissions.canViewReports) {
      return true;
    }

    _errorMessage = 'لا يملك هذا المستخدم صلاحية عرض التقارير.';
    notifyListeners();
    return false;
  }
}
