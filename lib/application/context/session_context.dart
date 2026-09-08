import 'package:grain_warehouse_erp_lite/application/context/execution_context.dart';
import 'package:grain_warehouse_erp_lite/application/identity/distributed_identity.dart';
import 'package:grain_warehouse_erp_lite/core/auth/app_user.dart';

enum AuthenticationKind { local, verifiedRemote }

final class SessionContext {
  const SessionContext.local({
    required this.sessionId,
    required this.localActorId,
  })  : remoteAuthUserIdentity = null,
        authenticationKind = AuthenticationKind.local;

  const SessionContext.verifiedRemote({
    required this.sessionId,
    required RemoteAuthUserId remoteAuthUserId,
  })  : localActorId = null,
        remoteAuthUserIdentity = remoteAuthUserId,
        authenticationKind = AuthenticationKind.verifiedRemote;

  final SessionId sessionId;
  final LocalActorId? localActorId;
  final RemoteAuthUserId? remoteAuthUserIdentity;
  final AuthenticationKind authenticationKind;

  bool get isVerifiedRemote =>
      authenticationKind == AuthenticationKind.verifiedRemote;
  String get userId => localActorId?.value ?? remoteAuthUserIdentity!.value;
  String? get authUserId => remoteAuthUserIdentity?.value;
}

abstract interface class SessionContextProvider {
  SessionContext? get current;
}

/// Creates one local-only execution context per authenticated lifecycle.
final class AuthSessionContextSynchronizer {
  const AuthSessionContextSynchronizer({
    required this.provider,
    required this.deviceIdentity,
    required this.sessionIdGenerator,
  });

  final MutableExecutionContextProvider provider;
  final DeviceId deviceIdentity;
  final SessionIdGenerator sessionIdGenerator;

  void synchronize(AppUser? user) {
    if (user == null || !user.canProceed) {
      provider.clear();
      return;
    }
    final active = provider.current;
    if (active != null &&
        active.business == null &&
        active.session.authenticationKind == AuthenticationKind.local &&
        active.session.localActorId?.value == user.id) {
      return;
    }
    provider.replace(
      ExecutionContext.local(
        session: SessionContext.local(
          sessionId: sessionIdGenerator.generate(),
          localActorId: LocalActorId(user.id),
        ),
        deviceIdentity: deviceIdentity,
      ),
    );
  }
}
