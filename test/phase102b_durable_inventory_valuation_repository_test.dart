import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:grain_warehouse_erp_lite/core/inventory_valuation/drift_inventory_valuation_repository.dart';
import 'package:grain_warehouse_erp_lite/core/inventory_valuation/inventory_valuation.dart';
import 'package:grain_warehouse_erp_lite/core/persistence/database_opener.dart';
// ignore: depend_on_referenced_packages
import 'package:sqlite3/sqlite3.dart';

void main() {
  test('schema 15 starts profitabilityNotActivated without fabricated values',
      () async {
    final database = openInMemoryTestDatabase();
    addTearDown(database.close);
    final repository = DriftInventoryValuationRepository(database);

    expect((await repository.getActivation()).isActivated, isFalse);
    expect(await repository.listStates(), isEmpty);
    expect(await repository.listEvents(), isEmpty);
    expect(database.schemaVersion, 16);
  });

  test('populated schema 14 migrates additively to 15 and stays inactive',
      () async {
    final directory = await Directory.systemTemp.createTemp('phase102b-v14-');
    final file = File('${directory.path}${Platform.pathSeparator}data.sqlite3');
    addTearDown(() async {
      if (directory.existsSync()) await directory.delete(recursive: true);
    });
    final legacy = sqlite3.open(file.path);
    legacy.execute('''
      CREATE TABLE expenses (
        id TEXT NOT NULL PRIMARY KEY,
        date INTEGER NOT NULL,
        category TEXT NOT NULL,
        amount_qirsh INTEGER NOT NULL,
        notes TEXT NULL,
        created_at INTEGER NOT NULL,
        financial_account_id TEXT NULL,
        payment_method TEXT NULL,
        created_by_user_id TEXT NULL,
        operation_request_id TEXT NULL,
        operation_request_fingerprint TEXT NULL
      )
    ''');
    legacy.execute(
      "INSERT INTO expenses VALUES ('legacy-expense', 1, 'legacy', 100, NULL, 1, NULL, NULL, NULL, NULL, NULL)",
    );
    legacy.execute('PRAGMA user_version = 14');
    legacy.dispose();

    final database = openDatabaseFile(file);
    addTearDown(database.close);
    final repository = DriftInventoryValuationRepository(database);

    expect(database.schemaVersion, 16);
    final legacyExpense = await database
        .customSelect(
          "SELECT accounting_classification FROM expenses WHERE id = 'legacy-expense'",
        )
        .getSingle();
    expect(legacyExpense.data['accounting_classification'], isNull);
    expect((await repository.getActivation()).isActivated, isFalse);
    expect(await repository.listStates(), isEmpty);
    expect(await repository.listEvents(), isEmpty);
  });

  test('activation, rational residual and COGS survive database reopen',
      () async {
    final directory = await Directory.systemTemp.createTemp('phase102b-val-');
    final file = File('${directory.path}${Platform.pathSeparator}data.sqlite3');
    addTearDown(() async {
      if (directory.existsSync()) await directory.delete(recursive: true);
    });

    var database = openDatabaseFile(file);
    var repository = DriftInventoryValuationRepository(database);
    await repository.activate(
      activationDate: DateTime(2026, 7, 27),
      approvedByUserId: 'fixture-owner',
      evidenceNote: 'TEST FIXTURE ONLY — not production owner data',
      openings: const [
        OpeningValuationInput(
          productId: 'wheat-fixture',
          quantityKg: 2,
          unitCostQirshPerKg: 1,
          evidenceReference: 'TEST-FIXTURE-EVIDENCE',
        ),
      ],
    );
    await repository.recordPurchase(
      productId: 'wheat-fixture',
      quantityKg: 1,
      unitCostQirshPerKg: 2,
      sourceDocumentId: 'purchase-fixture',
      effectiveDate: DateTime(2026, 7, 28),
      createdByUserId: 'fixture-owner',
    );
    final sale = await repository.recordSale(
      productId: 'wheat-fixture',
      quantityKg: 1,
      sourceDocumentId: 'sale-fixture',
      effectiveDate: DateTime(2026, 7, 29),
      createdByUserId: 'fixture-owner',
    );
    expect(sale!.allocationResidualNumerator, 1);
    await database.close();

    database = openDatabaseFile(file);
    repository = DriftInventoryValuationRepository(database);
    expect((await repository.getActivation()).isActivated, isTrue);
    final state = await repository.stateForProduct('wheat-fixture');
    expect(state!.quantityKg, 2);
    expect(state.totalValueQirsh, 3);
    expect(await repository.listEvents(), hasLength(3));
    await database.close();
  });

  test('durable restore round-trip keeps exact event fields', () async {
    final database = openInMemoryTestDatabase();
    addTearDown(database.close);
    final repository = DriftInventoryValuationRepository(database);
    await repository.activate(
      activationDate: DateTime(2026, 7, 27),
      approvedByUserId: 'fixture-owner',
      evidenceNote: 'TEST FIXTURE ONLY',
      openings: const [
        OpeningValuationInput(
          productId: 'wheat-fixture',
          quantityKg: 10,
          unitCostQirshPerKg: 100,
          evidenceReference: 'TEST-FIXTURE-EVIDENCE',
        ),
      ],
    );
    final data = await repository.exportRestoreData();
    await repository.clearForOwnerDataWipe();
    await repository.restoreIntoEmpty(data);

    final event = (await repository.listEvents()).single;
    expect(event.type, InventoryValuationEventType.openingValuation);
    expect(event.valueAfterQirsh, 1000);
    expect(event.evidenceReference, 'TEST-FIXTURE-EVIDENCE');
  });
}
