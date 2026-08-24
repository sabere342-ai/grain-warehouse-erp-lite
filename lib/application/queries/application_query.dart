abstract interface class QueryResultMetadata {
  const QueryResultMetadata();
}

enum QueryResultSource { local }

enum LocalReadAuthority { sqlite, managedFile }

enum LocalQueryConsistency { currentKnownState }

/// Describes a local result without freezing future cloud consistency
/// semantics. Future adapters can add another metadata subtype.
final class LocalQueryResultMetadata implements QueryResultMetadata {
  const LocalQueryResultMetadata({
    this.source = QueryResultSource.local,
    this.readAuthority = LocalReadAuthority.sqlite,
    this.consistency = LocalQueryConsistency.currentKnownState,
  });

  final QueryResultSource source;
  final LocalReadAuthority readAuthority;
  final LocalQueryConsistency consistency;
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
