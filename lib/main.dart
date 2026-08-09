import 'package:flutter/widgets.dart';
import 'package:grain_warehouse_erp_lite/app/grain_warehouse_app.dart';
import 'package:grain_warehouse_erp_lite/core/firebase/firebase_bootstrap.dart';
import 'package:grain_warehouse_erp_lite/app/app_repositories.dart';
import 'package:grain_warehouse_erp_lite/core/trial/trial_service.dart';
import 'package:grain_warehouse_erp_lite/features/trial/trial_app_gate.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await FirebaseBootstrap.initialize();
  await AppRepositories.initializeProduction();
  final trialService = await TrialService.production();
  final trialEvaluation = await trialService.evaluate();
  runApp(
    TrialAppGate(
      evaluation: trialEvaluation,
      evaluator: trialService,
      child: const GrainWarehouseApp(),
    ),
  );
}
