import 'package:grain_warehouse_erp_lite/application/queries/application_query.dart';
import 'package:grain_warehouse_erp_lite/core/expenses/expense.dart';
import 'package:grain_warehouse_erp_lite/core/expenses/expense_repository.dart';

final class LoadExpensesQuery {
  const LoadExpensesQuery();
}

final class LoadExpensesQueryHandler
    implements ApplicationQueryHandler<LoadExpensesQuery, List<ExpenseRecord>> {
  const LoadExpensesQueryHandler({required ExpenseRepository repository})
      : _repository = repository;

  final ExpenseRepository _repository;

  @override
  Future<ApplicationQueryResult<List<ExpenseRecord>>> execute(
    LoadExpensesQuery query,
  ) async {
    final expenses = await _repository.listExpenses();
    return ApplicationQueryResult(
      value: expenses,
      metadata: const LocalQueryResultMetadata(),
    );
  }
}
