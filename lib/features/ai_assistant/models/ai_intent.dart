enum AiExecutionMode { preview, execute, readOnly }

/// Structured input from a future intent provider. It performs no parsing.
final class AiIntent {
  const AiIntent({
    required this.name,
    required this.confidence,
    required this.parameters,
    required this.executionMode,
  }) : assert(confidence >= 0 && confidence <= 1);

  final String name;
  final double confidence;
  final Map<String, Object?> parameters;
  final AiExecutionMode executionMode;
}
