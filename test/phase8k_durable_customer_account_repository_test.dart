import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:grain_warehouse_erp_lite/app/app_repositories.dart';
import 'package:grain_warehouse_erp_lite/core/audit/audit_log_repository.dart';
import 'package:grain_warehouse_erp_lite/core/auth/auth_repository.dart';
import 'package:grain_warehouse_erp_lite/core/customer_accounts/customer_account_entry.dart';
import 'package:grain_warehouse_erp_lite/core/customer_accounts/drift_customer_account_repository.dart';
import 'package:grain_warehouse_erp_lite/core/customers/customer_repository.dart';
import 'package:grain_warehouse_erp_lite/core/financial_accounts/financial_account_repository.dart';
import 'package:grain_warehouse_erp_lite/core/financial_accounts/negative_balance_approval_repository.dart';
import 'package:grain_warehouse_erp_lite/core/financial_accounts/negative_balance_approval_service.dart';
import 'package:grain_warehouse_erp_lite/core/persistence/database_opener.dart';
import 'package:grain_warehouse_erp_lite/core/persistence/foundation_database.dart';
// ignore: depend_on_referenced_packages
import 'package:sqlite3/sqlite3.dart';

void main() {
  test('fresh schema is v11 with the five customer account tables', () async {
    final database = openInMemoryTestDatabase();
    addTearDown(database.close);
    expect(database.schemaVersion, 12);
    final names = (await database
            .customSelect(
              "SELECT name FROM sqlite_master WHERE type = 'table'",
            )
            .get())
        .map((row) => row.read<String>('name'))
        .toSet();
    expect(
        names,
        containsAll(<String>{
          'customer_account_entries',
          'customer_collections',
          'customer_advances',
          'customer_advance_applications',
          'customer_advance_refunds',
        }));
  });

  test('populated v10 migrates additively to v11', () async {
    final directory = await Directory.systemTemp.createTemp('phase8k-migrate-');
    final file = File('${directory.path}${Platform.pathSeparator}data.sqlite3');
    addTearDown(() async {
      if (directory.existsSync()) await directory.delete(recursive: true);
    });
    final seeded = openDatabaseFile(file);
    await seeded.writeProbe('v10-data', 'preserved');
    await seeded.close();
    final legacy = sqlite3.open(file.path);
    for (final table in const [
      'customer_advance_refunds',
      'customer_advance_applications',
      'customer_advances',
      'customer_collections',
      'customer_account_entries',
    ]) {
      legacy.execute('DROP TABLE $table');
    }
    legacy.execute('PRAGMA user_version = 10');
    legacy.dispose();

    final upgraded = openDatabaseFile(file);
    expect(upgraded.schemaVersion, 12);
    expect(await upgraded.readProbe('v10-data'), 'preserved');
    final count = await upgraded
        .customSelect(
          'SELECT COUNT(*) AS total FROM customer_account_entries',
        )
        .getSingle();
    expect(count.read<int>('total'), 0);
    await upgraded.close();
  });

  test('explicit state survives close and reopen with ordering intact',
      () async {
    final directory = await Directory.systemTemp.createTemp('phase8k-');
    final file = File('${directory.path}${Platform.pathSeparator}data.sqlite3');
    addTearDown(() async {
      if (directory.existsSync()) await directory.delete(recursive: true);
    });
    var database = openDatabaseFile(file);
    var repository = _repository(database);
    final later = DateTime.utc(2026, 7, 17, 12);
    await repository.restoreCustomerAccountsIntoEmpty(entries: [
      _entry('cle-20-9', later),
      _entry('cle-10-3', later.subtract(const Duration(hours: 1))),
    ], collections: const []);
    await database.close();

    database = openDatabaseFile(file);
    repository = _repository(database);
    final restored = await repository.listEntries();
    expect(restored.map((value) => value.id), ['cle-10-3', 'cle-20-9']);
    expect(restored.last.descriptionAr, 'stored-description');
    await database.close();
  });

  test('snapshot rollback and owner wipe restore durable state', () async {
    final database = openInMemoryTestDatabase();
    addTearDown(database.close);
    final repository = _repository(database);
    await repository.restoreCustomerAccountsIntoEmpty(
      entries: [_entry('cle-10-4', DateTime.utc(2026))],
      collections: const [],
    );
    final snapshot = repository.createTransactionSnapshot();
    await snapshot.capture();
    await repository.clearForOwnerDataWipe();
    expect(await repository.listEntries(), isEmpty);
    await snapshot.rollback();
    expect((await repository.listEntries()).single.id, 'cle-10-4');
    await repository.clearForOwnerDataWipe();
    expect(await repository.listEntries(), isEmpty);
  });

  test('unknown serialized enum fails explicitly', () async {
    final database = openInMemoryTestDatabase();
    addTearDown(database.close);
    await database.customStatement('''
      INSERT INTO customer_account_entries
        (id, customer_id, occurred_at, payload_json)
      VALUES ('bad', 'cus-1', 0,
        '{"id":"bad","customerId":"cus-1","date":"2026-01-01T00:00:00.000Z","type":"unknown","debitAmountQirsh":1,"creditAmountQirsh":0,"sourceDocumentType":"x","sourceDocumentId":"x","descriptionAr":"x","createdAt":"2026-01-01T00:00:00.000Z","createdByUserId":"u"}')
    ''');
    expect(_repository(database).listEntries(), throwsFormatException);
  });

  test('production composition wires the Drift implementation', () async {
    final database = openInMemoryTestDatabase();
    addTearDown(database.close);
    await AppRepositories.initializeProduction(
        databaseFactory: () async => database);
    expect(AppRepositories.customerAccountRepository,
        isA<DriftCustomerAccountRepository>());
  });
}

DriftCustomerAccountRepository _repository(FoundationDatabase database) {
  final audit = LocalAuditLogRepository();
  final approvalService = NegativeBalanceApprovalService(
    authRepository: LocalAuthRepository.empty(),
    approvalRepository: LocalNegativeBalanceApprovalRepository(),
    auditLogRepository: audit,
  );
  return DriftCustomerAccountRepository(
    database,
    customerRepository: LocalCustomerRepository(auditLogRepository: audit),
    auditLogRepository: audit,
    financialAccountRepository: LocalFinancialAccountRepository(
      auditLogRepository: audit,
      negativeBalanceApprovalService: approvalService,
    ),
    negativeBalanceApprovalService: approvalService,
  );
}

CustomerAccountEntry _entry(String id, DateTime createdAt) =>
    CustomerAccountEntry(
      id: id,
      customerId: 'cus-1',
      date: createdAt,
      type: CustomerAccountEntryType.openingBalance,
      debitAmountQirsh: 100,
      creditAmountQirsh: 0,
      sourceDocumentType: 'openingBalance',
      sourceDocumentId: 'source-$id',
      descriptionAr: 'stored-description',
      createdAt: createdAt,
      createdByUserId: 'owner-1',
    );
