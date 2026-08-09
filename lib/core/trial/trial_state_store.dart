import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';

import 'trial_state.dart';

enum TrialStateLoadKind { fresh, loaded, invalid }

class TrialStateLoadResult {
  const TrialStateLoadResult._(this.kind, this.state);

  const TrialStateLoadResult.fresh() : this._(TrialStateLoadKind.fresh, null);
  const TrialStateLoadResult.loaded(TrialPersistentState state)
      : this._(TrialStateLoadKind.loaded, state);
  const TrialStateLoadResult.invalid()
      : this._(TrialStateLoadKind.invalid, null);

  final TrialStateLoadKind kind;
  final TrialPersistentState? state;
}

abstract interface class TrialStateStore {
  Future<TrialStateLoadResult> read();
  Future<void> write(TrialPersistentState state);
}

class FileTrialStateStore implements TrialStateStore {
  FileTrialStateStore(Directory directory)
      : _directory = directory,
        _stateFile = File(path.join(directory.path, 'runtime.dat')),
        _sentinelFile = File(path.join(directory.path, '.initialized'));

  static const _integrityNamespace = 'grain-warehouse-erp-lite/local-trial/v1';
  static final String _sentinelValue = sha256
      .convert(utf8.encode('$_integrityNamespace/initialized'))
      .toString();

  final Directory _directory;
  final File _stateFile;
  final File _sentinelFile;

  static Future<FileTrialStateStore> production() async {
    final supportDirectory = await getApplicationSupportDirectory();
    return FileTrialStateStore(
      Directory(path.join(supportDirectory.path, 'trial_runtime')),
    );
  }

  String get stateFilePath => _stateFile.path;
  String get sentinelFilePath => _sentinelFile.path;

  @override
  Future<TrialStateLoadResult> read() async {
    final stateExists = await _stateFile.exists();
    final sentinelExists = await _sentinelFile.exists();
    if (!stateExists && !sentinelExists) {
      if (await _hasInterruptedWriteArtifact()) {
        return const TrialStateLoadResult.invalid();
      }
      return const TrialStateLoadResult.fresh();
    }
    if (!stateExists || !sentinelExists) {
      return const TrialStateLoadResult.invalid();
    }

    try {
      if ((await _sentinelFile.readAsString()).trim() != _sentinelValue) {
        return const TrialStateLoadResult.invalid();
      }
      final envelope = jsonDecode(await _stateFile.readAsString());
      if (envelope is! Map) return const TrialStateLoadResult.invalid();
      final map = Map<String, Object?>.from(envelope);
      if (map['v'] != trialStateVersion ||
          map['p'] is! String ||
          map['m'] is! String) {
        return const TrialStateLoadResult.invalid();
      }
      final payload = map['p']! as String;
      if (map['m'] != _markerFor(payload)) {
        return const TrialStateLoadResult.invalid();
      }
      final decodedPayload = jsonDecode(
        utf8.decode(base64Url.decode(base64Url.normalize(payload))),
      );
      if (decodedPayload is! Map) {
        return const TrialStateLoadResult.invalid();
      }
      final data = Map<String, Object?>.from(decodedPayload);
      final version = data['v'];
      final startedAt = data['s'];
      final lastAcceptedRun = data['l'];
      final tamperDetected = data['t'];
      final expired = data['e'];
      if (version is! int ||
          startedAt is! int ||
          lastAcceptedRun is! int ||
          tamperDetected is! bool ||
          expired is! bool) {
        return const TrialStateLoadResult.invalid();
      }
      return TrialStateLoadResult.loaded(
        TrialPersistentState(
          version: version,
          startedAtUtc:
              DateTime.fromMicrosecondsSinceEpoch(startedAt, isUtc: true),
          lastAcceptedRunAtUtc: DateTime.fromMicrosecondsSinceEpoch(
            lastAcceptedRun,
            isUtc: true,
          ),
          tamperDetected: tamperDetected,
          expired: expired,
        ),
      );
    } catch (_) {
      return const TrialStateLoadResult.invalid();
    }
  }

  @override
  Future<void> write(TrialPersistentState state) async {
    await _directory.create(recursive: true);
    if (!await _sentinelFile.exists()) {
      await _replaceFile(_sentinelFile, _sentinelValue);
    }
    final payload = base64Url.encode(
      utf8.encode(
        jsonEncode({
          'v': state.version,
          's': state.startedAtUtc.toUtc().microsecondsSinceEpoch,
          'l': state.lastAcceptedRunAtUtc.toUtc().microsecondsSinceEpoch,
          't': state.tamperDetected,
          'e': state.expired,
        }),
      ),
    );
    await _replaceFile(
      _stateFile,
      jsonEncode({
        'v': trialStateVersion,
        'p': payload,
        'm': _markerFor(payload),
      }),
    );
  }

  String _markerFor(String payload) =>
      sha256.convert(utf8.encode('$_integrityNamespace|$payload')).toString();

  Future<bool> _hasInterruptedWriteArtifact() async {
    for (final file in [_stateFile, _sentinelFile]) {
      if (await File('${file.path}.tmp').exists() ||
          await File('${file.path}.bak').exists()) {
        return true;
      }
    }
    return false;
  }

  Future<void> _replaceFile(File destination, String contents) async {
    final temporary = File('${destination.path}.tmp');
    final backup = File('${destination.path}.bak');
    if (await temporary.exists()) await temporary.delete();
    if (await backup.exists()) await backup.delete();
    await temporary.writeAsString(contents, flush: true);

    if (!await destination.exists()) {
      await temporary.rename(destination.path);
      return;
    }

    await destination.rename(backup.path);
    try {
      await temporary.rename(destination.path);
      await backup.delete();
    } catch (_) {
      if (!await destination.exists() && await backup.exists()) {
        await backup.rename(destination.path);
      }
      rethrow;
    }
  }
}
