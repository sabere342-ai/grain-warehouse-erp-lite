import 'package:flutter/foundation.dart';
import 'package:grain_warehouse_erp_lite/application/queries/application_query.dart';
import 'package:grain_warehouse_erp_lite/application/queries/load_audit_logs_query.dart';
import 'package:grain_warehouse_erp_lite/core/auth/app_user.dart';
import 'package:grain_warehouse_erp_lite/core/audit/audit_log_read_repository.dart';

class AuditLogController extends ChangeNotifier {
  AuditLogController({
    AuditLogReadRepository? repository,
    LoadAuditLogsQueryHandler? queryHandler,
  })  : assert(
          repository != null || queryHandler != null,
          'A repository or query handler is required.',
        ),
        _queryHandler =
            queryHandler ?? LoadAuditLogsQueryHandler(repository: repository!);

  final LoadAuditLogsQueryHandler _queryHandler;
  List<AuditLogReadModel> _entries = const [];
  QueryResultMetadata? _resultMetadata;
  String? _errorMessage;
  bool _isLoading = false;
  bool _isDisposed = false;

  List<AuditLogReadModel> get entries =>
      List<AuditLogReadModel>.unmodifiable(_entries);
  QueryResultMetadata? get resultMetadata => _resultMetadata;
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
      final result = await _queryHandler.execute(const LoadAuditLogsQuery());
      _entries = result.value;
      _resultMetadata = result.metadata;
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
