import 'dart:async';

import 'package:grain_warehouse_erp_lite/application/expenses/expense_posting_gateway.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

final class SupabaseExpensePostingGateway implements ExpensePostingGateway {
  const SupabaseExpensePostingGateway(this._client);

  final SupabaseClient _client;

  @override
  Future<ExpensePostingGatewayResponse> post(
    ExpensePostingRequestPayload payload,
  ) async {
    final session = _client.auth.currentSession;
    if (session == null || session.isExpired) {
      return const ExpensePostingGatewayFailure(
        category: PostExpenseFailureCategory.authentication,
        code: 'unauthenticated.sessionRequired',
        retryable: false,
      );
    }
    try {
      final response = await _client.rpc(
        'post_expense_v1',
        params: payload.toRpcParameters(),
      );
      if (response is! Map) {
        return _unexpected('rpc-shape');
      }
      final json = response.cast<String, dynamic>();
      if (json['ok'] != true) return _failureFromJson(json);
      final audits = (json['auditEventIds'] as List?)
          ?.map((value) => value as String)
          .toList(growable: false);
      if (audits == null || audits.length != 2 || audits[0] == audits[1]) {
        return _unexpected('rpc-audits');
      }
      return ExpensePostingGatewaySuccess(
        commandId: json['commandId'] as String,
        businessId: json['businessId'] as String,
        expenseId: json['expenseId'] as String,
        financialEntryId: json['financialEntryId'] as String,
        auditEventIds: audits,
        serverAcceptedAtUtc:
            DateTime.parse(json['serverAcceptedAtUtc'] as String).toUtc(),
        businessDate: json['businessDate'] as String,
        amountQirsh: json['amountQirsh'] as int,
        balanceAfterQirsh: json['balanceAfterQirsh'] as int,
        replayed: json['replayed'] as bool? ?? false,
      );
    } on TimeoutException {
      return _unavailable();
    } on PostgrestException catch (error) {
      if (error.code == '42501' || error.code == 'PGRST301') {
        return const ExpensePostingGatewayFailure(
          category: PostExpenseFailureCategory.authentication,
          code: 'unauthenticated.sessionRequired',
          retryable: false,
        );
      }
      if (error.code?.startsWith('08') == true ||
          error.code == 'PGRST000' ||
          error.code == 'PGRST002') {
        return _unavailable();
      }
      return ExpensePostingGatewayFailure(
        category: PostExpenseFailureCategory.transaction,
        code: 'transactionFailure',
        retryable: true,
        diagnosticReference: _safeDiagnostic(error.code),
      );
    } on Object {
      return _unavailable();
    }
  }

  ExpensePostingGatewayFailure _failureFromJson(Map<String, dynamic> json) {
    final code = json['code'] as String? ?? 'unexpectedServerError';
    final fields = <String, String>{};
    final rawFields = json['fieldErrors'];
    if (rawFields is Map) {
      for (final entry in rawFields.entries) {
        if (entry.key is String && entry.value is String) {
          fields[entry.key as String] = entry.value as String;
        }
      }
    }
    return ExpensePostingGatewayFailure(
      category: _category(code),
      code: _stableCodes.contains(code) ? code : 'unexpectedServerError',
      retryable: json['retryable'] as bool? ?? code == 'serverUnavailable',
      fieldErrors: Map<String, String>.unmodifiable(fields),
      diagnosticReference: _safeDiagnostic(
        json['diagnosticReference'] as String?,
      ),
    );
  }

  PostExpenseFailureCategory _category(String code) {
    if (code.startsWith('validation.')) {
      return PostExpenseFailureCategory.validation;
    }
    if (code.startsWith('unauthenticated.')) {
      return PostExpenseFailureCategory.authentication;
    }
    if (code.startsWith('unauthorized.')) {
      return PostExpenseFailureCategory.authorization;
    }
    return switch (code) {
      'wrongBusinessContext' => PostExpenseFailureCategory.businessContext,
      'account.notFoundOrInactive' => PostExpenseFailureCategory.account,
      'paymentRoute.invalid' => PostExpenseFailureCategory.paymentRoute,
      'period.closed' => PostExpenseFailureCategory.period,
      'balance.insufficient' => PostExpenseFailureCategory.balance,
      'approvalRequired' => PostExpenseFailureCategory.approval,
      'idempotencyConflict' => PostExpenseFailureCategory.idempotency,
      'serverUnavailable' => PostExpenseFailureCategory.connectivity,
      'transactionFailure' => PostExpenseFailureCategory.transaction,
      'projectionFailure' => PostExpenseFailureCategory.projection,
      _ => PostExpenseFailureCategory.unexpected,
    };
  }

  ExpensePostingGatewayFailure _unavailable() =>
      const ExpensePostingGatewayFailure(
        category: PostExpenseFailureCategory.connectivity,
        code: 'serverUnavailable',
        retryable: true,
      );

  ExpensePostingGatewayFailure _unexpected(String reference) =>
      ExpensePostingGatewayFailure(
        category: PostExpenseFailureCategory.unexpected,
        code: 'unexpectedServerError',
        retryable: false,
        diagnosticReference: reference,
      );

  String? _safeDiagnostic(String? value) {
    if (value == null) return null;
    final normalized = value.replaceAll(RegExp('[^A-Za-z0-9_.-]'), '');
    return normalized.isEmpty
        ? null
        : normalized.substring(
            0,
            normalized.length > 64 ? 64 : normalized.length,
          );
  }

  static const _stableCodes = <String>{
    'validation.invalidField',
    'unauthenticated.sessionRequired',
    'unauthorized.expensePostingDenied',
    'wrongBusinessContext',
    'account.notFoundOrInactive',
    'paymentRoute.invalid',
    'period.closed',
    'balance.insufficient',
    'approvalRequired',
    'idempotencyConflict',
    'serverUnavailable',
    'transactionFailure',
    'projectionFailure',
    'unexpectedServerError',
  };
}
