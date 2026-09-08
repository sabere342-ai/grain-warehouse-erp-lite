import 'package:grain_warehouse_erp_lite/application/context/business_context.dart';
import 'package:grain_warehouse_erp_lite/application/context/session_context.dart';
import 'package:grain_warehouse_erp_lite/application/identity/distributed_identity.dart';

final class ExecutionContext {
  factory ExecutionContext.local({
    required SessionContext session,
    required DeviceId deviceIdentity,
  }) {
    if (session.isVerifiedRemote) {
      throw ArgumentError('Local context cannot contain a remote session.');
    }
    return ExecutionContext._(
      session: session,
      business: null,
      deviceIdentity: deviceIdentity,
    );
  }

  factory ExecutionContext.verifiedBusiness({
    required SessionContext session,
    required BusinessContext business,
    required DeviceId deviceIdentity,
  }) {
    if (!session.isVerifiedRemote ||
        session.remoteAuthUserIdentity != business.memberAuthUserId) {
      throw ArgumentError(
        'Verified business context requires the matching remote session.',
      );
    }
    return ExecutionContext._(
      session: session,
      business: business,
      deviceIdentity: deviceIdentity,
    );
  }

  factory ExecutionContext.remoteSession({
    required SessionContext session,
    required DeviceId deviceIdentity,
  }) {
    if (!session.isVerifiedRemote) {
      throw ArgumentError('Remote context requires a verified remote session.');
    }
    return ExecutionContext._(
      session: session,
      business: null,
      deviceIdentity: deviceIdentity,
    );
  }

  const ExecutionContext._({
    required this.session,
    required this.business,
    required this.deviceIdentity,
  });

  final SessionContext session;
  final BusinessContext? business;
  final DeviceId deviceIdentity;

  bool isSameAuthenticatedScope(ExecutionContext other) =>
      session.sessionId == other.session.sessionId &&
      session.remoteAuthUserIdentity == other.session.remoteAuthUserIdentity &&
      deviceIdentity == other.deviceIdentity &&
      business?.businessId == other.business?.businessId &&
      business?.scope == other.business?.scope &&
      business?.memberAuthUserId == other.business?.memberAuthUserId &&
      business?.role == other.business?.role;
}

abstract interface class ExecutionContextProvider {
  ExecutionContext? get current;
}

final class MutableExecutionContextProvider
    implements ExecutionContextProvider {
  ExecutionContext? _current;

  @override
  ExecutionContext? get current => _current;

  void replace(ExecutionContext context) => _current = context;

  void clear() => _current = null;
}

final class ExecutionSessionContextProvider implements SessionContextProvider {
  const ExecutionSessionContextProvider(this._provider);

  final ExecutionContextProvider _provider;

  @override
  SessionContext? get current => _provider.current?.session;
}

final class ExecutionBusinessContextProvider
    implements BusinessContextProvider {
  const ExecutionBusinessContextProvider(this._provider);

  final ExecutionContextProvider _provider;

  @override
  BusinessContext? get current => _provider.current?.business;
}
