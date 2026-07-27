import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:grain_warehouse_erp_lite/core/audit/audit_log_repository.dart';
import 'package:grain_warehouse_erp_lite/core/auth/app_user.dart';
import 'package:grain_warehouse_erp_lite/core/auth/user_role.dart';
import 'package:grain_warehouse_erp_lite/core/backup/backup_export.dart';
import 'package:grain_warehouse_erp_lite/core/backup/backup_restore_service.dart';
import 'package:grain_warehouse_erp_lite/core/business_identity/business_identity.dart';
import 'package:grain_warehouse_erp_lite/core/business_identity/business_identity_controller.dart';
import 'package:grain_warehouse_erp_lite/core/business_identity/business_identity_repository.dart';
import 'package:grain_warehouse_erp_lite/core/catalog/product_repository.dart';
import 'package:grain_warehouse_erp_lite/core/customer_accounts/customer_account_repository.dart';
import 'package:grain_warehouse_erp_lite/core/customers/customer_repository.dart';
import 'package:grain_warehouse_erp_lite/core/documents/document_history.dart';
import 'package:grain_warehouse_erp_lite/core/expenses/expense_repository.dart';
import 'package:grain_warehouse_erp_lite/core/inventory/inventory_repository.dart';
import 'package:grain_warehouse_erp_lite/core/purchases/purchase_repository.dart';
import 'package:grain_warehouse_erp_lite/core/sales/sale_record.dart';
import 'package:grain_warehouse_erp_lite/core/sales/sale_repository.dart';
import 'package:grain_warehouse_erp_lite/core/supplier_accounts/supplier_account_repository.dart';
import 'package:grain_warehouse_erp_lite/core/suppliers/supplier_repository.dart';
import 'package:grain_warehouse_erp_lite/core/theme/app_theme.dart';
import 'package:grain_warehouse_erp_lite/features/prints/printable_sales_invoice_view.dart';

void main() {
  group('Phase 68 - LogoMetadata model', () {
    test('toJson and fromJson round-trip', () {
      const metadata = LogoMetadata(
        managedFileName: 'logo_abc123def456.png',
        mimeType: 'image/png',
        sha256: 'aabbccdd11223344',
        byteLength: 1024,
        width: 128,
        height: 128,
      );

      final json = metadata.toJson();
      final restored = LogoMetadata.fromJson(json);

      expect(restored.managedFileName, metadata.managedFileName);
      expect(restored.mimeType, metadata.mimeType);
      expect(restored.sha256, metadata.sha256);
      expect(restored.byteLength, metadata.byteLength);
      expect(restored.width, metadata.width);
      expect(restored.height, metadata.height);
    });

    test('fromJson handles null gracefully', () {
      final result = LogoMetadata.fromJson(null);
      expect(result.managedFileName, '');
      expect(result.mimeType, '');
      expect(result.isValid, isFalse);
    });

    test('fromJson handles non-map gracefully', () {
      final result = LogoMetadata.fromJson('invalid');
      expect(result.isValid, isFalse);
    });

    test('isValid requires all fields non-empty and byteLength > 0', () {
      const valid = LogoMetadata(
        managedFileName: 'file.png',
        mimeType: 'image/png',
        sha256: 'abc',
        byteLength: 100,
        width: 0,
        height: 0,
      );
      expect(valid.isValid, isTrue);

      const noFile = LogoMetadata(
        managedFileName: '',
        mimeType: 'image/png',
        sha256: 'abc',
        byteLength: 100,
        width: 0,
        height: 0,
      );
      expect(noFile.isValid, isFalse);

      const zeroBytes = LogoMetadata(
        managedFileName: 'file.png',
        mimeType: 'image/png',
        sha256: 'abc',
        byteLength: 0,
        width: 0,
        height: 0,
      );
      expect(zeroBytes.isValid, isFalse);
    });

    test('equality and hashCode', () {
      const a = LogoMetadata(
        managedFileName: 'f.png',
        mimeType: 'image/png',
        sha256: 'abc',
        byteLength: 10,
        width: 8,
        height: 8,
      );
      const b = LogoMetadata(
        managedFileName: 'f.png',
        mimeType: 'image/png',
        sha256: 'abc',
        byteLength: 10,
        width: 8,
        height: 8,
      );
      expect(a, equals(b));
      expect(a.hashCode, b.hashCode);

      const c = LogoMetadata(
        managedFileName: 'f.png',
        mimeType: 'image/png',
        sha256: 'xyz',
        byteLength: 10,
        width: 8,
        height: 8,
      );
      expect(a, isNot(equals(c)));
    });
  });

  group('Phase 68 - BusinessIdentity with logo', () {
    test('hasLogo is false when logo is null', () {
      const identity = BusinessIdentity(establishmentName: 'Test');
      expect(identity.hasLogo, isFalse);
    });

    test('hasLogo is false when logo is invalid', () {
      const identity = BusinessIdentity(
        establishmentName: 'Test',
        logo: LogoMetadata(
          managedFileName: '',
          mimeType: '',
          sha256: '',
          byteLength: 0,
          width: 0,
          height: 0,
        ),
      );
      expect(identity.hasLogo, isFalse);
    });

    test('hasLogo is true when logo is valid', () {
      const identity = BusinessIdentity(
        establishmentName: 'Test',
        logo: LogoMetadata(
          managedFileName: 'logo_abc.png',
          mimeType: 'image/png',
          sha256: 'abc123',
          byteLength: 512,
          width: 64,
          height: 64,
        ),
      );
      expect(identity.hasLogo, isTrue);
    });

    test('copyWith preserves logo by default', () {
      const identity = BusinessIdentity(
        establishmentName: 'Original',
        logo: LogoMetadata(
          managedFileName: 'logo_abc.png',
          mimeType: 'image/png',
          sha256: 'abc123',
          byteLength: 512,
          width: 64,
          height: 64,
        ),
      );

      final updated = identity.copyWith(establishmentName: 'Updated');
      expect(updated.hasLogo, isTrue);
      expect(updated.logo!.managedFileName, 'logo_abc.png');
    });

    test('copyWith with clearLogo removes logo', () {
      const identity = BusinessIdentity(
        establishmentName: 'Test',
        logo: LogoMetadata(
          managedFileName: 'logo_abc.png',
          mimeType: 'image/png',
          sha256: 'abc123',
          byteLength: 512,
          width: 64,
          height: 64,
        ),
      );

      final cleared = identity.copyWith(clearLogo: true);
      expect(cleared.hasLogo, isFalse);
      expect(cleared.logo, isNull);
    });

    test('toJson includes logo when present', () {
      const identity = BusinessIdentity(
        establishmentName: 'Test',
        logo: LogoMetadata(
          managedFileName: 'logo_abc.png',
          mimeType: 'image/png',
          sha256: 'abc123',
          byteLength: 512,
          width: 64,
          height: 64,
        ),
      );

      final json = identity.toJson();
      expect(json['logo'], isA<Map<String, Object?>>());
      final logoJson = json['logo'] as Map<String, Object?>;
      expect(logoJson['managedFileName'], 'logo_abc.png');
    });

    test('toJson omits logo when null', () {
      const identity = BusinessIdentity(establishmentName: 'Test');
      final json = identity.toJson();
      expect(json.containsKey('logo'), isFalse);
    });

    test('fromJson restores logo', () {
      final json = {
        'establishmentName': 'Test',
        'logo': {
          'managedFileName': 'logo_abc.png',
          'mimeType': 'image/png',
          'sha256': 'abc123',
          'byteLength': 512,
          'width': 64,
          'height': 64,
        },
      };

      final identity = BusinessIdentity.fromJson(json);
      expect(identity.hasLogo, isTrue);
      expect(identity.logo!.managedFileName, 'logo_abc.png');
    });

    test('fromJson handles missing logo', () {
      final json = {'establishmentName': 'Test'};
      final identity = BusinessIdentity.fromJson(json);
      expect(identity.hasLogo, isFalse);
    });
  });

  group('Phase 68 - LocalBusinessIdentityRepository logo storage', () {
    late Directory tempDir;

    setUp(() async {
      tempDir = await Directory.systemTemp.createTemp('phase68-logo-repo-');
    });

    tearDown(() async {
      if (await tempDir.exists()) {
        await tempDir.delete(recursive: true);
      }
    });

    test('saveLogoBytes writes file and returns metadata', () async {
      final repository = LocalBusinessIdentityRepository(
        filePath: '${tempDir.path}${Platform.pathSeparator}identity.json',
        logosDirectory: '${tempDir.path}${Platform.pathSeparator}logos',
      );

      final pngBytes = _createMinimalPng(64, 64);
      final metadata = await repository.saveLogoBytes(pngBytes, 'image/png');

      expect(metadata, isNotNull);
      expect(metadata!.managedFileName, contains('logo_'));
      expect(metadata.managedFileName, endsWith('.png'));
      expect(metadata.mimeType, 'image/png');
      expect(metadata.byteLength, pngBytes.length);
      expect(metadata.width, 64);
      expect(metadata.height, 64);
      expect(metadata.sha256, isNotEmpty);
    });

    test('loadLogoBytes returns saved bytes', () async {
      final repository = LocalBusinessIdentityRepository(
        filePath: '${tempDir.path}${Platform.pathSeparator}identity.json',
        logosDirectory: '${tempDir.path}${Platform.pathSeparator}logos',
      );

      final pngBytes = _createMinimalPng(32, 32);
      final metadata = await repository.saveLogoBytes(pngBytes, 'image/png');
      expect(metadata, isNotNull);

      final loaded = await repository.loadLogoBytes(metadata!.managedFileName);
      expect(loaded, isNotNull);
      expect(loaded, pngBytes);
    });

    test('loadLogoBytes returns null for non-existent file', () async {
      final repository = LocalBusinessIdentityRepository(
        filePath: '${tempDir.path}${Platform.pathSeparator}identity.json',
        logosDirectory: '${tempDir.path}${Platform.pathSeparator}logos',
      );

      final loaded = await repository.loadLogoBytes('nonexistent.png');
      expect(loaded, isNull);
    });

    test('loadLogoBytes rejects path traversal', () async {
      final repository = LocalBusinessIdentityRepository(
        filePath: '${tempDir.path}${Platform.pathSeparator}identity.json',
        logosDirectory: '${tempDir.path}${Platform.pathSeparator}logos',
      );

      expect(await repository.loadLogoBytes('../etc/passwd'), isNull);
      expect(await repository.loadLogoBytes('a/b/c.png'), isNull);
      expect(await repository.loadLogoBytes('a\\b\\c.png'), isNull);
    });

    test('deleteLogoFile removes file', () async {
      final repository = LocalBusinessIdentityRepository(
        filePath: '${tempDir.path}${Platform.pathSeparator}identity.json',
        logosDirectory: '${tempDir.path}${Platform.pathSeparator}logos',
      );

      final pngBytes = _createMinimalPng(16, 16);
      final metadata = await repository.saveLogoBytes(pngBytes, 'image/png');
      expect(metadata, isNotNull);

      await repository.deleteLogoFile(metadata!.managedFileName);

      final loaded = await repository.loadLogoBytes(metadata.managedFileName);
      expect(loaded, isNull);
    });

    test('deleteLogoFile rejects path traversal', () async {
      final repository = LocalBusinessIdentityRepository(
        filePath: '${tempDir.path}${Platform.pathSeparator}identity.json',
        logosDirectory: '${tempDir.path}${Platform.pathSeparator}logos',
      );

      // Should not throw
      await repository.deleteLogoFile('../etc/passwd');
      await repository.deleteLogoFile('a/b/c.png');
    });

    test('managedLogosDirectory returns configured path', () async {
      final logosDir = '${tempDir.path}${Platform.pathSeparator}mylogos';
      final repository = LocalBusinessIdentityRepository(
        filePath: '${tempDir.path}${Platform.pathSeparator}identity.json',
        logosDirectory: logosDir,
      );

      expect(repository.managedLogosDirectory, logosDir);
    });

    test('same bytes produce same SHA-256 and filename', () async {
      final repository = LocalBusinessIdentityRepository(
        filePath: '${tempDir.path}${Platform.pathSeparator}identity.json',
        logosDirectory: '${tempDir.path}${Platform.pathSeparator}logos',
      );

      final pngBytes = _createMinimalPng(48, 48);
      final m1 = await repository.saveLogoBytes(pngBytes, 'image/png');
      final m2 = await repository.saveLogoBytes(pngBytes, 'image/png');

      expect(m1, isNotNull);
      expect(m2, isNotNull);
      expect(m1!.managedFileName, m2!.managedFileName);
      expect(m1.sha256, m2.sha256);
    });

    test('saveLogoBytes returns null for empty bytes', () async {
      final repository = LocalBusinessIdentityRepository(
        filePath: '${tempDir.path}${Platform.pathSeparator}identity.json',
        logosDirectory: '${tempDir.path}${Platform.pathSeparator}logos',
      );

      final result = await repository.saveLogoBytes(Uint8List(0), 'image/png');
      expect(result, isNull);
    });
  });

  group('Phase 68 - BusinessIdentityController logo operations', () {
    late Directory tempDir;

    setUp(() async {
      tempDir = await Directory.systemTemp.createTemp('phase68-ctrl-');
    });

    tearDown(() async {
      if (await tempDir.exists()) {
        await tempDir.delete(recursive: true);
      }
    });

    test('saveLogo updates identity and persists logo metadata', () async {
      final repository = LocalBusinessIdentityRepository(
        filePath: '${tempDir.path}${Platform.pathSeparator}identity.json',
        logosDirectory: '${tempDir.path}${Platform.pathSeparator}logos',
      );
      await repository.saveIdentity(
        const BusinessIdentity(establishmentName: 'Test Co'),
      );

      final controller = BusinessIdentityController(repository: repository);
      addTearDown(controller.dispose);
      await controller.initialize();

      expect(controller.identity.hasLogo, isFalse);

      final pngBytes = _createMinimalPng(64, 64);
      await controller.saveLogo(pngBytes, 'image/png');

      expect(controller.identity.hasLogo, isTrue);
      expect(controller.identity.logo!.mimeType, 'image/png');

      final reloaded = await repository.loadIdentity();
      expect(reloaded.hasLogo, isTrue);
    });

    test('removeLogo clears logo from identity', () async {
      final repository = LocalBusinessIdentityRepository(
        filePath: '${tempDir.path}${Platform.pathSeparator}identity.json',
        logosDirectory: '${tempDir.path}${Platform.pathSeparator}logos',
      );

      final pngBytes = _createMinimalPng(32, 32);
      final savedMeta = await repository.saveLogoBytes(pngBytes, 'image/png');
      await repository.saveIdentity(
        BusinessIdentity(
          establishmentName: 'Test',
          logo: savedMeta,
        ),
      );

      final controller = BusinessIdentityController(repository: repository);
      addTearDown(controller.dispose);
      await controller.initialize();

      expect(controller.identity.hasLogo, isTrue);

      await controller.removeLogo();

      expect(controller.identity.hasLogo, isFalse);

      final reloaded = await repository.loadIdentity();
      expect(reloaded.hasLogo, isFalse);
    });
  });

  group('Phase 68 - Backup export with logo', () {
    late Directory sourceDir;

    setUp(() async {
      sourceDir = await Directory.systemTemp.createTemp('phase68-backup-');
    });

    tearDown(() async {
      if (await sourceDir.exists()) {
        await sourceDir.delete(recursive: true);
      }
    });

    test('backup version is 6', () {
      expect(BackupExportService.backupVersion, 8);
    });

    test('backup includes base64-encoded logo in businessIdentity', () async {
      final identityRepository = LocalBusinessIdentityRepository(
        filePath: '${sourceDir.path}${Platform.pathSeparator}identity.json',
        logosDirectory: '${sourceDir.path}${Platform.pathSeparator}logos',
      );

      final pngBytes = _createMinimalPng(64, 64);
      final logoMeta = await identityRepository.saveLogoBytes(
        pngBytes,
        'image/png',
      );
      expect(logoMeta, isNotNull);

      await identityRepository.saveIdentity(
        BusinessIdentity(
          establishmentName: 'شركة اختبار',
          logo: logoMeta,
        ),
      );

      final source = _RepoSet(identityRepository: identityRepository);
      final backup = await source.exportService.createBackup();
      final decoded = jsonDecode(backup.jsonText) as Map<String, Object?>;
      final data = decoded['data'] as Map<String, Object?>;
      final settings = data['settings'] as Map<String, Object?>;
      final identity = settings['businessIdentity'] as Map<String, Object?>;

      expect(identity['establishmentName'], 'شركة اختبار');

      final logo = identity['logo'] as Map<String, Object?>;
      expect(logo['mimeType'], 'image/png');
      expect(logo['base64Data'], isA<String>());

      final decodedBytes = base64Decode(logo['base64Data'] as String);
      expect(decodedBytes, pngBytes);

      expect(logo['sha256'], logoMeta!.sha256);
      expect(logo['byteLength'], pngBytes.length);
    });

    test('backup without logo omits logo payload', () async {
      final identityRepository = LocalBusinessIdentityRepository(
        filePath: '${sourceDir.path}${Platform.pathSeparator}identity.json',
      );
      await identityRepository.saveIdentity(
        const BusinessIdentity(establishmentName: 'بدون شعار'),
      );

      final source = _RepoSet(identityRepository: identityRepository);
      final backup = await source.exportService.createBackup();
      final decoded = jsonDecode(backup.jsonText) as Map<String, Object?>;
      final data = decoded['data'] as Map<String, Object?>;
      final settings = data['settings'] as Map<String, Object?>;
      final identity = settings['businessIdentity'] as Map<String, Object?>;

      expect(identity['logo'], isNull);
    });
  });

  group('Phase 68 - Backup restore with logo', () {
    late Directory sourceDir;
    late Directory targetDir;

    setUp(() async {
      sourceDir = await Directory.systemTemp.createTemp('phase68-rst-src-');
      targetDir = await Directory.systemTemp.createTemp('phase68-rst-dst-');
    });

    tearDown(() async {
      if (await sourceDir.exists()) await sourceDir.delete(recursive: true);
      if (await targetDir.exists()) await targetDir.delete(recursive: true);
    });

    test('restore with valid logo payload restores logo', () async {
      final sourceIdentityRepo = LocalBusinessIdentityRepository(
        filePath: '${sourceDir.path}${Platform.pathSeparator}identity.json',
        logosDirectory: '${sourceDir.path}${Platform.pathSeparator}logos',
      );

      final pngBytes = _createMinimalPng(48, 48);
      final logoMeta = await sourceIdentityRepo.saveLogoBytes(
        pngBytes,
        'image/png',
      );
      await sourceIdentityRepo.saveIdentity(
        BusinessIdentity(
          establishmentName: 'شركة استرجاع',
          logo: logoMeta,
        ),
      );

      final source = _RepoSet(identityRepository: sourceIdentityRepo);
      final backup = await source.exportService.createBackup();

      final targetIdentityRepo = LocalBusinessIdentityRepository(
        filePath: '${targetDir.path}${Platform.pathSeparator}identity.json',
        logosDirectory: '${targetDir.path}${Platform.pathSeparator}logos',
      );
      final target = _RepoSet(identityRepository: targetIdentityRepo);
      final now = DateTime(2026, 7, 10);
      final result = await target.restoreService.restoreToEmpty(
        user: AppUser(
          id: 'owner',
          name: 'المالك',
          phone: '01000000000',
          role: UserRole.owner,
          isActive: true,
          createdAt: now,
          updatedAt: now,
        ),
        jsonText: backup.jsonText,
      );

      expect(result.success, isTrue);
      final restored = await targetIdentityRepo.loadIdentity();
      expect(restored.displayName, 'شركة استرجاع');
      expect(restored.hasLogo, isTrue);
      expect(restored.logo!.mimeType, 'image/png');

      final restoredBytes = await targetIdentityRepo
          .loadLogoBytes(restored.logo!.managedFileName);
      expect(restoredBytes, pngBytes);
    });

    test('restore with corrupted logo data produces warning', () async {
      final identityRepository = LocalBusinessIdentityRepository(
        filePath: '${sourceDir.path}${Platform.pathSeparator}identity.json',
      );
      await identityRepository.saveIdentity(
        const BusinessIdentity(establishmentName: 'Test'),
      );

      final now = DateTime(2026, 7, 10);
      final user = AppUser(
        id: 'owner',
        name: 'المالك',
        phone: '01000000000',
        role: UserRole.owner,
        isActive: true,
        createdAt: now,
        updatedAt: now,
      );

      final backupJson = {
        'metadata': {
          'app': 'grain-warehouse-erp-lite',
          'backupVersion': 3,
          'generatedAt': now.toUtc().toIso8601String(),
          'fileName': 'test.json',
          'restoreSupported': false,
          'warning': 'test',
        },
        'counts': {
          'products': 0,
          'inventoryMovements': 0,
          'suppliers': 0,
          'purchases': 0,
          'sales': 0,
          'documentHistory': 0,
          'customers': 0,
          'customerLedgerEntries': 0,
          'customerCollections': 0,
          'supplierLedgerEntries': 0,
          'supplierPayments': 0,
          'expenses': 0,
          'auditLogs': 0,
        },
        'data': {
          'products': [],
          'inventoryMovements': [],
          'suppliers': [],
          'purchases': [],
          'sales': [],
          'documentHistory': [],
          'customers': [],
          'customerAccountEntries': [],
          'customerCollections': [],
          'supplierAccountEntries': [],
          'supplierPayments': [],
          'expenses': [],
          'auditLogs': [],
          'settings': {
            'businessIdentity': {
              'establishmentName': 'Test',
              'logo': {
                'mimeType': 'image/png',
                'base64Data': '!!!INVALID_BASE64!!!',
                'sha256': 'fakehash',
                'byteLength': 100,
                'width': 0,
                'height': 0,
              },
            },
          },
        },
        'checksum': '00000000',
        'checksumNote': 'test',
      };

      final targetIdentityRepo = LocalBusinessIdentityRepository(
        filePath: '${targetDir.path}${Platform.pathSeparator}identity.json',
        logosDirectory: '${targetDir.path}${Platform.pathSeparator}logos',
      );
      final target = _RepoSet(identityRepository: targetIdentityRepo);
      final result = await target.restoreService.restoreToEmpty(
        user: user,
        jsonText: jsonEncode(backupJson),
      );

      expect(result.success, isTrue);
      final restored = await targetIdentityRepo.loadIdentity();
      expect(restored.hasLogo, isFalse);
      expect(result.warnings, isNotEmpty);
      expect(
        result.warnings.any((w) => w.contains('شعار')),
        isTrue,
      );
    });

    test('restore with unsupported MIME type produces warning', () async {
      final identityRepository = LocalBusinessIdentityRepository(
        filePath: '${sourceDir.path}${Platform.pathSeparator}identity.json',
      );
      await identityRepository.saveIdentity(
        const BusinessIdentity(establishmentName: 'Test'),
      );

      final now = DateTime(2026, 7, 10);
      final user = AppUser(
        id: 'owner',
        name: 'المالك',
        phone: '01000000000',
        role: UserRole.owner,
        isActive: true,
        createdAt: now,
        updatedAt: now,
      );

      final backupJson = {
        'metadata': {
          'app': 'grain-warehouse-erp-lite',
          'backupVersion': 3,
          'generatedAt': now.toUtc().toIso8601String(),
          'fileName': 'test.json',
          'restoreSupported': false,
          'warning': 'test',
        },
        'counts': {
          'products': 0,
          'inventoryMovements': 0,
          'suppliers': 0,
          'purchases': 0,
          'sales': 0,
          'documentHistory': 0,
          'customers': 0,
          'customerLedgerEntries': 0,
          'customerCollections': 0,
          'supplierLedgerEntries': 0,
          'supplierPayments': 0,
          'expenses': 0,
          'auditLogs': 0,
        },
        'data': {
          'products': [],
          'inventoryMovements': [],
          'suppliers': [],
          'purchases': [],
          'sales': [],
          'documentHistory': [],
          'customers': [],
          'customerAccountEntries': [],
          'customerCollections': [],
          'supplierAccountEntries': [],
          'supplierPayments': [],
          'expenses': [],
          'auditLogs': [],
          'settings': {
            'businessIdentity': {
              'establishmentName': 'Test',
              'logo': {
                'mimeType': 'image/gif',
                'base64Data': base64Encode(Uint8List.fromList([1, 2, 3])),
                'sha256': 'abc',
                'byteLength': 3,
                'width': 0,
                'height': 0,
              },
            },
          },
        },
        'checksum': '00000000',
        'checksumNote': 'test',
      };

      final targetIdentityRepo = LocalBusinessIdentityRepository(
        filePath: '${targetDir.path}${Platform.pathSeparator}identity.json',
        logosDirectory: '${targetDir.path}${Platform.pathSeparator}logos',
      );
      final target = _RepoSet(identityRepository: targetIdentityRepo);
      final result = await target.restoreService.restoreToEmpty(
        user: user,
        jsonText: jsonEncode(backupJson),
      );

      expect(result.success, isTrue);
      final restored = await targetIdentityRepo.loadIdentity();
      expect(restored.hasLogo, isFalse);
    });

    test('restore v2 backup without logo still works', () async {
      final identityRepository = LocalBusinessIdentityRepository(
        filePath: '${sourceDir.path}${Platform.pathSeparator}identity.json',
      );
      await identityRepository.saveIdentity(
        const BusinessIdentity(establishmentName: 'اختبار v2'),
      );

      final source = _RepoSet(identityRepository: identityRepository);
      final backup = await source.exportService.createBackup();

      final targetIdentityRepo = LocalBusinessIdentityRepository(
        filePath: '${targetDir.path}${Platform.pathSeparator}identity.json',
      );
      final target = _RepoSet(identityRepository: targetIdentityRepo);
      final now = DateTime(2026, 7, 10);
      final result = await target.restoreService.restoreToEmpty(
        user: AppUser(
          id: 'owner',
          name: 'المالك',
          phone: '01000000000',
          role: UserRole.owner,
          isActive: true,
          createdAt: now,
          updatedAt: now,
        ),
        jsonText: backup.jsonText,
      );

      expect(result.success, isTrue);
      final restored = await targetIdentityRepo.loadIdentity();
      expect(restored.displayName, 'اختبار v2');
    });
  });

  group('Phase 68 - Invoice PDF builders accept logo', () {
    testWidgets('sales invoice shows establishment name without crashing',
        (tester) async {
      final identityController = BusinessIdentityController(
        repository: _MemoryBusinessIdentityRepository(
          const BusinessIdentity(establishmentName: 'شركة الفواتير'),
        ),
      );
      addTearDown(identityController.dispose);
      await identityController.initialize();

      final sale = SaleRecord(
        id: 'SALE-68',
        productId: 'p1',
        quantityKg: 50,
        salePriceQirshPerKg: 800,
        totalQirsh: 40000,
        createdByUserId: 'owner',
        createdAt: DateTime(2026, 7, 10, 14),
        stockMovementId: 'sm-68',
        customerId: 'c1',
      );

      await tester.pumpWidget(
        BusinessIdentityScope(
          controller: identityController,
          child: MaterialApp(
            theme: AppTheme.light,
            home: Scaffold(
              body: PrintableSalesInvoiceView(
                sale: sale,
                customerName: 'عميل اختبار',
                productNames: const {'p1': 'قمح'},
              ),
            ),
          ),
        ),
      );

      expect(find.text('شركة الفواتير'), findsOneWidget);
      expect(find.text('فاتورة بيع'), findsOneWidget);
    });

    testWidgets('AppBar logo widget renders without error', (tester) async {
      final identityController = BusinessIdentityController(
        repository: _MemoryBusinessIdentityRepository(
          const BusinessIdentity(establishmentName: 'Test'),
        ),
      );
      addTearDown(identityController.dispose);
      await identityController.initialize();

      await tester.pumpWidget(
        BusinessIdentityScope(
          controller: identityController,
          child: MaterialApp(
            theme: AppTheme.light,
            home: const Scaffold(
              body: Center(child: Text('content')),
            ),
          ),
        ),
      );

      expect(find.text('content'), findsOneWidget);
    });
  });

  group('Phase 68 - ICO generation script', () {
    test('PS1 script file exists', () {
      final projectDir = _findProjectRoot();
      if (projectDir != null) {
        final toolScript = File(
          '${projectDir.path}${Platform.pathSeparator}tool${Platform.pathSeparator}create_windows_app_icon.ps1',
        );
        expect(toolScript.existsSync(), isTrue);
      }
    });

    test('PS1 script accepts -SourceImage parameter', () {
      final projectDir = _findProjectRoot();
      if (projectDir != null) {
        final toolScript = File(
          '${projectDir.path}${Platform.pathSeparator}tool${Platform.pathSeparator}create_windows_app_icon.ps1',
        );
        if (toolScript.existsSync()) {
          final content = toolScript.readAsStringSync();
          expect(content, contains('param('));
          expect(content, contains('SourceImage'));
          expect(content, contains('OutputPath'));
        }
      }
    });

    test('PS1 script generates ICO from PNG source', () async {
      final projectDir = _findProjectRoot();
      if (projectDir == null) return;

      final tempDir = await Directory.systemTemp.createTemp('phase68-ico-');
      addTearDown(() => tempDir.delete(recursive: true));

      final sourcePng =
          File('${tempDir.path}${Platform.pathSeparator}source.png');
      await sourcePng.writeAsBytes(_createMinimalPng(256, 256));

      final outputIco =
          File('${tempDir.path}${Platform.pathSeparator}output.ico');

      final scriptPath =
          '${projectDir.path}${Platform.pathSeparator}tool${Platform.pathSeparator}create_windows_app_icon.ps1';

      final result = await Process.run(
        'powershell.exe',
        [
          '-NoProfile',
          '-ExecutionPolicy',
          'Bypass',
          '-File',
          scriptPath,
          '-SourceImage',
          sourcePng.path,
          '-OutputPath',
          outputIco.path,
        ],
        workingDirectory: projectDir.path,
      );

      if (result.exitCode == 0 && outputIco.existsSync()) {
        final icoBytes = await outputIco.readAsBytes();
        expect(icoBytes.length, greaterThan(6));

        // ICO header: reserved (2) + type (2) + count (2)
        expect(icoBytes[0], 0); // reserved
        expect(icoBytes[1], 0); // reserved
        expect(icoBytes[2], 1); // type low byte = ICO
        expect(icoBytes[3], 0); // type high byte

        final count = icoBytes[4] | (icoBytes[5] << 8);
        expect(count, greaterThanOrEqualTo(1));
        expect(count, lessThanOrEqualTo(6));
      }
    });

    test('PS1 script rejects non-PNG/JPEG input', () async {
      final projectDir = _findProjectRoot();
      if (projectDir == null) return;

      final tempDir = await Directory.systemTemp.createTemp('phase68-ico-');
      addTearDown(() => tempDir.delete(recursive: true));

      final sourceBmp =
          File('${tempDir.path}${Platform.pathSeparator}source.bmp');
      await sourceBmp.writeAsBytes(Uint8List(100));

      final scriptPath =
          '${projectDir.path}${Platform.pathSeparator}tool${Platform.pathSeparator}create_windows_app_icon.ps1';

      final result = await Process.run(
        'powershell.exe',
        [
          '-NoProfile',
          '-ExecutionPolicy',
          'Bypass',
          '-File',
          scriptPath,
          '-SourceImage',
          sourceBmp.path,
        ],
        workingDirectory: projectDir.path,
      );

      // Should fail with exit code 1
      expect(result.exitCode, isNot(0));
    });

    test('PS1 script -Help shows usage', () async {
      final projectDir = _findProjectRoot();
      if (projectDir == null) return;

      final scriptPath =
          '${projectDir.path}${Platform.pathSeparator}tool${Platform.pathSeparator}create_windows_app_icon.ps1';

      final result = await Process.run(
        'powershell.exe',
        [
          '-NoProfile',
          '-ExecutionPolicy',
          'Bypass',
          '-File',
          scriptPath,
          '-Help',
        ],
        workingDirectory: projectDir.path,
      );

      final output = '${result.stdout}${result.stderr}';
      expect(output, contains('SourceImage'));
    });
  });

  group('Phase 68 - Settings UI logo section', () {
    testWidgets('BusinessIdentityScope provides controller to descendants',
        (tester) async {
      final identityController = BusinessIdentityController(
        repository: _MemoryBusinessIdentityRepository(
          const BusinessIdentity(establishmentName: 'نظام اختبار'),
        ),
      );
      addTearDown(identityController.dispose);
      await identityController.initialize();

      await tester.pumpWidget(
        BusinessIdentityScope(
          controller: identityController,
          child: MaterialApp(
            theme: AppTheme.light,
            home: Builder(
              builder: (context) {
                final ctrl = BusinessIdentityScope.of(context);
                return Scaffold(
                  body: Text(ctrl.identity.displayName),
                );
              },
            ),
          ),
        ),
      );

      expect(find.text('نظام اختبار'), findsOneWidget);
    });
  });
}

/// Creates a minimal valid 1x1 transparent PNG for testing.
Uint8List _createMinimalPng(int width, int height) {
  // Minimal PNG: IHDR chunk with specified dimensions, single transparent pixel
  final pngSignature = Uint8List.fromList([
    0x89,
    0x50,
    0x4E,
    0x47,
    0x0D,
    0x0A,
    0x1A,
    0x0A,
  ]);

  // IHDR chunk
  final ihdrData = ByteData(13);
  ihdrData.setUint32(0, width); // width
  ihdrData.setUint32(4, height); // height
  ihdrData.setUint8(8, 8); // bit depth
  ihdrData.setUint8(9, 6); // color type (RGBA)
  ihdrData.setUint8(10, 0); // compression
  ihdrData.setUint8(11, 0); // filter
  ihdrData.setUint8(12, 0); // interlace

  final ihdrBytes = ihdrData.buffer.asUint8List();
  final ihdrCrc = _crc32(_concatenate(
    Uint8List.fromList([0x49, 0x48, 0x44, 0x52]), // "IHDR"
    ihdrBytes,
  ));

  final ihdrChunk = _concatenate(
    Uint8List.fromList([0, 0, 0, 13]), // length
    Uint8List.fromList([0x49, 0x48, 0x44, 0x52]), // "IHDR"
    ihdrBytes,
    ihdrCrc,
  );

  // IDAT chunk with minimal compressed data (single transparent pixel repeated)
  final rawData = <int>[];
  for (var y = 0; y < height; y++) {
    rawData.add(0); // filter byte (none)
    for (var x = 0; x < width; x++) {
      rawData.addAll([0, 0, 0, 0]); // RGBA: transparent
    }
  }

  // Simple zlib compression
  final compressed = _zlibCompress(Uint8List.fromList(rawData));
  final idatCrc = _crc32(_concatenate(
    Uint8List.fromList([0x49, 0x44, 0x41, 0x54]), // "IDAT"
    compressed,
  ));

  final idatChunk = _concatenate(
    _uint32ToBytes(compressed.length),
    Uint8List.fromList([0x49, 0x44, 0x41, 0x54]), // "IDAT"
    compressed,
    idatCrc,
  );

  // IEND chunk
  final iendCrc = _crc32(Uint8List.fromList([0x49, 0x45, 0x4E, 0x44]));
  final iendChunk = _concatenate(
    Uint8List.fromList([0, 0, 0, 0]),
    Uint8List.fromList([0x49, 0x45, 0x4E, 0x44]),
    iendCrc,
  );

  return _concatenate(pngSignature, ihdrChunk, idatChunk, iendChunk);
}

Uint8List _concatenate(List<int> a, List<int> b, [List<int>? c, List<int>? d]) {
  final total = a.length + b.length + (c?.length ?? 0) + (d?.length ?? 0);
  final result = Uint8List(total);
  var offset = 0;
  result.setRange(offset, offset + a.length, a);
  offset += a.length;
  result.setRange(offset, offset + b.length, b);
  offset += b.length;
  if (c != null) {
    result.setRange(offset, offset + c.length, c);
    offset += c.length;
  }
  if (d != null) {
    result.setRange(offset, offset + d.length, d);
  }
  return result;
}

Uint8List _uint32ToBytes(int value) {
  return Uint8List.fromList([
    (value >> 24) & 0xFF,
    (value >> 16) & 0xFF,
    (value >> 8) & 0xFF,
    value & 0xFF,
  ]);
}

Uint8List _crc32(List<int> data) {
  var crc = 0xFFFFFFFF;
  for (final byte in data) {
    crc ^= byte;
    for (var i = 0; i < 8; i++) {
      if ((crc & 1) != 0) {
        crc = (crc >> 1) ^ 0xEDB88320;
      } else {
        crc >>= 1;
      }
    }
  }
  crc ^= 0xFFFFFFFF;
  return _uint32ToBytes(crc);
}

Uint8List _zlibCompress(Uint8List data) {
  // Minimal zlib: CMF=0x78, FLG=0x01 (no dict, level 0)
  // Then stored (uncompressed) blocks
  final blocks = <int>[];
  var offset = 0;

  while (offset < data.length) {
    final remaining = data.length - offset;
    final chunkSize = remaining > 65535 ? 65535 : remaining;
    final isLast = offset + chunkSize >= data.length;

    blocks.add(isLast ? 0x01 : 0x00); // BFINAL + BTYPE=00 (stored)
    blocks.addAll([
      chunkSize & 0xFF,
      (chunkSize >> 8) & 0xFF,
      (~chunkSize) & 0xFF,
      ((~chunkSize) >> 8) & 0xFF,
    ]);
    blocks.addAll(data.sublist(offset, offset + chunkSize));
    offset += chunkSize;
  }

  final result = Uint8List(2 + blocks.length + 4);
  result[0] = 0x78; // CMF
  result[1] = 0x01; // FLG
  result.setRange(2, 2 + blocks.length, blocks);

  // Adler-32 checksum
  var a = 1;
  var b = 0;
  for (final byte in data) {
    a = (a + byte) % 65521;
    b = (b + a) % 65521;
  }
  final adler = (b << 16) | a;
  result[result.length - 4] = (adler >> 24) & 0xFF;
  result[result.length - 3] = (adler >> 16) & 0xFF;
  result[result.length - 2] = (adler >> 8) & 0xFF;
  result[result.length - 1] = adler & 0xFF;

  return result;
}

Directory? _findProjectRoot() {
  var dir = Directory.current;
  for (var i = 0; i < 5; i++) {
    final pubspec = File('${dir.path}${Platform.pathSeparator}pubspec.yaml');
    if (pubspec.existsSync()) {
      final content = pubspec.readAsStringSync();
      if (content.contains('grain_warehouse_erp_lite')) {
        return dir;
      }
    }
    dir = dir.parent;
  }
  return null;
}

class _MemoryBusinessIdentityRepository implements BusinessIdentityRepository {
  _MemoryBusinessIdentityRepository(this._identity);

  BusinessIdentity _identity;

  @override
  Future<BusinessIdentity> loadIdentity() async => _identity;

  @override
  Future<void> saveIdentity(BusinessIdentity identity) async {
    _identity = identity;
  }

  @override
  Future<LogoMetadata?> saveLogoBytes(Uint8List bytes, String mimeType) async {
    return null;
  }

  @override
  Future<Uint8List?> loadLogoBytes(String managedFileName) async {
    return null;
  }

  @override
  Future<void> deleteLogoFile(String managedFileName) async {}

  @override
  String get managedLogosDirectory => '';
}

class _RepoSet {
  _RepoSet({required this.identityRepository})
      : auditLogRepository = LocalAuditLogRepository(),
        productRepository = LocalProductRepository(),
        supplierRepository = LocalSupplierRepository(),
        customerRepository = LocalCustomerRepository(),
        expenseRepository = LocalExpenseRepository() {
    inventoryRepository =
        LocalInventoryRepository(productRepository: productRepository);
    customerAccountRepository = LocalCustomerAccountRepository(
      customerRepository: customerRepository,
      auditLogRepository: auditLogRepository,
    );
    supplierAccountRepository = LocalSupplierAccountRepository(
      supplierRepository: supplierRepository,
      auditLogRepository: auditLogRepository,
    );
    purchaseRepository = LocalPurchaseRepository(
      supplierRepository: supplierRepository,
      productRepository: productRepository,
      inventoryRepository: inventoryRepository,
      supplierAccountRepository: supplierAccountRepository,
    );
    saleRepository = LocalSaleRepository(
      productRepository: productRepository,
      inventoryRepository: inventoryRepository,
    );
    documentHistoryRepository = LocalDocumentHistoryRepository(
      purchaseRepository: purchaseRepository,
      saleRepository: saleRepository,
      productRepository: productRepository,
      inventoryRepository: inventoryRepository,
    );
  }

  final LocalBusinessIdentityRepository identityRepository;
  final LocalAuditLogRepository auditLogRepository;
  final LocalProductRepository productRepository;
  final LocalSupplierRepository supplierRepository;
  final LocalCustomerRepository customerRepository;
  final LocalExpenseRepository expenseRepository;
  late final LocalInventoryRepository inventoryRepository;
  late final LocalCustomerAccountRepository customerAccountRepository;
  late final LocalSupplierAccountRepository supplierAccountRepository;
  late final LocalPurchaseRepository purchaseRepository;
  late final LocalSaleRepository saleRepository;
  late final LocalDocumentHistoryRepository documentHistoryRepository;

  BackupExportService get exportService => BackupExportService(
        businessIdentityRepository: identityRepository,
        productRepository: productRepository,
        inventoryRepository: inventoryRepository,
        supplierRepository: supplierRepository,
        purchaseRepository: purchaseRepository,
        saleRepository: saleRepository,
        documentHistoryRepository: documentHistoryRepository,
        customerRepository: customerRepository,
        customerAccountRepository: customerAccountRepository,
        supplierAccountRepository: supplierAccountRepository,
        expenseRepository: expenseRepository,
        auditLogRepository: auditLogRepository,
      );

  BackupRestoreService get restoreService => BackupRestoreService(
        businessIdentityRepository: identityRepository,
        productRepository: productRepository,
        inventoryRepository: inventoryRepository,
        supplierRepository: supplierRepository,
        purchaseRepository: purchaseRepository,
        saleRepository: saleRepository,
        documentHistoryRepository: documentHistoryRepository,
        customerRepository: customerRepository,
        customerAccountRepository: customerAccountRepository,
        supplierAccountRepository: supplierAccountRepository,
        expenseRepository: expenseRepository,
        auditLogRepository: auditLogRepository,
      );
}
