import 'package:flutter/foundation.dart';
import 'package:grain_warehouse_erp_lite/application/queries/load_document_history_query.dart';
import 'package:grain_warehouse_erp_lite/core/auth/app_user.dart';
import 'package:grain_warehouse_erp_lite/core/documents/document_history.dart';

class DocumentHistoryController extends ChangeNotifier {
  DocumentHistoryController({
    DocumentHistoryRepository? repository,
    LoadDocumentHistoryQueryHandler? queryHandler,
  })  : assert(
          (repository == null) != (queryHandler == null),
          'Exactly one repository or query handler is required.',
        ),
        _queryHandler = queryHandler ??
            LoadDocumentHistoryQueryHandler(repository: repository!);

  final LoadDocumentHistoryQueryHandler _queryHandler;

  List<DocumentHistoryEntry> _entries = const [];
  DocumentHistoryFilter _filter = const DocumentHistoryFilter();
  bool _isLoading = false;
  bool _canViewOwnerAudit = false;

  List<DocumentHistoryEntry> get entries =>
      List<DocumentHistoryEntry>.unmodifiable(_entries);
  DocumentHistoryFilter get filter => _filter;
  bool get isLoading => _isLoading;
  bool get canViewOwnerAudit => _canViewOwnerAudit;

  Future<void> load(AppUser user) async {
    _isLoading = true;
    _canViewOwnerAudit =
        user.permissions.canViewAuditLogs || user.permissions.canCancelInvoice;
    notifyListeners();

    final result = await _queryHandler.execute(
      LoadDocumentHistoryQuery(filter: _filter),
    );
    _entries = result.value;
    _isLoading = false;
    notifyListeners();
  }

  Future<void> applyFilter({
    required AppUser user,
    required DocumentHistoryFilter filter,
  }) async {
    _filter = filter;
    await load(user);
  }
}
