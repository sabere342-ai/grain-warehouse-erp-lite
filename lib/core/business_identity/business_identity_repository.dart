import 'dart:convert';
import 'dart:io';

import 'package:grain_warehouse_erp_lite/core/audit/audit_log_repository.dart';
import 'package:grain_warehouse_erp_lite/core/business_identity/business_identity.dart';

abstract class BusinessIdentityRepository {
  Future<BusinessIdentity> loadIdentity();

  Future<void> saveIdentity(BusinessIdentity identity);
}

class LocalBusinessIdentityRepository implements BusinessIdentityRepository {
  LocalBusinessIdentityRepository({
    String? filePath,
    AuditLogRepository? auditLogRepository,
  })  : _filePath = filePath,
        _auditLogRepository = auditLogRepository;

  final String? _filePath;
  final AuditLogRepository? _auditLogRepository;

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
        descriptionAr: 'تم تحديث اسم المنشأة المعروض على الفواتير.',
      ),
    );
  }

  String _resolvedFilePath() {
    if (_filePath != null) {
      return _filePath;
    }
    final appData = Platform.environment['APPDATA'];
    final home = Platform.environment['USERPROFILE'] ??
        Platform.environment['HOME'] ??
        Directory.current.path;
    final base = appData == null || appData.trim().isEmpty ? home : appData;
    return '$base${Platform.pathSeparator}GrainWarehouseErpLite'
        '${Platform.pathSeparator}business_identity.json';
  }
}
