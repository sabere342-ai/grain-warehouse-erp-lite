import 'dart:convert';
import 'dart:io';

import 'package:grain_warehouse_erp_lite/application/identity/device_identity_store.dart';
import 'package:grain_warehouse_erp_lite/application/identity/distributed_identity.dart';
import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';

final class FileDeviceIdentityStore implements DeviceIdentityStore {
  FileDeviceIdentityStore({
    required Directory profileDirectory,
    DeviceIdGenerator generator = const UuidV4DeviceIdGenerator(),
  })  : _file = File(path.join(profileDirectory.path, fileName)),
        _generator = generator;

  static const String fileName = 'installation_device_identity.json';
  static const int schemaVersion = 1;

  final File _file;
  final DeviceIdGenerator _generator;

  static Future<FileDeviceIdentityStore> production({
    DeviceIdGenerator generator = const UuidV4DeviceIdGenerator(),
  }) async {
    final directory = await getApplicationSupportDirectory();
    return FileDeviceIdentityStore(
      profileDirectory: directory,
      generator: generator,
    );
  }

  @override
  Future<DeviceId> loadOrProvision() async {
    try {
      if (await _file.exists()) return _readExisting();
      if (await _temporary.exists() || await _backup.exists()) {
        throw const DeviceIdentityStoreException('incompleteAtomicWrite');
      }
      final generated = _generator.generate();
      await _writeNew(generated);
      return generated;
    } on DeviceIdentityStoreException {
      rethrow;
    } on Object catch (error) {
      throw DeviceIdentityStoreException('deviceIdentityUnavailable', error);
    }
  }

  @override
  Future<DeviceId> reprovision() async {
    try {
      if (!await _file.exists()) {
        throw const DeviceIdentityStoreException('deviceIdentityMissing');
      }
      await _readExisting();
      if (await _temporary.exists() || await _backup.exists()) {
        throw const DeviceIdentityStoreException('incompleteAtomicWrite');
      }
      final replacement = _generator.generate();
      await _writeReplacement(replacement);
      return replacement;
    } on DeviceIdentityStoreException {
      rethrow;
    } on Object catch (error) {
      throw DeviceIdentityStoreException('deviceIdentityUnavailable', error);
    }
  }

  File get _temporary => File('${_file.path}.tmp');
  File get _backup => File('${_file.path}.bak');

  Future<DeviceId> _readExisting() async {
    try {
      final decoded = jsonDecode(await _file.readAsString());
      if (decoded is! Map<String, dynamic> ||
          decoded.length != 2 ||
          decoded['schemaVersion'] != schemaVersion ||
          decoded['deviceId'] is! String) {
        throw const DeviceIdentityStoreException('corruptDeviceIdentity');
      }
      return DeviceId(decoded['deviceId']! as String);
    } on DeviceIdentityStoreException {
      rethrow;
    } on Object catch (error) {
      throw DeviceIdentityStoreException('corruptDeviceIdentity', error);
    }
  }

  String _contents(DeviceId value) => jsonEncode(<String, Object>{
        'schemaVersion': schemaVersion,
        'deviceId': value.value,
      });

  Future<void> _writeNew(DeviceId value) async {
    await _file.parent.create(recursive: true);
    final temporary = _temporary;
    await temporary.writeAsString(_contents(value), flush: true);
    try {
      await temporary.rename(_file.path);
    } on Object {
      if (await temporary.exists()) await temporary.delete();
      rethrow;
    }
    final persisted = await _readExisting();
    if (persisted != value) {
      throw const DeviceIdentityStoreException('persistenceVerificationFailed');
    }
  }

  Future<void> _writeReplacement(DeviceId value) async {
    final temporary = _temporary;
    final backup = _backup;
    await temporary.writeAsString(_contents(value), flush: true);
    await _file.rename(backup.path);
    try {
      await temporary.rename(_file.path);
      final persisted = await _readExisting();
      if (persisted != value) {
        throw const DeviceIdentityStoreException(
          'persistenceVerificationFailed',
        );
      }
      await backup.delete();
    } on Object {
      if (await _file.exists()) await _file.delete();
      if (await backup.exists()) await backup.rename(_file.path);
      if (await temporary.exists()) await temporary.delete();
      rethrow;
    }
  }
}
