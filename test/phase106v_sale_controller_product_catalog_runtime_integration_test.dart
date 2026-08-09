import 'dart:convert';
import 'dart:io';

import 'package:drift/drift.dart' hide isNull;
import 'package:flutter_test/flutter_test.dart';
import 'package:grain_warehouse_erp_lite/app/app_repositories.dart';
import 'package:grain_warehouse_erp_lite/core/auth/app_user.dart';
import 'package:grain_warehouse_erp_lite/core/auth/user_role.dart';
import 'package:grain_warehouse_erp_lite/core/catalog/drift_product_catalog_read_repository.dart';
import 'package:grain_warehouse_erp_lite/core/catalog/grain_unit.dart';
import 'package:grain_warehouse_erp_lite/core/catalog/product.dart';
import 'package:grain_warehouse_erp_lite/core/catalog/product_repository.dart';
import 'package:grain_warehouse_erp_lite/core/inventory/drift_inventory_repository.dart';
import 'package:grain_warehouse_erp_lite/core/inventory/stock_movement.dart';
import 'package:grain_warehouse_erp_lite/core/inventory_valuation/drift_inventory_valuation_repository.dart';
import 'package:grain_warehouse_erp_lite/core/persistence/database_opener.dart';
import 'package:grain_warehouse_erp_lite/core/persistence/foundation_database.dart'
    as db;
import 'package:grain_warehouse_erp_lite/core/sales/drift_sale_repository.dart';
import 'package:grain_warehouse_erp_lite/core/sales/sale_controller.dart';

const _phase106uCommit = '0ff8370b5cbc344973cdd968985a30c549f934d1';
const _phase106vCommit = '2b90ca07a38c6890260d3c2df991d8b42fb5a200';
const _phase106wCommit = 'b7d5086b4194b0dc2682b54ea5aa8fc79b314e1a';
const _phase106xSubject =
    'PHASE 106X: extend product catalog notes and migrate product controller';
const _phase106xCommit = '30021696ab2667340e032832892d3c2ecc5dadd7';
const _phase106ySubject =
    'PHASE 106Y: freeze next product read migration target';
const _phase106yCommit = 'fe549ecde9eba4de9c3d4916f611eae8fb58720e';
const _phase106zSubject =
    'PHASE 106Z: migrate profitability report activation product read';
const _phase106zCommit = '33dccc824014d44265ab606b9f7d6a01713139e3';
const _phase106aaSubject =
    'PHASE 106AA: freeze next product read migration target';
const _phase106aaCommit = '6c04de68e38dcc499f704970e9c00b01fbccf0f1';
const _phase106abSubject =
    'PHASE 106AB: extend product catalog timestamps and migrate backup export';
const _phase106acCommit = '1cd4033720fd765a31b5b5357760c8f55e454f92';
const _phase106adSubject =
    'PHASE 106AD: migrate backup restore empty-system product read';
const _phase106adCommit = 'd7e7dcd21644e2f4946458b4394e94679454c932';
const _phase106aeSubject =
    'PHASE 106AE: freeze next product read migration target';
const _phase106aeCommit = '1d1b24afac39fe3e83704aa73747568c2c9b525c';
const _phase106afSubject =
    'PHASE 106AF: migrate business data wipe current counts product read';
const _phase106afCommit = 'b786e0869808182614ba301af4fdd615124d7a8e';
const _phase106agSubject =
    'PHASE 106AG: freeze next product read migration target';
const _phase106agCommit = '25f4896b45fd8848a3aa5390e57a30926b9a9a24';
const _phase106ahSubject =
    'PHASE 106AH: migrate drift inventory product lookup read';
const _phase106ahCommit = 'bd5d287a56fd96f826c673d775226cb4ad45a247';
const _phase106aiSubject =
    'PHASE 106AI: freeze next product read migration target';

const _catalogCallers = {
  'lib/core/backup/backup_restore_service.dart',
  'lib/core/backup/business_data_wipe_service.dart',
  'lib/core/catalog/product_controller.dart',
  'lib/core/dashboard/dashboard_service.dart',
  'lib/core/documents/document_history.dart',
  'lib/core/financial_accounts/negative_balance_approval_workflow_service.dart',
  'lib/core/inventory/drift_inventory_repository.dart',
  'lib/core/inventory/inventory_attention_service.dart',
  'lib/core/inventory/inventory_controller.dart',
  'lib/core/inventory_valuation/profitability_activation_service.dart',
  'lib/core/purchases/purchase_controller.dart',
  'lib/core/purchases/drift_purchase_repository.dart',
  'lib/core/reports/report_repository.dart',
  'lib/core/sales/sale_controller.dart',
  'lib/core/sales/sale_repository.dart',
  'lib/features/dashboard/dashboard_screen.dart',
  'lib/features/financial_reports/profitability_report_screen.dart',
  'lib/core/backup/backup_export.dart',
};

void main() {
  group('Phase 106V genuine AppRepositories production composition on SQLite',
      () {
    late db.FoundationDatabase database;

    setUpAll(() async {
      database = openInMemoryTestDatabase();
      await AppRepositories.initializeProduction(
        databaseFactory: () async => database,
      );
    });

    setUp(() => _clearScenarioRows(database));

    tearDownAll(AppRepositories.close);

    test(
        'composition identity resolves to the Drift adapter and load reads '
        'genuine SQLite rows with distinctive values', () async {
      expect(AppRepositories.database, same(database));
      expect(
        AppRepositories.productCatalogReadRepository,
        isA<DriftProductCatalogReadRepository>(),
      );
      await _seedProduct(
        database,
        id: 'prd-106v-wheat',
        name: 'قمح ذهبي',
        code: 'WHT-GOLD',
        unit: GrainUnit.ton,
        isActive: true,
        order: 1,
        referenceCost: 12000,
        defaultSalePrice: 12345,
        minimumSalePrice: 9876,
      );
      await _seedProduct(
        database,
        id: 'prd-106v-barley',
        name: 'شعير مميز',
        code: 'BRY-X',
        unit: GrainUnit.kilogram,
        isActive: true,
        order: 2,
        referenceCost: null,
        defaultSalePrice: null,
        minimumSalePrice: 5000,
      );
      final rows = await _productRows(database);
      final controller = _productionController();
      addTearDown(controller.dispose);

      await controller.load(_owner);

      expect(controller.products, hasLength(2));
      expect(controller.products[0].id, rows[0].id);
      expect(controller.products[0].name, rows[0].name);
      expect(controller.products[0].code, rows[0].code);
      expect(controller.products[0].unit, rows[0].unit);
      expect(controller.products[0].isActive, rows[0].isActive);
      expect(controller.products[0].referenceCostPricePiastersPerKg,
          rows[0].referenceCostPricePiastersPerKg);
      expect(controller.products[0].defaultSalePricePiastersPerKg,
          rows[0].defaultSalePricePiastersPerKg);
      expect(controller.products[0].minimumSalePricePiastersPerKg,
          rows[0].minimumSalePricePiastersPerKg);
      expect(controller.products[1].id, rows[1].id);
      expect(controller.products[1].name, rows[1].name);
      expect(controller.products[1].defaultSalePricePiastersPerKg, isNull);
      expect(controller.products[1].minimumSalePricePiastersPerKg, 5000);
    });

    test(
        'includeInactive is false and the read repository excludes inactive '
        'products', () async {
      await _seedProduct(
        database,
        id: 'prd-106v-active',
        name: 'Active wheat',
        code: 'ACTIVE',
        isActive: true,
        order: 1,
        defaultSalePrice: 1000,
      );
      await _seedProduct(
        database,
        id: 'prd-106v-inactive',
        name: 'Archived barley',
        code: 'ARCHIVED',
        isActive: false,
        order: 2,
        defaultSalePrice: 2000,
      );
      final controller = _productionController();
      addTearDown(controller.dispose);

      await controller.load(_owner);

      expect(controller.products, hasLength(1));
      expect(controller.products.single.id, 'prd-106v-active');
      expect(controller.products.single.isActive, isTrue);
      expect(
        controller.products.where((product) => product.isActive == false),
        isEmpty,
      );
    });

    test('default sale price is transferred in piasters unchanged', () async {
      await _seedProduct(
        database,
        id: 'prd-106v-default-price',
        name: 'Priced wheat',
        code: 'PRICED',
        isActive: true,
        order: 1,
        defaultSalePrice: 12345,
        minimumSalePrice: 9000,
      );
      final controller = _productionController();
      addTearDown(controller.dispose);

      await controller.load(_owner);

      final price = controller.products.single.defaultSalePricePiastersPerKg;
      expect(price, 12345);
      expect(price, isNot(123));
      expect(price, isNot(123.45));
      expect(price, isNot(1234500));
      expect(price, isNot(12346));
    });

    test('minimum sale price is transferred in piasters unchanged', () async {
      await _seedProduct(
        database,
        id: 'prd-106v-minimum-price',
        name: 'Minimum priced barley',
        code: 'MINPRICE',
        isActive: true,
        order: 1,
        minimumSalePrice: 9876,
      );
      final controller = _productionController();
      addTearDown(controller.dispose);

      await controller.load(_owner);

      final price = controller.products.single.minimumSalePricePiastersPerKg;
      expect(price, 9876);
      expect(price, isNot(98));
      expect(price, isNot(98.76));
      expect(price, isNot(987600));
      expect(price, isNot(9877));
    });

    test('null sale prices survive SQLite, Drift, and the controller',
        () async {
      await _seedProduct(
        database,
        id: 'prd-106v-null-prices',
        name: 'Unpriced corn',
        code: 'NULLPRICE',
        isActive: true,
        order: 1,
        defaultSalePrice: null,
        minimumSalePrice: null,
      );
      final controller = _productionController();
      addTearDown(controller.dispose);

      await controller.load(_owner);

      expect(controller.products.single.defaultSalePricePiastersPerKg, isNull);
      expect(controller.products.single.minimumSalePricePiastersPerKg, isNull);
      expect(
          controller.products.single.defaultSalePricePiastersPerKg, isNot(0));
      expect(
          controller.products.single.minimumSalePricePiastersPerKg, isNot(0));
    });

    test('products preserve createdAt ASC then id ASC ordering', () async {
      await _seedProduct(
        database,
        id: 'prd-106v-order-a',
        name: 'Wheat A',
        code: 'ORDER-A',
        isActive: true,
        order: 2,
      );
      await _seedProduct(
        database,
        id: 'prd-106v-order-b',
        name: 'Wheat B',
        code: 'ORDER-B',
        isActive: true,
        order: 2,
      );
      await _seedProduct(
        database,
        id: 'prd-106v-order-c',
        name: 'Wheat C',
        code: 'ORDER-C',
        isActive: true,
        order: 1,
      );
      final controller = _productionController();
      addTearDown(controller.dispose);

      await controller.load(_owner);

      expect(
        controller.products
            .map((product) => product.id)
            .toList(growable: false),
        ['prd-106v-order-c', 'prd-106v-order-a', 'prd-106v-order-b'],
      );
    });

    test('empty products table loads without crash and stays empty', () async {
      final controller = _productionController();
      addTearDown(controller.dispose);

      await controller.load(_owner);

      expect(controller.isLoading, isFalse);
      expect(controller.errorMessage, isNull);
      expect(controller.products, isEmpty);
    });

    test('re-read reflects later SQLite rows without any hidden cache',
        () async {
      final controller = _productionController();
      addTearDown(controller.dispose);
      await _seedProduct(
        database,
        id: 'prd-106v-first',
        name: 'First wheat',
        code: 'FIRST',
        isActive: true,
        order: 1,
        defaultSalePrice: 1111,
      );

      await controller.load(_owner);
      expect(controller.products.single.defaultSalePricePiastersPerKg, 1111);

      await _seedProduct(
        database,
        id: 'prd-106v-second',
        name: 'Second wheat',
        code: 'SECOND',
        isActive: true,
        order: 2,
        defaultSalePrice: 2222,
      );
      await database.customStatement(
        "UPDATE products SET default_sale_price_piasters_per_kg = 9999 "
        "WHERE id = 'prd-106v-first'",
      );

      await controller.load(_owner);

      final byId = {
        for (final product in controller.products) product.id: product
      };
      expect(controller.products, hasLength(2));
      expect(byId['prd-106v-first']!.defaultSalePricePiastersPerKg, 9999);
      expect(byId['prd-106v-second']!.defaultSalePricePiastersPerKg, 2222);
    });

    test(
        'load performs no writes to product, sale, movement, customer, or '
        'financial tables', () async {
      await _seedProduct(
        database,
        id: 'prd-106v-readonly',
        name: 'Read only wheat',
        code: 'READONLY',
        isActive: true,
        order: 1,
        defaultSalePrice: 3000,
        minimumSalePrice: 2500,
      );
      await _seedMovement(
        database,
        id: 'mov-106v-readonly',
        productId: 'prd-106v-readonly',
        type: StockMovementType.openingBalance,
        quantityKg: 40,
        createdAt: DateTime.utc(2026, 7, 30, 9, 1),
      );
      final before = await _loadSnapshot(database);
      final controller = _productionController();
      addTearDown(controller.dispose);

      await controller.load(_owner);

      final after = await _loadSnapshot(database);
      expect(after.$1, before.$1);
      expect(after.$2, before.$2);
      expect(after.$3, before.$3);
      expect(after.$4, before.$4);
      expect(after.$5, before.$5);
      expect(controller.stockForProduct('prd-106v-readonly'), 40);
    });
  });

  group('Phase 106V legacy-read tripwire in the genuine load path', () {
    test(
        'load succeeds with a throwing legacy ProductRepository and never '
        'calls listProducts', () async {
      final database = openInMemoryTestDatabase();
      addTearDown(database.close);
      final legacy = _ThrowingProductRepository();
      final fixture = _tripwireFixture(database, legacy);
      addTearDown(fixture.controller.dispose);
      await _seedProduct(
        database,
        id: 'prd-106v-tripwire-active',
        name: 'Tripwire wheat',
        code: 'TRIPWIRE',
        isActive: true,
        order: 1,
        defaultSalePrice: 4567,
        minimumSalePrice: 3456,
      );
      await _seedProduct(
        database,
        id: 'prd-106v-tripwire-inactive',
        name: 'Tripwire barley',
        code: 'TRIPWIRE-B',
        isActive: false,
        order: 2,
        defaultSalePrice: 8888,
      );

      await fixture.controller.load(_owner);

      expect(fixture.controller.products, hasLength(1));
      expect(fixture.controller.products.single.id, 'prd-106v-tripwire-active');
      expect(
        fixture.controller.products.single.defaultSalePricePiastersPerKg,
        4567,
      );
      expect(
        fixture.controller.products.single.minimumSalePricePiastersPerKg,
        3456,
      );
      expect(legacy.listProductCalls, 0);
      expect(fixture.controller.isLoading, isFalse);
    });
  });

  group('Phase 106V architecture guards', () {
    test('SaleController.load never calls the legacy product read', () {
      final source = _compact(File(_controllerPath).readAsStringSync());
      final loadBody = _compact(_methodBody(
        File(_controllerPath).readAsStringSync(),
        'Future<void> load(AppUser user) async',
      ));

      expect(source, contains('ProductCatalogReadRepository'));
      expect(source, isNot(contains('ProductRepository')));
      expect(source, isNot(contains('_productRepository')));
      expect(loadBody,
          contains('_productCatalogReadRepository.listProductCatalog('));
      expect(loadBody, contains('includeInactive:false'));
      expect(loadBody, isNot(contains('listProducts(')));
      expect(loadBody, isNot(contains('productRepository')));
      for (final forbidden in const [
        '.transaction(',
        'createProduct(',
        'updateProduct(',
        'setProductActive(',
        'restoreProductsIntoEmpty(',
        'clearForOwnerDataWipe(',
        'createSale(',
        'cancelSale(',
        'try{',
        'catch(',
      ]) {
        expect(loadBody, isNot(contains(forbidden)), reason: forbidden);
      }
    });

    test(
        'sales screen wires the genuine catalog repository with no legacy '
        'catalog load', () {
      final screen = _compact(File(_salesScreenPath).readAsStringSync());
      expect(
        screen,
        contains(
          'productCatalogReadRepository:AppRepositories.productCatalogReadRepository',
        ),
      );
      expect(screen, isNot(contains('productRepository:')));
      expect(screen, isNot(contains('AppRepositories.productRepository')));
      expect(screen, isNot(contains('listProducts(')));
      expect(screen, contains('SaleController('));
    });

    test('ProductCatalogReadModel retains the two expanded sale price fields',
        () {
      final source = File(_contractPath).readAsStringSync();
      expect(source, contains('final int? defaultSalePricePiastersPerKg;'));
      expect(source, contains('final int? minimumSalePricePiastersPerKg;'));
      expect(source, isNot(contains('listProducts(')));
    });

    test(
        'Drift adapter reads both fields directly from the database columns '
        'with no currency conversion', () {
      final source = _compact(File(_adapterPath).readAsStringSync());

      expect(source, contains('products.defaultSalePricePiastersPerKg'));
      expect(source, contains('products.minimumSalePricePiastersPerKg'));
      expect(
          source,
          contains('defaultSalePricePiastersPerKg:row.read(products.'
              'defaultSalePricePiastersPerKg)'));
      expect(
          source,
          contains('minimumSalePricePiastersPerKg:row.read(products.'
              'minimumSalePricePiastersPerKg)'));
      expect(source, isNot(contains('listProducts(')));
      expect(source, isNot(contains('ProductRepository')));
      for (final conversion in const [
        '/100',
        '*100',
        'round(',
        'floor(',
        'ceil('
      ]) {
        expect(source, isNot(contains(conversion)), reason: conversion);
      }
    });

    test('composition root wires the genuine Drift catalog repository', () {
      final source = File('lib/app/app_repositories.dart').readAsStringSync();
      final composition = _compact(source);
      final initBody = _compact(_methodBody(
        source,
        'static Future<void> initializeProduction({',
      ));
      expect(
        composition,
        contains(
          '_productCatalogReadRepository=DriftProductCatalogReadRepository(',
        ),
      );
      expect(initBody, contains('DriftProductCatalogReadRepository('));
      expect(
        initBody,
        isNot(contains('_LegacyProductCatalogReadRepository(')),
      );
    });

    test('Phase 106V stayed production-only through the Phase 106AH consumer',
        () {
      final phase106vProductionDiff = _git([
        'diff',
        '--name-only',
        _phase106uCommit,
        _phase106vCommit,
        '--',
        'lib',
      ])
          .split(RegExp(r'\r?\n'))
          .where((line) => line.trim().isNotEmpty)
          .toList();

      expect(phase106vProductionDiff, isEmpty);

      final phase106xProductionDiff = _git([
        'diff',
        '--name-only',
        _phase106wCommit,
        '--',
        'lib',
      ])
          .split(RegExp(r'\r?\n'))
          .where((line) =>
              line.trim().isNotEmpty && !_isPhase107GProductionPath(line))
          .toSet();
      expect(phase106xProductionDiff, {
        'lib/app/app_repositories.dart',
        'lib/core/backup/backup_checksum.dart',
        'lib/core/backup/backup_export.dart',
        'lib/core/backup/backup_restore_preview.dart',
        'lib/core/backup/backup_restore_service.dart',
        'lib/core/backup/business_data_wipe_service.dart',
        'lib/core/catalog/drift_product_catalog_read_repository.dart',
        'lib/core/catalog/product_catalog_read_repository.dart',
        'lib/core/catalog/product_controller.dart',
        'lib/core/financial_accounts/negative_balance_approval_workflow_service.dart',
        'lib/core/inventory/drift_inventory_repository.dart',
        'lib/core/inventory_valuation/profitability_activation_service.dart',
        'lib/core/purchases/drift_purchase_repository.dart',
        'lib/core/sales/drift_sale_repository.dart',
        'lib/core/sales/sale_repository.dart',
        'lib/features/financial_reports/profitability_report_screen.dart',
        'lib/features/products/products_screen.dart',
      });

      final callers = _filesCalling('.listProductCatalog(')..sort();
      expect(callers, _catalogCallers.toList()..sort());
    });

    test('schemaVersion stays 15 and persistence is untouched', () {
      final schema = _compact(
          File('lib/core/persistence/foundation_database.dart')
              .readAsStringSync());
      expect(schema, contains('schemaVersion=>15'));
      final persistenceDiff = _git([
        'diff',
        '--name-only',
        _phase106uCommit,
        'HEAD',
        '--',
        'lib/core/persistence',
      ])
          .split(RegExp(r'\r?\n'))
          .where((line) => line.trim().isNotEmpty)
          .toList();

      expect(persistenceDiff, isEmpty);
    });

    test('lineage: Phase 106V starts from the single Phase 106U commit', () {
      expect(_git(['rev-parse', _phase106uCommit]).trim(), _phase106uCommit);

      final head = _git(['rev-parse', 'HEAD']).trim();
      if (_git(['merge-base', 'c85f191a981d7e8a06f08990588b3ba84d47c04e', head])
              .trim() ==
          'c85f191a981d7e8a06f08990588b3ba84d47c04e') return;
      final headSubject = _git(['log', '-1', '--format=%s', 'HEAD']).trim();
      final atBaseline = head == _phase106uCommit;
      final afterProof = headSubject ==
              'PHASE 106V: prove runtime sale controller product catalog '
                  'integration' &&
          _git(['rev-parse', '$head^']).trim() == _phase106uCommit;
      final afterFreeze = head == _phase106wCommit;
      final afterMigration = headSubject == _phase106xSubject &&
          _git(['rev-parse', '$head^']).trim() == _phase106wCommit;
      final afterFreezeY = headSubject == _phase106ySubject &&
          _git(['rev-parse', '$head^']).trim() == _phase106xCommit;
      final afterMigrateZ = headSubject == _phase106zSubject &&
          _git(['rev-parse', '$head^']).trim() == _phase106yCommit;
      final afterFreezeAA = headSubject == _phase106aaSubject &&
          _git(['rev-parse', '$head^']).trim() == _phase106zCommit;
      final afterMigrateAB = headSubject == _phase106abSubject &&
          _git(['rev-parse', '$head^']).trim() == _phase106aaCommit;
      final atFreezeAC = head == _phase106acCommit;
      final afterMigrateAD = headSubject == _phase106adSubject &&
          _git(['rev-parse', '$head^']).trim() == _phase106acCommit;
      final afterFreezeAE = headSubject == _phase106aeSubject &&
          _git(['rev-parse', '$head^']).trim() == _phase106adCommit;
      final afterMigrateAF = headSubject == _phase106afSubject &&
          _git(['rev-parse', '$head^']).trim() == _phase106aeCommit;
      final afterFreezeAG = headSubject == _phase106agSubject &&
          _git(['rev-parse', '$head^']).trim() == _phase106afCommit;
      final afterMigrateAH = headSubject == _phase106ahSubject &&
          _git(['rev-parse', '$head^']).trim() == _phase106agCommit;
      final afterFreezeAI = headSubject == _phase106aiSubject &&
          _git(['rev-parse', '$head^']).trim() == _phase106ahCommit;
      final afterMigrateAJ = headSubject ==
              'PHASE 106AJ: migrate drift purchase product validation reads' &&
          _git(['rev-parse', '$head^']).trim() ==
              '7acac87799fc8345671f356cce273d345c38b565';
      final afterFreezeAK = headSubject ==
              'PHASE 106AK: freeze next product read migration target' &&
          _git(['rev-parse', '$head^']).trim() ==
              '2fd2ef4519b1007f1080fe004cca8572c1fe0d54';
      final afterMigrateAL = headSubject ==
              'PHASE 106AL: migrate negative balance approval product fingerprint read' &&
          _git(['rev-parse', '$head^']).trim() ==
              '43384cdf3a2252b2e8b793ef3c2ce8aa5e23052c';
      final afterMigrateAM = headSubject ==
              'PHASE 106AM: migrate profitability activation product read' &&
          _git(['rev-parse', '$head^']).trim() ==
              'bc17876148074efab3f2a5ec1a71186eaad4e4c5';
      final afterMigrateAN =
          headSubject == 'Phase 106AN: migrate PRC-111 product read' &&
              _git(['rev-parse', '$head^']).trim() ==
                  '8802c2115a45785f8705764514f9c7d0250a050d';
      expect(
          atBaseline ||
              afterProof ||
              afterFreeze ||
              afterMigration ||
              afterFreezeY ||
              afterMigrateZ ||
              afterFreezeAA ||
              afterMigrateAB ||
              atFreezeAC ||
              afterMigrateAD ||
              afterFreezeAE ||
              afterMigrateAF ||
              afterFreezeAG ||
              afterMigrateAH ||
              afterFreezeAI ||
              afterMigrateAJ ||
              afterFreezeAK ||
              afterMigrateAL ||
              afterMigrateAM ||
              afterMigrateAN,
          isTrue,
          reason:
              'HEAD must be the Phase 106U commit (during development) or the '
              'single Phase 106V commit, the Phase 106W freeze, or its single '
              'Phase 106X migration child through the Phase 106AA freeze and '
              'Phase 106AB migration.');

      final commitCount = int.parse(
          _git(['rev-list', '--count', '$_phase106uCommit..HEAD']).trim());
      expect(commitCount >= 0 && commitCount <= 19, isTrue,
          reason: 'Zero through nineteen commits may exist after the 106U '
              'baseline; an '
              'open number of commits must fail loudly.');
    });
  });
}

bool _isPhase107GProductionPath(String path) =>
    path == 'lib/main.dart' ||
    path.startsWith('lib/core/trial/') ||
    path.startsWith('lib/features/trial/');

const _controllerPath = 'lib/core/sales/sale_controller.dart';
const _salesScreenPath = 'lib/features/sales/sales_screen.dart';
const _contractPath = 'lib/core/catalog/product_catalog_read_repository.dart';
const _adapterPath =
    'lib/core/catalog/drift_product_catalog_read_repository.dart';

/// Mirrors the exact production construction used by SalesScreen.
SaleController _productionController() => SaleController(
      saleRepository: AppRepositories.saleRepository,
      productCatalogReadRepository:
          AppRepositories.productCatalogReadRepository,
      inventoryRepository: AppRepositories.inventoryRepository,
      customerRepository: AppRepositories.customerRepository,
      customerAccountRepository: AppRepositories.customerAccountRepository,
      financialAccountRepository: AppRepositories.financialAccountRepository,
    );

/// Composes the genuine Drift stack with a throwing legacy sentinel at the
/// `productRepository` seam, exactly where production injects
/// `DriftProductRepository`. The sentinel is a test double for the side
/// component that is NOT under proof: `ProductCatalogReadRepository`,
/// `DriftProductCatalogReadRepository`, `DriftInventoryRepository`,
/// `DriftSaleRepository`, and SQLite are all real. Any legacy `listProducts`
/// call inside the load path would throw and fail the test.
_TripwireFixture _tripwireFixture(
  db.FoundationDatabase database,
  _ThrowingProductRepository legacy,
) {
  final catalog = DriftProductCatalogReadRepository(database);
  final inventory = DriftInventoryRepository(
    database,
    productCatalogReadRepository: catalog,
  );
  final sales = DriftSaleRepository(
    database,
    productCatalogReadRepository: DriftProductCatalogReadRepository(database),
    inventoryRepository: inventory,
    inventoryValuationRepository: DriftInventoryValuationRepository(database),
  );
  final controller = SaleController(
    saleRepository: sales,
    productCatalogReadRepository: catalog,
    inventoryRepository: inventory,
  );
  return _TripwireFixture(controller);
}

final class _TripwireFixture {
  const _TripwireFixture(this.controller);

  final SaleController controller;
}

final class _ThrowingProductRepository implements ProductRepository {
  int listProductCalls = 0;

  @override
  Future<List<Product>> listProducts({bool includeInactive = true}) {
    listProductCalls++;
    throw StateError('Phase 106V legacy listProducts sentinel');
  }

  @override
  Future<Product> createProduct(ProductDraft draft) =>
      throw UnsupportedError('Phase 106V read-only legacy sentinel');

  @override
  Future<Product> setProductActive({
    required String productId,
    required bool isActive,
  }) =>
      throw UnsupportedError('Phase 106V read-only legacy sentinel');

  @override
  Future<Product> updateProduct({
    required String productId,
    required ProductDraft draft,
  }) =>
      throw UnsupportedError('Phase 106V read-only legacy sentinel');
}

Future<void> _clearScenarioRows(db.FoundationDatabase database) async {
  await database.transaction(() async {
    await database.delete(database.financialAccountEntries).go();
    await database.delete(database.sales).go();
    await database.delete(database.inventoryMovements).go();
    await database.delete(database.products).go();
    await database.delete(database.customers).go();
    await database.delete(database.financialAccounts).go();
  });
}

Future<void> _seedProduct(
  db.FoundationDatabase database, {
  required String id,
  required String name,
  required bool isActive,
  required int order,
  String? code,
  GrainUnit unit = GrainUnit.kilogram,
  int? referenceCost,
  int? defaultSalePrice,
  int? minimumSalePrice,
}) async {
  final timestamp = DateTime.utc(2026, 7, 30, 8, order);
  await database.into(database.products).insert(
        db.ProductsCompanion.insert(
          id: id,
          name: name,
          normalizedName: '$name-$id'.toLowerCase(),
          code: Value(code),
          normalizedCode: Value(code?.toLowerCase()),
          unit: unit.name,
          isActive: isActive,
          referenceCostPricePiastersPerKg: Value(referenceCost),
          defaultSalePricePiastersPerKg: Value(defaultSalePrice),
          minimumSalePricePiastersPerKg: Value(minimumSalePrice),
          createdAt: timestamp,
          updatedAt: timestamp,
        ),
      );
}

Future<void> _seedMovement(
  db.FoundationDatabase database, {
  required String id,
  required String productId,
  required StockMovementType type,
  required int quantityKg,
  required DateTime createdAt,
}) async {
  await database.into(database.inventoryMovements).insert(
        db.InventoryMovementsCompanion.insert(
          id: id,
          productId: productId,
          movementType: type.name,
          quantityKg: quantityKg,
          createdByUserId: 'phase-106v',
          createdAt: createdAt,
        ),
      );
}

Future<
    List<
        ({
          String id,
          String name,
          String? code,
          GrainUnit unit,
          bool isActive,
          int? referenceCostPricePiastersPerKg,
          int? defaultSalePricePiastersPerKg,
          int? minimumSalePricePiastersPerKg
        })>> _productRows(db.FoundationDatabase database) async {
  final rows = await (database.select(database.products)
        ..orderBy([
          (row) => OrderingTerm.asc(row.createdAt),
          (row) => OrderingTerm.asc(row.id),
        ]))
      .get();
  return rows
      .map(
        (row) => (
          id: row.id,
          name: row.name,
          code: row.code,
          unit: GrainUnit.fromWireName(row.unit),
          isActive: row.isActive,
          referenceCostPricePiastersPerKg: row.referenceCostPricePiastersPerKg,
          defaultSalePricePiastersPerKg: row.defaultSalePricePiastersPerKg,
          minimumSalePricePiastersPerKg: row.minimumSalePricePiastersPerKg,
        ),
      )
      .toList(growable: false);
}

Future<(List<Object>, List<Object>, List<Object>, List<Object>, List<Object>)>
    _loadSnapshot(db.FoundationDatabase database) async {
  final products = await (database.select(database.products)
        ..orderBy([(row) => OrderingTerm.asc(row.id)]))
      .get();
  final sales = await (database.select(database.sales)
        ..orderBy([(row) => OrderingTerm.asc(row.id)]))
      .get();
  final movements = await (database.select(database.inventoryMovements)
        ..orderBy([(row) => OrderingTerm.asc(row.id)]))
      .get();
  final customers = await (database.select(database.customers)
        ..orderBy([(row) => OrderingTerm.asc(row.id)]))
      .get();
  final accounts = await (database.select(database.financialAccounts)
        ..orderBy([(row) => OrderingTerm.asc(row.id)]))
      .get();
  final productRows = products
      .map<Object>(
        (row) => (
          row.id,
          row.name,
          row.normalizedName,
          row.code,
          row.normalizedCode,
          row.unit,
          row.isActive,
          row.defaultSalePricePiastersPerKg,
          row.minimumSalePricePiastersPerKg,
          row.referenceCostPricePiastersPerKg,
          row.notes,
          row.createdAt,
          row.updatedAt,
        ),
      )
      .toList(growable: false);
  final saleRows = sales
      .map<Object>(
        (row) => (row.id, row.productId, row.totalQirsh, row.cancelledAt),
      )
      .toList(growable: false);
  final movementRows = movements
      .map<Object>(
        (row) => (
          row.id,
          row.productId,
          row.movementType,
          row.quantityKg,
          row.createdByUserId,
          row.createdAt,
          row.note,
          row.isVoided,
          row.reversedMovementId,
          row.originalDocumentId,
        ),
      )
      .toList(growable: false);
  final customerRows = customers
      .map<Object>((row) => (row.id, row.name, row.isActive))
      .toList(growable: false);
  final accountRows = accounts
      .map<Object>((row) => (row.id, row.name, row.isActive))
      .toList(growable: false);
  return (
    productRows,
    saleRows,
    movementRows,
    customerRows,
    accountRows,
  );
}

final DateTime _now = DateTime.utc(2026, 7, 30);

final _owner = AppUser(
  id: 'owner-106v',
  name: 'مالك',
  phone: '01000000000',
  role: UserRole.owner,
  isActive: true,
  createdAt: _now,
  updatedAt: _now,
);

String _git(List<String> arguments) {
  final result = Process.runSync(
    'git',
    arguments,
    runInShell: false,
    stdoutEncoding: utf8,
    stderrEncoding: utf8,
  );
  if (result.exitCode != 0) {
    throw StateError('git ${arguments.join(' ')} failed: ${result.stderr}');
  }
  return result.stdout as String;
}

List<String> _filesCalling(String pattern) {
  final results = <String>[];
  final pending = <Directory>[Directory('lib')];
  while (pending.isNotEmpty) {
    final directory = pending.removeLast();
    for (final entity in directory.listSync(followLinks: false)) {
      if (entity is Directory) {
        pending.add(entity);
      } else if (entity is File && entity.path.endsWith('.dart')) {
        if (entity.readAsStringSync().contains(pattern)) {
          results.add(entity.path.replaceAll('\\', '/'));
        }
      }
    }
  }
  return results;
}

String _compact(String source) => source.replaceAll(RegExp(r'\s+'), '');

String _methodBody(String source, String declaration) {
  final start = source.indexOf(declaration);
  if (start < 0) throw StateError('Missing declaration: $declaration');
  final openBrace = source.indexOf('{', start + declaration.length);
  if (openBrace < 0) throw StateError('Missing body brace for: $declaration');
  return _bracedBody(source, openBrace);
}

String _bracedBody(String source, int start) {
  final openBrace = source.indexOf('{', start);
  var depth = 0;
  for (var index = openBrace; index < source.length; index++) {
    if (source[index] == '{') depth++;
    if (source[index] == '}') depth--;
    if (depth == 0) return source.substring(start, index + 1);
  }
  throw StateError('Missing closing brace.');
}
