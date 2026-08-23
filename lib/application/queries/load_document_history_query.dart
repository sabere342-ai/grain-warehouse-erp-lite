import 'package:grain_warehouse_erp_lite/application/queries/application_query.dart';
import 'package:grain_warehouse_erp_lite/core/documents/document_history.dart';

final class LoadDocumentHistoryQuery {
  const LoadDocumentHistoryQuery({required this.filter});

  final DocumentHistoryFilter filter;
}

final class LoadDocumentHistoryQueryHandler
    implements
        ApplicationQueryHandler<LoadDocumentHistoryQuery,
            List<DocumentHistoryEntry>> {
  const LoadDocumentHistoryQueryHandler({
    required DocumentHistoryRepository repository,
  }) : _repository = repository;

  final DocumentHistoryRepository _repository;

  @override
  Future<ApplicationQueryResult<List<DocumentHistoryEntry>>> execute(
    LoadDocumentHistoryQuery query,
  ) async {
    final entries = await _repository.listHistory(filter: query.filter);
    return ApplicationQueryResult(
      value: entries,
      metadata: const LocalQueryResultMetadata(),
    );
  }
}
