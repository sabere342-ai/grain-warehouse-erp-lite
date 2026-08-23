final class BusinessContext {
  const BusinessContext({
    required this.businessId,
    required this.userId,
  })  : authUserId = null,
        role = null,
        isVerifiedMembership = false;

  const BusinessContext.verifiedMembership({
    required this.businessId,
    required String memberAuthUserId,
    required this.role,
  })  : userId = memberAuthUserId,
        authUserId = memberAuthUserId,
        isVerifiedMembership = true;

  final String businessId;
  final String userId;
  final String? authUserId;
  final String? role;
  final bool isVerifiedMembership;
}

abstract interface class BusinessContextProvider {
  BusinessContext? get current;
}

final class MutableBusinessContextProvider implements BusinessContextProvider {
  BusinessContext? _current;

  @override
  BusinessContext? get current => _current;

  void replace(BusinessContext context) => _current = context;

  void clear() => _current = null;
}

/// Production remains single-business in Phase 108E. This typed provider keeps
/// business identity out of handlers until a verified context is available.
final class NoBusinessContextProvider implements BusinessContextProvider {
  const NoBusinessContextProvider();

  @override
  BusinessContext? get current => null;
}
