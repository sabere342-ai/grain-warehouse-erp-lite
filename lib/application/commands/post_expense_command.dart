import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:grain_warehouse_erp_lite/application/commands/application_command.dart';
import 'package:grain_warehouse_erp_lite/application/context/business_context.dart';
import 'package:grain_warehouse_erp_lite/application/context/session_context.dart';
import 'package:grain_warehouse_erp_lite/application/expenses/confirmed_expense_projection_writer.dart';
import 'package:grain_warehouse_erp_lite/application/expenses/expense_posting_attempt_store.dart';
import 'package:grain_warehouse_erp_lite/application/expenses/expense_posting_gateway.dart';
import 'package:grain_warehouse_erp_lite/core/expenses/expense.dart';
import 'package:grain_warehouse_erp_lite/core/financial_accounts/financial_account_entry.dart';
import 'package:uuid/uuid.dart';

final class PostExpenseCommand {
  factory PostExpenseCommand({
    required String commandId,
    int schemaVersion = 1,
    required String businessId,
    required String businessDate,
    required String category,
    required int amountQirsh,
    String? notes,
    required String financialAccountId,
    required PaymentMethod paymentMethod,
    required ExpenseAccountingClassification accountingClassification,
  }) {
    final normalizedCommandId = commandId.trim().toLowerCase();
    final normalizedBusinessId = businessId.trim().toLowerCase();
    final normalizedAccountId = financialAccountId.trim().toLowerCase();
    final normalizedCategory = category.trim();
    final normalizedNotes = _optional(notes);
    if (schemaVersion != 1) {
      throw ArgumentError.value(schemaVersion, 'schemaVersion');
    }
    for (final entry in <String, String>{
      'commandId': normalizedCommandId,
      'businessId': normalizedBusinessId,
      'financialAccountId': normalizedAccountId,
    }.entries) {
      if (!Uuid.isValidUUID(fromString: entry.value)) {
        throw ArgumentError.value(entry.value, entry.key, 'UUID required.');
      }
    }
    if (!_isValidDateOnly(businessDate)) {
      throw ArgumentError.value(businessDate, 'businessDate');
    }
    if (normalizedCategory.isEmpty) {
      throw ArgumentError.value(category, 'category');
    }
    if (amountQirsh <= 0) {
      throw ArgumentError.value(amountQirsh, 'amountQirsh');
    }
    if (paymentMethod == PaymentMethod.check) {
      throw ArgumentError.value(paymentMethod, 'paymentMethod');
    }
    return PostExpenseCommand._(
      commandId: normalizedCommandId,
      schemaVersion: schemaVersion,
      businessId: normalizedBusinessId,
      businessDate: businessDate,
      category: normalizedCategory,
      amountQirsh: amountQirsh,
      notes: normalizedNotes,
      financialAccountId: normalizedAccountId,
      paymentMethod: paymentMethod,
      accountingClassification: accountingClassification,
    );
  }

  const PostExpenseCommand._({
    required this.commandId,
    required this.schemaVersion,
    required this.businessId,
    required this.businessDate,
    required this.category,
    required this.amountQirsh,
    required this.notes,
    required this.financialAccountId,
    required this.paymentMethod,
    required this.accountingClassification,
  });

  final String commandId;
  final int schemaVersion;
  final String businessId;
  final String businessDate;
  final String category;
  final int amountQirsh;
  final String? notes;
  final String financialAccountId;
  final PaymentMethod paymentMethod;
  final ExpenseAccountingClassification accountingClassification;

  ExpensePostingRequestPayload toGatewayPayload() =>
      ExpensePostingRequestPayload(
        commandId: commandId,
        schemaVersion: schemaVersion,
        businessId: businessId,
        businessDate: businessDate,
        category: category,
        amountQirsh: amountQirsh,
        notes: notes,
        financialAccountId: financialAccountId,
        paymentMethod: paymentMethod.name,
        accountingClassification: accountingClassification.name,
      );

  String get canonicalPayloadJson =>
      jsonEncode(toGatewayPayload().toCanonicalMap());
  String get localFingerprint =>
      sha256.convert(utf8.encode(canonicalPayloadJson)).toString();

  static String? _optional(String? value) {
    final normalized = value?.trim();
    return normalized == null || normalized.isEmpty ? null : normalized;
  }

  static bool _isValidDateOnly(String value) {
    final match = RegExp(r'^(\d{4})-(\d{2})-(\d{2})$').firstMatch(value);
    if (match == null) return false;
    final year = int.parse(match.group(1)!);
    final month = int.parse(match.group(2)!);
    final day = int.parse(match.group(3)!);
    if (month < 1 || month > 12 || day < 1 || day > 31) return false;
    final parsed = DateTime.utc(year, month, day);
    return parsed.year == year && parsed.month == month && parsed.day == day;
  }
}

sealed class PostExpenseResult {
  const PostExpenseResult({required this.commandId});
  final String commandId;
}

final class PostExpenseSuccess extends PostExpenseResult {
  const PostExpenseSuccess({
    required super.commandId,
    required this.businessId,
    required this.expenseId,
    required this.financialEntryId,
    required this.auditEventIds,
    required this.serverAcceptedAtUtc,
    required this.businessDate,
    required this.amountQirsh,
    required this.balanceAfterQirsh,
    required this.replayed,
    this.projectionPending = false,
    this.projectionErrorCode,
  });

  final String businessId;
  final String expenseId;
  final String financialEntryId;
  final List<String> auditEventIds;
  final DateTime serverAcceptedAtUtc;
  final String businessDate;
  final int amountQirsh;
  final int balanceAfterQirsh;
  final bool replayed;
  final bool projectionPending;
  final String? projectionErrorCode;

  PostExpenseSuccess copyWithProjectionPending(bool value) =>
      PostExpenseSuccess(
        commandId: commandId,
        businessId: businessId,
        expenseId: expenseId,
        financialEntryId: financialEntryId,
        auditEventIds: auditEventIds,
        serverAcceptedAtUtc: serverAcceptedAtUtc,
        businessDate: businessDate,
        amountQirsh: amountQirsh,
        balanceAfterQirsh: balanceAfterQirsh,
        replayed: replayed,
        projectionPending: value,
        projectionErrorCode: value ? 'projectionFailure' : null,
      );

  Map<String, Object?> toJson() => <String, Object?>{
        'amountQirsh': amountQirsh,
        'auditEventIds': auditEventIds,
        'balanceAfterQirsh': balanceAfterQirsh,
        'businessDate': businessDate,
        'businessId': businessId,
        'commandId': commandId,
        'expenseId': expenseId,
        'financialEntryId': financialEntryId,
        'replayed': replayed,
        'serverAcceptedAtUtc': serverAcceptedAtUtc.toUtc().toIso8601String(),
      };

  static PostExpenseSuccess fromJson(Map<String, Object?> json) =>
      PostExpenseSuccess(
        commandId: json['commandId']! as String,
        businessId: json['businessId']! as String,
        expenseId: json['expenseId']! as String,
        financialEntryId: json['financialEntryId']! as String,
        auditEventIds: (json['auditEventIds']! as List)
            .map((value) => value as String)
            .toList(growable: false),
        serverAcceptedAtUtc:
            DateTime.parse(json['serverAcceptedAtUtc']! as String).toUtc(),
        businessDate: json['businessDate']! as String,
        amountQirsh: json['amountQirsh']! as int,
        balanceAfterQirsh: json['balanceAfterQirsh']! as int,
        replayed: json['replayed']! as bool,
      );
}

final class PostExpenseFailure extends PostExpenseResult {
  const PostExpenseFailure({
    required super.commandId,
    required this.category,
    required this.code,
    required this.retryable,
    this.fieldErrors = const <String, String>{},
    this.diagnosticReference,
  });

  final PostExpenseFailureCategory category;
  final String code;
  final bool retryable;
  final Map<String, String> fieldErrors;
  final String? diagnosticReference;
}

final class PostExpenseCommandHandler
    implements
        ApplicationCommandHandler<PostExpenseCommand, PostExpenseResult> {
  const PostExpenseCommandHandler({
    required this.sessionContextProvider,
    required this.businessContextProvider,
    required this.attemptStore,
    required this.gateway,
    required this.projectionWriter,
  });

  final SessionContextProvider sessionContextProvider;
  final BusinessContextProvider businessContextProvider;
  final ExpensePostingAttemptStore attemptStore;
  final ExpensePostingGateway gateway;
  final ConfirmedExpenseProjectionWriter projectionWriter;

  @override
  Future<PostExpenseResult> execute(
    ApplicationCommandRequest<PostExpenseCommand> request,
  ) async {
    final command = request.command;
    if (request.idempotencyKey != command.commandId) {
      return _failure(command, PostExpenseFailureCategory.validation,
          'validation.invalidField');
    }
    final session = sessionContextProvider.current;
    if (session == null ||
        !session.isVerifiedRemote ||
        session.authUserId == null) {
      return _failure(command, PostExpenseFailureCategory.authentication,
          'unauthenticated.sessionRequired');
    }
    final activeBusiness = businessContextProvider.current;
    final requestBusiness = request.businessContext;
    if (activeBusiness == null ||
        requestBusiness == null ||
        !activeBusiness.isVerifiedMembership ||
        !requestBusiness.isVerifiedMembership ||
        activeBusiness.businessId != command.businessId ||
        requestBusiness.businessId != command.businessId ||
        activeBusiness.authUserId != session.authUserId ||
        requestBusiness.authUserId != session.authUserId) {
      return _failure(command, PostExpenseFailureCategory.businessContext,
          'wrongBusinessContext');
    }

    late ExpensePostingAttempt attempt;
    try {
      attempt = await attemptStore.prepare(
        commandId: command.commandId,
        businessId: command.businessId,
        canonicalPayloadJson: command.canonicalPayloadJson,
        localFingerprint: command.localFingerprint,
      );
    } on ExpensePostingAttemptConflictException {
      return _failure(command, PostExpenseFailureCategory.idempotency,
          'idempotencyConflict');
    }

    final storedResult = attempt.canonicalServerResultJson;
    if (storedResult != null &&
        (attempt.state ==
                ExpensePostingAttemptState.confirmedProjectionPending ||
            attempt.state == ExpensePostingAttemptState.confirmed)) {
      final success = PostExpenseSuccess.fromJson(
        (jsonDecode(storedResult) as Map<String, dynamic>)
            .cast<String, Object?>(),
      );
      if (attempt.state == ExpensePostingAttemptState.confirmed) return success;
      return _project(command, session.authUserId!, success);
    }

    await attemptStore.markSending(command.commandId);
    final response = await gateway.post(command.toGatewayPayload());
    if (response is ExpensePostingGatewayFailure) {
      final state = response.code == 'serverUnavailable'
          ? ExpensePostingAttemptState.unknownOutcome
          : ExpensePostingAttemptState.rejected;
      await attemptStore.markFailure(
        command.commandId,
        state: state,
        errorCode: response.code,
      );
      return PostExpenseFailure(
        commandId: command.commandId,
        category: response.category,
        code: response.code,
        retryable: response.retryable,
        fieldErrors: response.fieldErrors,
        diagnosticReference: response.diagnosticReference,
      );
    }
    final accepted = response as ExpensePostingGatewaySuccess;
    if (accepted.commandId != command.commandId ||
        accepted.businessId != command.businessId ||
        accepted.businessDate != command.businessDate ||
        accepted.amountQirsh != command.amountQirsh ||
        !Uuid.isValidUUID(fromString: accepted.expenseId) ||
        !Uuid.isValidUUID(fromString: accepted.financialEntryId) ||
        accepted.auditEventIds.length != 2 ||
        accepted.auditEventIds.toSet().length != 2 ||
        accepted.auditEventIds.any(
          (id) => !Uuid.isValidUUID(fromString: id),
        )) {
      await attemptStore.markFailure(
        command.commandId,
        state: ExpensePostingAttemptState.unknownOutcome,
        errorCode: 'unexpectedServerError',
      );
      return _failure(command, PostExpenseFailureCategory.unexpected,
          'unexpectedServerError',
          retryable: true);
    }
    final success = PostExpenseSuccess(
      commandId: accepted.commandId,
      businessId: accepted.businessId,
      expenseId: accepted.expenseId,
      financialEntryId: accepted.financialEntryId,
      auditEventIds: List<String>.unmodifiable(accepted.auditEventIds),
      serverAcceptedAtUtc: accepted.serverAcceptedAtUtc.toUtc(),
      businessDate: accepted.businessDate,
      amountQirsh: accepted.amountQirsh,
      balanceAfterQirsh: accepted.balanceAfterQirsh,
      replayed: accepted.replayed,
    );
    await attemptStore.markServerConfirmed(
      command.commandId,
      jsonEncode(success.toJson()),
    );
    return _project(command, session.authUserId!, success);
  }

  Future<PostExpenseSuccess> _project(
    PostExpenseCommand command,
    String actorAuthUserId,
    PostExpenseSuccess success,
  ) async {
    try {
      await projectionWriter.project(
        ConfirmedExpenseProjection(
          commandId: command.commandId,
          localFingerprint: command.localFingerprint,
          businessId: command.businessId,
          serverAccountId: command.financialAccountId,
          expenseId: success.expenseId,
          financialEntryId: success.financialEntryId,
          auditEventIds: success.auditEventIds,
          serverAcceptedAtUtc: success.serverAcceptedAtUtc,
          businessDate: success.businessDate,
          category: command.category,
          amountQirsh: command.amountQirsh,
          notes: command.notes,
          paymentMethod: command.paymentMethod,
          accountingClassification: command.accountingClassification,
          actorAuthUserId: actorAuthUserId,
          balanceAfterQirsh: success.balanceAfterQirsh,
        ),
      );
      await attemptStore.markConfirmed(command.commandId);
      return success.copyWithProjectionPending(false);
    } on Object {
      await attemptStore.markFailure(
        command.commandId,
        state: ExpensePostingAttemptState.confirmedProjectionPending,
        errorCode: 'projectionFailure',
      );
      return success.copyWithProjectionPending(true);
    }
  }

  PostExpenseFailure _failure(
    PostExpenseCommand command,
    PostExpenseFailureCategory category,
    String code, {
    bool retryable = false,
  }) =>
      PostExpenseFailure(
        commandId: command.commandId,
        category: category,
        code: code,
        retryable: retryable,
      );
}
