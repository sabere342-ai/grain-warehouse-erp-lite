import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:grain_warehouse_erp_lite/application/commands/application_command.dart';
import 'package:grain_warehouse_erp_lite/application/context/business_context.dart';
import 'package:grain_warehouse_erp_lite/application/context/session_context.dart';
import 'package:grain_warehouse_erp_lite/application/financial_transfers/confirmed_internal_transfer_projection_writer.dart';
import 'package:grain_warehouse_erp_lite/application/financial_transfers/internal_transfer_posting_attempt_store.dart';
import 'package:grain_warehouse_erp_lite/application/financial_transfers/internal_transfer_posting_gateway.dart';
import 'package:uuid/uuid.dart';

final class PostInternalTransferCommand {
  factory PostInternalTransferCommand({
    required String commandId,
    int schemaVersion = 1,
    required String businessId,
    required String sourceFinancialAccountId,
    required String destinationFinancialAccountId,
    required int amountQirsh,
    required String effectiveBusinessDate,
    required String transferReference,
    String? note,
  }) {
    final normalizedCommandId = commandId.trim().toLowerCase();
    final normalizedBusinessId = businessId.trim().toLowerCase();
    final normalizedSourceId = sourceFinancialAccountId.trim().toLowerCase();
    final normalizedDestinationId =
        destinationFinancialAccountId.trim().toLowerCase();
    final normalizedReference = transferReference.trim().toLowerCase();
    if (schemaVersion != 1) {
      throw ArgumentError.value(schemaVersion, 'schemaVersion');
    }
    for (final entry in <String, String>{
      'commandId': normalizedCommandId,
      'businessId': normalizedBusinessId,
      'sourceFinancialAccountId': normalizedSourceId,
      'destinationFinancialAccountId': normalizedDestinationId,
      'transferReference': normalizedReference,
    }.entries) {
      if (!Uuid.isValidUUID(fromString: entry.value)) {
        throw ArgumentError.value(entry.value, entry.key, 'UUID required.');
      }
    }
    if (normalizedSourceId == normalizedDestinationId) {
      throw ArgumentError.value(
        destinationFinancialAccountId,
        'destinationFinancialAccountId',
        'Source and destination must differ.',
      );
    }
    if (amountQirsh <= 0) {
      throw ArgumentError.value(amountQirsh, 'amountQirsh');
    }
    if (!_isValidDateOnly(effectiveBusinessDate)) {
      throw ArgumentError.value(
        effectiveBusinessDate,
        'effectiveBusinessDate',
      );
    }
    return PostInternalTransferCommand._(
      commandId: normalizedCommandId,
      schemaVersion: schemaVersion,
      businessId: normalizedBusinessId,
      sourceFinancialAccountId: normalizedSourceId,
      destinationFinancialAccountId: normalizedDestinationId,
      amountQirsh: amountQirsh,
      effectiveBusinessDate: effectiveBusinessDate,
      transferReference: normalizedReference,
      note: _optional(note),
    );
  }

  const PostInternalTransferCommand._({
    required this.commandId,
    required this.schemaVersion,
    required this.businessId,
    required this.sourceFinancialAccountId,
    required this.destinationFinancialAccountId,
    required this.amountQirsh,
    required this.effectiveBusinessDate,
    required this.transferReference,
    required this.note,
  });

  final String commandId;
  final int schemaVersion;
  final String businessId;
  final String sourceFinancialAccountId;
  final String destinationFinancialAccountId;
  final int amountQirsh;
  final String effectiveBusinessDate;
  final String transferReference;
  final String? note;

  InternalTransferPostingRequestPayload toGatewayPayload() =>
      InternalTransferPostingRequestPayload(
        commandId: commandId,
        schemaVersion: schemaVersion,
        businessId: businessId,
        sourceFinancialAccountId: sourceFinancialAccountId,
        destinationFinancialAccountId: destinationFinancialAccountId,
        amountQirsh: amountQirsh,
        effectiveBusinessDate: effectiveBusinessDate,
        transferReference: transferReference,
        note: note,
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

sealed class PostInternalTransferResult {
  const PostInternalTransferResult({required this.commandId});
  final String commandId;
}

final class PostInternalTransferSuccess extends PostInternalTransferResult {
  const PostInternalTransferSuccess({
    required super.commandId,
    required this.businessId,
    required this.transferId,
    required this.displayNumber,
    required this.transferReference,
    required this.sourceFinancialAccountId,
    required this.destinationFinancialAccountId,
    required this.sourceFinancialEntryId,
    required this.destinationFinancialEntryId,
    required this.auditEventIds,
    required this.effectiveBusinessDate,
    required this.amountQirsh,
    required this.sourceBalanceAfterQirsh,
    required this.destinationBalanceAfterQirsh,
    required this.serverAcceptedAtUtc,
    required this.replayed,
    this.projectionPending = false,
    this.projectionErrorCode,
  });

  final String businessId;
  final String transferId;
  final String displayNumber;
  final String transferReference;
  final String sourceFinancialAccountId;
  final String destinationFinancialAccountId;
  final String sourceFinancialEntryId;
  final String destinationFinancialEntryId;
  final List<String> auditEventIds;
  final String effectiveBusinessDate;
  final int amountQirsh;
  final int sourceBalanceAfterQirsh;
  final int destinationBalanceAfterQirsh;
  final DateTime serverAcceptedAtUtc;
  final bool replayed;
  final bool projectionPending;
  final String? projectionErrorCode;

  PostInternalTransferSuccess copyWithProjectionPending(bool value) =>
      PostInternalTransferSuccess(
        commandId: commandId,
        businessId: businessId,
        transferId: transferId,
        displayNumber: displayNumber,
        transferReference: transferReference,
        sourceFinancialAccountId: sourceFinancialAccountId,
        destinationFinancialAccountId: destinationFinancialAccountId,
        sourceFinancialEntryId: sourceFinancialEntryId,
        destinationFinancialEntryId: destinationFinancialEntryId,
        auditEventIds: auditEventIds,
        effectiveBusinessDate: effectiveBusinessDate,
        amountQirsh: amountQirsh,
        sourceBalanceAfterQirsh: sourceBalanceAfterQirsh,
        destinationBalanceAfterQirsh: destinationBalanceAfterQirsh,
        serverAcceptedAtUtc: serverAcceptedAtUtc,
        replayed: replayed,
        projectionPending: value,
        projectionErrorCode: value ? 'projectionFailure' : null,
      );

  Map<String, Object?> toJson() => <String, Object?>{
        'amountQirsh': amountQirsh,
        'auditEventIds': auditEventIds,
        'businessId': businessId,
        'commandId': commandId,
        'destinationBalanceAfterQirsh': destinationBalanceAfterQirsh,
        'destinationFinancialAccountId': destinationFinancialAccountId,
        'destinationFinancialEntryId': destinationFinancialEntryId,
        'displayNumber': displayNumber,
        'effectiveBusinessDate': effectiveBusinessDate,
        'replayed': replayed,
        'serverAcceptedAtUtc': serverAcceptedAtUtc.toUtc().toIso8601String(),
        'sourceBalanceAfterQirsh': sourceBalanceAfterQirsh,
        'sourceFinancialAccountId': sourceFinancialAccountId,
        'sourceFinancialEntryId': sourceFinancialEntryId,
        'transferId': transferId,
        'transferReference': transferReference,
      };

  static PostInternalTransferSuccess fromJson(Map<String, Object?> json) =>
      PostInternalTransferSuccess(
        commandId: json['commandId']! as String,
        businessId: json['businessId']! as String,
        transferId: json['transferId']! as String,
        displayNumber: json['displayNumber']! as String,
        transferReference: json['transferReference']! as String,
        sourceFinancialAccountId: json['sourceFinancialAccountId']! as String,
        destinationFinancialAccountId:
            json['destinationFinancialAccountId']! as String,
        sourceFinancialEntryId: json['sourceFinancialEntryId']! as String,
        destinationFinancialEntryId:
            json['destinationFinancialEntryId']! as String,
        auditEventIds: (json['auditEventIds']! as List)
            .map((value) => value as String)
            .toList(growable: false),
        effectiveBusinessDate: json['effectiveBusinessDate']! as String,
        amountQirsh: json['amountQirsh']! as int,
        sourceBalanceAfterQirsh: json['sourceBalanceAfterQirsh']! as int,
        destinationBalanceAfterQirsh:
            json['destinationBalanceAfterQirsh']! as int,
        serverAcceptedAtUtc:
            DateTime.parse(json['serverAcceptedAtUtc']! as String).toUtc(),
        replayed: json['replayed']! as bool,
      );
}

final class PostInternalTransferFailure extends PostInternalTransferResult {
  const PostInternalTransferFailure({
    required super.commandId,
    required this.category,
    required this.code,
    required this.retryable,
    this.fieldErrors = const <String, String>{},
    this.diagnosticReference,
  });

  final PostInternalTransferFailureCategory category;
  final String code;
  final bool retryable;
  final Map<String, String> fieldErrors;
  final String? diagnosticReference;
}

final class PostInternalTransferCommandHandler
    implements
        ApplicationCommandHandler<PostInternalTransferCommand,
            PostInternalTransferResult> {
  const PostInternalTransferCommandHandler({
    required this.sessionContextProvider,
    required this.businessContextProvider,
    required this.attemptStore,
    required this.gateway,
    required this.projectionWriter,
  });

  final SessionContextProvider sessionContextProvider;
  final BusinessContextProvider businessContextProvider;
  final InternalTransferPostingAttemptStore attemptStore;
  final InternalTransferPostingGateway gateway;
  final ConfirmedInternalTransferProjectionWriter projectionWriter;

  @override
  Future<PostInternalTransferResult> execute(
    ApplicationCommandRequest<PostInternalTransferCommand> request,
  ) async {
    final command = request.command;
    if (request.idempotencyKey != command.commandId) {
      return _failure(command, PostInternalTransferFailureCategory.validation,
          'validation.invalidField');
    }
    final session = sessionContextProvider.current;
    if (session == null ||
        !session.isVerifiedRemote ||
        session.authUserId == null) {
      return _failure(
        command,
        PostInternalTransferFailureCategory.authentication,
        'unauthenticated.sessionRequired',
      );
    }
    final activeBusiness = businessContextProvider.current;
    final requestBusiness = request.businessContext;
    if (activeBusiness == null ||
        requestBusiness == null ||
        !activeBusiness.isVerifiedMembership ||
        !requestBusiness.isVerifiedMembership ||
        activeBusiness.role != 'owner' ||
        requestBusiness.role != 'owner' ||
        activeBusiness.businessId != command.businessId ||
        requestBusiness.businessId != command.businessId ||
        activeBusiness.authUserId != session.authUserId ||
        requestBusiness.authUserId != session.authUserId) {
      return _failure(
        command,
        PostInternalTransferFailureCategory.businessContext,
        'wrongBusinessContext',
      );
    }

    late InternalTransferPostingAttempt attempt;
    try {
      attempt = await attemptStore.prepare(
        commandId: command.commandId,
        businessId: command.businessId,
        canonicalPayloadJson: command.canonicalPayloadJson,
        localFingerprint: command.localFingerprint,
      );
    } on InternalTransferPostingAttemptConflictException {
      return _failure(command, PostInternalTransferFailureCategory.idempotency,
          'idempotencyConflict');
    }

    final storedResult = attempt.canonicalServerResultJson;
    if (storedResult != null &&
        (attempt.state ==
                InternalTransferPostingAttemptState
                    .confirmedProjectionPending ||
            attempt.state == InternalTransferPostingAttemptState.confirmed)) {
      try {
        final success = PostInternalTransferSuccess.fromJson(
          (jsonDecode(storedResult) as Map<String, dynamic>)
              .cast<String, Object?>(),
        );
        if (attempt.state == InternalTransferPostingAttemptState.confirmed) {
          return success;
        }
        return _project(command, session.authUserId!, success);
      } on Object {
        await attemptStore.markFailure(
          command.commandId,
          state: InternalTransferPostingAttemptState.unknownOutcome,
          errorCode: 'unexpectedServerError',
        );
        return _failure(command, PostInternalTransferFailureCategory.unexpected,
            'unexpectedServerError',
            retryable: true);
      }
    }

    await attemptStore.markSending(command.commandId);
    final response = await gateway.post(command.toGatewayPayload());
    if (response is InternalTransferPostingGatewayFailure) {
      final state = response.retryable
          ? InternalTransferPostingAttemptState.unknownOutcome
          : InternalTransferPostingAttemptState.rejected;
      await attemptStore.markFailure(
        command.commandId,
        state: state,
        errorCode: response.code,
      );
      return PostInternalTransferFailure(
        commandId: command.commandId,
        category: response.category,
        code: response.code,
        retryable: response.retryable,
        fieldErrors: response.fieldErrors,
        diagnosticReference: response.diagnosticReference,
      );
    }
    final accepted = response as InternalTransferPostingGatewaySuccess;
    if (!_validEnvelope(command, accepted)) {
      await attemptStore.markFailure(
        command.commandId,
        state: InternalTransferPostingAttemptState.unknownOutcome,
        errorCode: 'unexpectedServerError',
      );
      return _failure(command, PostInternalTransferFailureCategory.unexpected,
          'unexpectedServerError',
          retryable: true);
    }
    final success = PostInternalTransferSuccess(
      commandId: accepted.commandId,
      businessId: accepted.businessId,
      transferId: accepted.transferId,
      displayNumber: accepted.displayNumber,
      transferReference: accepted.transferReference,
      sourceFinancialAccountId: accepted.sourceFinancialAccountId,
      destinationFinancialAccountId: accepted.destinationFinancialAccountId,
      sourceFinancialEntryId: accepted.sourceFinancialEntryId,
      destinationFinancialEntryId: accepted.destinationFinancialEntryId,
      auditEventIds: List<String>.unmodifiable(accepted.auditEventIds),
      effectiveBusinessDate: accepted.effectiveBusinessDate,
      amountQirsh: accepted.amountQirsh,
      sourceBalanceAfterQirsh: accepted.sourceBalanceAfterQirsh,
      destinationBalanceAfterQirsh: accepted.destinationBalanceAfterQirsh,
      serverAcceptedAtUtc: accepted.serverAcceptedAtUtc.toUtc(),
      replayed: accepted.replayed,
    );
    await attemptStore.markServerConfirmed(
      command.commandId,
      jsonEncode(success.toJson()),
    );
    return _project(command, session.authUserId!, success);
  }

  bool _validEnvelope(
    PostInternalTransferCommand command,
    InternalTransferPostingGatewaySuccess accepted,
  ) {
    final ids = <String>[
      accepted.transferId,
      accepted.sourceFinancialEntryId,
      accepted.destinationFinancialEntryId,
      ...accepted.auditEventIds,
    ];
    return accepted.commandId == command.commandId &&
        accepted.businessId == command.businessId &&
        accepted.sourceFinancialAccountId == command.sourceFinancialAccountId &&
        accepted.destinationFinancialAccountId ==
            command.destinationFinancialAccountId &&
        accepted.transferReference == command.transferReference &&
        accepted.effectiveBusinessDate == command.effectiveBusinessDate &&
        accepted.amountQirsh == command.amountQirsh &&
        RegExp(r'^TR-\d{6,}$').hasMatch(accepted.displayNumber) &&
        accepted.sourceFinancialEntryId !=
            accepted.destinationFinancialEntryId &&
        accepted.auditEventIds.length == 3 &&
        accepted.auditEventIds.toSet().length == 3 &&
        ids.every((id) => Uuid.isValidUUID(fromString: id));
  }

  Future<PostInternalTransferSuccess> _project(
    PostInternalTransferCommand command,
    String actorAuthUserId,
    PostInternalTransferSuccess success,
  ) async {
    try {
      await projectionWriter.project(
        ConfirmedInternalTransferProjection(
          commandId: command.commandId,
          localFingerprint: command.localFingerprint,
          businessId: command.businessId,
          sourceServerAccountId: command.sourceFinancialAccountId,
          destinationServerAccountId: command.destinationFinancialAccountId,
          transferId: success.transferId,
          displayNumber: success.displayNumber,
          transferReference: success.transferReference,
          sourceEntryId: success.sourceFinancialEntryId,
          destinationEntryId: success.destinationFinancialEntryId,
          auditEventIds: success.auditEventIds,
          serverAcceptedAtUtc: success.serverAcceptedAtUtc,
          effectiveBusinessDate: success.effectiveBusinessDate,
          amountQirsh: success.amountQirsh,
          note: command.note,
          actorAuthUserId: actorAuthUserId,
          sourceBalanceAfterQirsh: success.sourceBalanceAfterQirsh,
          destinationBalanceAfterQirsh: success.destinationBalanceAfterQirsh,
        ),
      );
      await attemptStore.markConfirmed(command.commandId);
      return success.copyWithProjectionPending(false);
    } on Object {
      await attemptStore.markFailure(
        command.commandId,
        state: InternalTransferPostingAttemptState.confirmedProjectionPending,
        errorCode: 'projectionFailure',
      );
      return success.copyWithProjectionPending(true);
    }
  }

  PostInternalTransferFailure _failure(
    PostInternalTransferCommand command,
    PostInternalTransferFailureCategory category,
    String code, {
    bool retryable = false,
  }) =>
      PostInternalTransferFailure(
        commandId: command.commandId,
        category: category,
        code: code,
        retryable: retryable,
      );
}
