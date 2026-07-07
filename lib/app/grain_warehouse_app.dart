import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:grain_warehouse_erp_lite/app/app_repositories.dart';
import 'package:grain_warehouse_erp_lite/app/routes.dart';
import 'package:grain_warehouse_erp_lite/core/auth/auth_controller.dart';
import 'package:grain_warehouse_erp_lite/core/auth/auth_repository.dart';
import 'package:grain_warehouse_erp_lite/core/theme/app_theme.dart';
import 'package:grain_warehouse_erp_lite/core/theme/theme_controller.dart';
import 'package:grain_warehouse_erp_lite/core/theme/theme_settings_repository.dart';
import 'package:grain_warehouse_erp_lite/features/auth/auth_gate.dart';

class GrainWarehouseApp extends StatefulWidget {
  const GrainWarehouseApp({
    super.key,
    this.authController,
    this.themeController,
    this.initializeAuth = true,
  });

  final AuthController? authController;
  final ThemeController? themeController;
  final bool initializeAuth;

  @override
  State<GrainWarehouseApp> createState() => _GrainWarehouseAppState();
}

class _GrainWarehouseAppState extends State<GrainWarehouseApp> {
  late final AuthController _authController;
  late final ThemeController _themeController;
  late final bool _ownsAuthController;
  late final bool _ownsThemeController;

  @override
  void initState() {
    super.initState();
    _ownsAuthController = widget.authController == null;
    _ownsThemeController = widget.themeController == null;
    _authController = widget.authController ??
        AuthController(repository: LocalAuthRepository.empty());
    _themeController = widget.themeController ??
        ThemeController(
            repository: LocalThemeSettingsRepository(
              auditLogRepository: AppRepositories.auditLogRepository,
            ),
          );

    if (widget.initializeAuth) {
      _authController.initialize();
    }
    _themeController.initialize();
  }

  @override
  void dispose() {
    if (_ownsAuthController) {
      _authController.dispose();
    }
    if (_ownsThemeController) {
      _themeController.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ThemeScope(
      controller: _themeController,
      child: AuthScope(
        controller: _authController,
        child: AnimatedBuilder(
          animation: _themeController,
          builder: (context, _) {
            return MaterialApp(
              title: 'Grain Warehouse ERP Lite',
              debugShowCheckedModeBanner: false,
              theme: AppTheme.fromPreset(_themeController.preset),
              locale: const Locale('ar'),
              supportedLocales: const [Locale('ar')],
              localizationsDelegates: GlobalMaterialLocalizations.delegates,
              builder: (context, child) {
                return Directionality(
                  textDirection: TextDirection.rtl,
                  child: child ?? const SizedBox.shrink(),
                );
              },
              routes: AppRoutes.routes,
              home: const AuthGate(),
            );
          },
        ),
      ),
    );
  }
}
