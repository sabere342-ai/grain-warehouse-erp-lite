enum AiParameterType { string, integer, decimal, boolean, date, object, list }

final class AiToolParameter {
  const AiToolParameter({
    required this.id,
    required this.type,
    required this.description,
    this.required = false,
  });

  final String id;
  final AiParameterType type;
  final String description;
  final bool required;
}
