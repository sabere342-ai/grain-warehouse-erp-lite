import 'dart:convert';
import 'dart:io';

import 'package:grain_warehouse_erp_lite/core/audit/audit_log_repository.dart';
import 'package:grain_warehouse_erp_lite/core/theme/app_theme_mode.dart';
import 'package:grain_warehouse_erp_lite/core/theme/app_theme_preset.dart';

class AppThemeSettings {
  const AppThemeSettings({
    required this.mode,
    required this.preset,
  });

  final AppThemeMode mode;
  final AppThemePreset preset;

  Map<String, Object?> toJson() => {
        'version': 1,
        'mode': mode.id,
        'accent': preset.id,
      };
}

abstract class ThemeSettingsRepository {
  Future<AppThemeSettings> loadSettings();

  Future<void> saveSettings(AppThemeSettings settings);
}

class LocalThemeSettingsRepository implements ThemeSettingsRepository {
  LocalThemeSettingsRepository(
      {String? filePath, AuditLogRepository? auditLogRepository})
      : _filePath = filePath,
        _auditLogRepository = auditLogRepository;

  final String? _filePath;
  final AuditLogRepository? _auditLogRepository;

  @override
  Future<AppThemeSettings> loadSettings() async {
    try {
      final file = File(_resolvedFilePath());
      if (!await file.exists()) {
        return const AppThemeSettings(
          mode: AppThemeMode.system,
          preset: AppThemePreset.olive,
        );
      }
      final content = (await file.readAsString()).trim();
      if (content.startsWith('{')) {
        final decoded = jsonDecode(content);
        if (decoded is Map) {
          final map = Map<String, Object?>.from(decoded);
          return AppThemeSettings(
            mode: AppThemeMode.byId(map['mode'] as String?),
            preset: AppThemePreset.byId(map['accent'] as String? ?? ''),
          );
        }
      }

      // Phase 67 stored only the preset id. Keep that file readable.
      final legacyPreset = AppThemePreset.byId(content);
      return AppThemeSettings(
        mode: legacyPreset.isDark ? AppThemeMode.dark : AppThemeMode.system,
        preset: legacyPreset.isDark ? AppThemePreset.olive : legacyPreset,
      );
    } catch (_) {
      return const AppThemeSettings(
        mode: AppThemeMode.system,
        preset: AppThemePreset.olive,
      );
    }
  }

  @override
  Future<void> saveSettings(AppThemeSettings settings) async {
    final file = File(_resolvedFilePath());
    await file.parent.create(recursive: true);
    await file.writeAsString(jsonEncode(settings.toJson()), flush: true);
    await _auditLogRepository?.record(
      AuditLogDraft(
        actionType: 'settings.theme.changed',
        descriptionAr:
            'تم تغيير مظهر التطبيق إلى ${settings.mode.labelAr} بلمسة ${settings.preset.labelAr}.',
      ),
    );
  }

  Future<AppThemePreset> loadThemePreset() async {
    return (await loadSettings()).preset;
  }

  Future<void> saveThemePreset(AppThemePreset preset) async {
    final current = await loadSettings();
    await saveSettings(AppThemeSettings(mode: current.mode, preset: preset));
  }

  String _resolvedFilePath() {
    if (_filePath != null) {
      return _filePath;
    }
    final appData = Platform.environment['APPDATA'];
    final home = Platform.environment['USERPROFILE'] ??
        Platform.environment['HOME'] ??
        Directory.current.path;
    final base = appData == null || appData.trim().isEmpty ? home : appData;
    return '$base${Platform.pathSeparator}GrainWarehouseErpLite${Platform.pathSeparator}theme.txt';
  }
}
