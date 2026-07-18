import 'package:flutter_test/flutter_test.dart';
import 'package:grain_warehouse_erp_lite/features/ai_assistant/ai_assistant.dart';

void main() {
  const successfulIntent = AiIntent(
    name: 'reports.daily_summary',
    confidence: 0.98,
    parameters: {'date': '2026-07-18'},
    executionMode: AiExecutionMode.execute,
  );

  test('registry automatically indexes supplied tools by id', () {
    final tool = _TestTool(id: 'reports.daily_summary');
    final registry = AiToolRegistry([tool]);

    expect(registry.findById('reports.daily_summary'), same(tool));
    expect(registry.all, contains(tool));
  });

  test('registry rejects blank and duplicate tool ids', () {
    expect(() => AiToolRegistry([_TestTool(id: ' ')]), throwsArgumentError);
    expect(
      () => AiToolRegistry([
        _TestTool(id: 'same'),
        _TestTool(id: 'same'),
      ]),
      throwsArgumentError,
    );
  });

  test('execution resolves a registered tool and returns its structured result',
      () async {
    final tool = _TestTool(id: successfulIntent.name);
    final service = AiExecutionService(registry: AiToolRegistry([tool]));

    final response = await service.execute(successfulIntent);

    expect(response.isSuccess, isTrue);
    expect(response.messages, ['Completed.']);
    expect(response.tables.single.columns, ['total']);
    expect(response.actions.single.id, 'open-report');
    expect(tool.executionMode, AiExecutionMode.execute);
  });

  test('unknown tool returns a structured unknown-tool response', () async {
    const intent = AiIntent(
      name: 'unknown.operation',
      confidence: 1,
      parameters: {},
      executionMode: AiExecutionMode.execute,
    );
    final service = AiExecutionService(registry: AiToolRegistry([]));

    final response = await service.execute(intent);

    expect(response.status, AiResponseStatus.unknownTool);
    expect(response.messages.single, contains('unknown.operation'));
  });

  test('required parameter validation prevents tool invocation', () async {
    final tool = _TestTool(id: 'requires-date', requiredParameter: true);
    final service = AiExecutionService(registry: AiToolRegistry([tool]));
    const intent = AiIntent(
      name: 'requires-date',
      confidence: 1,
      parameters: {},
      executionMode: AiExecutionMode.execute,
    );

    final response = await service.execute(intent);

    expect(response.status, AiResponseStatus.validationFailure);
    expect(response.validationErrors.single.field, 'date');
    expect(tool.wasExecuted, isFalse);
  });

  test('tool validation errors propagate without being flattened', () async {
    final service = AiExecutionService(
      registry: AiToolRegistry([_ValidationTool(id: successfulIntent.name)]),
    );

    final response = await service.execute(successfulIntent);

    expect(response.status, AiResponseStatus.validationFailure);
    expect(response.messages, ['A date is required.']);
    expect(response.validationErrors.single.field, 'date');
  });

  test('unexpected tool errors return a safe failure response', () async {
    final service = AiExecutionService(
      registry: AiToolRegistry([_ErrorTool(id: successfulIntent.name)]),
    );

    final response = await service.execute(successfulIntent);

    expect(response.status, AiResponseStatus.failure);
    expect(
        response.messages, ['The requested operation could not be completed.']);
  });
}

class _TestTool implements AiTool {
  _TestTool({required this.id, this.requiredParameter = false});

  @override
  final String id;
  final bool requiredParameter;
  bool wasExecuted = false;

  @override
  String get name => 'Daily summary';
  @override
  String get description => 'Returns the existing daily summary.';
  @override
  List<AiToolParameter> get parameters => [
        AiToolParameter(
          id: 'date',
          type: AiParameterType.date,
          description: 'Business date',
          required: requiredParameter,
        ),
      ];

  AiExecutionMode? executionMode;

  @override
  Future<AiToolResult> execute(
    Map<String, Object?> parameters, {
    required AiExecutionMode executionMode,
  }) async {
    wasExecuted = true;
    this.executionMode = executionMode;
    return const AiToolResult(
      messages: ['Completed.'],
      tables: [
        AiResponseTable(columns: [
          'total'
        ], rows: [
          [42]
        ])
      ],
      actions: [AiResponseAction(id: 'open-report', label: 'Open report')],
    );
  }
}

final class _ValidationTool extends _TestTool {
  _ValidationTool({required super.id});

  @override
  Future<AiToolResult> execute(
    Map<String, Object?> parameters, {
    required AiExecutionMode executionMode,
  }) {
    throw const AiToolValidationException(
      message: 'A date is required.',
      errors: [
        AiValidationError(field: 'date', message: 'Choose a valid date.')
      ],
    );
  }
}

final class _ErrorTool extends _TestTool {
  _ErrorTool({required super.id});

  @override
  Future<AiToolResult> execute(
    Map<String, Object?> parameters, {
    required AiExecutionMode executionMode,
  }) {
    throw StateError('Controller operation failed.');
  }
}
