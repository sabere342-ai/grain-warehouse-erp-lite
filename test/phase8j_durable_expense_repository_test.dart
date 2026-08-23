import 'dart:io';

import 'package:drift/drift.dart' hide isNull;
import 'package:flutter_test/flutter_test.dart';
import 'package:grain_warehouse_erp_lite/app/app_repositories.dart';
import 'package:grain_warehouse_erp_lite/core/audit/audit_log_repository.dart';
import 'package:grain_warehouse_erp_lite/core/expenses/drift_expense_repository.dart';
import 'package:grain_warehouse_erp_lite/core/expenses/expense.dart';
import 'package:grain_warehouse_erp_lite/core/expenses/expense_repository.dart';
import 'package:grain_warehouse_erp_lite/core/financial_accounts/financial_account.dart';
import 'package:grain_warehouse_erp_lite/core/financial_accounts/financial_account_entry.dart';
import 'package:grain_warehouse_erp_lite/core/financial_accounts/financial_account_repository.dart';
import 'package:grain_warehouse_erp_lite/core/financial_accounts/repository_transaction.dart';
import 'package:grain_warehouse_erp_lite/core/persistence/database_opener.dart';
import 'package:grain_warehouse_erp_lite/core/persistence/foundation_database.dart'
    as db;
// ignore: depend_on_referenced_packages
import 'package:sqlite3/sqlite3.dart';

void main() {
  test('fresh v10 round-trips every field and survives reopen', () async {
    final directory = await Directory.systemTemp.createTemp('phase8j-reopen-');
    final file = File('${directory.path}${Platform.pathSeparator}data.sqlite3');
    addTearDown(() async {
      if (directory.existsSync()) await directory.delete(recursive: true);
    });
    var database = openDatabaseFile(file);
    var repository = DriftExpenseRepository(database);
    expect(database.schemaVersion, 16);
    final created = await repository.createExpense(ExpenseDraft(
      accountingClassification: ExpenseAccountingClassification.operating,
      date: DateTime.utc(2026, 7, 15, 18),
      category: ' نقل ',
      amountQirsh: 12550,
      createdByUserId: 'owner',
      operationRequestId: 'phase8j-reopen-1',
      notes: ' عاجل ',
      financialAccountId: 'cash-1',
      paymentMethod: PaymentMethod.cash,
    ));
    await database.close();

    database = openDatabaseFile(file);
    repository = DriftExpenseRepository(database);
    final restored = (await repository.listExpenses()).single;
    expect(restored.id, created.id);
    expect(restored.date, DateTime(2026, 7, 15));
    expect(restored.category, 'نقل');
    expect(restored.amountQirsh, 12550);
    expect(restored.notes, 'عاجل');
    expect(restored.createdAt, created.createdAt);
    expect(restored.financialAccountId, 'cash-1');
    expect(restored.paymentMethod, PaymentMethod.cash);
    await database.close();
  });

  test('nullable fields and deterministic date-created-id ordering', () async {
    final database = openInMemoryTestDatabase();
    addTearDown(database.close);
    final repository = DriftExpenseRepository(database);
    final date = DateTime.utc(2026, 7, 15);
    final created = DateTime.utc(2026, 7, 16);
    await repository.restoreExpensesIntoEmpty([
      _expense('exp-1-1', date, created),
      _expense('exp-1-3', date, created),
      _expense('exp-1-2', date.add(const Duration(days: 1)), created),
    ]);
    final rows = await repository.listExpenses();
    expect(rows.map((row) => row.id), ['exp-1-2', 'exp-1-3', 'exp-1-1']);
    expect(rows.last.notes, isNull);
    expect(rows.last.financialAccountId, isNull);
    expect(rows.last.paymentMethod, isNull);
  });

  test('sequence survives reopen and restored high counter', () async {
    final database = openInMemoryTestDatabase();
    addTearDown(database.close);
    final repository = DriftExpenseRepository(database);
    await repository.restoreExpensesIntoEmpty([
      _expense('exp-100-41', DateTime.utc(2026), DateTime.utc(2026)),
    ]);
    final created = await repository.createExpense(
      ExpenseDraft(
        accountingClassification: ExpenseAccountingClassification.operating,
        date: DateTime.utc(2026),
        category: 'وقود',
        amountQirsh: 1,
        createdByUserId: 'owner',
        operationRequestId: 'phase8j-sequence-1',
      ),
    );
    expect(created.id.endsWith('-42'), isTrue);
  });

  test('snapshot rollback restores rows and sequence', () async {
    final database = openInMemoryTestDatabase();
    addTearDown(database.close);
    final repository = DriftExpenseRepository(database);
    final first = await repository.createExpense(
      ExpenseDraft(
        accountingClassification: ExpenseAccountingClassification.operating,
        date: DateTime.utc(2026),
        category: 'أول',
        amountQirsh: 1,
        createdByUserId: 'owner',
        operationRequestId: 'phase8j-snapshot-first',
      ),
    );
    final snapshot = repository.createTransactionSnapshot();
    await snapshot.capture();
    await repository.createExpense(
      ExpenseDraft(
        accountingClassification: ExpenseAccountingClassification.operating,
        date: DateTime.utc(2026),
        category: 'يلغى',
        amountQirsh: 2,
        createdByUserId: 'owner',
        operationRequestId: 'phase8j-snapshot-rollback',
      ),
    );
    await snapshot.rollback();
    expect((await repository.listExpenses()).single.id, first.id);
    final after = await repository.createExpense(
      ExpenseDraft(
        accountingClassification: ExpenseAccountingClassification.operating,
        date: DateTime.utc(2026),
        category: 'بعد',
        amountQirsh: 3,
        createdByUserId: 'owner',
        operationRequestId: 'phase8j-snapshot-after',
      ),
    );
    expect(after.id.endsWith('-2'), isTrue);
  });

  test('owner wipe clears rows and resets sequence', () async {
    final database = openInMemoryTestDatabase();
    addTearDown(database.close);
    final repository = DriftExpenseRepository(database);
    await repository.createExpense(
      ExpenseDraft(
        accountingClassification: ExpenseAccountingClassification.operating,
        date: DateTime.utc(2026),
        category: 'قبل',
        amountQirsh: 1,
        createdByUserId: 'owner',
        operationRequestId: 'phase8j-wipe-before',
      ),
    );
    await repository.clearForOwnerDataWipe();
    expect(await repository.listExpenses(), isEmpty);
    final after = await repository.createExpense(
      ExpenseDraft(
        accountingClassification: ExpenseAccountingClassification.operating,
        date: DateTime.utc(2026),
        category: 'بعد',
        amountQirsh: 1,
        createdByUserId: 'owner',
        operationRequestId: 'phase8j-wipe-after',
      ),
    );
    expect(after.id.endsWith('-1'), isTrue);
  });

  test('financial failure rolls expense and sequence back', () async {
    final database = openInMemoryTestDatabase();
    addTearDown(database.close);
    final finances = LocalFinancialAccountRepository();
    final account = await finances.createAccount(
      const FinancialAccountDraft(
        name: 'خزينة',
        type: FinancialAccountType.treasury,
        createdByUserId: 'owner',
      ),
    );
    await finances.setOpeningBalance(
      accountId: account.id,
      amountQirsh: 10,
      effectiveDate: DateTime.utc(2026),
      createdByUserId: 'owner',
    );
    final repository = DriftExpenseRepository(
      database,
      financialAccountRepository: finances,
    );
    await expectLater(
      repository.createExpense(ExpenseDraft(
        accountingClassification: ExpenseAccountingClassification.operating,
        date: DateTime.utc(2026),
        category: 'فشل مالي',
        amountQirsh: 1,
        createdByUserId: 'owner',
        operationRequestId: 'phase8j-financial-failure',
        financialAccountId: 'missing',
        paymentMethod: PaymentMethod.cash,
      )),
      throwsStateError,
    );
    expect(await repository.listExpenses(), isEmpty);
    final after = await repository.createExpense(
      ExpenseDraft(
        accountingClassification: ExpenseAccountingClassification.operating,
        date: DateTime.utc(2026),
        category: 'بعد',
        amountQirsh: 1,
        createdByUserId: 'owner',
        operationRequestId: 'phase8j-financial-after',
        financialAccountId: account.id,
        paymentMethod: PaymentMethod.cash,
      ),
    );
    expect(after.id.endsWith('-1'), isTrue);
  });

  test('audit failure rolls expense and financial entry back', () async {
    final database = openInMemoryTestDatabase();
    addTearDown(database.close);
    final finances = LocalFinancialAccountRepository();
    final account = await finances.createAccount(const FinancialAccountDraft(
      name: 'خزينة',
      type: FinancialAccountType.treasury,
      allowNegativeBalance: true,
      createdByUserId: 'owner',
    ));
    final repository = DriftExpenseRepository(
      database,
      auditLogRepository: _FailingAuditRepository(),
      financialAccountRepository: finances,
    );
    await expectLater(
      repository.createExpense(ExpenseDraft(
        accountingClassification: ExpenseAccountingClassification.operating,
        date: DateTime.utc(2026),
        category: 'فشل تدقيق',
        amountQirsh: 10,
        createdByUserId: 'owner',
        operationRequestId: 'phase8j-audit-failure',
        financialAccountId: account.id,
        paymentMethod: PaymentMethod.cash,
      )),
      throwsStateError,
    );
    expect(await repository.listExpenses(), isEmpty);
    expect(await finances.currentBalanceForAccount(account.id), 0);
    expect((await finances.statementForAccount(account.id)).lines, isEmpty);
  });

  test('corrupt payment method fails explicitly', () async {
    final database = openInMemoryTestDatabase();
    addTearDown(database.close);
    await database.into(database.expenses).insert(db.ExpensesCompanion.insert(
          id: 'exp-bad-1',
          date: DateTime.utc(2026),
          category: 'تالف',
          amountQirsh: 1,
          notes: const Value(null),
          createdAt: DateTime.utc(2026).microsecondsSinceEpoch,
          financialAccountId: const Value(null),
          paymentMethod: const Value('unknown'),
        ));
    expect(
      DriftExpenseRepository(database).listExpenses(),
      throwsA(isA<FormatException>()),
    );
  });

  test('populated v9 database migrates additively to v10', () async {
    final directory = await Directory.systemTemp.createTemp('phase8j-migrate-');
    final file = File('${directory.path}${Platform.pathSeparator}data.sqlite3');
    addTearDown(() async {
      if (directory.existsSync()) await directory.delete(recursive: true);
    });
    final seeded = openDatabaseFile(file);
    await seeded.writeProbe('legacy', 'kept');
    await seeded.close();
    final legacy = sqlite3.open(file.path);
    legacy.execute('DROP TABLE expenses');
    legacy.execute('PRAGMA user_version = 9');
    legacy.dispose();

    final upgraded = openDatabaseFile(file);
    expect(await upgraded.readProbe('legacy'), 'kept');
    expect(await upgraded.expenses.count().getSingle(), 0);
    await upgraded.close();
  });

  test('production wiring uses Drift and Local contract remains compatible',
      () async {
    final database = openInMemoryTestDatabase();
    await AppRepositories.initializeProduction(
        databaseFactory: () async => database);
    expect(AppRepositories.expenseRepository, isA<DriftExpenseRepository>());
    expect(LocalExpenseRepository(), isA<DurableExpenseRepository>());
    await AppRepositories.close();
  });
}

ExpenseRecord _expense(
  String id,
  DateTime date,
  DateTime createdAt,
) =>
    ExpenseRecord(
      id: id,
      date: date,
      category: 'نقل',
      amountQirsh: 100,
      createdAt: createdAt,
    );

class _FailingAuditRepository
    implements AuditLogRepository, TransactionSnapshotProvider {
  @override
  Future<bool> hasRecordedAction({
    required String actionType,
    required String referenceId,
  }) async =>
      false;

  @override
  Future<AuditLogEntry> record(AuditLogDraft draft) {
    throw StateError('injected audit failure');
  }

  @override
  SnapshotHolder createTransactionSnapshot() => _NoopSnapshot();
}

class _NoopSnapshot extends SnapshotHolder {
  @override
  Future<void> capture() async {}

  @override
  Future<void> rollback() async {}
}
