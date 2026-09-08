import 'package:grain_warehouse_erp_lite/application/identity/distributed_identity.dart';

abstract interface class DeviceIdentityStore {
  Future<DeviceId> loadOrProvision();

  /// Explicit profile-reset/clone-recovery operation. Production does not call
  /// this automatically.
  Future<DeviceId> reprovision();
}

final class DeviceIdentityStoreException implements Exception {
  const DeviceIdentityStoreException(this.code, [this.cause]);

  final String code;
  final Object? cause;

  @override
  String toString() => 'DeviceIdentityStoreException($code)';
}
