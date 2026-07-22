import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:grain_warehouse_erp_lite/core/business_identity/business_identity.dart';
import 'package:grain_warehouse_erp_lite/core/theme/app_semantic_colors.dart';
import 'package:grain_warehouse_erp_lite/core/theme/app_theme.dart';
import 'package:grain_warehouse_erp_lite/core/theme/app_theme_mode.dart';
import 'package:grain_warehouse_erp_lite/core/theme/app_theme_preset.dart';
import 'package:grain_warehouse_erp_lite/core/theme/theme_controller.dart';
import 'package:grain_warehouse_erp_lite/core/theme/theme_settings_repository.dart';
import 'package:grain_warehouse_erp_lite/shared/widgets/ghalal_status_badge.dart';

void main() {
  group('Phase 83 design system and theme', () {
    test('all accent presets build accessible light and dark themes', () {
      for (final preset in AppThemePreset.accentValues) {
        final light = AppTheme.lightFor(preset);
        final dark = AppTheme.darkFor(preset);

        expect(light.brightness, Brightness.light);
        expect(dark.brightness, Brightness.dark);
        expect(light.useMaterial3, isTrue);
        expect(dark.useMaterial3, isTrue);
        expect(light.textTheme.bodyMedium?.fontFamily, 'Arial');
        expect(dark.textTheme.bodyMedium?.fontFamily, 'Arial');

        final lightSemantic = light.extension<AppSemanticColors>();
        final darkSemantic = dark.extension<AppSemanticColors>();
        expect(lightSemantic, isNotNull);
        expect(darkSemantic, isNotNull);
        expect(lightSemantic!.pending, isNot(lightSemantic.executed));
        expect(lightSemantic.rejected, isNot(lightSemantic.cancelled));
        expect(darkSemantic!.pending, isNot(darkSemantic.executed));
        expect(darkSemantic.stale, isNot(darkSemantic.cancelled));
      }
    });

    test('theme mode and accent persist together across repository restart',
        () async {
      final directory =
          await Directory.systemTemp.createTemp('phase83-theme-settings-');
      addTearDown(() => directory.delete(recursive: true));
      final path = '${directory.path}${Platform.pathSeparator}theme.json';
      final repository = LocalThemeSettingsRepository(filePath: path);

      await repository.saveSettings(
        const AppThemeSettings(
          mode: AppThemeMode.dark,
          preset: AppThemePreset.blue,
        ),
      );

      final restarted = LocalThemeSettingsRepository(filePath: path);
      final restored = await restarted.loadSettings();
      expect(restored.mode, AppThemeMode.dark);
      expect(restored.preset.id, AppThemePreset.blue.id);
      expect((await restarted.loadThemePreset()).id, AppThemePreset.blue.id);
    });

    test('legacy preset-only files remain readable without inventing data',
        () async {
      final directory =
          await Directory.systemTemp.createTemp('phase83-legacy-theme-');
      addTearDown(() => directory.delete(recursive: true));
      final path = '${directory.path}${Platform.pathSeparator}theme.txt';
      final file = File(path);

      await file.writeAsString(AppThemePreset.blue.id);
      var restored =
          await LocalThemeSettingsRepository(filePath: path).loadSettings();
      expect(restored.mode, AppThemeMode.system);
      expect(restored.preset.id, AppThemePreset.blue.id);

      await file.writeAsString(AppThemePreset.highContrast.id);
      restored =
          await LocalThemeSettingsRepository(filePath: path).loadSettings();
      expect(restored.mode, AppThemeMode.dark);
      expect(restored.preset.id, AppThemePreset.olive.id);
    });

    test('controller saves mode and accent independently', () async {
      final directory =
          await Directory.systemTemp.createTemp('phase83-theme-controller-');
      addTearDown(() => directory.delete(recursive: true));
      final repository = LocalThemeSettingsRepository(
        filePath: '${directory.path}${Platform.pathSeparator}theme.json',
      );
      final controller = ThemeController(repository: repository);
      addTearDown(controller.dispose);

      await controller.initialize();
      await controller.selectMode(AppThemeMode.light);
      await controller.selectPreset(AppThemePreset.wheat);

      final restored = await repository.loadSettings();
      expect(restored.mode, AppThemeMode.light);
      expect(restored.preset.id, AppThemePreset.wheat.id);
      expect(controller.message, isNotEmpty);
    });

    testWidgets('status badge communicates state with text icon and semantics',
        (tester) async {
      final semantics = tester.ensureSemantics();
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light,
          home: const Scaffold(
            body: GhalalStatusBadge(
              label: 'معلّق',
              icon: Icons.schedule_rounded,
              tone: GhalalStatusTone.warning,
            ),
          ),
        ),
      );

      expect(find.text('معلّق'), findsOneWidget);
      expect(find.byIcon(Icons.schedule_rounded), findsOneWidget);
      final semanticsWidget = tester.widget<Semantics>(
        find
            .descendant(
              of: find.byType(GhalalStatusBadge),
              matching: find.byType(Semantics),
            )
            .first,
      );
      expect(semanticsWidget.properties.label, 'الحالة: معلّق');
      expect(tester.takeException(), isNull);
      semantics.dispose();
    });

    testWidgets('switching light and dark while mounted throws no exception',
        (tester) async {
      final mode = ValueNotifier(ThemeMode.light);
      addTearDown(mode.dispose);
      await tester.pumpWidget(
        ValueListenableBuilder<ThemeMode>(
          valueListenable: mode,
          builder: (context, value, _) => MaterialApp(
            theme: AppTheme.lightFor(AppThemePreset.olive),
            darkTheme: AppTheme.darkFor(AppThemePreset.olive),
            themeMode: value,
            home: const Scaffold(body: Text('غلال')),
          ),
        ),
      );
      expect(Theme.of(tester.element(find.text('غلال'))).brightness,
          Brightness.light);

      mode.value = ThemeMode.dark;
      await tester.pumpAndSettle();
      expect(Theme.of(tester.element(find.text('غلال'))).brightness,
          Brightness.dark);
      expect(tester.takeException(), isNull);
    });

    test('brand fallback is Ghalal and reference medicine identity is absent',
        () {
      expect(BusinessIdentity.empty.displayName, 'غلال');
      final source = Directory('lib')
          .listSync(recursive: true)
          .whereType<File>()
          .where((file) => file.path.endsWith('.dart'))
          .map((file) => file.readAsStringSync())
          .join('\n')
          .toLowerCase();
      expect(source, isNot(contains('medicine bs')));
      expect(source, isNot(contains('صيدلية')));
      expect(source, isNot(contains('دواء')));
    });
  });
}
