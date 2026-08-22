import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:grain_warehouse_erp_lite/app/routes.dart';
import 'package:grain_warehouse_erp_lite/core/auth/auth_controller.dart';
import 'package:grain_warehouse_erp_lite/core/business_identity/business_identity_controller.dart';
import 'package:grain_warehouse_erp_lite/core/theme/app_theme.dart';
import 'package:grain_warehouse_erp_lite/core/theme/theme_controller.dart';
import 'package:grain_warehouse_erp_lite/features/auth/auth_gate.dart';

class GrainWarehouseApp extends StatefulWidget {
  const GrainWarehouseApp({
    super.key,
    required this.authController,
    required this.themeController,
    required this.businessIdentityController,
    this.initializeAuth = true,
  });

  final AuthController authController;
  final ThemeController themeController;
  final BusinessIdentityController businessIdentityController;
  final bool initializeAuth;

  @override
  State<GrainWarehouseApp> createState() => _GrainWarehouseAppState();
}

class _GrainWarehouseAppState extends State<GrainWarehouseApp> {
  late final AuthController _authController;
  late final ThemeController _themeController;
  late final BusinessIdentityController _businessIdentityController;

  @override
  void initState() {
    super.initState();
    _authController = widget.authController;
    _themeController = widget.themeController;
    _businessIdentityController = widget.businessIdentityController;

    if (widget.initializeAuth) {
      _authController.initialize();
    }
    _themeController.initialize();
    _businessIdentityController.initialize();
  }

  @override
  Widget build(BuildContext context) {
    return BusinessIdentityScope(
      controller: _businessIdentityController,
      child: ThemeScope(
        controller: _themeController,
        child: AuthScope(
          controller: _authController,
          child: AnimatedBuilder(
            animation: Listenable.merge([
              _themeController,
              _businessIdentityController,
            ]),
            builder: (context, _) {
              return MaterialApp(
                title: _businessIdentityController.identity.displayName,
                debugShowCheckedModeBanner: false,
                theme: AppTheme.lightFor(_themeController.preset),
                darkTheme: AppTheme.darkFor(_themeController.preset),
                themeMode: _themeController.mode.materialMode,
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
      ),
    );
  }
}
