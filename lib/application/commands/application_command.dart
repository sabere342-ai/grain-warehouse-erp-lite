import 'package:grain_warehouse_erp_lite/application/context/execution_context.dart';

final class ApplicationCommandRequest<C> {
  const ApplicationCommandRequest({
    required this.command,
    this.executionContext,
    this.idempotencyKey,
  });

  final C command;
  final ExecutionContext? executionContext;

  /// Optional until commands are migrated to durable/server execution. A real
  /// key can be carried without changing handler signatures later.
  final String? idempotencyKey;
}

abstract interface class ApplicationCommandHandler<C, R> {
  Future<R> execute(ApplicationCommandRequest<C> request);
}
