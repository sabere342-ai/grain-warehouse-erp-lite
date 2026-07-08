import 'package:flutter/foundation.dart';
import 'package:grain_warehouse_erp_lite/core/dashboard/dashboard_service.dart';

class DashboardController extends ChangeNotifier {
  DashboardController({required DashboardService service})
      : _service = service;

  final DashboardService _service;

  DashboardData _data = DashboardData.empty();
  bool _isLoading = false;
  String? _errorMessage;

  DashboardData get data => _data;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;

  Future<void> load() async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      _data = await _service.load();
      _isLoading = false;
      notifyListeners();
    } catch (error) {
      _isLoading = false;
      _errorMessage = 'تعذر تحميل بيانات لوحة المتابعة.';
      notifyListeners();
    }
  }
}
