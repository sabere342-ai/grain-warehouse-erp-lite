import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:grain_warehouse_erp_lite/app/app_repositories.dart';
import 'package:grain_warehouse_erp_lite/application/application_boundary.dart';
import 'package:grain_warehouse_erp_lite/application/queries/application_query.dart';
import 'package:grain_warehouse_erp_lite/application/queries/load_expenses_query.dart';
import 'package:grain_warehouse_erp_lite/composition/app_composition_root.dart';
import 'package:grain_warehouse_erp_lite/composition/application_scope.dart';
import 'package:grain_warehouse_erp_lite/core/auth/app_user.dart';
import 'package:grain_warehouse_erp_lite/core/auth/auth_controller.dart';
import 'package:grain_warehouse_erp_lite/core/auth/auth_repository.dart';
import 'package:grain_warehouse_erp_lite/core/auth/user_role.dart';
import 'package:grain_warehouse_erp_lite/core/expenses/expense.dart';
import 'package:grain_warehouse_erp_lite/core/expenses/expense_controller.dart';
import 'package:grain_warehouse_erp_lite/core/expenses/expense_repository.dart';
import 'package:grain_warehouse_erp_lite/core/persistence/database_opener.dart';
import 'package:grain_warehouse_erp_lite/core/persistence/foundation_database.dart'
    show FoundationDatabase;
import 'package:grain_warehouse_erp_lite/core/theme/app_theme.dart';
import 'package:grain_warehouse_erp_lite/core/trial/trial_service.dart';
import 'package:grain_warehouse_erp_lite/core/trial/trial_state.dart';
import 'package:grain_warehouse_erp_lite/features/expenses/expenses_screen.dart';
import 'support/fixed_device_identity_store.dart';

void main() {
  group('confirmed expense-list application query handler', () {
    test('delegates once and preserves list, records, membership, and order',
        () async {
      final repository = _ExpenseRepositorySpy(_snapshot);
      final handler = LoadExpensesQueryHandler(repository: repository);

      final result = await handler.execute(const LoadExpensesQuery());

      expect(repository.listCalls, 1);
      expect(repository.createCalls, 0);
      expect(repository.reclassifyCalls, 0);
      expect(repository.totalCalls, 0);
      expect(result.value, same(_snapshot));
      expect(result.value[0], same(_snapshot[0]));
      expect(result.value[1], same(_snapshot[1]));
      expect(result.value.map((expense) => expense.id), [
        'expense-newer',
        'expense-older',
      ]);
    });

    test('preserves empty success and local SQLite metadata', () async {
      final expenses = <ExpenseRecord>[];
      final handler = LoadExpensesQueryHandler(
        repository: _ExpenseRepositorySpy(expenses),
      );

      final result = await handler.execute(const LoadExpensesQuery());
      final metadata = result.metadata as LocalQueryResultMetadata;

      expect(result.value, same(expenses));
      expect(result.value, isEmpty);
      expect(metadata.source, QueryResultSource.local);
      expect(metadata.readAuthority, LocalReadAuthority.sqlite);
      expect(metadata.consistency, LocalQueryConsistency.currentKnownState);
    });

    test('propagates the exact repository exception', () async {
      final failure = StateError('sentinel expense-list failure');
      final repository = _ExpenseRepositorySpy(const [], failure: failure);
      final handler = LoadExpensesQueryHandler(repository: repository);

      await expectLater(
        handler.execute(const LoadExpensesQuery()),
        throwsA(same(failure)),
      );
      expect(repository.listCalls, 1);
    });
  });

  group('ExpenseController query migration compatibility', () {
    test('legacy repository construction adapts to the query handler',
        () async {
      final repository = _ExpenseRepositorySpy(_snapshot);
      final controller = ExpenseController(repository: repository);
      addTearDown(controller.dispose);

      await controller.loadExpenses(_owner);

      expect(repository.listCalls, 1);
      expect(controller.expenses[0], same(_snapshot[0]));
      expect(controller.expenses[1], same(_snapshot[1]));
    });

    test('load and refresh preserve state, notifications, and no filtering',
        () async {
      final reads = _ExpenseRepositorySpy(_snapshot);
      final writes = _ExpenseRepositorySpy(const []);
      final controller = ExpenseController(
        queryHandler: LoadExpensesQueryHandler(repository: reads),
        repository: writes,
      );
      addTearDown(controller.dispose);
      final loadingStates = <bool>[];
      controller.addListener(() => loadingStates.add(controller.isLoading));

      await controller.loadExpenses(_owner);
      await controller.refreshAfterConfirmedProjection(_employee);

      expect(reads.listCalls, 2);
      expect(writes.listCalls, 0);
      expect(controller.expenses[0], same(_snapshot[0]));
      expect(controller.expenses[1], same(_snapshot[1]));
      expect(loadingStates, [true, false, true, false]);
      expect(() => controller.expenses.add(_snapshot.first),
          throwsUnsupportedError);
    });

    test('empty result replaces the prior list successfully', () async {
      final reads = _ExpenseRepositorySpy(_snapshot);
      final controller = ExpenseController(
        queryHandler: LoadExpensesQueryHandler(repository: reads),
        repository: _ExpenseRepositorySpy(const []),
      );
      addTearDown(controller.dispose);
      await controller.loadExpenses(_owner);
      reads.expenses = const [];

      await controller.loadExpenses(_employee);

      expect(controller.expenses, isEmpty);
      expect(controller.isLoading, isFalse);
      expect(controller.errorMessage, isNull);
    });

    test('failure retains list and preserves exact error and loading behavior',
        () async {
      final reads = _ExpenseRepositorySpy(_snapshot);
      final controller = ExpenseController(
        queryHandler: LoadExpensesQueryHandler(repository: reads),
        repository: _ExpenseRepositorySpy(const []),
      );
      addTearDown(controller.dispose);
      await controller.loadExpenses(_owner);
      final retained = controller.expenses.first;
      final failure = StateError('later expense-list failure');
      reads.failure = failure;
      final loadingStates = <bool>[];
      controller.addListener(() => loadingStates.add(controller.isLoading));

      await expectLater(
        controller.loadExpenses(_employee),
        throwsA(same(failure)),
      );

      expect(controller.expenses.first, same(retained));
      expect(controller.isLoading, isTrue);
      expect(controller.errorMessage, isNull);
      expect(loadingStates, [true]);
    });

    test('reclassification writes once and refreshes once through the query',
        () async {
      final reads = _ExpenseRepositorySpy(_snapshot);
      final writes = _ExpenseRepositorySpy(const []);
      final controller = ExpenseController(
        queryHandler: LoadExpensesQueryHandler(repository: reads),
        repository: writes,
      );
      addTearDown(controller.dispose);

      final success = await controller.reclassifyExpense(
        user: _owner,
        expenseId: _snapshot.first.id,
        classification: ExpenseAccountingClassification.capital,
        reason: 'capital asset',
      );

      expect(success, isTrue);
      expect(writes.reclassifyCalls, 1);
      expect(writes.listCalls, 0);
      expect(reads.listCalls, 1);
      expect(controller.expenses.first, same(_snapshot.first));
    });
  });

  group('production composition and ExpensesScreen ownership', () {
    late FoundationDatabase database;
    late ApplicationBoundary application;

    setUpAll(() async {
      database = openInMemoryTestDatabase();
      application = await AppCompositionRoot.initializeProduction(
        databaseFactory: () async => database,
        deviceIdentityStore: FixedDeviceIdentityStore(),
        trialEvaluator: _TrialEvaluatorStub(),
      );
    });

    tearDownAll(() async {
      final runtime = application.dependencies.runtime;
      runtime.authController.dispose();
      runtime.themeController.dispose();
      runtime.businessIdentityController.dispose();
      await AppCompositionRoot.close();
    });

    test('captures the shared expense repository in the application query', () {
      expect(
        application.dependencies.repositories.expenseRepository,
        same(AppRepositories.expenseRepository),
      );
      expect(AppRepositories.database, same(database));
      expect(application.queries.expenses, isA<LoadExpensesQueryHandler>());

      final source = File(
        'lib/composition/app_composition_root.dart',
      ).readAsStringSync();
      expect(
        source,
        contains('repository: dependencies.repositories.expenseRepository'),
      );
    });

    testWidgets('authenticated default screen loads through scoped query',
        (tester) async {
      final reads = _ExpenseRepositorySpy(_snapshot);
      final auth = await _signedInAuth('01000000000', 'owner123');
      addTearDown(auth.dispose);

      await tester.pumpWidget(
        _screenHarness(
          application: _withExpenseHandler(application, reads),
          auth: auth,
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(reads.listCalls, 1);
      expect(find.text('Transport newer'), findsOneWidget);
      expect(find.text('Storage older'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('unauthenticated default screen does not query',
        (tester) async {
      final reads = _ExpenseRepositorySpy(_snapshot);
      final auth = AuthController(repository: LocalAuthRepository.demo());
      addTearDown(auth.dispose);
      await auth.initialize();

      await tester.pumpWidget(
        _screenHarness(
          application: _withExpenseHandler(application, reads),
          auth: auth,
        ),
      );
      await tester.pumpAndSettle();

      expect(reads.listCalls, 0);
      expect(find.text('يلزم تسجيل الدخول'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });

  group('static scope guards', () {
    test('handler is one-shot, read-only, and infrastructure-free', () {
      final source = File(
        'lib/application/queries/load_expenses_query.dart',
      ).readAsStringSync();

      expect(source, contains('ExpenseRepository _repository'));
      expect(source, contains('_repository.listExpenses()'));
      expect(source, isNot(contains('app_repositories.dart')));
      expect(source, isNot(contains('AppRepositories')));
      expect(source, isNot(contains('FoundationDatabase')));
      expect(source, isNot(contains('Drift')));
      expect(source, isNot(contains('Supabase')));
      for (final writeToken in [
        '.createExpense(',
        '.reclassifyExpense(',
        '.totalExpensesQirsh(',
      ]) {
        expect(source, isNot(contains(writeToken)));
      }
    });

    test('controller and screen route list reads only through the query', () {
      final controller = File(
        'lib/core/expenses/expense_controller.dart',
      ).readAsStringSync();
      final screen = File(
        'lib/features/expenses/expenses_screen.dart',
      ).readAsStringSync();
      final compactScreen = screen.replaceAll(RegExp(r'\s+'), '');

      expect(controller, isNot(contains('.listExpenses(')));
      expect(controller, contains('LoadExpensesQueryHandler'));
      expect(controller, contains('const LoadExpensesQuery()'));
      expect(screen, isNot(contains('.listExpenses(')));
      expect(
          compactScreen, contains('queryHandler:application.queries.expenses'));
      expect('expenseRepository'.allMatches(screen), hasLength(1));
      expect(compactScreen,
          contains('ApplicationScope.of(context).commands.postExpense'));
      expect(screen, isNot(contains('DriftExpenseRepository')));
      expect(screen, isNot(contains('FoundationDatabase')));
    });
  });
}

ApplicationBoundary _withExpenseHandler(
  ApplicationBoundary application,
  ExpenseRepository repository,
) {
  return ApplicationBoundary(
    dependencies: application.dependencies,
    commands: application.commands,
    queries: ApplicationQueries(
      auditLogs: application.queries.auditLogs,
      businessLogo: application.queries.businessLogo,
      documentHistory: application.queries.documentHistory,
      expenses: LoadExpensesQueryHandler(repository: repository),
      productCatalog: application.queries.productCatalog,
    ),
  );
}

Widget _screenHarness({
  required ApplicationBoundary application,
  required AuthController auth,
}) {
  return ApplicationScope(
    application: application,
    child: AuthScope(
      controller: auth,
      child: MaterialApp(
        theme: AppTheme.light,
        locale: const Locale('ar'),
        home: const ExpensesScreen(),
      ),
    ),
  );
}

Future<AuthController> _signedInAuth(String phone, String password) async {
  final controller = AuthController(repository: LocalAuthRepository.demo());
  await controller.initialize();
  await controller.signIn(phone: phone, password: password);
  return controller;
}

final class _ExpenseRepositorySpy implements ExpenseRepository {
  _ExpenseRepositorySpy(this.expenses, {this.failure});

  List<ExpenseRecord> expenses;
  Object? failure;
  int listCalls = 0;
  int createCalls = 0;
  int reclassifyCalls = 0;
  int totalCalls = 0;

  @override
  Future<List<ExpenseRecord>> listExpenses() async {
    listCalls++;
    final error = failure;
    if (error != null) throw error;
    return expenses;
  }

  @override
  Future<ExpenseRecord> createExpense(ExpenseDraft draft) async {
    createCalls++;
    return _snapshot.first;
  }

  @override
  Future<ExpenseRecord> reclassifyExpense({
    required AppUser user,
    required String expenseId,
    required ExpenseAccountingClassification classification,
    required String reason,
  }) async {
    reclassifyCalls++;
    return _snapshot.first;
  }

  @override
  Future<int> totalExpensesQirsh({
    required DateTime start,
    required DateTime end,
  }) async {
    totalCalls++;
    return 0;
  }
}

final _timestamp = DateTime.utc(2026, 9, 7, 12);

final _snapshot = <ExpenseRecord>[
  ExpenseRecord(
    id: 'expense-newer',
    date: DateTime.utc(2026, 9, 7),
    category: 'Transport newer',
    amountQirsh: 2500,
    createdAt: _timestamp,
    createdByUserId: 'owner-expenses',
    notes: '  verbatim note  ',
    accountingClassification: ExpenseAccountingClassification.operating,
  ),
  ExpenseRecord(
    id: 'expense-older',
    date: DateTime.utc(2026, 9, 6),
    category: 'Storage older',
    amountQirsh: 1500,
    createdAt: _timestamp.subtract(const Duration(hours: 1)),
    createdByUserId: 'employee-expenses',
    accountingClassification: ExpenseAccountingClassification.nonOperating,
  ),
];

final _owner = AppUser(
  id: 'owner-expenses',
  name: 'Owner',
  phone: '01000000108',
  role: UserRole.owner,
  isActive: true,
  createdAt: _timestamp,
  updatedAt: _timestamp,
);

final _employee = AppUser(
  id: 'employee-expenses',
  name: 'Employee',
  phone: '01100000108',
  role: UserRole.employee,
  isActive: true,
  createdAt: _timestamp,
  updatedAt: _timestamp,
);

final class _TrialEvaluatorStub implements TrialEvaluator {
  @override
  Future<TrialEvaluation> evaluate() async =>
      TrialEvaluation.blocked(TrialAccessStatus.invalidState);
}
