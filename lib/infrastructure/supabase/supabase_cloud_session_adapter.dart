import 'dart:async';

import 'package:grain_warehouse_erp_lite/application/context/business_context.dart';
import 'package:grain_warehouse_erp_lite/application/context/session_context.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';

/// Converts only a live Supabase session plus an active server membership into
/// the verified contexts consumed by PostExpense.
final class SupabaseCloudSessionAdapter {
  SupabaseCloudSessionAdapter(this._client)
      : sessionContexts = MutableSessionContextProvider(),
        businessContexts = MutableBusinessContextProvider();

  final SupabaseClient _client;
  final MutableSessionContextProvider sessionContexts;
  final MutableBusinessContextProvider businessContexts;
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
      final businessId = rows.single['business_id'] as String?;
      final role = rows.single['role'] as String?;
      if (businessId == null ||
          role == null ||
          !Uuid.isValidUUID(fromString: businessId) ||
          (role != 'owner' && role != 'employee')) {
        clear();
        return;
      }
      sessionContexts.replace(SessionContext.verifiedRemote(
        remoteAuthUserId: user.id,
      ));
      businessContexts.replace(BusinessContext.verifiedMembership(
        businessId: businessId,
        memberAuthUserId: user.id,
        role: role,
      ));
    } on Object {
      clear();
    }
  }

  void clear() {
    sessionContexts.clear();
    businessContexts.clear();
  }

  Future<void> dispose() async => _subscription?.cancel();
}
