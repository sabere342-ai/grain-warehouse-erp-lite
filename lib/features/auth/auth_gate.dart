import 'package:flutter/material.dart';
import 'package:grain_warehouse_erp_lite/core/auth/auth_controller.dart';
import 'package:grain_warehouse_erp_lite/core/auth/auth_state.dart';
import 'package:grain_warehouse_erp_lite/features/auth/first_owner_setup_screen.dart';
import 'package:grain_warehouse_erp_lite/features/auth/login_screen.dart';
import 'package:grain_warehouse_erp_lite/features/dashboard/dashboard_shell.dart';

class AuthGate extends StatelessWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context) {
    final auth = AuthScope.of(context);
    final state = auth.state;

    switch (state.status) {
      case AuthStatus.checking:
        return const Scaffold(
          body: Center(child: CircularProgressIndicator()),
        );
      case AuthStatus.needsFirstOwner:
        return const FirstOwnerSetupScreen();
      case AuthStatus.signedOut:
        return const LoginScreen();
      case AuthStatus.signedIn:
        if (!state.canProceed) {
          return const LoginScreen();
        }
        return const DashboardShell();
    }
  }
}
