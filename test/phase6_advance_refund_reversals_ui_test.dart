import 'package:flutter_test/flutter_test.dart';
import 'package:grain_warehouse_erp_lite/core/customer_accounts/customer_advance.dart';
import 'package:grain_warehouse_erp_lite/core/customers/customer_controller.dart';
import 'package:grain_warehouse_erp_lite/core/supplier_accounts/supplier_advance.dart';
import 'package:grain_warehouse_erp_lite/core/suppliers/supplier_controller.dart';

void main() {
  final now = DateTime(2026, 7, 15);

  test('customer refund history preserves active and reversed records', () {
    final advance = CustomerAdvance(
      id: 'advance-c',
      customerId: 'customer-1',
      sourceCollectionId: 'col-1',
      financialAccountId: 'account-1',
      amountQirsh: 1000,
      createdAt: now,
      createdByUserId: 'owner-1',
      ownerApprovalId: 'approval-1',
      operationRequestId: 'advance-request-c',
    );
    final active = CustomerAdvanceRefund(
      id: 'refund-c1',
      advanceId: advance.id,
      customerId: advance.customerId,
      financialAccountId: advance.financialAccountId,
      amountQirsh: 200,
      refundedAt: now,
      createdByUserId: 'owner-1',
      operationRequestId: 'refund-request-c1',
      financialEntryId: 'entry-c1',
    );
    final reversed = CustomerAdvanceRefund(
      id: 'refund-c2',
      advanceId: advance.id,
      customerId: advance.customerId,
      financialAccountId: advance.financialAccountId,
      amountQirsh: 100,
      refundedAt: now,
      createdByUserId: 'owner-1',
      operationRequestId: 'refund-request-c2',
      financialEntryId: 'entry-c2',
      reversedAt: now,
      reversedByUserId: 'owner-1',
      reversalReason: 'تصحيح',
      reversalFinancialEntryId: 'entry-c2-r',
    );
    final summary = CustomerAdvanceSummary(
      advance: advance,
      appliedQirsh: 0,
      refundedQirsh: 200,
      remainingQirsh: 800,
      refunds: [active, reversed],
    );
    expect(summary.refunds, hasLength(2));
    expect(summary.refunds.first.isReversed, isFalse);
    expect(summary.refunds.last.isReversed, isTrue);
    expect(summary.refunds.last.reversalReason, 'تصحيح');
  });

  test('supplier refund history preserves original account and amount', () {
    final advance = SupplierAdvance(
      id: 'advance-s',
      supplierId: 'supplier-1',
      sourcePaymentId: 'pay-1',
      financialAccountId: 'account-1',
      amountQirsh: 1000,
      createdAt: now,
      createdByUserId: 'owner-1',
      ownerApprovalId: 'approval-1',
      operationRequestId: 'advance-request-s',
    );
    final refund = SupplierAdvanceRefund(
      id: 'refund-s1',
      advanceId: advance.id,
      supplierId: advance.supplierId,
      financialAccountId: advance.financialAccountId,
      amountQirsh: 250,
      refundedAt: now,
      createdByUserId: 'owner-1',
      operationRequestId: 'refund-request-s1',
      financialEntryId: 'entry-s1',
    );
    final summary = SupplierAdvanceSummary(
      advance: advance,
      appliedQirsh: 0,
      refundedQirsh: 250,
      remainingQirsh: 750,
      refunds: [refund],
    );
    expect(summary.refunds.single.financialAccountId, 'account-1');
    expect(summary.refunds.single.amountQirsh, 250);
    expect(summary.refunds.single.isReversed, isFalse);
  });

  test('approval-required result is distinct from failure and success', () {
    const required = SupplierAdvanceActionResult.approvalRequired();
    const success = SupplierAdvanceActionResult.success();
    const failure = SupplierAdvanceActionResult.failure('error');
    expect(required.requiresApproval, isTrue);
    expect(required.isSuccess, isFalse);
    expect(success.isSuccess, isTrue);
    expect(failure.requiresApproval, isFalse);
  });
}
