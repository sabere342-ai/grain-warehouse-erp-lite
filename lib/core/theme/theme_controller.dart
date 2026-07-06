import 'package:flutter/widgets.dart';
import 'package:grain_warehouse_erp_lite/core/theme/app_theme_preset.dart';
import 'package:grain_warehouse_erp_lite/core/theme/theme_settings_repository.dart';

class ThemeController extends ChangeNotifier {
  ThemeController({required ThemeSettingsRepository repository})
      : _repository = repository;

  final ThemeSettingsRepository _repository;
  AppThemePreset _preset = AppThemePreset.olive;
  bool _isLoading = false;
  String? _message;

  AppThemePreset get preset => _preset;
  bool get isLoading => _isLoading;
  String? get message => _message;

  Future<void> initialize() async {
    _isLoading = true;
    notifyListeners();
    _preset = await _repository.loadThemePreset();
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
      await _repository.saveThemePreset(preset);
      _message = 'تم حفظ الألوان.';
    } catch (_) {
      _message = 'تم تطبيق الألوان الآن، لكن تعذر حفظها للجلسة القادمة.';
    }
    notifyListeners();
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
