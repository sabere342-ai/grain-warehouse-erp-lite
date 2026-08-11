abstract interface class QueryResultMetadata {
  const QueryResultMetadata();
}

/// Describes the current SQLite-backed result without freezing future cloud
/// consistency semantics. Future adapters can add another metadata subtype.
final class LocalQueryResultMetadata implements QueryResultMetadata {
  const LocalQueryResultMetadata();
}

final class ApplicationQueryResult<T> {
  const ApplicationQueryResult({
    required this.value,
    required this.metadata,
  });

  final T value;
  final QueryResultMetadata metadata;
}

abstract interface class ApplicationQueryHandler<Q, R> {
  Future<ApplicationQueryResult<R>> execute(Q query);
}
