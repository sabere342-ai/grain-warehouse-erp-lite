import 'dart:async';

import 'package:grain_warehouse_erp_lite/application/context/business_context.dart';
import 'package:grain_warehouse_erp_lite/application/context/execution_context.dart';
import 'package:grain_warehouse_erp_lite/application/context/session_context.dart';
import 'package:grain_warehouse_erp_lite/application/identity/distributed_identity.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Converts only a live Supabase session plus an active server membership into
/// one verified execution context consumed by distributed commands.
final class SupabaseCloudSessionAdapter {
  SupabaseCloudSessionAdapter(
    this._client, {
    required this.executionContexts,
    required this.deviceIdentity,
    this.sessionIdGenerator = const UuidV4SessionIdGenerator(),
  })  : sessionContexts = ExecutionSessionContextProvider(executionContexts),
        businessContexts = ExecutionBusinessContextProvider(executionContexts);

  final SupabaseClient _client;
  final MutableExecutionContextProvider executionContexts;
  final DeviceId deviceIdentity;
  final SessionIdGenerator sessionIdGenerator;
  final SessionContextProvider sessionContexts;
  final BusinessContextProvider businessContexts;
  StreamSubscription<AuthState>? _subscription;

  Future<void> initialize() async {
    await refresh();
    _subscription = _client.auth.onAuthStateChange.listen((_) {
      unawaited(refresh());
    });
  }

  Future<void> refresh() async {
    final session = _client.auth.currentSession;
    final user = session?.user;
    if (session == null || user == null || session.isExpired) {
      clear();
      return;
    }
    try {
      final response = await _client
          .from('business_memberships')
          .select('business_id, role, is_active')
          .eq('auth_user_id', user.id)
          .eq('is_active', true)
          .limit(2);
      final rows = (response as List).cast<Map<String, dynamic>>();
      if (rows.length != 1) {
        clear();
        return;
      }
      final businessIdValue = rows.single['business_id'] as String?;
      final role = rows.single['role'] as String?;
      if (businessIdValue == null || role == null) {
        clear();
        return;
      }
      final remoteActor = RemoteAuthUserId(user.id);
      final active = executionContexts.current;
      final sessionId = active != null &&
              active.session.isVerifiedRemote &&
              active.session.remoteAuthUserIdentity == remoteActor
          ? active.session.sessionId
          : sessionIdGenerator.generate();
      final sessionContext = SessionContext.verifiedRemote(
        sessionId: sessionId,
        remoteAuthUserId: remoteActor,
      );
      final businessContext = BusinessContext.verifiedMembership(
        businessId: BusinessId(businessIdValue),
        memberAuthUserId: remoteActor,
        role: role,
        scope: const BusinessWide(),
      );
      executionContexts.replace(
        ExecutionContext.verifiedBusiness(
          session: sessionContext,
          business: businessContext,
          deviceIdentity: deviceIdentity,
        ),
      );
    } on Object {
      clear();
    }
  }

  void clear() {
    executionContexts.clear();
  }

  Future<void> dispose() async => _subscription?.cancel();
}
