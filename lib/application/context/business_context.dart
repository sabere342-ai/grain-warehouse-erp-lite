final class BusinessContext {
  const BusinessContext({
    required this.businessId,
    required this.userId,
  });

  final String businessId;
  final String userId;
}

abstract interface class BusinessContextProvider {
  BusinessContext? get current;
}

/// Production remains single-business in Phase 108E. This typed provider keeps
/// business identity out of handlers until a verified context is available.
final class NoBusinessContextProvider implements BusinessContextProvider {
  const NoBusinessContextProvider();

  @override
  BusinessContext? get current => null;
}
