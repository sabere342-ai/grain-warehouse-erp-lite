enum AiResponseStatus { success, validationFailure, failure, unknownTool }

final class AiValidationError {
  const AiValidationError({required this.field, required this.message});

  final String field;
  final String message;
}

final class AiResponseTable {
  const AiResponseTable({required this.columns, required this.rows});

  final List<String> columns;
  final List<List<Object?>> rows;
}

final class AiResponseAction {
  const AiResponseAction({required this.id, required this.label});

  final String id;
  final String label;
}

final class AiToolResult {
  const AiToolResult({
    this.messages = const [],
    this.tables = const [],
    this.actions = const [],
    this.data,
  });

  final List<String> messages;
  final List<AiResponseTable> tables;
  final List<AiResponseAction> actions;
  final Object? data;
}

final class AiExecutionResponse {
  const AiExecutionResponse({
    required this.status,
    required this.messages,
    this.validationErrors = const [],
    this.tables = const [],
    this.actions = const [],
    this.data,
  });

  final AiResponseStatus status;
  final List<String> messages;
  final List<AiValidationError> validationErrors;
  final List<AiResponseTable> tables;
  final List<AiResponseAction> actions;
  final Object? data;

  bool get isSuccess => status == AiResponseStatus.success;
}
