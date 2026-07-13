import 'package:grain_warehouse_erp_lite/core/documents/cancellation_metadata.dart';
import 'package:grain_warehouse_erp_lite/core/financial_accounts/financial_account_entry.dart';

enum SalePaymentMode {
  cash,
  credit,
  partial;

  String get labelAr {
    switch (this) {
      case SalePaymentMode.cash:
        return '\u0646\u0642\u062f\u064a';
      case SalePaymentMode.credit:
        return '\u0622\u062c\u0644 \u0639\u0644\u0649 \u0639\u0645\u064a\u0644';
      case SalePaymentMode.partial:
        return '\u062f\u0641\u0639 \u062c\u0632\u0626\u064a';
    }
  }
}

class SaleLineItem {
  const SaleLineItem({
    required this.productId,
    required this.quantityKg,
    required this.salePriceQirshPerKg,
    required this.lineTotalQirsh,
  });

  final String productId;
  final int quantityKg;
  final int salePriceQirshPerKg;
  final int lineTotalQirsh;
}

class SaleLineItemDraft {
  const SaleLineItemDraft({
    required this.productId,
    required this.quantityKg,
    required this.salePriceQirshPerKg,
  });

  final String productId;
  final int quantityKg;
  final int salePriceQirshPerKg;
}

/// An immutable portion of the amount paid for one sales invoice.
///
/// Amounts are stored in qirsh/minor units so allocation arithmetic is exact.
class SalePaymentAllocation {
  const SalePaymentAllocation({
    required this.financialAccountId,
    required this.amountQirsh,
    required this.paymentMethod,
  });

  final String financialAccountId;
  final int amountQirsh;
  final PaymentMethod paymentMethod;
}

class SaleRecord {
  const SaleRecord({
    required this.id,
    required this.productId,
    required this.quantityKg,
    required this.salePriceQirshPerKg,
    required this.totalQirsh,
    required this.createdByUserId,
    required this.createdAt,
    required this.stockMovementId,
    this.paymentMode = SalePaymentMode.cash,
    this.customerId,
    this.createdByUserName,
    this.notes,
    this.cancellation,
    this.items = const [],
    this.paidAmountQirsh,
    this.financialAccountId,
    this.paymentMethod,
    this.paymentAllocations = const [],
    this.operationRequestId,
  });

  final String id;
  final String productId;
  final int quantityKg;
  final int salePriceQirshPerKg;
  final int totalQirsh;
  final String createdByUserId;
  final String? createdByUserName;
  final DateTime createdAt;
  final String stockMovementId;
  final SalePaymentMode paymentMode;
  final String? customerId;
  final String? notes;
  final CancellationMetadata? cancellation;
  final List<SaleLineItem> items;
  final int? paidAmountQirsh;
  final String? financialAccountId;
  final PaymentMethod? paymentMethod;
  final List<SalePaymentAllocation> paymentAllocations;
  final String? operationRequestId;

  bool get hasValidId => id.trim().isNotEmpty;
  bool get isCancelled => cancellation != null;
  bool get isCreditSale => paymentMode == SalePaymentMode.credit;
  bool get isPartialPayment => paymentMode == SalePaymentMode.partial;
  bool get isMultiItem => items.length > 1;

  int get effectivePaidAmountQirsh {
    if (paidAmountQirsh != null) return paidAmountQirsh!;
    return isCreditSale ? 0 : totalQirsh;
  }

  int get remainingAmountQirsh => totalQirsh - effectivePaidAmountQirsh;

  SaleRecord copyWith({
    CancellationMetadata? cancellation,
    List<SaleLineItem>? items,
    int? paidAmountQirsh,
    List<SalePaymentAllocation>? paymentAllocations,
  }) {
    return SaleRecord(
      id: id,
      productId: productId,
      quantityKg: quantityKg,
      salePriceQirshPerKg: salePriceQirshPerKg,
      totalQirsh: totalQirsh,
      createdByUserId: createdByUserId,
      createdByUserName: createdByUserName,
      createdAt: createdAt,
      stockMovementId: stockMovementId,
      paymentMode: paymentMode,
      customerId: customerId,
      notes: notes,
      cancellation: cancellation ?? this.cancellation,
      items: items ?? this.items,
      paidAmountQirsh: paidAmountQirsh ?? this.paidAmountQirsh,
      financialAccountId: financialAccountId,
      paymentMethod: paymentMethod,
      paymentAllocations: paymentAllocations ?? this.paymentAllocations,
      operationRequestId: operationRequestId,
    );
  }
}

class SaleDraft {
  const SaleDraft({
    required this.productId,
    required this.quantityKg,
    required this.salePriceQirshPerKg,
    required this.createdByUserId,
    this.paymentMode = SalePaymentMode.cash,
    this.customerId,
    this.createdByUserName,
    this.notes,
    this.items = const [],
    this.paidAmountQirsh,
    this.financialAccountId,
    this.paymentMethod,
    this.paymentAllocations = const [],
    this.operationRequestId,
  });

  final String productId;
  final int quantityKg;
  final int salePriceQirshPerKg;
  final String createdByUserId;
  final SalePaymentMode paymentMode;
  final String? customerId;
  final String? createdByUserName;
  final String? notes;
  final List<SaleLineItemDraft> items;
  final int? paidAmountQirsh;
  final String? financialAccountId;
  final PaymentMethod? paymentMethod;
  final List<SalePaymentAllocation> paymentAllocations;
  final String? operationRequestId;

  bool get isMultiItem => items.length > 1;

  int get effectivePaidAmountQirsh {
    if (paidAmountQirsh != null) return paidAmountQirsh!;
    return paymentMode == SalePaymentMode.credit ? 0 : 0;
  }
}
