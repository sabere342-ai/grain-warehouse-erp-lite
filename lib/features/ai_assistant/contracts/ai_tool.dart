import '../models/ai_execution_response.dart';
import '../models/ai_intent.dart';
import '../models/ai_parameter.dart';

/// A controlled entry point into existing application business logic.
///
/// Implementations must delegate to controllers; they must never access a
/// repository or persistence API directly.
abstract interface class AiTool {
  String get id;
  String get name;
  String get description;
  List<AiToolParameter> get parameters;

  /// [executionMode] lets tools implement a controller-backed preview when the
  /// underlying business operation supports one.
  Future<AiToolResult> execute(
    Map<String, Object?> parameters, {
    required AiExecutionMode executionMode,
  });
}

/// A recoverable validation failure returned by a tool or its controller.
final class AiToolValidationException implements Exception {
  const AiToolValidationException({
    required this.message,
    this.errors = const [],
  });

  final String message;
  final List<AiValidationError> errors;
}
