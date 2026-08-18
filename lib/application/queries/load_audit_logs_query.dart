import 'package:grain_warehouse_erp_lite/application/queries/application_query.dart';
import 'package:grain_warehouse_erp_lite/core/audit/audit_log_read_repository.dart';

final class LoadAuditLogsQuery {
  const LoadAuditLogsQuery();
}

final class LoadAuditLogsQueryHandler
    implements
        ApplicationQueryHandler<LoadAuditLogsQuery, List<AuditLogReadModel>> {
  const LoadAuditLogsQueryHandler({
    required AuditLogReadRepository repository,
  }) : _repository = repository;

  final AuditLogReadRepository _repository;

  @override
  Future<ApplicationQueryResult<List<AuditLogReadModel>>> execute(
    LoadAuditLogsQuery query,
  ) async {
    final entries = await _repository.listAuditLogs();
    return ApplicationQueryResult(
      value: entries,
      metadata: const LocalQueryResultMetadata(),
    );
  }
}
