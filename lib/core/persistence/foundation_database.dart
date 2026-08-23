import 'package:drift/drift.dart';

import 'migration_strategy.dart';

part 'foundation_database.g.dart';

/// Technical-only table used to prove the Phase 8A database lifecycle.
class FoundationProbes extends Table {
  TextColumn get key => text()();
  TextColumn get value => text()();

  @override
  Set<Column<Object>> get primaryKey => {key};
}

class Products extends Table {
  TextColumn get id => text()();
  TextColumn get name => text()();
  TextColumn get normalizedName => text().unique()();
  TextColumn get code => text().nullable()();
  TextColumn get normalizedCode => text().nullable().unique()();
  TextColumn get unit => text()();
  BoolColumn get isActive => boolean()();
  IntColumn get defaultSalePricePiastersPerKg => integer().nullable()();
  IntColumn get minimumSalePricePiastersPerKg => integer().nullable()();
  IntColumn get referenceCostPricePiastersPerKg => integer().nullable()();
  TextColumn get notes => text().nullable()();
  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get updatedAt => dateTime()();

  @override
  Set<Column<Object>> get primaryKey => {id};
}

class RepositorySequences extends Table {
  TextColumn get repository => text()();
  IntColumn get nextValue => integer()();

  @override
  Set<Column<Object>> get primaryKey => {repository};
}

class Customers extends Table {
  TextColumn get id => text()();
  TextColumn get name => text()();
  TextColumn get normalizedName => text().unique()();
  TextColumn get phone => text().nullable()();
  TextColumn get normalizedPhone => text().nullable().unique()();
  TextColumn get notes => text().nullable()();
  BoolColumn get isActive => boolean()();
  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get updatedAt => dateTime()();

  @override
  Set<Column<Object>> get primaryKey => {id};
}

class Suppliers extends Table {
  TextColumn get id => text()();
  TextColumn get name => text()();
  TextColumn get normalizedName => text().unique()();
  TextColumn get phone => text().nullable()();
  TextColumn get normalizedPhone => text().nullable().unique()();
  TextColumn get address => text().nullable()();
  TextColumn get notes => text().nullable()();
  BoolColumn get isActive => boolean()();
  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get updatedAt => dateTime()();

  @override
  Set<Column<Object>> get primaryKey => {id};
}

@TableIndex(name: 'inventory_movements_product_idx', columns: {#productId})
@TableIndex(
  name: 'inventory_movements_created_idx',
  columns: {#createdAt, #id},
)
@TableIndex(
  name: 'inventory_movements_document_idx',
  columns: {#originalDocumentId},
)
class InventoryMovements extends Table {
  TextColumn get id => text()();
  TextColumn get productId => text()();
  TextColumn get movementType => text()();
  IntColumn get quantityKg => integer()();
  TextColumn get createdByUserId => text()();
  DateTimeColumn get createdAt => dateTime()();
  TextColumn get note => text().nullable()();
  BoolColumn get isVoided => boolean().withDefault(const Constant(false))();
  TextColumn get reversedMovementId => text().nullable()();
  TextColumn get originalDocumentId => text().nullable()();

  @override
  Set<Column<Object>> get primaryKey => {id};
}

@DataClassName('ProfitabilityActivationRow')
class ProfitabilityActivations extends Table {
  TextColumn get id => text()();
  TextColumn get status => text()();
  DateTimeColumn get activationDate => dateTime().nullable()();
  DateTimeColumn get approvedAt => dateTime().nullable()();
  TextColumn get approvedByUserId => text().nullable()();
  TextColumn get evidenceNote => text().nullable()();

  @override
  Set<Column<Object>> get primaryKey => {id};
}

@DataClassName('InventoryValuationStateRow')
class InventoryValuationStates extends Table {
  TextColumn get productId => text()();
  IntColumn get quantityKg => integer()();
  IntColumn get totalValueQirsh => integer()();
  DateTimeColumn get updatedAt => dateTime()();
  TextColumn get lastEventId => text()();

  @override
  Set<Column<Object>> get primaryKey => {productId};
}

@DataClassName('InventoryValuationEventRow')
@TableIndex(
  name: 'inventory_valuation_events_product_created_idx',
  columns: {#productId, #createdAt, #id},
)
@TableIndex(
  name: 'inventory_valuation_events_source_idx',
  columns: {#sourceDocumentId},
)
class InventoryValuationEvents extends Table {
  TextColumn get id => text()();
  TextColumn get productId => text()();
  TextColumn get eventType => text()();
  IntColumn get quantityBeforeKg => integer()();
  IntColumn get quantityDeltaKg => integer()();
  IntColumn get quantityAfterKg => integer()();
  IntColumn get valueBeforeQirsh => integer()();
  IntColumn get valueDeltaQirsh => integer()();
  IntColumn get valueAfterQirsh => integer()();
  IntColumn get unitCostMicrosQirshPerKg => integer()();
  IntColumn get allocationResidualNumerator => integer()();
  IntColumn get allocationResidualDenominator => integer()();
  TextColumn get sourceDocumentId => text()();
  DateTimeColumn get effectiveDate => dateTime()();
  DateTimeColumn get createdAt => dateTime()();
  TextColumn get createdByUserId => text()();
  TextColumn get reversalOfEventId => text().nullable()();
  TextColumn get reason => text().nullable()();
  TextColumn get evidenceReference => text().nullable()();

  @override
  Set<Column<Object>> get primaryKey => {id};
}

@TableIndex(name: 'purchases_supplier_idx', columns: {#supplierId})
@TableIndex(name: 'purchases_created_idx', columns: {#createdAt, #id})
@TableIndex(name: 'purchases_product_idx', columns: {#productId})
@TableIndex(name: 'purchases_request_idx', columns: {#operationRequestId})
class Purchases extends Table {
  TextColumn get id => text()();
  TextColumn get supplierId => text()();
  TextColumn get supplierName => text().nullable()();
  TextColumn get supplierPhone => text().nullable()();
  TextColumn get supplierAddress => text().nullable()();
  TextColumn get productId => text()();
  IntColumn get quantityKg => integer()();
  TextColumn get entryUnit => text()();
  IntColumn get unitPricePiastersPerKg => integer()();
  IntColumn get totalAmountPiasters => integer()();
  TextColumn get createdByUserId => text()();
  DateTimeColumn get createdAt => dateTime()();
  TextColumn get stockMovementId => text()();
  TextColumn get notes => text().nullable()();
  TextColumn get financialAccountId => text().nullable()();
  TextColumn get paymentMethod => text().nullable()();
  TextColumn get paymentMode => text()();
  IntColumn get paidAmountQirsh => integer().nullable()();
  TextColumn get negativeBalanceApprovalId => text().nullable()();
  TextColumn get operationRequestId => text().nullable().unique()();
  TextColumn get requestFingerprint => text().nullable()();
  DateTimeColumn get cancelledAt => dateTime().nullable()();
  TextColumn get cancelledByUserId => text().nullable()();
  TextColumn get cancellationReason => text().nullable()();
  TextColumn get reversalMovementIds => text().nullable()();

  @override
  Set<Column<Object>> get primaryKey => {id};
}

@TableIndex(name: 'sales_customer_idx', columns: {#customerId})
@TableIndex(name: 'sales_created_idx', columns: {#createdAt, #id})
@TableIndex(name: 'sales_request_idx', columns: {#operationRequestId})
@TableIndex(name: 'sales_cancelled_idx', columns: {#cancelledAt})
class Sales extends Table {
  TextColumn get id => text()();
  TextColumn get productId => text()();
  IntColumn get quantityKg => integer()();
  IntColumn get salePriceQirshPerKg => integer()();
  IntColumn get totalQirsh => integer()();
  TextColumn get createdByUserId => text()();
  TextColumn get createdByUserName => text().nullable()();
  DateTimeColumn get createdAt => dateTime()();
  TextColumn get stockMovementId => text()();
  TextColumn get paymentMode => text()();
  TextColumn get customerId => text().nullable()();
  TextColumn get notes => text().nullable()();
  TextColumn get itemsJson => text()();
  IntColumn get paidAmountQirsh => integer().nullable()();
  TextColumn get financialAccountId => text().nullable()();
  TextColumn get paymentMethod => text().nullable()();
  TextColumn get paymentAllocationsJson => text()();
  TextColumn get operationRequestId => text().nullable().unique()();
  DateTimeColumn get cancelledAt => dateTime().nullable()();
  TextColumn get cancelledByUserId => text().nullable()();
  TextColumn get cancellationReason => text().nullable()();
  TextColumn get reversalMovementIdsJson => text().nullable()();

  @override
  Set<Column<Object>> get primaryKey => {id};
}

@DataClassName('FinancialAccountRow')
class FinancialAccounts extends Table {
  TextColumn get id => text()();
  TextColumn get name => text()();
  TextColumn get type => text()();
  BoolColumn get isActive => boolean()();
  BoolColumn get allowNegativeBalance => boolean()();
  IntColumn get openingBalanceQirsh => integer()();
  DateTimeColumn get openingBalanceDate => dateTime().nullable()();
  TextColumn get referenceInfo => text().nullable()();
  TextColumn get notes => text().nullable()();
  TextColumn get createdByUserId => text()();
  DateTimeColumn get createdAt => dateTime()();
  @override
  Set<Column<Object>> get primaryKey => {id};
}

@TableIndex(
    name: 'financial_entries_account_date_idx',
    columns: {#accountId, #effectiveDate, #id})
@DataClassName('FinancialAccountEntryRow')
class FinancialAccountEntries extends Table {
  TextColumn get id => text()();
  TextColumn get accountId => text().references(FinancialAccounts, #id)();
  TextColumn get direction => text()();
  IntColumn get amountQirsh => integer()();
  TextColumn get sourceType => text()();
  TextColumn get sourceDocumentId => text()();
  TextColumn get sourceDocumentNumber => text().nullable()();
  DateTimeColumn get effectiveDate => dateTime()();
  DateTimeColumn get createdAt => dateTime()();
  TextColumn get createdByUserId => text()();
  TextColumn get reference => text().nullable()();
  TextColumn get note => text().nullable()();
  TextColumn get reversalOf => text().nullable()();
  TextColumn get correctionGroup => text().nullable()();
  TextColumn get paymentMethod => text().nullable()();
  TextColumn get approvedByUserId => text().nullable()();
  TextColumn get negativeBalanceApprovalId => text().nullable()();
  @override
  Set<Column<Object>> get primaryKey => {id};
}

@TableIndex(
    name: 'financial_transfers_request_idx', columns: {#clientRequestId})
@DataClassName('FinancialTransferRow')
class FinancialTransfers extends Table {
  TextColumn get id => text()();
  TextColumn get displayNumber => text()();
  TextColumn get clientRequestId => text().unique()();
  TextColumn get transferReference => text().unique()();
  TextColumn get sourceAccountId => text().references(FinancialAccounts, #id)();
  TextColumn get destinationAccountId =>
      text().references(FinancialAccounts, #id)();
  IntColumn get amountQirsh => integer()();
  DateTimeColumn get effectiveDate => dateTime()();
  DateTimeColumn get createdAt => dateTime()();
  TextColumn get createdByUserId => text()();
  TextColumn get sourceEntryId => text()();
  TextColumn get destinationEntryId => text()();
  TextColumn get note => text().nullable()();
  TextColumn get negativeBalanceApprovalId => text().nullable()();
  TextColumn get originalTransferId => text().nullable()();
  TextColumn get reversalTransferId => text().nullable()();
  TextColumn get reversalReason => text().nullable()();
  @override
  Set<Column<Object>> get primaryKey => {id};
}

@DataClassName('FinancialClosingRow')
class FinancialClosings extends Table {
  TextColumn get id => text()();
  TextColumn get kind => text()();
  DateTimeColumn get fromDate => dateTime()();
  DateTimeColumn get toDate => dateTime()();
  TextColumn get linesJson => text()();
  DateTimeColumn get createdAt => dateTime()();
  TextColumn get createdByUserId => text()();
  TextColumn get note => text().nullable()();
  DateTimeColumn get reopenedAt => dateTime().nullable()();
  TextColumn get reopenedByUserId => text().nullable()();
  TextColumn get reopenReason => text().nullable()();
  @override
  Set<Column<Object>> get primaryKey => {id};
}

@DataClassName('AuditLogRow')
@TableIndex(name: 'audit_logs_timestamp_idx', columns: {#timestamp, #id})
@TableIndex(name: 'audit_logs_action_idx', columns: {#actionType})
@TableIndex(name: 'audit_logs_reference_idx', columns: {#referenceId})
class AuditLogs extends Table {
  TextColumn get id => text()();
  DateTimeColumn get timestamp => dateTime()();
  TextColumn get actionType => text()();
  TextColumn get descriptionAr => text()();
  TextColumn get actorId => text().nullable()();
  TextColumn get referenceId => text().nullable()();
  TextColumn get metadataJson => text()();

  @override
  Set<Column<Object>> get primaryKey => {id};
}

@DataClassName('ExpenseRow')
@TableIndex(
  name: 'expenses_date_created_at_idx',
  columns: {#date, #createdAt, #id},
)
@TableIndex(
  name: 'expenses_operation_request_uq',
  columns: {#operationRequestId},
  unique: true,
)
class Expenses extends Table {
  TextColumn get id => text()();
  DateTimeColumn get date => dateTime()();
  TextColumn get category => text()();
  IntColumn get amountQirsh => integer()();
  TextColumn get notes => text().nullable()();
  IntColumn get createdAt => integer()();
  TextColumn get financialAccountId => text().nullable()();
  TextColumn get paymentMethod => text().nullable()();
  TextColumn get createdByUserId => text().nullable()();
  TextColumn get operationRequestId => text().nullable()();
  TextColumn get operationRequestFingerprint => text().nullable()();
  TextColumn get accountingClassification => text().nullable()();

  @override
  Set<Column<Object>> get primaryKey => {id};
}

@DataClassName('FinancialAccountCloudLinkRow')
@TableIndex(
  name: 'financial_account_cloud_links_business_server_uq',
  columns: {#businessId, #serverAccountUuid},
  unique: true,
)
class FinancialAccountCloudLinks extends Table {
  TextColumn get localAccountId => text()();
  TextColumn get businessId => text()();
  TextColumn get serverAccountUuid => text()();
  IntColumn get reconciledServerBalanceQirsh => integer()();
  DateTimeColumn get reconciledAtUtc => dateTime()();
  IntColumn get reconciliationVersion => integer()();
  DateTimeColumn get readyAtUtc => dateTime()();

  @override
  Set<Column<Object>> get primaryKey => {localAccountId};
}

@DataClassName('ExpensePostingAttemptRow')
@TableIndex(
  name: 'expense_posting_attempts_business_state_idx',
  columns: {#businessId, #lifecycleState, #updatedAtUtc},
)
class ExpensePostingAttempts extends Table {
  TextColumn get commandId => text()();
  TextColumn get businessId => text()();
  TextColumn get canonicalPayloadJson => text()();
  TextColumn get localFingerprint => text()();
  TextColumn get lifecycleState => text()();
  TextColumn get canonicalServerResultJson => text().nullable()();
  DateTimeColumn get createdAtUtc => dateTime()();
  DateTimeColumn get updatedAtUtc => dateTime()();
  IntColumn get attemptCount => integer().withDefault(const Constant(0))();
  TextColumn get lastErrorCode => text().nullable()();

  @override
  Set<Column<Object>> get primaryKey => {commandId};
}

abstract class CustomerAccountPayloadTable extends Table {
  TextColumn get id => text()();
  TextColumn get customerId => text()();
  DateTimeColumn get occurredAt => dateTime()();
  TextColumn get payloadJson => text()();

  @override
  Set<Column<Object>> get primaryKey => {id};
}

@TableIndex(
  name: 'customer_account_entries_customer_timestamp_idx',
  columns: {#customerId, #occurredAt, #id},
)
@DataClassName('CustomerAccountEntryRow')
class CustomerAccountEntries extends CustomerAccountPayloadTable {}

@TableIndex(
  name: 'customer_collections_customer_timestamp_idx',
  columns: {#customerId, #occurredAt, #id},
)
@DataClassName('CustomerCollectionRow')
class CustomerCollections extends CustomerAccountPayloadTable {}

@TableIndex(
  name: 'customer_advances_customer_timestamp_idx',
  columns: {#customerId, #occurredAt, #id},
)
@DataClassName('CustomerAdvanceRow')
class CustomerAdvances extends CustomerAccountPayloadTable {}

@TableIndex(
  name: 'customer_advance_applications_advance_idx',
  columns: {#advanceId},
)
@DataClassName('CustomerAdvanceApplicationRow')
class CustomerAdvanceApplications extends CustomerAccountPayloadTable {
  TextColumn get advanceId => text()();
}

@TableIndex(
  name: 'customer_advance_refunds_advance_idx',
  columns: {#advanceId},
)
@DataClassName('CustomerAdvanceRefundRow')
class CustomerAdvanceRefunds extends CustomerAccountPayloadTable {
  TextColumn get advanceId => text()();
}

abstract class SupplierAccountPayloadTable extends Table {
  TextColumn get id => text()();
  TextColumn get supplierId => text()();
  DateTimeColumn get occurredAt => dateTime()();
  TextColumn get payloadJson => text()();

  @override
  Set<Column<Object>> get primaryKey => {id};
}

@TableIndex(
  name: 'supplier_account_entries_supplier_timestamp_idx',
  columns: {#supplierId, #occurredAt, #id},
)
@DataClassName('SupplierAccountEntryRow')
class SupplierAccountEntries extends SupplierAccountPayloadTable {}

@TableIndex(
  name: 'supplier_payments_supplier_timestamp_idx',
  columns: {#supplierId, #occurredAt, #id},
)
@DataClassName('SupplierPaymentRow')
class SupplierPayments extends SupplierAccountPayloadTable {}

@TableIndex(
  name: 'supplier_advances_supplier_timestamp_idx',
  columns: {#supplierId, #occurredAt, #id},
)
@DataClassName('SupplierAdvanceRow')
class SupplierAdvances extends SupplierAccountPayloadTable {}

@TableIndex(
  name: 'supplier_advance_applications_advance_idx',
  columns: {#advanceId},
)
@DataClassName('SupplierAdvanceApplicationRow')
class SupplierAdvanceApplications extends SupplierAccountPayloadTable {
  TextColumn get advanceId => text()();
}

@TableIndex(
  name: 'supplier_advance_refunds_advance_idx',
  columns: {#advanceId},
)
@DataClassName('SupplierAdvanceRefundRow')
class SupplierAdvanceRefunds extends SupplierAccountPayloadTable {
  TextColumn get advanceId => text()();
}

@TableIndex(name: 'auth_accounts_role_active_idx', columns: {#role, #isActive})
@TableIndex(name: 'auth_accounts_created_idx', columns: {#createdAt, #id})
@DataClassName('AuthAccountRow')
class AuthAccounts extends Table {
  TextColumn get id => text()();
  TextColumn get phoneNormalized => text().unique()();
  TextColumn get name => text()();
  TextColumn get role => text()();
  BoolColumn get isActive => boolean()();
  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get updatedAt => dateTime()();
  TextColumn get credentialScheme => text()();
  BlobColumn get credentialSalt => blob()();
  BlobColumn get credentialVerifier => blob()();
  TextColumn get credentialParametersJson => text()();
  DateTimeColumn get credentialUpdatedAt => dateTime()();

  @override
  Set<Column<Object>> get primaryKey => {id};
}

@TableIndex(
  name: 'negative_balance_approval_requests_status_requested_idx',
  columns: {#status, #requestedAt},
)
@TableIndex(
  name: 'negative_balance_approval_requests_account_idx',
  columns: {#financialAccountId, #requestedAt},
)
@DataClassName('NegativeBalanceApprovalRequest')
class NegativeBalanceApprovalRequests extends Table {
  TextColumn get id => text()();
  TextColumn get idempotencyKey => text().unique()();
  TextColumn get operationType => text()();
  TextColumn get status => text()();
  TextColumn get financialAccountId => text()();
  TextColumn get paymentMethod => text()();
  IntColumn get amountQirsh => integer()();
  TextColumn get sourceDocumentId => text()();
  TextColumn get payloadJson => text()();
  TextColumn get payloadFingerprint => text()();
  TextColumn get relatedPartyId => text().nullable()();
  TextColumn get requesterActorId => text()();
  DateTimeColumn get requestedAt => dateTime()();
  IntColumn get balanceAtRequestQirsh => integer()();
  IntColumn get expectedBalanceAtRequestQirsh => integer()();
  IntColumn get deficitAtRequestQirsh => integer()();
  TextColumn get reason => text()();
  TextColumn get resolverActorId => text().nullable()();
  DateTimeColumn get resolvedAt => dateTime().nullable()();
  TextColumn get resolutionReason => text().nullable()();
  TextColumn get ownerVerificationReference => text().nullable()();
  TextColumn get resultDocumentId => text().nullable()();
  IntColumn get recordVersion => integer().withDefault(const Constant(1))();

  @override
  Set<Column<Object>> get primaryKey => {id};
}

@TableIndex(
  name: 'negative_balance_request_transitions_request_time_idx',
  columns: {#requestId, #occurredAt},
)
@DataClassName('NegativeBalanceApprovalRequestTransition')
class NegativeBalanceApprovalRequestTransitions extends Table {
  TextColumn get id => text()();
  TextColumn get requestId => text().references(
        NegativeBalanceApprovalRequests,
        #id,
        onDelete: KeyAction.cascade,
      )();
  TextColumn get fromStatus => text().nullable()();
  TextColumn get toStatus => text()();
  TextColumn get actorId => text()();
  DateTimeColumn get occurredAt => dateTime()();
  TextColumn get reason => text()();

  @override
  Set<Column<Object>> get primaryKey => {id};
}

@DriftDatabase(tables: [
  FoundationProbes,
  Products,
  RepositorySequences,
  Customers,
  Suppliers,
  InventoryMovements,
  ProfitabilityActivations,
  InventoryValuationStates,
  InventoryValuationEvents,
  Purchases,
  Sales,
  FinancialAccounts,
  FinancialAccountEntries,
  FinancialTransfers,
  FinancialClosings,
  AuditLogs,
  Expenses,
  FinancialAccountCloudLinks,
  ExpensePostingAttempts,
  CustomerAccountEntries,
  CustomerCollections,
  CustomerAdvances,
  CustomerAdvanceApplications,
  CustomerAdvanceRefunds,
  SupplierAccountEntries,
  SupplierPayments,
  SupplierAdvances,
  SupplierAdvanceApplications,
  SupplierAdvanceRefunds,
  AuthAccounts,
  NegativeBalanceApprovalRequests,
  NegativeBalanceApprovalRequestTransitions,
])
class FoundationDatabase extends _$FoundationDatabase {
  FoundationDatabase(super.executor);

  @override
  int get schemaVersion => 16;

  @override
  MigrationStrategy get migration => foundationMigrationStrategy(this);

  Future<T> inTransaction<T>(Future<T> Function() action) =>
      transaction(action);

  Future<void> writeProbe(String key, String value) =>
      into(foundationProbes).insertOnConflictUpdate(
        FoundationProbesCompanion.insert(key: key, value: value),
      );

  Future<String?> readProbe(String key) async {
    final row = await (select(foundationProbes)
          ..where((table) => table.key.equals(key)))
        .getSingleOrNull();
    return row?.value;
  }

  Future<int> probeCount() async {
    final count = foundationProbes.key.count();
    final row =
        await (selectOnly(foundationProbes)..addColumns([count])).getSingle();
    return row.read(count) ?? 0;
  }
}
