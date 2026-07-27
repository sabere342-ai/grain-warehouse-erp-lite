import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:grain_warehouse_erp_lite/app/app_repositories.dart';
import 'package:grain_warehouse_erp_lite/core/audit/audit_log_repository.dart';
import 'package:grain_warehouse_erp_lite/core/auth/auth_repository.dart';
import 'package:grain_warehouse_erp_lite/core/supplier_accounts/supplier_account_entry.dart';
import 'package:grain_warehouse_erp_lite/core/supplier_accounts/drift_supplier_account_repository.dart';
import 'package:grain_warehouse_erp_lite/core/supplier_accounts/supplier_payment.dart';
import 'package:grain_warehouse_erp_lite/core/suppliers/supplier_repository.dart';
import 'package:grain_warehouse_erp_lite/core/financial_accounts/financial_account_repository.dart';
import 'package:grain_warehouse_erp_lite/core/financial_accounts/negative_balance_approval_repository.dart';
import 'package:grain_warehouse_erp_lite/core/financial_accounts/negative_balance_approval_service.dart';
import 'package:grain_warehouse_erp_lite/core/persistence/database_opener.dart';
import 'package:grain_warehouse_erp_lite/core/persistence/foundation_database.dart';
// ignore: depend_on_referenced_packages
import 'package:sqlite3/sqlite3.dart';

void main() {
  test('fresh schema retains the five supplier account tables', () async {
    final database = openInMemoryTestDatabase();
    addTearDown(database.close);
    expect(database.schemaVersion, 15);
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
          'supplier_account_entries',
          'supplier_payments',
          'supplier_advances',
          'supplier_advance_applications',
          'supplier_advance_refunds',
        }));
  });

  test('populated v11 migrates additively to v12', () async {
    final directory = await Directory.systemTemp.createTemp('phase8l-migrate-');
    final file = File('${directory.path}${Platform.pathSeparator}data.sqlite3');
    addTearDown(() async {
      if (directory.existsSync()) await directory.delete(recursive: true);
    });
    final seeded = openDatabaseFile(file);
    await seeded.writeProbe('v11-data', 'preserved');
    await seeded.close();
    final legacy = sqlite3.open(file.path);
    for (final table in const [
      'supplier_advance_refunds',
      'supplier_advance_applications',
      'supplier_advances',
      'supplier_payments',
      'supplier_account_entries',
    ]) {
      legacy.execute('DROP TABLE $table');
    }
    legacy.execute('PRAGMA user_version = 11');
    legacy.dispose();

    final upgraded = openDatabaseFile(file);
    expect(upgraded.schemaVersion, 15);
    expect(await upgraded.readProbe('v11-data'), 'preserved');
    final count = await upgraded
        .customSelect(
          'SELECT COUNT(*) AS total FROM supplier_account_entries',
        )
        .getSingle();
    expect(count.read<int>('total'), 0);
    await upgraded.close();
  });

  test('explicit state survives close and reopen with ordering intact',
      () async {
    final directory = await Directory.systemTemp.createTemp('phase8l-');
    final file = File('${directory.path}${Platform.pathSeparator}data.sqlite3');
    addTearDown(() async {
      if (directory.existsSync()) await directory.delete(recursive: true);
    });
    var database = openDatabaseFile(file);
    var repository = _repository(database);
    final later = DateTime.utc(2026, 7, 17, 12);
    await repository.restoreSupplierAccountsIntoEmpty(entries: [
      _entry('sle-20-9', later),
      _entry('sle-10-3', later.subtract(const Duration(hours: 1))),
    ], payments: const []);
    await database.close();

    database = openDatabaseFile(file);
    repository = _repository(database);
    final restored = await repository.listEntries();
    expect(restored.map((value) => value.id), ['sle-10-3', 'sle-20-9']);
    expect(restored.last.descriptionAr, 'stored-description');
    await database.close();
  });

  test('payment request and embedded cancellation metadata survive reopen',
      () async {
    final directory = await Directory.systemTemp.createTemp('phase8l-payment-');
    final file = File('${directory.path}${Platform.pathSeparator}data.sqlite3');
    addTearDown(() async {
      if (directory.existsSync()) await directory.delete(recursive: true);
    });
    final occurredAt = DateTime.utc(2026, 7, 17, 13);
    var database = openDatabaseFile(file);
    var repository = _repository(database);
    await repository.restoreSupplierAccountsIntoEmpty(
      entries: const [],
      payments: [
        SupplierPaymentRecord(
          id: 'spy-20-7',
          supplierId: 'sup-1',
          date: occurredAt,
          amountQirsh: 100,
          createdAt: occurredAt,
          createdByUserId: 'owner-1',
          operationRequestId: 'payment-request-1',
          operationRequestFingerprint: 'payment-fingerprint-1',
          cancellation: SupplierPaymentCancellation(
            id: 'spc-20-8',
            originalPaymentId: 'spy-20-7',
            cancelledAt: occurredAt,
            cancelledByUserId: 'owner-1',
            reason: 'cancelled',
            supplierLedgerReversalEntryId: 'sle-20-8',
            operationRequestId: 'cancel-request-1',
          ),
        ),
      ],
    );
    await database.close();

    database = openDatabaseFile(file);
    repository = _repository(database);
    final payment = (await repository.listPayments()).single;
    expect(payment.operationRequestId, 'payment-request-1');
    expect(payment.operationRequestFingerprint, 'payment-fingerprint-1');
    expect(payment.cancellation?.operationRequestId, 'cancel-request-1');
    await database.close();
  });

  test('indexes and six sequence namespaces are durable', () async {
    final database = openInMemoryTestDatabase();
    addTearDown(database.close);
    final indexes = (await database
            .customSelect("SELECT name FROM sqlite_master WHERE type='index'")
            .get())
        .map((row) => row.read<String>('name'))
        .toSet();
    expect(
        indexes,
        containsAll({
          'supplier_account_entries_supplier_timestamp_idx',
          'supplier_payments_supplier_timestamp_idx',
          'supplier_advances_supplier_timestamp_idx',
          'supplier_advance_applications_advance_idx',
          'supplier_advance_refunds_advance_idx',
        }));
    await _repository(database).restoreSupplierAccountsIntoEmpty(
      entries: [_entry('sle-10-4', DateTime.utc(2026))],
      payments: const [],
    );
    final namespaces = (await database
            .customSelect('SELECT repository FROM repository_sequences')
            .get())
        .map((row) => row.read<String>('repository'))
        .toSet();
    expect(
        namespaces,
        containsAll({
          'supplier_account_entries',
          'supplier_payments',
          'supplier_payment_cancellations',
          'supplier_advances',
          'supplier_advance_applications',
          'supplier_advance_refunds',
        }));
  });

  test('snapshot rollback and owner wipe restore durable state', () async {
    final database = openInMemoryTestDatabase();
    addTearDown(database.close);
    final repository = _repository(database);
    await repository.restoreSupplierAccountsIntoEmpty(
      entries: [_entry('sle-10-4', DateTime.utc(2026))],
      payments: const [],
    );
    final snapshot = repository.createTransactionSnapshot();
    await snapshot.capture();
    await repository.clearForOwnerDataWipe();
    expect(await repository.listEntries(), isEmpty);
    await snapshot.rollback();
    expect((await repository.listEntries()).single.id, 'sle-10-4');
    await repository.clearForOwnerDataWipe();
    expect(await repository.listEntries(), isEmpty);
  });

  test('unknown serialized enum fails explicitly', () async {
    final database = openInMemoryTestDatabase();
    addTearDown(database.close);
    await database.customStatement('''
      INSERT INTO supplier_account_entries
        (id, supplier_id, occurred_at, payload_json)
      VALUES ('bad', 'sup-1', 0,
        '{"id":"bad","supplierId":"sup-1","date":"2026-01-01T00:00:00.000Z","type":"unknown","debitAmountQirsh":1,"creditAmountQirsh":0,"sourceDocumentType":"x","sourceDocumentId":"x","descriptionAr":"x","createdAt":"2026-01-01T00:00:00.000Z","createdByUserId":"u"}')
    ''');
    expect(_repository(database).listEntries(), throwsFormatException);
  });

  test('production composition wires the Drift implementation', () async {
    final database = openInMemoryTestDatabase();
    addTearDown(database.close);
    await AppRepositories.initializeProduction(
        databaseFactory: () async => database);
    expect(AppRepositories.supplierAccountRepository,
        isA<DriftSupplierAccountRepository>());
  });
}

DriftSupplierAccountRepository _repository(FoundationDatabase database) {
  final audit = LocalAuditLogRepository();
  final approvalService = NegativeBalanceApprovalService(
    authRepository: LocalAuthRepository.empty(),
    approvalRepository: LocalNegativeBalanceApprovalRepository(),
    auditLogRepository: audit,
  );
  return DriftSupplierAccountRepository(
    database,
    supplierRepository: LocalSupplierRepository(),
    auditLogRepository: audit,
    financialAccountRepository: LocalFinancialAccountRepository(
      auditLogRepository: audit,
      negativeBalanceApprovalService: approvalService,
    ),
    negativeBalanceApprovalService: approvalService,
  );
}

SupplierAccountEntry _entry(String id, DateTime createdAt) =>
    SupplierAccountEntry(
      id: id,
      supplierId: 'sup-1',
      date: createdAt,
      type: SupplierAccountEntryType.openingBalance,
      debitAmountQirsh: 100,
      creditAmountQirsh: 0,
      sourceDocumentType: 'openingBalance',
      sourceDocumentId: 'source-$id',
      descriptionAr: 'stored-description',
      createdAt: createdAt,
      createdByUserId: 'owner-1',
    );
