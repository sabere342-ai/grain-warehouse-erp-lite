import 'package:flutter/foundation.dart';
import 'package:grain_warehouse_erp_lite/core/auth/app_user.dart';
import 'package:grain_warehouse_erp_lite/core/audit/audit_log_read_repository.dart';

class AuditLogController extends ChangeNotifier {
  AuditLogController({required AuditLogReadRepository repository})
      : _repository = repository;

  final AuditLogReadRepository _repository;
  List<AuditLogReadModel> _entries = const [];
  String? _errorMessage;
  bool _isLoading = false;

  List<AuditLogReadModel> get entries =>
      List<AuditLogReadModel>.unmodifiable(_entries);
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
    _entries = await _repository.listAuditLogs();
    _isLoading = false;
    notifyListeners();
    return true;
  }
}
