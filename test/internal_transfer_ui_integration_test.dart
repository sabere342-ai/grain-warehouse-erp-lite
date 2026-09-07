import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('Cloud transfer uses typed command and cannot use local authority', () {
    final source = File(
      'lib/features/financial_accounts/financial_transfers_screen.dart',
    ).readAsStringSync();
    final compact = source.replaceAll(RegExp(r'\s+'), '');

    expect(compact,
        contains('ApplicationScope.of(context).commands.postInternalTransfer'));
    expect(source, contains('if (_isCloudMode)'));
    expect(source, contains('await _postCloudTransfer'));
    expect(source, contains('if (_isCloudMode) {\n      _message'));
    expect(
      source.indexOf('await _postCloudTransfer'),
      lessThan(source.indexOf('_controller.createTransfer')),
    );
  });

  test('Cloud UI exposes explicit recovery and stable failure states', () {
    final source = File(
      'lib/features/financial_accounts/financial_transfers_screen.dart',
    ).readAsStringSync();
    for (final token in <String>[
      'queued',
      'sending',
      'unknownOutcome',
      'confirmedProjectionPending',
      'confirmed',
      'serverUnavailable',
      'balance.insufficient',
      'transferReference.conflict',
      'idempotencyConflict',
      'loadIncompleteForBusiness',
    ]) {
      expect(source, contains(token), reason: 'missing UI state $token');
    }
  });
}
