import 'package:grain_warehouse_erp_lite/application/commands/application_command.dart';
import 'package:grain_warehouse_erp_lite/core/trial/trial_service.dart';
import 'package:grain_warehouse_erp_lite/core/trial/trial_state.dart';

final class EvaluateTrialCommand {
  const EvaluateTrialCommand();
}

final class EvaluateTrialCommandHandler
    implements
        ApplicationCommandHandler<EvaluateTrialCommand, TrialEvaluation>,
        TrialEvaluator {
  const EvaluateTrialCommandHandler({
    required TrialEvaluator trialEvaluator,
  }) : _trialEvaluator = trialEvaluator;

  final TrialEvaluator _trialEvaluator;

  @override
  Future<TrialEvaluation> execute(
    ApplicationCommandRequest<EvaluateTrialCommand> request,
  ) {
    return _trialEvaluator.evaluate();
  }

  /// Keeps the existing minute checkpoint contract while routing every UI
  /// refresh through the same application command boundary.
  @override
  Future<TrialEvaluation> evaluate() {
    return execute(
      const ApplicationCommandRequest(command: EvaluateTrialCommand()),
    );
  }
}
