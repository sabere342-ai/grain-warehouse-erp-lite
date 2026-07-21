import 'package:grain_warehouse_erp_lite/core/financial_accounts/financial_account.dart';
import 'package:grain_warehouse_erp_lite/core/financial_accounts/financial_account_entry.dart';

/// Authoritative compatibility rules for new money-moving operations.
///
/// Historic restored records may legitimately have no payment route. New
/// operations must never infer a route, and cheque posting remains blocked
/// until the product has an owner-approved cheque/intermediary account model.
class PaymentRoutingPolicy {
  PaymentRoutingPolicy._();

  static const selectablePaymentMethods = <PaymentMethod>[
    PaymentMethod.cash,
    PaymentMethod.bankTransfer,
    PaymentMethod.mobileWallet,
  ];

  static bool isCompatible({
    required PaymentMethod paymentMethod,
    required FinancialAccountType accountType,
  }) {
    return switch (paymentMethod) {
      PaymentMethod.cash => accountType == FinancialAccountType.treasury,
      PaymentMethod.bankTransfer => accountType == FinancialAccountType.bank,
      PaymentMethod.mobileWallet =>
        accountType == FinancialAccountType.electronicWallet,
      PaymentMethod.check => false,
    };
  }

  static void validateAccount({
    required FinancialAccount account,
    required PaymentMethod paymentMethod,
  }) {
    if (!account.isActive) {
      throw StateError('الحساب المالي المختار غير نشط.');
    }
    if (paymentMethod == PaymentMethod.check) {
      throw StateError(
        'لا يمكن تسجيل الشيك قبل اعتماد حساب شيكات أو حساب وسيط مخصص.',
      );
    }
    if (!isCompatible(
      paymentMethod: paymentMethod,
      accountType: account.type,
    )) {
      throw StateError('طريقة الدفع لا تتوافق مع نوع الحساب المالي المختار.');
    }
  }
}
