import 'package:flutter/widgets.dart';
import 'package:grain_warehouse_erp_lite/app/grain_warehouse_app.dart';
import 'package:grain_warehouse_erp_lite/application/commands/application_command.dart';
import 'package:grain_warehouse_erp_lite/application/commands/evaluate_trial_command.dart';
import 'package:grain_warehouse_erp_lite/composition/app_composition_root.dart';
import 'package:grain_warehouse_erp_lite/composition/application_scope.dart';
import 'package:grain_warehouse_erp_lite/core/firebase/firebase_bootstrap.dart';
import 'package:grain_warehouse_erp_lite/features/trial/trial_app_gate.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await FirebaseBootstrap.initialize();
  final application = await AppCompositionRoot.initializeProduction();
  final trialEvaluation = await application.commands.trialEvaluation.execute(
    const ApplicationCommandRequest(command: EvaluateTrialCommand()),
  );
  runApp(
    ApplicationScope(
      application: application,
      child: TrialAppGate(
        evaluation: trialEvaluation,
        evaluator: application.commands.trialEvaluation,
        child: GrainWarehouseApp(
          authController: application.dependencies.runtime.authController,
          themeController: application.dependencies.runtime.themeController,
          businessIdentityController:
              application.dependencies.runtime.businessIdentityController,
        ),
      ),
    ),
  );
}
