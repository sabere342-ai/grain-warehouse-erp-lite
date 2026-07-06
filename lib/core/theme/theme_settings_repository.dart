import 'dart:io';

import 'package:grain_warehouse_erp_lite/core/theme/app_theme_preset.dart';

abstract class ThemeSettingsRepository {
  Future<AppThemePreset> loadThemePreset();

  Future<void> saveThemePreset(AppThemePreset preset);
}

class LocalThemeSettingsRepository implements ThemeSettingsRepository {
  LocalThemeSettingsRepository({String? filePath}) : _filePath = filePath;

  final String? _filePath;

  @override
  Future<AppThemePreset> loadThemePreset() async {
    try {
      final file = File(_resolvedFilePath());
      if (!await file.exists()) {
        return AppThemePreset.olive;
      }
      final id = (await file.readAsString()).trim();
      return AppThemePreset.byId(id);
    } catch (_) {
      return AppThemePreset.olive;
    }
  }

  @override
  Future<void> saveThemePreset(AppThemePreset preset) async {
    final file = File(_resolvedFilePath());
    await file.parent.create(recursive: true);
    await file.writeAsString(preset.id);
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
