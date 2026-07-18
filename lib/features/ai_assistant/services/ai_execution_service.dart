import '../contracts/ai_tool.dart';
import '../models/ai_execution_response.dart';
import '../models/ai_intent.dart';
import '../registry/ai_tool_registry.dart';

/// Resolves a structured intent to an allow-listed tool and executes it.
final class AiExecutionService {
  const AiExecutionService({required AiToolRegistry registry})
      : _registry = registry;

  final AiToolRegistry _registry;

  Future<AiExecutionResponse> execute(AiIntent intent) async {
    final tool = _registry.findById(intent.name);
    if (tool == null) {
      return AiExecutionResponse(
        status: AiResponseStatus.unknownTool,
        messages: ['No registered AI tool matches "${intent.name}".'],
      );
    }

    final missing = tool.parameters
        .where((parameter) =>
            parameter.required && !intent.parameters.containsKey(parameter.id))
        .map((parameter) => AiValidationError(
              field: parameter.id,
              message: '${parameter.id} is required.',
            ))
        .toList(growable: false);
    if (missing.isNotEmpty) {
      return AiExecutionResponse(
        status: AiResponseStatus.validationFailure,
        messages: const ['Tool parameters failed validation.'],
        validationErrors: missing,
      );
    }

    try {
      final result = await tool.execute(
        Map.unmodifiable(intent.parameters),
        executionMode: intent.executionMode,
      );
      return AiExecutionResponse(
        status: AiResponseStatus.success,
        messages: result.messages,
        tables: result.tables,
        actions: result.actions,
      );
    } on AiToolValidationException catch (error) {
      return AiExecutionResponse(
        status: AiResponseStatus.validationFailure,
        messages: [error.message],
        validationErrors: error.errors,
      );
    } catch (_) {
      return const AiExecutionResponse(
        status: AiResponseStatus.failure,
        messages: ['The requested operation could not be completed.'],
      );
    }
  }
}
