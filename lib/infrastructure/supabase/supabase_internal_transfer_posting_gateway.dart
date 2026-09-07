import 'dart:async';

import 'package:grain_warehouse_erp_lite/application/financial_transfers/internal_transfer_posting_gateway.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

final class SupabaseInternalTransferPostingGateway
    implements InternalTransferPostingGateway {
  const SupabaseInternalTransferPostingGateway(this._client);

  final SupabaseClient _client;

  @override
  Future<InternalTransferPostingGatewayResponse> post(
    InternalTransferPostingRequestPayload payload,
  ) async {
    final session = _client.auth.currentSession;
    if (session == null || session.isExpired) {
      return const InternalTransferPostingGatewayFailure(
        category: PostInternalTransferFailureCategory.authentication,
        code: 'unauthenticated.sessionRequired',
        retryable: false,
      );
    }
    try {
      final response = await _client.rpc(
        'post_internal_transfer_v1',
        params: payload.toRpcParameters(),
      );
      if (response is! Map) return _unexpected('rpc-shape');
      final json = response.cast<String, dynamic>();
      if (json['ok'] != true) return _failureFromJson(json);
      final audits = (json['auditEventIds'] as List?)
          ?.map((value) => value as String)
          .toList(growable: false);
      if (audits == null || audits.length != 3 || audits.toSet().length != 3) {
        return _unexpected('rpc-audits');
      }
      return InternalTransferPostingGatewaySuccess(
        commandId: json['commandId'] as String,
        businessId: json['businessId'] as String,
        transferId: json['transferId'] as String,
        displayNumber: json['displayNumber'] as String,
        transferReference: json['transferReference'] as String,
        sourceFinancialAccountId: json['sourceFinancialAccountId'] as String,
        destinationFinancialAccountId:
            json['destinationFinancialAccountId'] as String,
        sourceFinancialEntryId: json['sourceFinancialEntryId'] as String,
        destinationFinancialEntryId:
            json['destinationFinancialEntryId'] as String,
        auditEventIds: audits,
        effectiveBusinessDate: json['effectiveBusinessDate'] as String,
        amountQirsh: json['amountQirsh'] as int,
        sourceBalanceAfterQirsh: json['sourceBalanceAfterQirsh'] as int,
        destinationBalanceAfterQirsh:
            json['destinationBalanceAfterQirsh'] as int,
        serverAcceptedAtUtc:
            DateTime.parse(json['serverAcceptedAtUtc'] as String).toUtc(),
        replayed: json['replayed'] as bool? ?? false,
      );
    } on TimeoutException {
      return _unavailable();
    } on PostgrestException catch (error) {
      if (error.code == '42501' || error.code == 'PGRST301') {
        return const InternalTransferPostingGatewayFailure(
          category: PostInternalTransferFailureCategory.authentication,
          code: 'unauthenticated.sessionRequired',
          retryable: false,
        );
      }
      if (error.code?.startsWith('08') == true ||
          error.code == 'PGRST000' ||
          error.code == 'PGRST002') {
        return _unavailable();
      }
      return InternalTransferPostingGatewayFailure(
        category: PostInternalTransferFailureCategory.transaction,
        code: 'transactionFailure',
        retryable: true,
        diagnosticReference: _safeDiagnostic(error.code),
      );
    } on Object {
      return _unavailable();
    }
  }

  InternalTransferPostingGatewayFailure _failureFromJson(
    Map<String, dynamic> json,
  ) {
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
    final stableCode =
        _stableCodes.contains(code) ? code : 'unexpectedServerError';
    return InternalTransferPostingGatewayFailure(
      category: _category(stableCode),
      code: stableCode,
      retryable: json['retryable'] as bool? ??
          stableCode == 'serverUnavailable' ||
              stableCode == 'transactionFailure',
      fieldErrors: Map<String, String>.unmodifiable(fields),
      diagnosticReference:
          _safeDiagnostic(json['diagnosticReference'] as String?),
    );
  }

  PostInternalTransferFailureCategory _category(String code) {
    if (code.startsWith('validation.')) {
      return PostInternalTransferFailureCategory.validation;
    }
    if (code.startsWith('unauthenticated.')) {
      return PostInternalTransferFailureCategory.authentication;
    }
    if (code.startsWith('unauthorized.')) {
      return PostInternalTransferFailureCategory.authorization;
    }
    return switch (code) {
      'wrongBusinessContext' =>
        PostInternalTransferFailureCategory.businessContext,
      'sourceAccount.notFoundOrInactive' ||
      'destinationAccount.notFoundOrInactive' =>
        PostInternalTransferFailureCategory.account,
      'period.closed' => PostInternalTransferFailureCategory.period,
      'balance.insufficient' => PostInternalTransferFailureCategory.balance,
      'transferReference.conflict' ||
      'idempotencyConflict' =>
        PostInternalTransferFailureCategory.idempotency,
      'serverUnavailable' => PostInternalTransferFailureCategory.connectivity,
      'transactionFailure' => PostInternalTransferFailureCategory.transaction,
      'projectionFailure' => PostInternalTransferFailureCategory.projection,
      _ => PostInternalTransferFailureCategory.unexpected,
    };
  }

  InternalTransferPostingGatewayFailure _unavailable() =>
      const InternalTransferPostingGatewayFailure(
        category: PostInternalTransferFailureCategory.connectivity,
        code: 'serverUnavailable',
        retryable: true,
      );

  InternalTransferPostingGatewayFailure _unexpected(String reference) =>
      InternalTransferPostingGatewayFailure(
        category: PostInternalTransferFailureCategory.unexpected,
        code: 'unexpectedServerError',
        retryable: true,
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
    'validation.sameAccount',
    'unauthenticated.sessionRequired',
    'unauthorized.internalTransferDenied',
    'wrongBusinessContext',
    'sourceAccount.notFoundOrInactive',
    'destinationAccount.notFoundOrInactive',
    'period.closed',
    'balance.insufficient',
    'transferReference.conflict',
    'idempotencyConflict',
    'serverUnavailable',
    'transactionFailure',
    'projectionFailure',
    'unexpectedServerError',
  };
}
