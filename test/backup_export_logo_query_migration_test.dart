import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:grain_warehouse_erp_lite/app/app_repositories.dart';
import 'package:grain_warehouse_erp_lite/application/queries/load_business_logo_query.dart';
import 'package:grain_warehouse_erp_lite/core/backup/backup_checksum.dart';
import 'package:grain_warehouse_erp_lite/core/backup/backup_export.dart';
import 'package:grain_warehouse_erp_lite/core/business_identity/business_identity.dart';
import 'package:grain_warehouse_erp_lite/core/business_identity/business_identity_repository.dart';
import 'package:grain_warehouse_erp_lite/core/catalog/product_repository.dart';
import 'package:grain_warehouse_erp_lite/core/documents/document_history.dart';
import 'package:grain_warehouse_erp_lite/core/inventory/inventory_repository.dart';
import 'package:grain_warehouse_erp_lite/core/inventory_valuation/inventory_valuation_repository.dart';
import 'package:grain_warehouse_erp_lite/core/purchases/purchase_repository.dart';
import 'package:grain_warehouse_erp_lite/core/sales/sale_repository.dart';
import 'package:grain_warehouse_erp_lite/core/suppliers/supplier_repository.dart';

import 'support/product_catalog_read_repository_test_adapter.dart';

final _bytes = Uint8List.fromList([0, 255, 17, 128, 42]);
final _time = DateTime(2026, 1, 2, 3, 4, 5);
const _fileName = 'grain-warehouse-backup-20260102-030405.json';
const _managedName = 'opaque-logo.bin';

void main() {
  test(
      'T1/T3 explicit canonical query owns the sole read and embeds exact bytes',
      () async {
    final identity = _identity();
    final a = _Spy(identity: identity, bytes: Uint8List.fromList([99]));
    final b = _Spy(bytes: _bytes);
    final result = await _service(a: a, b: b).createBackup();
    _expectEmbedded(result, identity);
    expect(a.identityReads, 1);
    expect(a.names, isEmpty);
    expect(b.identityReads, 0);
    expect(b.names, [_managedName]);
    _expectNoWrites([a, b]);
  });

  for (final invalid in <String, LogoMetadata?>{
    'absent logo': null,
    'empty filename': _metadata(name: ''),
    'empty MIME': _metadata(mime: ''),
    'empty hash': _metadata(hash: ''),
    'zero declared length': _metadata(length: 0),
    'negative declared length': _metadata(length: -1),
  }.entries) {
    test('T4 ${invalid.key} preserves original JSON without querying',
        () async {
      final identity = _identity(logo: invalid.value, useDefaultLogo: false);
      final a = _Spy(identity: identity);
      final b = _Spy(bytes: _bytes);
      final result = await _service(a: a, b: b).createBackup();
      expect(_exportedIdentity(result), identity.toJson());
      expect(a.identityReads, 1);
      expect(a.names, isEmpty);
      expect(b.names, isEmpty);
      _expectNoWrites([a, b]);
    });
  }

  for (final outcome in ['null', 'empty', 'hash mismatch', 'exception']) {
    test('T4/T11 $outcome preserves metadata with one read and no retry',
        () async {
      final identity = _identity();
      final a = _Spy(identity: identity);
      final b = _Spy(
        bytes: outcome == 'empty'
            ? Uint8List(0)
            : outcome == 'hash mismatch'
                ? Uint8List.fromList([1])
                : null,
        logoError: outcome == 'exception' ? StateError('logo sentinel') : null,
      );
      final result = await _service(a: a, b: b).createBackup();
      expect(_exportedIdentity(result), identity.toJson());
      expect(b.names, [_managedName]);
      expect(a.names, isEmpty);
      expect(result.checksum, BackupChecksum.computeEnvelope(_decode(result)));
      _expectNoWrites([a, b]);
    });
  }

  test('T3 declared length and invalid dimensions do not validate opaque bytes',
      () async {
    final identity = _identity(
      logo: _metadata(length: 999, width: -12, height: 0),
    );
    final a = _Spy(identity: identity);
    final b = _Spy(bytes: _bytes);
    _expectEmbedded(await _service(a: a, b: b).createBackup(), identity);
    expect(b.names, [_managedName]);
    _expectNoWrites([a, b]);
  });

  test(
      'T8 omitted handler retains logo through canonical compatibility default',
      () async {
    final a = _Spy(identity: _identity(), bytes: _bytes);
    final service = _service(a: a);
    expect(a.names, isEmpty);
    _expectEmbedded(await service.createBackup(), a.identity);
    expect(a.identityReads, 1);
    expect(a.names, [_managedName]);
    _expectNoWrites([a]);
  });

  for (final explicitHandler in [false, true]) {
    test('T4/T8 absent repository, explicit handler=$explicitHandler',
        () async {
      final b = _Spy(bytes: _bytes);
      final result =
          await _service(b: explicitHandler ? b : null).createBackup();
      expect(_exportedIdentity(result), BusinessIdentity.empty.toJson());
      expect(_exportedIdentity(result).containsKey('logo'), isFalse);
      expect(b.names, isEmpty);
      expect(b.identityReads, 0);
      _expectNoWrites([b]);
    });
  }

  test('T9 awaits logo before checksum; each export performs a fresh read',
      () async {
    final release = Completer<Uint8List?>();
    final a = _Spy(identity: _identity());
    final b = _Spy(pending: release.future);
    final service = _service(a: a, b: b);
    var completed = false;
    final pending = service.createBackup().then((result) {
      completed = true;
      return result;
    });
    await b.started.future;
    await Future<void>.delayed(Duration.zero);
    expect(completed, isFalse);
    expect(b.names, [_managedName]);
    release.complete(_bytes);
    final first = await pending;
    _expectEmbedded(first, a.identity);
    expect(first.checksum, BackupChecksum.computeEnvelope(_decode(first)));
    final second = await service.createBackup();
    expect(second.jsonText, first.jsonText);
    expect(b.names, [_managedName, _managedName]);
    expect(a.identityReads, 2);
    _expectNoWrites([a, b]);
  });

  test('T11 identity failure propagates unchanged before any logo execution',
      () async {
    final sentinel = StateError('identity sentinel');
    final a = _Spy(identity: _identity(), identityError: sentinel);
    final b = _Spy(bytes: _bytes);
    await expectLater(
        _service(a: a, b: b).createBackup(), throwsA(same(sentinel)));
    expect(a.identityReads, 1);
    expect(a.names, isEmpty);
    expect(b.names, isEmpty);
    _expectNoWrites([a, b]);
  });

  test('T5 exact empty version 8 envelope, order, checksum and JSON encoding',
      () async {
    final result = await _service().createBackup();
    final expectedPayload = <String, Object?>{
      'metadata': {
        'app': 'grain-warehouse-erp-lite',
        'backupVersion': 8,
        'generatedAt': _time.toUtc().toIso8601String(),
        'fileName': _fileName,
        'restoreSupported': false,
        'warning':
            'هذه نسخة احتياطية للتصدير والحفظ. يمكن استرجاعها فقط إلى نظام فارغ بعد فحصها.',
      },
      'counts': {for (final key in _countKeys) key: 0},
      'data': {
        for (final key in _collectionKeys) key: <Object?>[],
        'profitabilityActivation': {
          'status': 'profitabilityNotActivated',
          'activationDate': null,
          'approvedAt': null,
          'approvedByUserId': null,
          'evidenceNote': null,
        },
        'inventoryValuationStates': <Object?>[],
        'inventoryValuationEvents': <Object?>[],
        'settings': {
          'businessIdentity': {'establishmentName': null},
        },
      },
    };
    final checksum = BackupChecksum.computePayload(expectedPayload);
    final expected = {
      ...expectedPayload,
      'checksum': checksum,
      'checksumNote': 'فحص بسيط لاكتشاف تلف النسخ، وليس ميزة تشفير أو حماية.',
    };
    expect(_decode(result), expected);
    expect(
        result.jsonText, const JsonEncoder.withIndent('  ').convert(expected));
    expect(result.counts.toJson(), expectedPayload['counts']);
    expect(result.backupVersion, 8);
    expect(result.generatedAt, _time);
    expect(result.fileName, _fileName);
    expect(result.checksum, checksum);
    expect(utf8.decode(utf8.encode(result.jsonText)), result.jsonText);
    BackupExportValidator.validateJsonText(result.jsonText);
  });

  test(
      'T10 production factory uses the current owned identity store, no writes',
      () async {
    final previous = AppRepositories.businessIdentityRepository;
    addTearDown(() => AppRepositories.businessIdentityRepository = previous);
    final first = _Spy(identity: _identity(), bytes: _bytes);
    AppRepositories.businessIdentityRepository = first;
    _expectEmbedded(
      await AppRepositories.backupExportService.createBackup(),
      first.identity,
    );
    expect(first.identityReads, 1);
    expect(first.names, [_managedName]);
    final second = _Spy(identity: _identity(), bytes: _bytes);
    AppRepositories.businessIdentityRepository = second;
    _expectEmbedded(
      await AppRepositories.backupExportService.createBackup(),
      second.identity,
    );
    expect(first.names, [_managedName]);
    expect(second.identityReads, 1);
    expect(second.names, [_managedName]);
    _expectNoWrites([first, second]);
  });

  test(
      'T2/T10 whole-lib ownership rejects direct calls, tear-offs and locators',
      () {
    final lib = Directory('lib')
        .listSync(recursive: true)
        .whereType<File>()
        .where((file) => file.path.endsWith('.dart'));
    final memberReferences = RegExp(r'\.\s*loadLogoBytes\b');
    final symbol = RegExp(r'\bloadLogoBytes\b');
    final callers = <String>[];
    final symbolFiles = <String>{};
    for (final file in lib) {
      final source = file.readAsStringSync();
      final path = file.path.replaceAll('\\', '/');
      for (final _ in memberReferences.allMatches(source)) {
        callers.add(path);
      }
      if (symbol.hasMatch(source)) symbolFiles.add(path);
    }
    expect(callers, ['lib/application/queries/load_business_logo_query.dart']);
    expect(symbolFiles, {
      'lib/application/queries/load_business_logo_query.dart',
      'lib/core/business_identity/business_identity_repository.dart',
    });
    final source =
        File('lib/core/backup/backup_export.dart').readAsStringSync();
    expect(source, isNot(contains('loadLogoBytes')));
    for (final forbidden in [
      'AppRepositories',
      'ApplicationScope',
      'BuildContext',
      'app_repositories.dart',
      'application_scope.dart',
      'LocalBusinessIdentityRepository',
    ]) {
      expect(source, isNot(contains(forbidden)), reason: forbidden);
    }
    expect(RegExp(r'businessLogoQuery\.execute\(').allMatches(source),
        hasLength(1));
    expect(RegExp(r'LoadBusinessLogoQuery\(').allMatches(source), hasLength(1));
    expect(source, contains('final logoBytes = result.value;'));
    expect(source,
        contains('final LoadBusinessLogoQueryHandler? _businessLogoQuery;'));
    expect(source, contains('_businessLogoQuery = businessLogoQuery ??'));
    expect(
        source, contains('await _businessIdentityRepository?.loadIdentity()'));
    final factory = File('lib/app/app_repositories.dart').readAsStringSync();
    final start =
        factory.indexOf('static BackupExportService get backupExportService');
    final end = factory.indexOf('static DurablePurchaseRepository', start);
    final wiring = factory.substring(start, end);
    expect(wiring,
        contains('businessIdentityRepository: businessIdentityRepository,'));
    expect(
        wiring,
        matches(RegExp(
            r'businessLogoQuery:\s*LoadBusinessLogoQueryHandler\(\s*repository:\s*businessIdentityRepository,')));
  });
}

LogoMetadata _metadata(
        {String name = _managedName,
        String mime = 'image/png',
        String? hash,
        int? length,
        int width = 24,
        int height = 18}) =>
    LogoMetadata(
      managedFileName: name,
      mimeType: mime,
      sha256: hash ?? sha256.convert(_bytes).toString(),
      byteLength: length ?? _bytes.length,
      width: width,
      height: height,
    );

BusinessIdentity _identity({LogoMetadata? logo, bool useDefaultLogo = true}) =>
    BusinessIdentity(
        establishmentName: '  Grain warehouse  ',
        taxNumber: ' 123 ',
        address: '',
        phone: ' 010 ',
        logo: logo ?? (useDefaultLogo ? _metadata() : null));

Map<String, Object?> _decode(BackupExportResult result) =>
    jsonDecode(result.jsonText) as Map<String, Object?>;

Map<String, Object?> _exportedIdentity(BackupExportResult result) =>
    ((_decode(result)['data'] as Map<String, Object?>)['settings']
        as Map<String, Object?>)['businessIdentity'] as Map<String, Object?>;

void _expectEmbedded(BackupExportResult result, BusinessIdentity identity) {
  final expected = <String, Object?>{
    ...identity.toJson(),
    'logo': {
      'mimeType': identity.logo!.mimeType,
      'base64Data': base64Encode(_bytes),
      'sha256': sha256.convert(_bytes).toString(),
      'byteLength': _bytes.length,
      'width': identity.logo!.width,
      'height': identity.logo!.height,
    },
  };
  final actual = _exportedIdentity(result);
  expect(actual, expected);
  final logo = actual['logo'] as Map<String, Object?>;
  expect(logo.keys.toList(),
      ['mimeType', 'base64Data', 'sha256', 'byteLength', 'width', 'height']);
  expect(base64Decode(logo['base64Data'] as String), orderedEquals(_bytes));
  expect(logo.containsKey('managedFileName'), isFalse);
}

void _expectNoWrites(List<_Spy> spies) {
  for (final spy in spies) {
    expect(spy.writes, 0);
  }
}

BackupExportService _service({_Spy? a, _Spy? b}) {
  final products = LocalProductRepository();
  final catalog = ProductCatalogReadRepositoryTestAdapter(products);
  final suppliers = LocalSupplierRepository();
  final inventory = LocalInventoryRepository(productRepository: products);
  final valuation = LocalInventoryValuationRepository();
  final purchases = LocalPurchaseRepository(
      supplierRepository: suppliers,
      productRepository: products,
      inventoryRepository: inventory,
      inventoryValuationRepository: valuation);
  final sales = LocalSaleRepository(
      productCatalogReadRepository: catalog,
      inventoryRepository: inventory,
      inventoryValuationRepository: valuation);
  return BackupExportService(
      productCatalogReadRepository: catalog,
      supplierRepository: suppliers,
      inventoryRepository: inventory,
      purchaseRepository: purchases,
      saleRepository: sales,
      documentHistoryRepository: LocalDocumentHistoryRepository(
          purchaseRepository: purchases,
          saleRepository: sales,
          productCatalogReadRepository: catalog,
          inventoryRepository: inventory),
      inventoryValuationRepository: valuation,
      businessIdentityRepository: a,
      businessLogoQuery:
          b == null ? null : LoadBusinessLogoQueryHandler(repository: b),
      now: () => _time);
}

class _Spy extends LocalBusinessIdentityRepository {
  _Spy(
      {this.identity = BusinessIdentity.empty,
      this.bytes,
      this.identityError,
      this.logoError,
      this.pending});
  final BusinessIdentity identity;
  final Uint8List? bytes;
  final Object? identityError;
  final Object? logoError;
  final Future<Uint8List?>? pending;
  final started = Completer<void>();
  int identityReads = 0;
  int writes = 0;
  final names = <String>[];

  @override
  Future<BusinessIdentity> loadIdentity() async {
    identityReads++;
    if (identityError != null) throw identityError!;
    return identity;
  }

  @override
  Future<Uint8List?> loadLogoBytes(String managedFileName) async {
    names.add(managedFileName);
    if (!started.isCompleted) started.complete();
    if (logoError != null) throw logoError!;
    return pending != null ? await pending : bytes;
  }

  @override
  Future<void> saveIdentity(BusinessIdentity identity) async {
    writes++;
  }

  @override
  Future<LogoMetadata?> saveLogoBytes(Uint8List bytes, String mimeType) async {
    writes++;
    return null;
  }

  @override
  Future<void> deleteLogoFile(String managedFileName) async {
    writes++;
  }
}

const _countKeys = [
  'products',
  'inventoryMovements',
  'suppliers',
  'purchases',
  'sales',
  'documentHistory',
  'customers',
  'customerLedgerEntries',
  'customerCollections',
  'supplierLedgerEntries',
  'supplierPayments',
  'expenses',
  'auditLogs',
  'financialAccounts',
  'financialAccountEntries',
  'financialTransfers',
  'financialClosings',
  'negativeBalanceApprovalRequests',
  'negativeBalanceApprovalRequestTransitions',
];
const _collectionKeys = [
  'products',
  'inventoryMovements',
  'suppliers',
  'purchases',
  'sales',
  'documentHistory',
  'customers',
  'customerAccountEntries',
  'customerCollections',
  'customerAdvances',
  'customerAdvanceApplications',
  'customerAdvanceRefunds',
  'supplierAccountEntries',
  'supplierPayments',
  'supplierAdvances',
  'supplierAdvanceApplications',
  'supplierAdvanceRefunds',
  'expenses',
  'auditLogs',
  'financialAccounts',
  'financialAccountEntries',
  'financialTransfers',
  'financialClosings',
  'negativeBalanceApprovalRequests',
  'negativeBalanceApprovalRequestTransitions',
];
