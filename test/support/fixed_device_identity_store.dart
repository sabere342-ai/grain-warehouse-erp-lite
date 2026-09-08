import 'package:grain_warehouse_erp_lite/application/identity/device_identity_store.dart';
import 'package:grain_warehouse_erp_lite/application/identity/distributed_identity.dart';

final class FixedDeviceIdentityStore implements DeviceIdentityStore {
  FixedDeviceIdentityStore({
    String deviceId = 'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa',
  }) : _identity = DeviceId(deviceId);

  final DeviceId _identity;

  @override
  Future<DeviceId> loadOrProvision() async => _identity;

  @override
  Future<DeviceId> reprovision() async =>
      DeviceId('bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb');
}
