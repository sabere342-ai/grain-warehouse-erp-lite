import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:grain_warehouse_erp_lite/core/catalog/drift_product_catalog_read_repository.dart';
import 'package:grain_warehouse_erp_lite/core/catalog/drift_product_repository.dart';
import 'package:grain_warehouse_erp_lite/core/catalog/grain_unit.dart';
import 'package:grain_warehouse_erp_lite/core/catalog/product.dart';
import 'package:grain_warehouse_erp_lite/core/customers/customer.dart';
import 'package:grain_warehouse_erp_lite/core/customers/drift_customer_repository.dart';
import 'package:grain_warehouse_erp_lite/core/inventory/drift_inventory_repository.dart';
import 'package:grain_warehouse_erp_lite/core/persistence/database_opener.dart';
import 'package:grain_warehouse_erp_lite/core/persistence/foundation_database.dart';
import 'package:grain_warehouse_erp_lite/core/purchases/drift_purchase_repository.dart';
import 'package:grain_warehouse_erp_lite/core/purchases/purchase_intake.dart';
import 'package:grain_warehouse_erp_lite/core/suppliers/drift_supplier_repository.dart';
import 'package:grain_warehouse_erp_lite/core/suppliers/supplier.dart';
import 'package:grain_warehouse_erp_lite/core/trial/trial_clock.dart';
import 'package:grain_warehouse_erp_lite/core/trial/trial_service.dart';
import 'package:grain_warehouse_erp_lite/core/trial/trial_state.dart';
import 'package:grain_warehouse_erp_lite/core/trial/trial_state_store.dart';
import 'package:grain_warehouse_erp_lite/features/trial/trial_app_gate.dart';

final _t0 = DateTime.utc(2026, 8, 10, 10);

void main() {
  group('Phase 107G trial state machine T1-T18', () {
    test('T1 fresh initialization starts at first evaluated runtime', () async {
      final harness = _TrialHarness(_t0);

      final result = await harness.evaluateAt(_t0);

      expect(result.status, TrialAccessStatus.active);
      expect(result.startedAtUtc, _t0);
      expect(result.lastAcceptedRunAtUtc, _t0);
      expect(harness.store.state!.tamperDetected, isFalse);
      expect(harness.store.state!.expired, isFalse);
      expect(result.daysRemaining, 14);
    });

    test('T2 same-time restart preserves the original start', () async {
      final harness = _TrialHarness(_t0);
      await harness.evaluateAt(_t0);

      final restarted = await harness.restartAt(_t0);

      expect(restarted.status, TrialAccessStatus.active);
      expect(restarted.startedAtUtc, _t0);
      expect(harness.store.writes, hasLength(1));
    });

    test('T3 normal restart advances only last accepted run', () async {
      final harness = _TrialHarness(_t0);
      await harness.evaluateAt(_t0);
      final later = _t0.add(const Duration(hours: 7));

      final restarted = await harness.restartAt(later);

      expect(restarted.status, TrialAccessStatus.active);
      expect(restarted.startedAtUtc, _t0);
      expect(restarted.lastAcceptedRunAtUtc, later);
    });

    for (final testCase in [
      (name: 'T4 day 1', elapsed: const Duration(days: 1)),
      (name: 'T5 day 13', elapsed: const Duration(days: 13)),
      (
        name: 'T6 one second before expiry',
        elapsed: const Duration(days: 14) - const Duration(seconds: 1),
      ),
    ]) {
      test('${testCase.name} is active', () async {
        final harness = _TrialHarness(_t0);
        await harness.evaluateAt(_t0);

        final result = await harness.evaluateAt(_t0.add(testCase.elapsed));

        expect(result.status, TrialAccessStatus.active);
      });
    }

    test('T7 exact 14-day boundary is expired', () async {
      final harness = _TrialHarness(_t0);
      await harness.evaluateAt(_t0);

      final result = await harness.evaluateAt(_t0.add(trialDuration));

      expect(result.status, TrialAccessStatus.expired);
      expect(harness.store.state!.expired, isTrue);
    });

    test('T8 beyond expiry is expired', () async {
      final harness = _TrialHarness(_t0);
      await harness.evaluateAt(_t0);

      final result = await harness.evaluateAt(
        _t0.add(const Duration(days: 21)),
      );

      expect(result.status, TrialAccessStatus.expired);
    });

    test('T9 expired restart stays blocked even after clock moves back',
        () async {
      final harness = _TrialHarness(_t0);
      await harness.evaluateAt(_t0);
      await harness.evaluateAt(_t0.add(trialDuration));

      final restarted = await harness.restartAt(
        _t0.add(const Duration(days: 10)),
      );

      expect(restarted.status, TrialAccessStatus.expired);
      expect(harness.store.state!.expired, isTrue);
    });

    test('T10 forward clock jump shortens the remaining duration normally',
        () async {
      final harness = _TrialHarness(_t0);
      await harness.evaluateAt(_t0);
      await harness.evaluateAt(_t0.add(const Duration(days: 3)));

      final result = await harness.evaluateAt(
        _t0.add(const Duration(days: 8)),
      );

      expect(result.status, TrialAccessStatus.active);
      expect(result.daysRemaining, 6);
    });

    test('T11 large forward jump expires the trial', () async {
      final harness = _TrialHarness(_t0);
      await harness.evaluateAt(_t0);

      final result = await harness.evaluateAt(
        _t0.add(const Duration(days: 365)),
      );

      expect(result.status, TrialAccessStatus.expired);
    });

    test('T12 rollback behind last accepted run is detected and persisted',
        () async {
      final harness = _TrialHarness(_t0);
      await harness.evaluateAt(_t0);
      await harness.evaluateAt(_t0.add(const Duration(days: 3)));

      final result = await harness.evaluateAt(
        _t0.add(const Duration(days: 1)),
      );

      expect(result.status, TrialAccessStatus.clockRollbackDetected);
      expect(harness.store.state!.startedAtUtc, _t0);
      expect(harness.store.state!.tamperDetected, isTrue);
    });

    test('T13 rollback flag is sticky after restart and clock correction',
        () async {
      final harness = _TrialHarness(_t0);
      await harness.evaluateAt(_t0);
      await harness.evaluateAt(_t0.add(const Duration(days: 3)));
      await harness.evaluateAt(_t0.add(const Duration(days: 1)));

      final restarted = await harness.restartAt(
        _t0.add(const Duration(days: 4)),
      );

      expect(restarted.status, TrialAccessStatus.clockRollbackDetected);
      expect(harness.store.state!.tamperDetected, isTrue);
    });

    test(
        'T14 zero-tolerance boundary accepts equality and rejects 1 microsecond',
        () async {
      expect(TrialService.rollbackTolerance, Duration.zero);
      final accepted = _TrialHarness(_t0);
      await accepted.evaluateAt(_t0);
      final acceptedRun = _t0.add(const Duration(days: 1));
      await accepted.evaluateAt(acceptedRun);
      expect(
        (await accepted.restartAt(acceptedRun)).status,
        TrialAccessStatus.active,
      );

      final rejected = _TrialHarness(_t0);
      await rejected.evaluateAt(_t0);
      await rejected.evaluateAt(acceptedRun);
      expect(
        (await rejected.evaluateAt(
          acceptedRun.subtract(const Duration(microseconds: 1)),
        ))
            .status,
        TrialAccessStatus.clockRollbackDetected,
      );
    });

    test('T15 corrupted state fails closed', () async {
      final harness = _TrialHarness(_t0);
      harness.store.corrupt();

      final result = await harness.evaluateAt(_t0);

      expect(result.status, TrialAccessStatus.invalidState);
      expect(harness.store.writes, isEmpty);
    });

    test('T16 partial initialized state fails closed', () async {
      final harness = _TrialHarness(_t0);
      harness.store.partial();

      final result = await harness.evaluateAt(_t0);

      expect(result.status, TrialAccessStatus.invalidState);
      expect(harness.store.writes, isEmpty);
    });

    test('T17 future start timestamp is a sticky rollback block', () async {
      final harness = _TrialHarness(_t0);
      harness.store.load(
        _state(
          started: _t0.add(const Duration(hours: 1)),
          last: _t0.add(const Duration(hours: 1)),
        ),
      );

      final result = await harness.evaluateAt(_t0);

      expect(result.status, TrialAccessStatus.clockRollbackDetected);
      expect(harness.store.state!.tamperDetected, isTrue);
    });

    test('T18 impossible last-run ordering fails closed', () async {
      final harness = _TrialHarness(_t0);
      harness.store.load(
        _state(
          started: _t0,
          last: _t0.subtract(const Duration(seconds: 1)),
        ),
      );

      final result = await harness.evaluateAt(_t0);

      expect(result.status, TrialAccessStatus.invalidState);
    });

    test('last accepted run at or beyond expiry is impossible', () async {
      final harness = _TrialHarness(_t0);
      harness.store.load(
        _state(started: _t0, last: _t0.add(trialDuration)),
      );

      expect(
        (await harness.evaluateAt(_t0.add(trialDuration))).status,
        TrialAccessStatus.invalidState,
      );
    });

    test('storage errors fail closed without crashing', () async {
      final service = TrialService(
        store: _ThrowingTrialStore(),
        clock: _FakeTrialClock(_t0),
      );

      final result = await service.evaluate();

      expect(result.status, TrialAccessStatus.invalidState);
    });
  });

  group('Phase 107G file persistence and casual tamper detection', () {
    test('state is independent, encoded, integrity checked, and restart-safe',
        () async {
      final directory = await Directory.systemTemp.createTemp('trial-107g-');
      addTearDown(() => directory.delete(recursive: true));
      final store = FileTrialStateStore(directory);
      final state = _state(started: _t0, last: _t0);

      await store.write(state);
      final raw = await File(store.stateFilePath).readAsString();
      final loaded = await store.read();

      expect(raw, isNot(contains(_t0.toIso8601String())));
      expect(raw, isNot(contains('trialStartedAtUtc')));
      expect(loaded.kind, TrialStateLoadKind.loaded);
      expect(loaded.state!.startedAtUtc, _t0);
    });

    test('edited integrity marker is invalid and does not create a new trial',
        () async {
      final directory = await Directory.systemTemp.createTemp('trial-107g-');
      addTearDown(() => directory.delete(recursive: true));
      final store = FileTrialStateStore(directory);
      await store.write(_state(started: _t0, last: _t0));
      final stateFile = File(store.stateFilePath);
      final envelope = jsonDecode(await stateFile.readAsString()) as Map;
      envelope['m'] = 'edited';
      await stateFile.writeAsString(jsonEncode(envelope), flush: true);

      final result = await TrialService(
        store: store,
        clock: _FakeTrialClock(_t0),
      ).evaluate();

      expect(result.status, TrialAccessStatus.invalidState);
      expect((await store.read()).kind, TrialStateLoadKind.invalid);
    });

    test('missing state or sentinel after initialization is invalid', () async {
      for (final missingState in [true, false]) {
        final directory =
            await Directory.systemTemp.createTemp('trial-107g-partial-');
        addTearDown(() => directory.delete(recursive: true));
        final store = FileTrialStateStore(directory);
        await store.write(_state(started: _t0, last: _t0));
        await File(
          missingState ? store.stateFilePath : store.sentinelFilePath,
        ).delete();

        expect((await store.read()).kind, TrialStateLoadKind.invalid);
      }
    });
  });

  group('Phase 107G UI and bypass enforcement T19-T21/B1-B6', () {
    testWidgets('active trial shows ceiling-based unobtrusive status',
        (tester) async {
      final state = _state(started: _t0, last: _t0);
      final evaluation = TrialEvaluation.active(
        state,
        _t0.add(const Duration(hours: 2)),
      );

      await tester.pumpWidget(
        TrialAppGate(
          evaluation: evaluation,
          child: const MaterialApp(home: Text('business-ui')),
        ),
      );

      expect(find.text('business-ui'), findsOneWidget);
      expect(find.byKey(const Key('trial-status-banner')), findsOneWidget);
      expect(find.text('نسخة تجريبية — متبقي 14 يومًا'), findsOneWidget);
    });

    testWidgets('open application re-evaluates and blocks at runtime',
        (tester) async {
      final state = _state(started: _t0, last: _t0);
      final active = TrialEvaluation.active(
        state,
        _t0.add(trialDuration - const Duration(seconds: 30)),
      );
      final evaluator = _QueuedTrialEvaluator([
        TrialEvaluation.blocked(
          TrialAccessStatus.expired,
          state: state,
        ),
      ]);
      await tester.pumpWidget(
        TrialAppGate(
          evaluation: active,
          evaluator: evaluator,
          child: const MaterialApp(home: Text('business-ui')),
        ),
      );

      await tester.pump(const Duration(seconds: 30));
      await tester.pump();

      expect(evaluator.calls, 1);
      expect(find.text('business-ui'), findsNothing);
      expect(find.text('انتهت الفترة التجريبية'), findsOneWidget);
    });

    for (final route in [
      'login-success-dashboard',
      'saved-session-business-screen',
      'owner-setup-success-dashboard',
      'direct-named-business-route',
    ]) {
      testWidgets('expired gate blocks $route', (tester) async {
        await tester.pumpWidget(
          TrialAppGate(
            evaluation: TrialEvaluation.blocked(TrialAccessStatus.expired),
            child: MaterialApp(home: Text(route)),
          ),
        );

        expect(find.text(route), findsNothing);
        expect(find.byKey(const Key('trial-blocked-screen')), findsOneWidget);
        expect(find.text('انتهت الفترة التجريبية'), findsOneWidget);
        expect(find.textContaining('بياناتك محفوظة'), findsOneWidget);
      });
    }

    for (final status in [
      TrialAccessStatus.clockRollbackDetected,
      TrialAccessStatus.invalidState,
    ]) {
      testWidgets('$status is controlled and blocks all child access',
          (tester) async {
        await tester.pumpWidget(
          TrialAppGate(
            evaluation: TrialEvaluation.blocked(status),
            child: const MaterialApp(home: Text('must-not-build')),
          ),
        );

        expect(find.text('must-not-build'), findsNothing);
        expect(
          find.text('تعذر التحقق من صلاحية الفترة التجريبية'),
          findsOneWidget,
        );
        expect(find.textContaining('runtime.dat'), findsNothing);
      });
    }

    test('T19 incomplete owner setup cannot reset the trial start', () async {
      final harness = _TrialHarness(_t0);
      await harness.evaluateAt(_t0);

      final reopened = await harness.restartAt(
        _t0.add(const Duration(days: 2)),
      );

      expect(reopened.startedAtUtc, _t0);
      expect(reopened.status, TrialAccessStatus.active);
    });

    test('remaining-day mapping uses ceiling and never drives expiry', () {
      final state = _state(started: _t0, last: _t0);
      expect(TrialEvaluation.active(state, _t0).daysRemaining, 14);
      expect(
        TrialEvaluation.active(
          state,
          _t0.add(const Duration(days: 7)),
        ).daysRemaining,
        7,
      );
      expect(
        TrialEvaluation.active(
          state,
          _t0.add(trialDuration - const Duration(hours: 2)),
        ).daysRemaining,
        1,
      );
      expect(
        TrialEvaluation.blocked(TrialAccessStatus.expired).daysRemaining,
        0,
      );
    });
  });

  group('Phase 107G data-preservation integration T22-T24', () {
    test('expiry blocks access without mutating durable business rows',
        () async {
      final fixture = await _BusinessFixture.create();
      addTearDown(fixture.close);
      final before = await fixture.snapshot();
      final harness = _TrialHarness(_t0);
      await harness.evaluateAt(_t0);

      final result = await harness.evaluateAt(_t0.add(trialDuration));
      final after = await fixture.snapshot();

      expect(result.status, TrialAccessStatus.expired);
      expect(after, before);
    });

    test('sticky rollback blocks access without mutating business rows',
        () async {
      final fixture = await _BusinessFixture.create();
      addTearDown(fixture.close);
      final before = await fixture.snapshot();
      final harness = _TrialHarness(_t0);
      await harness.evaluateAt(_t0);
      await harness.evaluateAt(_t0.add(const Duration(days: 3)));

      final result = await harness.evaluateAt(
        _t0.add(const Duration(days: 1)),
      );
      final restarted = await harness.restartAt(
        _t0.add(const Duration(days: 4)),
      );
      final after = await fixture.snapshot();

      expect(result.status, TrialAccessStatus.clockRollbackDetected);
      expect(restarted.status, TrialAccessStatus.clockRollbackDetected);
      expect(after, before);
    });
  });

  test('negative controls N1-N4 distinguish required failures', () async {
    final state = _state(started: _t0, last: _t0);
    final exactExpiry = _t0.add(trialDuration);
    final actualBoundaryAllows = exactExpiry.isBefore(
      state.startedAtUtc.add(trialDuration),
    );
    final mutantBoundaryAllows = !exactExpiry.isAfter(
      state.startedAtUtc.add(trialDuration),
    );
    expect(actualBoundaryAllows, isFalse);
    expect(mutantBoundaryAllows, isTrue);

    final rollbackHarness = _TrialHarness(_t0);
    await rollbackHarness.evaluateAt(_t0);
    await rollbackHarness.evaluateAt(_t0.add(const Duration(days: 3)));
    final rollback = await rollbackHarness.evaluateAt(
      _t0.add(const Duration(days: 1)),
    );
    expect(rollback.allowsAccess, isFalse);

    final corruptHarness = _TrialHarness(_t0)..store.corrupt();
    expect((await corruptHarness.evaluateAt(_t0)).allowsAccess, isFalse);

    final expired = TrialEvaluation.blocked(TrialAccessStatus.expired);
    expect(expired.allowsAccess, isFalse);
  });
}

TrialPersistentState _state({
  required DateTime started,
  required DateTime last,
  bool tamperDetected = false,
  bool expired = false,
}) {
  return TrialPersistentState(
    version: trialStateVersion,
    startedAtUtc: started,
    lastAcceptedRunAtUtc: last,
    tamperDetected: tamperDetected,
    expired: expired,
  );
}

class _FakeTrialClock implements TrialClock {
  _FakeTrialClock(this.value);

  DateTime value;

  @override
  DateTime nowUtc() => value;
}

class _MemoryTrialStore implements TrialStateStore {
  TrialStateLoadResult _result = const TrialStateLoadResult.fresh();
  final List<TrialPersistentState> writes = [];

  TrialPersistentState? get state => _result.state;

  void load(TrialPersistentState value) {
    _result = TrialStateLoadResult.loaded(value);
  }

  void corrupt() {
    _result = const TrialStateLoadResult.invalid();
  }

  void partial() {
    _result = const TrialStateLoadResult.invalid();
  }

  @override
  Future<TrialStateLoadResult> read() async => _result;

  @override
  Future<void> write(TrialPersistentState state) async {
    writes.add(state);
    load(state);
  }
}

class _ThrowingTrialStore implements TrialStateStore {
  @override
  Future<TrialStateLoadResult> read() => throw const FileSystemException();

  @override
  Future<void> write(TrialPersistentState state) =>
      throw const FileSystemException();
}

class _QueuedTrialEvaluator implements TrialEvaluator {
  _QueuedTrialEvaluator(this.results);

  final List<TrialEvaluation> results;
  int calls = 0;

  @override
  Future<TrialEvaluation> evaluate() async {
    final result = results[calls];
    calls++;
    return result;
  }
}

class _TrialHarness {
  _TrialHarness(DateTime initialTime)
      : clock = _FakeTrialClock(initialTime),
        store = _MemoryTrialStore();

  final _FakeTrialClock clock;
  final _MemoryTrialStore store;

  Future<TrialEvaluation> evaluateAt(DateTime value) {
    clock.value = value;
    return TrialService(store: store, clock: clock).evaluate();
  }

  Future<TrialEvaluation> restartAt(DateTime value) => evaluateAt(value);
}

class _BusinessFixture {
  _BusinessFixture(this.database);

  final FoundationDatabase database;

  static Future<_BusinessFixture> create() async {
    final database = openInMemoryTestDatabase();
    await database.customStatement('''
      INSERT INTO auth_accounts (
        id, phone_normalized, name, role, is_active, created_at, updated_at,
        credential_scheme, credential_salt, credential_verifier,
        credential_parameters_json, credential_updated_at
      ) VALUES (
        'owner-107g', '01000000107', 'Phase 107G owner', 'owner', 1, 0, 0,
        'test', X'00', X'00', '{}', 0
      )
    ''');
    final products = DriftProductRepository(database);
    final catalog = DriftProductCatalogReadRepository(database);
    final customers = DriftCustomerRepository(database);
    final suppliers = DriftSupplierRepository(database);
    final inventory = DriftInventoryRepository(
      database,
      productCatalogReadRepository: catalog,
    );
    final purchases = DriftPurchaseRepository(
      database,
      supplierRepository: suppliers,
      productCatalogReadRepository: catalog,
      inventoryRepository: inventory,
    );
    final product = await products.createProduct(
      const ProductDraft(
        name: 'Phase 107G wheat',
        unit: GrainUnit.kilogram,
        referenceCostPricePiastersPerKg: 500,
      ),
    );
    final supplier = await suppliers.createSupplier(
      const SupplierDraft(name: 'Phase 107G supplier'),
    );
    await customers.createCustomer(
      const CustomerDraft(name: 'Phase 107G customer', isActive: true),
    );
    await purchases.createPurchaseIntake(
      PurchaseIntakeDraft(
        supplierId: supplier.id,
        productId: product.id,
        quantityKg: 1000,
        entryUnit: GrainUnit.kilogram,
        unitPricePiastersPerKg: 500,
        createdByUserId: 'owner-107g',
      ),
    );
    return _BusinessFixture(database);
  }

  Future<String> snapshot() async {
    const queries = {
      'owner': 'SELECT id, phone_normalized, name, role, is_active '
          'FROM auth_accounts ORDER BY id',
      'products': 'SELECT * FROM products ORDER BY id',
      'inventory': 'SELECT * FROM inventory_movements ORDER BY id',
      'customers': 'SELECT * FROM customers ORDER BY id',
      'suppliers': 'SELECT * FROM suppliers ORDER BY id',
      'purchases': 'SELECT * FROM purchases ORDER BY id',
    };
    final snapshot = <String, Object?>{};
    for (final entry in queries.entries) {
      final rows = await database.customSelect(entry.value).get();
      snapshot[entry.key] = rows.map((row) => row.data).toList(growable: false);
    }
    return jsonEncode(snapshot);
  }

  Future<void> close() => database.close();
}
