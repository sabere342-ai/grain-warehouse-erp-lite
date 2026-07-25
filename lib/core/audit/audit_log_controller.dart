import 'package:flutter/foundation.dart';
import 'package:grain_warehouse_erp_lite/core/auth/app_user.dart';
import 'package:grain_warehouse_erp_lite/core/audit/audit_log_repository.dart';

class AuditLogController extends ChangeNotifier {
  AuditLogController({required AuditLogRepository repository})
      : _repository = repository;

  final AuditLogRepository _repository;
  List<AuditLogEntry> _entries = const [];
  String? _errorMessage;
  bool _isLoading = false;

  List<AuditLogEntry> get entries => List<AuditLogEntry>.unmodifiable(_entries);
  String? get errorMessage => _errorMessage;
  bool get isLoading => _isLoading;

  Future<bool> loadLogs(AppUser user) async {
    if (!user.canProceed || !user.permissions.canViewAuditLogs) {
      _errorMessage = 'سجل التدقيق متاح للمالك فقط.';
      notifyListeners();
      return false;
    }
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();
    _entries = await _repository.listLogs();
    _isLoading = false;
    notifyListeners();
    return true;
  }
}
