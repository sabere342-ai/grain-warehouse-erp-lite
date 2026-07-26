import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:grain_warehouse_erp_lite/core/auth/auth_controller.dart';
import 'package:grain_warehouse_erp_lite/core/auth/auth_repository.dart';
import 'package:grain_warehouse_erp_lite/core/documents/document_history.dart';
import 'package:grain_warehouse_erp_lite/core/documents/document_history_controller.dart';
import 'package:grain_warehouse_erp_lite/core/theme/app_theme.dart';
import 'package:grain_warehouse_erp_lite/core/theme/app_theme_preset.dart';
import 'package:grain_warehouse_erp_lite/features/backup/backup_export_screen.dart';
import 'package:grain_warehouse_erp_lite/features/documents/document_history_screen.dart';

void main() {
  group('Phase 101H standalone route surfaces', () {
    test('dark accent controls retain readable semantic contrast', () {
      for (final preset in AppThemePreset.values) {
        final theme = AppTheme.darkFor(preset);
        final scheme = theme.colorScheme;

        expect(
          _contrastRatio(scheme.primary, scheme.onPrimary),
          greaterThanOrEqualTo(4.5),
          reason: '${preset.id} filled controls must remain readable',
        );
        expect(
          _contrastRatio(scheme.primary, theme.scaffoldBackgroundColor),
          greaterThanOrEqualTo(4.5),
          reason: '${preset.id} outlined controls must remain readable',
        );
      }
    });

    for (final brightness in Brightness.values) {
      testWidgets(
        'backup route paints the $brightness theme surface',
        (tester) async {
          final auth = await _signedInOwner();
          addTearDown(auth.dispose);
          final theme =
              brightness == Brightness.light ? AppTheme.light : AppTheme.dark;

          await _pumpRoute(
            tester,
            theme: theme,
            auth: auth,
            child: const BackupExportScreen(),
          );

          _expectSemanticRouteSurface(
            tester,
            key: const Key('backup-export-route-scaffold'),
            theme: theme,
          );
        },
      );

      testWidgets(
        'document history paints the $brightness theme surface',
        (tester) async {
          final auth = await _signedInOwner();
          addTearDown(auth.dispose);
          final controller = DocumentHistoryController(
            repository: _EmptyDocumentHistoryRepository(),
          );
          addTearDown(controller.dispose);
          final theme =
              brightness == Brightness.light ? AppTheme.light : AppTheme.dark;

          await _pumpRoute(
            tester,
            theme: theme,
            auth: auth,
            child: DocumentHistoryScreen(controller: controller),
          );

          _expectSemanticRouteSurface(
            tester,
            key: const Key('document-history-route-scaffold'),
            theme: theme,
          );
        },
      );
    }

    testWidgets('video-derived routes preserve Arabic RTL presentation',
        (tester) async {
      final auth = await _signedInOwner();
      addTearDown(auth.dispose);
      final controller = DocumentHistoryController(
        repository: _EmptyDocumentHistoryRepository(),
      );
      addTearDown(controller.dispose);

      await _pumpRoute(
        tester,
        theme: AppTheme.light,
        auth: auth,
        child: DocumentHistoryScreen(controller: controller),
      );

      final headerContext = tester.element(find.text('سجل المستندات'));
      expect(Directionality.of(headerContext), TextDirection.rtl);
      expect(find.byIcon(Icons.arrow_forward_rounded), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });
}

double _contrastRatio(Color first, Color second) {
  final lighter = first.computeLuminance() > second.computeLuminance()
      ? first.computeLuminance()
      : second.computeLuminance();
  final darker = first.computeLuminance() > second.computeLuminance()
      ? second.computeLuminance()
      : first.computeLuminance();
  return (lighter + 0.05) / (darker + 0.05);
}

Future<void> _pumpRoute(
  WidgetTester tester, {
  required ThemeData theme,
  required AuthController auth,
  required Widget child,
}) async {
  tester.view.physicalSize = const Size(1920, 1020);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);

  await tester.pumpWidget(
    MaterialApp(
      theme: theme,
      locale: const Locale('ar'),
      builder: (context, routeChild) => Directionality(
        textDirection: TextDirection.rtl,
        child: routeChild ?? const SizedBox.shrink(),
      ),
      home: AuthScope(controller: auth, child: child),
    ),
  );
  await tester.pumpAndSettle();
}

void _expectSemanticRouteSurface(
  WidgetTester tester, {
  required Key key,
  required ThemeData theme,
}) {
  final scaffold = tester.widget<Scaffold>(find.byKey(key));
  expect(scaffold.backgroundColor, theme.scaffoldBackgroundColor);
  if (theme.brightness == Brightness.light) {
    expect(scaffold.backgroundColor, isNot(Colors.black));
  }
  expect(tester.takeException(), isNull);
}

Future<AuthController> _signedInOwner() async {
  final controller = AuthController(repository: LocalAuthRepository.demo());
  await controller.initialize();
  await controller.signIn(phone: '01000000000', password: 'owner123');
  return controller;
}

class _EmptyDocumentHistoryRepository implements DocumentHistoryRepository {
  @override
  Future<List<DocumentHistoryEntry>> listHistory({
    DocumentHistoryFilter filter = const DocumentHistoryFilter(),
  }) async =>
      const [];
}
