import 'package:flutter_test/flutter_test.dart';
import 'package:grain_warehouse_erp_lite/core/auth/app_user.dart';
import 'package:grain_warehouse_erp_lite/core/auth/user_role.dart';
import 'package:grain_warehouse_erp_lite/core/financial_accounts/financial_account.dart';
import 'package:grain_warehouse_erp_lite/core/financial_accounts/financial_account_repository.dart';
import 'package:grain_warehouse_erp_lite/core/financial_accounts/financial_closing.dart';
import 'package:grain_warehouse_erp_lite/core/financial_accounts/financial_report_models.dart';
import 'package:grain_warehouse_erp_lite/core/financial_accounts/financial_report_service.dart';

void main() {
  late _CountingFinancialAccountRepository repository;
  late FinancialReportService service;
  late FinancialAccount treasury;
  late FinancialAccount bank;

  setUp(() async {
    repository = _CountingFinancialAccountRepository();
    service = FinancialReportService(repository: repository);
    treasury = await repository.createAccount(const FinancialAccountDraft(
      name: 'Treasury',
      type: FinancialAccountType.treasury,
      createdByUserId: 'owner',
    ));
    bank = await repository.createAccount(const FinancialAccountDraft(
      name: 'Historical bank',
      type: FinancialAccountType.bank,
      createdByUserId: 'owner',
    ));
  });

  test('returns an immutable empty report after one read of each source',
      () async {
    final report = await service.closingReconciliationReport();

    expect(repository.listAccountsCalls, 1);
    expect(repository.listClosingsCalls, 1);
    expect(report.closings, isEmpty);
    expect(report.isEmpty, isTrue);
    expect(() => report.closings.add(_summary()), throwsUnsupportedError);
  });

  test('preserves canonical closing and account-row ordering and values',
      () async {
    final older = await _close(
      repository,
      from: DateTime(2026, 7, 1),
      to: DateTime(2026, 7, 1),
      treasuryId: treasury.id,
      bankId: bank.id,
      treasuryActual: 900,
      bankActual: 1100,
    );
    final newer = await _close(
      repository,
      from: DateTime(2026, 7, 2),
      to: DateTime(2026, 7, 2),
      treasuryId: treasury.id,
      bankId: bank.id,
      treasuryActual: 950,
      bankActual: 1050,
    );
    await repository.deactivateAccount(bank.id, 'owner');
    repository.resetReadCounts();

    final report = await service.closingReconciliationReport();
    final first = report.closings.first;
    final firstTreasury = first.accountRows.first;
    final firstBank = first.accountRows.last;

    expect(repository.listAccountsCalls, 1);
    expect(repository.listClosingsCalls, 1);
    expect(report.closings.map((closing) => closing.closingId), [
      newer.id,
      older.id,
    ]);
    expect(first.accountRows.map((row) => row.accountId), [
      treasury.id,
      bank.id,
    ]);
    expect(firstTreasury.accountName, 'Treasury');
    expect(firstTreasury.accountType, FinancialAccountType.treasury);
    expect(firstTreasury.isAccountActive, isTrue);
    expect(firstTreasury.expectedBalanceQirsh, 0);
    expect(firstTreasury.actualBalanceQirsh, 950);
    expect(firstTreasury.differenceQirsh, 950);
    expect(firstBank.accountName, 'Historical bank');
    expect(firstBank.accountType, FinancialAccountType.bank);
    expect(firstBank.isAccountActive, isFalse);
    expect(firstBank.expectedBalanceQirsh, 0);
    expect(firstBank.actualBalanceQirsh, 1050);
    expect(firstBank.differenceQirsh, 1050);
    expect(first.totalDifferenceQirsh, 2000);
    expect(first.isOpen, isFalse);
    expect(first.reopenedAt, isNull);
    expect(first.reopenedByUserId, isNull);
    expect(first.reopenReason, isNull);
    expect(
      () => first.accountRows.add(firstTreasury),
      throwsUnsupportedError,
    );
  });

  test('passes through reopened fields, zero variance, and variance signs',
      () async {
    final closing = await _close(
      repository,
      from: DateTime(2026, 7, 1),
      to: DateTime(2026, 7, 1),
      treasuryId: treasury.id,
      bankId: bank.id,
      treasuryActual: 0,
      bankActual: -5,
    );
    final reopened = await repository.reopenClosing(
      user: _owner,
      closingId: closing.id,
      reason: 'Documented correction',
    );

    final report = await service.closingReconciliationReport();
    final summary = report.closings.single;

    expect(summary.isOpen, reopened.isOpen);
    expect(summary.reopenedAt, reopened.reopenedAt);
    expect(summary.reopenedByUserId, reopened.reopenedByUserId);
    expect(summary.reopenReason, 'Documented correction');
    expect(summary.accountRows.first.differenceQirsh, 0);
    expect(summary.accountRows.last.differenceQirsh, -5);
    expect(summary.totalDifferenceQirsh, -5);
  });

  test('fails safely when a closing references an unavailable account',
      () async {
    final service = FinancialReportService(
      repository: _MissingAccountClosingRepository(),
    );

    await expectLater(
      service.closingReconciliationReport(),
      throwsA(isA<StateError>()),
    );
  });
}

Future<FinancialClosing> _close(
  LocalFinancialAccountRepository repository, {
  required DateTime from,
  required DateTime to,
  required String treasuryId,
  required String bankId,
  required int treasuryActual,
  required int bankActual,
}) =>
    repository.createClosing(
      user: _owner,
      draft: FinancialClosingDraft(
        kind: FinancialClosingKind.daily,
        fromDate: from,
        toDate: to,
        actualBalancesQirsh: {
          treasuryId: treasuryActual,
          bankId: bankActual,
        },
      ),
    );

FinancialClosingReconciliationSummary _summary() =>
    FinancialClosingReconciliationSummary(
      closingId: 'closing',
      kind: FinancialClosingKind.daily,
      fromDate: DateTime(2026),
      toDate: DateTime(2026),
      createdAt: DateTime(2026),
      createdByUserId: 'owner',
      isOpen: false,
      totalDifferenceQirsh: 0,
      accountRows: const [],
    );

final _owner = AppUser(
  id: 'owner',
  name: 'Owner',
  phone: '01000000000',
  role: UserRole.owner,
  isActive: true,
  createdAt: DateTime(2026),
  updatedAt: DateTime(2026),
);

final class _CountingFinancialAccountRepository
    extends LocalFinancialAccountRepository {
  int listAccountsCalls = 0;
  int listClosingsCalls = 0;

  @override
  Future<List<FinancialAccount>> listAccounts({bool includeInactive = false}) {
    listAccountsCalls++;
    return super.listAccounts(includeInactive: includeInactive);
  }

  @override
  Future<List<FinancialClosing>> listClosings() {
    listClosingsCalls++;
    return super.listClosings();
  }

  void resetReadCounts() {
    listAccountsCalls = 0;
    listClosingsCalls = 0;
  }
}

final class _MissingAccountClosingRepository
    extends LocalFinancialAccountRepository {
  @override
  Future<List<FinancialClosing>> listClosings() async => [
        FinancialClosing(
          id: 'missing-account-closing',
          kind: FinancialClosingKind.daily,
          fromDate: DateTime(2026, 7, 1),
          toDate: DateTime(2026, 7, 1),
          lines: const [
            FinancialClosingLine(
              accountId: 'missing-account',
              expectedBalanceQirsh: 1,
              actualBalanceQirsh: 1,
            ),
          ],
          createdAt: DateTime(2026, 7, 1),
          createdByUserId: 'owner',
        ),
      ];
}
