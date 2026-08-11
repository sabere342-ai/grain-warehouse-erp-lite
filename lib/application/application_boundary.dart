import 'package:grain_warehouse_erp_lite/application/application_dependencies.dart';
import 'package:grain_warehouse_erp_lite/application/commands/evaluate_trial_command.dart';

final class ApplicationBoundary {
  const ApplicationBoundary({
    required this.dependencies,
    required this.commands,
  });

  final ApplicationDependencies dependencies;
  final ApplicationCommands commands;
}

final class ApplicationCommands {
  const ApplicationCommands({
    required this.trialEvaluation,
  });

  final EvaluateTrialCommandHandler trialEvaluation;
}
