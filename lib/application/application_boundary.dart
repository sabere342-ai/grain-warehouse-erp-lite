import 'package:grain_warehouse_erp_lite/application/application_dependencies.dart';
import 'package:grain_warehouse_erp_lite/application/commands/evaluate_trial_command.dart';
import 'package:grain_warehouse_erp_lite/application/commands/post_expense_command.dart';
import 'package:grain_warehouse_erp_lite/application/queries/load_audit_logs_query.dart';
import 'package:grain_warehouse_erp_lite/application/queries/load_business_logo_query.dart';
import 'package:grain_warehouse_erp_lite/application/queries/load_document_history_query.dart';
import 'package:grain_warehouse_erp_lite/application/queries/load_product_catalog_query.dart';

final class ApplicationBoundary {
  const ApplicationBoundary({
    required this.dependencies,
    required this.commands,
    required this.queries,
  });

  final ApplicationDependencies dependencies;
  final ApplicationCommands commands;
  final ApplicationQueries queries;
}

final class ApplicationCommands {
  const ApplicationCommands({
    required this.trialEvaluation,
    required this.postExpense,
  });

  final EvaluateTrialCommandHandler trialEvaluation;
  final PostExpenseCommandHandler postExpense;
}

final class ApplicationQueries {
  const ApplicationQueries({
    required this.auditLogs,
    required this.businessLogo,
    required this.documentHistory,
    required this.productCatalog,
  });

  final LoadAuditLogsQueryHandler auditLogs;
  final LoadBusinessLogoQueryHandler businessLogo;
  final LoadDocumentHistoryQueryHandler documentHistory;
  final LoadProductCatalogQueryHandler productCatalog;
}
