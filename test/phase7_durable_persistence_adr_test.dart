import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Phase 7 — Durable Persistence Architecture Decision', () {
    late String adr;
    late String executionPlan;
    late String roadmap;
    late String decisionRegister;
    late String handoff;

    setUpAll(() {
      adr = File('docs/ADR-001-DURABLE-PERSISTENCE.md').readAsStringSync();
      executionPlan =
          File('MASTER-PROJECT-EXECUTION-PLAN-AR.md').readAsStringSync();
      roadmap = File('docs/MASTER-PRODUCT-ROADMAP.md').readAsStringSync();
      decisionRegister =
          File('docs/ROADMAP-DECISION-REGISTER.md').readAsStringSync();
      handoff = File('docs/DEVELOPER-HANDOFF-NOTES.md').readAsStringSync();
    });

    test('ADR is accepted and selects SQLite with Drift', () {
      expect(adr, contains('Status: Accepted'));
      expect(adr, contains('Phase: 7'));
      expect(adr, contains('SQLite with Drift — selected'));
      expect(adr, contains('Direct SQLite bindings without Drift — rejected'));
      expect(adr, contains('JSON files as the live store — rejected'));
      expect(
          adr, contains('Firebase, Supabase, or a custom server — deferred'));
    });

    test('ADR defines transition, acceptance, rollback, and risk contracts',
        () {
      expect(adr, contains('## Phase 8 transition plan'));
      expect(adr, contains('## Phase 8 acceptance criteria'));
      expect(adr, contains('## Rollback and recovery strategy'));
      expect(adr, contains('## Risks and mitigations'));
      expect(adr, contains('shared transaction context'));
      expect(adr, contains('join one SQL transaction'));
      expect(adr, contains('integer qirsh'));
      expect(adr, contains('integer grams'));
    });

    test('governing documents record Phase 7 and keep Phase 8 unstarted', () {
      for (final document in <String>[
        executionPlan,
        roadmap,
        decisionRegister,
        handoff,
      ]) {
        expect(document, contains('Phase 7'));
        expect(document, contains('Phase 8'));
      }
      expect(decisionRegister, contains('DC-025'));
      expect(decisionRegister, contains('Phase 8 NOT STARTED'));
      expect(
          handoff, contains('Phase 8 is Durable Persistence Implementation'));
    });

    test('Phase 7 introduces no persistence dependency or production file', () {
      final pubspec = File('pubspec.yaml').readAsStringSync().toLowerCase();
      expect(pubspec, isNot(contains('drift:')));
      expect(pubspec, isNot(contains('sqlite3:')));
      expect(pubspec, isNot(contains('sqlite3_flutter_libs:')));

      final productionFiles = Directory('lib')
          .listSync(recursive: true)
          .whereType<File>()
          .map((file) => file.path.replaceAll('\\', '/'))
          .toList();
      expect(productionFiles.where((path) => path.endsWith('.drift')), isEmpty);
      expect(
          productionFiles.where((path) => path.endsWith('.sqlite')), isEmpty);
      expect(productionFiles.where((path) => path.endsWith('.db')), isEmpty);
    });
  });
}
