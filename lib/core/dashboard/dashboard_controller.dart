import 'package:flutter/foundation.dart';
import 'package:grain_warehouse_erp_lite/core/dashboard/dashboard_service.dart';

class DashboardController extends ChangeNotifier {
  DashboardController({
    DashboardService? service,
    Future<DashboardData> Function()? loadData,
  })  : assert(service != null || loadData != null),
        _loadData = loadData ?? service!.load;

  final Future<DashboardData> Function() _loadData;

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
      _data = await _loadData();
      _isLoading = false;
      notifyListeners();
    } catch (error) {
      _isLoading = false;
      _errorMessage = 'تعذر تحميل بيانات لوحة المتابعة.';
      notifyListeners();
    }
  }
}
