import 'package:flutter_test/flutter_test.dart';
import 'package:grain_warehouse_erp_lite/core/auth/app_user.dart';
import 'package:grain_warehouse_erp_lite/core/auth/user_role.dart';
import 'package:grain_warehouse_erp_lite/core/financial_accounts/financial_account.dart';
import 'package:grain_warehouse_erp_lite/core/financial_accounts/financial_account_repository.dart';
import 'package:grain_warehouse_erp_lite/core/financial_accounts/financial_transfer.dart';

void main() {
  final owner = AppUser(
      id: 'owner',
      name: 'Owner',
      phone: '0',
      role: UserRole.owner,
      isActive: true,
      createdAt: DateTime(2026),
      updatedAt: DateTime(2026));
  final employee = AppUser(
      id: 'employee',
      name: 'Employee',
      phone: '1',
      role: UserRole.employee,
      isActive: true,
      createdAt: DateTime(2026),
      updatedAt: DateTime(2026));

  Future<(LocalFinancialAccountRepository, FinancialAccount, FinancialAccount)>
      setup() async {
    final repo = LocalFinancialAccountRepository();
    final source = await repo.createAccount(FinancialAccountDraft(
        name: 'خزينة',
        type: FinancialAccountType.treasury,
        createdByUserId: owner.id));
    final destination = await repo.createAccount(FinancialAccountDraft(
        name: 'بنك',
        type: FinancialAccountType.bank,
        createdByUserId: owner.id));
    await repo.setOpeningBalance(
        accountId: source.id,
        amountQirsh: 10000,
        effectiveDate: DateTime(2026, 1, 1),
        createdByUserId: owner.id);
    return (repo, source, destination);
  }

  FinancialTransferDraft draft(
          FinancialAccount source, FinancialAccount destination,
          {String id = 'request-1', int amount = 2500}) =>
      FinancialTransferDraft(
          clientRequestId: id,
          transferReference: 'TR-$id',
          sourceAccountId: source.id,
          destinationAccountId: destination.id,
          amountQirsh: amount,
          effectiveDate: DateTime(2026, 1, 2),
          createdByUserId: owner.id);

  test('creates equal opposite ledger entries and is idempotent', () async {
    final (repo, source, destination) = await setup();
    final first = await repo.createTransfer(
        user: owner, draft: draft(source, destination));
    final retry = await repo.createTransfer(
        user: owner, draft: draft(source, destination));
    expect(retry.id, first.id);
    expect(await repo.currentBalanceForAccount(source.id), 7500);
    expect(await repo.currentBalanceForAccount(destination.id), 2500);
  });

  test(
      'rejects employee, future date, inactive account and insufficient balance',
      () async {
    final (repo, source, destination) = await setup();
    expect(
        () => repo.createTransfer(
            user: employee, draft: draft(source, destination)),
        throwsStateError);
    expect(
      () => repo.createTransfer(
        user: owner,
        draft: FinancialTransferDraft(
            clientRequestId: 'future',
            transferReference: 'TR-future',
            sourceAccountId: source.id,
            destinationAccountId: destination.id,
            amountQirsh: 1,
            effectiveDate: DateTime.now().add(const Duration(days: 1)),
            createdByUserId: owner.id),
      ),
      throwsArgumentError,
    );
    expect(
        () => repo.createTransfer(
            user: owner,
            draft: draft(source, destination, id: 'large', amount: 10001)),
        throwsStateError);
  });

  test('reversal is paired and cannot be repeated', () async {
    final (repo, source, destination) = await setup();
    final transfer = await repo.createTransfer(
        user: owner, draft: draft(source, destination));
    final reversal = await repo.reverseTransfer(
        user: owner, transferId: transfer.id, reason: 'تصحيح');
    expect(reversal.originalTransferId, transfer.id);
    expect(await repo.currentBalanceForAccount(source.id), 10000);
    expect(
        () => repo.reverseTransfer(
            user: owner, transferId: transfer.id, reason: 'مرة أخرى'),
        throwsStateError);
  });
}
