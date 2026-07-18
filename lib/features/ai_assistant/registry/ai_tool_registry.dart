import '../contracts/ai_tool.dart';

/// Immutable allow-list of operations callable through the AI layer.
final class AiToolRegistry {
  AiToolRegistry(Iterable<AiTool> tools) : _tools = _index(tools);

  final Map<String, AiTool> _tools;

  AiTool? findById(String id) => _tools[id];
  Iterable<AiTool> get all => _tools.values;

  static Map<String, AiTool> _index(Iterable<AiTool> tools) {
    final indexed = <String, AiTool>{};
    for (final tool in tools) {
      if (tool.id.trim().isEmpty) {
        throw ArgumentError.value(
            tool.id, 'tool.id', 'Tool id cannot be blank.');
      }
      if (indexed.containsKey(tool.id)) {
        throw ArgumentError.value(
            tool.id, 'tool.id', 'Tool ids must be unique.');
      }
      indexed[tool.id] = tool;
    }
    return Map.unmodifiable(indexed);
  }
}
