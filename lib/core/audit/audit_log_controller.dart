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
  bool _isDisposed = false;

  List<AuditLogReadModel> get entries =>
      List<AuditLogReadModel>.unmodifiable(_entries);
  String? get errorMessage => _errorMessage;
  bool get isLoading => _isLoading;

  Future<bool> loadLogs(AppUser user) async {
    if (!user.canProceed || !user.permissions.canViewAuditLogs) {
      _isLoading = false;
      _errorMessage = 'سجل التدقيق متاح للمالك فقط.';
      _notifyListenersIfActive();
      return false;
    }

    _isLoading = true;
    _errorMessage = null;
    _notifyListenersIfActive();

    try {
      _entries = await _repository.listAuditLogs();
      return true;
    } catch (_) {
      _errorMessage = 'تعذر تحميل سجل التدقيق. حاول مرة أخرى.';
      return false;
    } finally {
      _isLoading = false;
      _notifyListenersIfActive();
    }
  }

  @override
  void dispose() {
    _isDisposed = true;
    super.dispose();
  }

  void _notifyListenersIfActive() {
    if (!_isDisposed) notifyListeners();
  }
}
