import 'package:flutter/widgets.dart';
import 'package:grain_warehouse_erp_lite/core/theme/app_theme_mode.dart';
import 'package:grain_warehouse_erp_lite/core/theme/app_theme_preset.dart';
import 'package:grain_warehouse_erp_lite/core/theme/theme_settings_repository.dart';

class ThemeController extends ChangeNotifier {
  ThemeController({required ThemeSettingsRepository repository})
      : _repository = repository;

  final ThemeSettingsRepository _repository;
  AppThemePreset _preset = AppThemePreset.olive;
  AppThemeMode _mode = AppThemeMode.system;
  bool _isLoading = false;
  String? _message;

  AppThemePreset get preset => _preset;
  AppThemeMode get mode => _mode;
  bool get isLoading => _isLoading;
  String? get message => _message;

  Future<void> initialize() async {
    _isLoading = true;
    notifyListeners();
    final settings = await _repository.loadSettings();
    _preset = settings.preset;
    _mode = settings.mode;
    _isLoading = false;
    notifyListeners();
  }

  Future<void> selectPreset(AppThemePreset preset) async {
    if (preset.id == _preset.id) {
      return;
    }
    _preset = preset;
    _message = null;
    notifyListeners();
    try {
      await _save();
      _message = 'تم حفظ الألوان.';
    } catch (_) {
      _message = 'تم تطبيق الألوان الآن، لكن تعذر حفظها للجلسة القادمة.';
    }
    notifyListeners();
  }

  Future<void> selectMode(AppThemeMode mode) async {
    if (mode == _mode) return;
    _mode = mode;
    _message = null;
    notifyListeners();
    try {
      await _save();
      _message = 'تم حفظ وضع العرض.';
    } catch (_) {
      _message = 'تم تطبيق وضع العرض الآن، لكن تعذر حفظه للجلسة القادمة.';
    }
    notifyListeners();
  }

  Future<void> _save() {
    return _repository.saveSettings(
      AppThemeSettings(mode: _mode, preset: _preset),
    );
  }
}

class ThemeScope extends InheritedNotifier<ThemeController> {
  const ThemeScope({
    super.key,
    required ThemeController controller,
    required super.child,
  }) : super(notifier: controller);

  static ThemeController of(BuildContext context) {
    final scope = context.dependOnInheritedWidgetOfExactType<ThemeScope>();
    if (scope == null || scope.notifier == null) {
      throw StateError('ThemeScope was not found.');
    }
    return scope.notifier!;
  }
}
