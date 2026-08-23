import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('expense production post uses only the typed application command seam',
      () {
    final source = File(
      'lib/features/expenses/expenses_screen.dart',
    ).readAsStringSync();
    final compactSource = source.replaceAll(RegExp(r'\s+'), '');

    expect(
      compactSource,
      contains('ApplicationScope.of(context).commands.postExpense'),
    );
    expect(source, isNot(contains('negativeBalanceApprovalWorkflowService')));
    expect(source, isNot(contains('.submitExpense(')));
    expect(source, isNot(contains('.createExpense(')));
  });

  test('expense UI carries all explicit Phase 108J lifecycle/error states', () {
    final source = File(
      'lib/features/expenses/expenses_screen.dart',
    ).readAsStringSync();

    for (final token in [
      'queued',
      'sending',
      'unknownOutcome',
      'confirmed',
      'confirmedProjectionPending',
      'approvalRequired',
      'validation.invalidField',
      'unauthorized.expensePostingDenied',
    ]) {
      expect(source, contains(token), reason: 'missing UI state $token');
    }
  });
}
