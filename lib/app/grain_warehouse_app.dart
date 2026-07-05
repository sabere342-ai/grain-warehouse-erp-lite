import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:grain_warehouse_erp_lite/app/routes.dart';
import 'package:grain_warehouse_erp_lite/core/auth/auth_controller.dart';
import 'package:grain_warehouse_erp_lite/core/auth/auth_repository.dart';
import 'package:grain_warehouse_erp_lite/core/theme/app_theme.dart';
import 'package:grain_warehouse_erp_lite/features/auth/auth_gate.dart';

class GrainWarehouseApp extends StatefulWidget {
  const GrainWarehouseApp({
    super.key,
    this.authController,
    this.initializeAuth = true,
  });

  final AuthController? authController;
  final bool initializeAuth;

  @override
  State<GrainWarehouseApp> createState() => _GrainWarehouseAppState();
}

class _GrainWarehouseAppState extends State<GrainWarehouseApp> {
  late final AuthController _authController;
  late final bool _ownsController;

  @override
  void initState() {
    super.initState();
    _ownsController = widget.authController == null;
    _authController = widget.authController ??
        AuthController(repository: LocalAuthRepository.empty());

    if (widget.initializeAuth) {
      _authController.initialize();
    }
  }

  @override
  void dispose() {
    if (_ownsController) {
      _authController.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AuthScope(
      controller: _authController,
      child: MaterialApp(
        title: 'Grain Warehouse ERP Lite',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.light,
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
      ),
    );
  }
}
