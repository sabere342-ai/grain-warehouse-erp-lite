import 'package:flutter_test/flutter_test.dart';
import 'package:grain_warehouse_erp_lite/core/financial_accounts/negative_balance_approval.dart';
import 'package:grain_warehouse_erp_lite/core/financial_accounts/negative_balance_approval_repository.dart';

void main() {
  group('Phase 6A supplier refund reversal approval contract', () {
    test('uses a dedicated operation and immutable full authorization context',
        () {
      expect(
        NegativeBalanceOperationType.supplierAdvanceRefundReversal.labelAr,
        'عكس استرداد سلفة المورد',
      );
      const context =
          NegativeBalanceApprovalContext.supplierAdvanceRefundReversal(
        supplierId: 'supplier-1',
        advanceId: 'advance-1',
        refundId: 'refund-1',
      );
      expect(context.supplierId, 'supplier-1');
      expect(context.advanceId, 'advance-1');
      expect(context.refundId, 'refund-1');
      expect(context.financialDirection,
          NegativeBalanceFinancialDirection.outflow);
      expect(
          context.matches(const NegativeBalanceApprovalContext
              .supplierAdvanceRefundReversal(
            supplierId: 'supplier-1',
            advanceId: 'advance-1',
            refundId: 'refund-1',
          )),
          isTrue);
      expect(
          context.matches(const NegativeBalanceApprovalContext
              .supplierAdvanceRefundReversal(
            supplierId: 'supplier-2',
            advanceId: 'advance-1',
            refundId: 'refund-1',
          )),
          isFalse);
    });

    test('rejects missing supplier, advance, or refund bindings', () {
      NegativeBalanceApprovalBinding binding(
              NegativeBalanceApprovalContext context) =>
          NegativeBalanceApprovalBinding(
            approvalId: 'approval-1',
            transactionId: 'transaction-1',
            accountId: 'account-1',
            amountQirsh: 100,
            operationType:
                NegativeBalanceOperationType.supplierAdvanceRefundReversal,
            sourceDocumentId: 'request-1',
            sourceDocumentType: 'supplierAdvanceRefundReversal',
            requestedByUserId: 'owner-1',
            balanceBeforeQirsh: 0,
            expectedBalanceAfterQirsh: -100,
            authorizationContext: context,
          );

      expect(
        () => binding(
            const NegativeBalanceApprovalContext.supplierAdvanceRefundReversal(
          supplierId: '',
          advanceId: 'advance-1',
          refundId: 'refund-1',
        )).validate(),
        throwsArgumentError,
      );
      expect(
        () => binding(
            const NegativeBalanceApprovalContext.supplierAdvanceRefundReversal(
          supplierId: 'supplier-1',
          advanceId: '',
          refundId: 'refund-1',
        )).validate(),
        throwsArgumentError,
      );
      expect(
        () => binding(
            const NegativeBalanceApprovalContext.supplierAdvanceRefundReversal(
          supplierId: 'supplier-1',
          advanceId: 'advance-1',
          refundId: '',
        )).validate(),
        throwsArgumentError,
      );
    });

    test('supplier overpayment and customer refund contracts remain distinct',
        () {
      expect(NegativeBalanceOperationType.supplierOverpayment,
          isNot(NegativeBalanceOperationType.supplierAdvanceRefundReversal));
      expect(NegativeBalanceOperationType.customerAdvanceRefund,
          isNot(NegativeBalanceOperationType.supplierAdvanceRefundReversal));
      expect(
        const NegativeBalanceApprovalContext.customerAdvanceRefund(
          customerId: 'customer-1',
          advanceId: 'advance-1',
        ).supplierId,
        isNull,
      );
    });
  });
}
