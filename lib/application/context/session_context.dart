import 'package:grain_warehouse_erp_lite/core/auth/app_user.dart';

final class SessionContext {
  const SessionContext({required this.userId});

  final String userId;
}

abstract interface class SessionContextProvider {
  SessionContext? get current;

  void replace(SessionContext context);

  void clear();
}

/// Application-local session state. Its lifetime is owned by the composition
/// root; widgets may consume the auth controller but do not own this context.
final class LocalSessionContextProvider implements SessionContextProvider {
  SessionContext? _current;

  @override
  SessionContext? get current => _current;

  @override
  void replace(SessionContext context) {
    _current = context;
  }

  @override
  void clear() {
    _current = null;
  }
}

/// Translates the existing local authentication authority into the narrower
/// application session boundary. It deliberately does not create business
/// identity: an authenticated user is not proof of business membership.
final class AuthSessionContextSynchronizer {
  const AuthSessionContextSynchronizer({required this.provider});

  final SessionContextProvider provider;

  void synchronize(AppUser? user) {
    if (user == null || !user.canProceed) {
      provider.clear();
      return;
    }
    provider.replace(SessionContext(userId: user.id));
  }
}
