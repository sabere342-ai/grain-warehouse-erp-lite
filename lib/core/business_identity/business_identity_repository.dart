import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:grain_warehouse_erp_lite/core/audit/audit_log_repository.dart';
import 'package:grain_warehouse_erp_lite/core/business_identity/business_identity.dart';

abstract class BusinessIdentityRepository {
  Future<BusinessIdentity> loadIdentity();

  Future<void> saveIdentity(BusinessIdentity identity);

  Future<LogoMetadata?> saveLogoBytes(Uint8List bytes, String mimeType);

  Future<Uint8List?> loadLogoBytes(String managedFileName);

  Future<void> deleteLogoFile(String managedFileName);

  String get managedLogosDirectory;
}

class LocalBusinessIdentityRepository implements BusinessIdentityRepository {
  LocalBusinessIdentityRepository({
    String? filePath,
    String? logosDirectory,
    AuditLogRepository? auditLogRepository,
  })  : _filePath = filePath,
        _logosDirectory = logosDirectory,
        _auditLogRepository = auditLogRepository;

  final String? _filePath;
  final String? _logosDirectory;
  final AuditLogRepository? _auditLogRepository;

  @override
  String get managedLogosDirectory {
    if (_logosDirectory != null) {
      return _logosDirectory;
    }
    return '${_baseDataPath()}${Platform.pathSeparator}logos';
  }

  @override
  Future<BusinessIdentity> loadIdentity() async {
    try {
      final file = File(_resolvedFilePath());
      if (!await file.exists()) {
        return BusinessIdentity.empty;
      }
      final decoded = jsonDecode(await file.readAsString());
      if (decoded is Map) {
        return BusinessIdentity.fromJson(Map<String, Object?>.from(decoded));
      }
      return BusinessIdentity.empty;
    } catch (_) {
      return BusinessIdentity.empty;
    }
  }

  @override
  Future<void> saveIdentity(BusinessIdentity identity) async {
    final file = File(_resolvedFilePath());
    await file.parent.create(recursive: true);
    await file.writeAsString(
      const JsonEncoder.withIndent('  ').convert(identity.toJson()),
    );
    await _auditLogRepository?.record(
      const AuditLogDraft(
        actionType: 'settings.business_identity.changed',
        descriptionAr: 'تم تحديث هوية المنشأة.',
      ),
    );
  }

  @override
  Future<LogoMetadata?> saveLogoBytes(Uint8List bytes, String mimeType) async {
    if (bytes.isEmpty) return null;

    final hash = sha256.convert(bytes).toString();
    final ext = _extensionForMime(mimeType);
    final fileName = 'logo_${hash.substring(0, 16)}.$ext';
    final dir = Directory(managedLogosDirectory);
    await dir.create(recursive: true);
    final finalPath =
        '${dir.path}${Platform.pathSeparator}$fileName';

    final tempPath = '$finalPath.tmp';
    final tempFile = File(tempPath);
    await tempFile.writeAsBytes(bytes, flush: true);

    final finalFile = File(finalPath);
    if (await finalFile.exists()) {
      await tempFile.delete();
    } else {
      await tempFile.rename(finalPath);
    }

    final verified = File(finalPath);
    if (!await verified.exists()) return null;
    final verifiedBytes = await verified.readAsBytes();
    if (verifiedBytes.length != bytes.length) return null;

    int width = 0;
    int height = 0;
    if (mimeType == 'image/png' || mimeType == 'image/jpeg') {
      final dims = _decodeDimensions(verifiedBytes, mimeType);
      width = dims[0];
      height = dims[1];
    }

    return LogoMetadata(
      managedFileName: fileName,
      mimeType: mimeType,
      sha256: hash,
      byteLength: verifiedBytes.length,
      width: width,
      height: height,
    );
  }

  @override
  Future<Uint8List?> loadLogoBytes(String managedFileName) async {
    if (managedFileName.isEmpty) return null;
    if (managedFileName.contains('..') ||
        managedFileName.contains('/') ||
        managedFileName.contains('\\')) {
      return null;
    }
    final file =
        File('$managedLogosDirectory${Platform.pathSeparator}$managedFileName');
    if (!await file.exists()) return null;
    return await file.readAsBytes();
  }

  @override
  Future<void> deleteLogoFile(String managedFileName) async {
    if (managedFileName.isEmpty) return;
    if (managedFileName.contains('..') ||
        managedFileName.contains('/') ||
        managedFileName.contains('\\')) {
      return;
    }
    final file =
        File('$managedLogosDirectory${Platform.pathSeparator}$managedFileName');
    if (await file.exists()) {
      await file.delete();
    }
  }

  String _resolvedFilePath() {
    if (_filePath != null) {
      return _filePath;
    }
    return '${_baseDataPath()}${Platform.pathSeparator}business_identity.json';
  }

  String _baseDataPath() {
    final appData = Platform.environment['APPDATA'];
    final home = Platform.environment['USERPROFILE'] ??
        Platform.environment['HOME'] ??
        Directory.current.path;
    final base = appData == null || appData.trim().isEmpty ? home : appData;
    return '$base${Platform.pathSeparator}GrainWarehouseErpLite';
  }

  String _extensionForMime(String mimeType) {
    switch (mimeType) {
      case 'image/png':
        return 'png';
      case 'image/jpeg':
        return 'jpg';
      default:
        return 'img';
    }
  }

  List<int> _decodeDimensions(Uint8List bytes, String mimeType) {
    try {
      if (mimeType == 'image/png' && bytes.length >= 24) {
        if (bytes[0] == 0x89 &&
            bytes[1] == 0x50 &&
            bytes[2] == 0x4E &&
            bytes[3] == 0x47) {
          final width = (bytes[16] << 24) |
              (bytes[17] << 16) |
              (bytes[18] << 8) |
              bytes[19];
          final height = (bytes[20] << 24) |
              (bytes[21] << 16) |
              (bytes[22] << 8) |
              bytes[23];
          return [width, height];
        }
      }
      if (mimeType == 'image/jpeg' && bytes.length >= 4) {
        if (bytes[0] == 0xFF && bytes[1] == 0xD8) {
          int offset = 2;
          while (offset < bytes.length - 1) {
            if (bytes[offset] != 0xFF) break;
            final marker = bytes[offset + 1];
            if (marker >= 0xC0 && marker <= 0xCF && marker != 0xC4 &&
                marker != 0xC8 && marker != 0xCC) {
              if (offset + 9 < bytes.length) {
                final h = (bytes[offset + 5] << 8) | bytes[offset + 6];
                final w = (bytes[offset + 7] << 8) | bytes[offset + 8];
                return [w, h];
              }
            }
            if (offset + 3 < bytes.length) {
              final segLen =
                  (bytes[offset + 2] << 8) | bytes[offset + 3];
              offset += 2 + segLen;
            } else {
              break;
            }
          }
        }
      }
    } catch (_) {}
    return [0, 0];
  }
}
