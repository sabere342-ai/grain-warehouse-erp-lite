import 'package:grain_warehouse_erp_lite/core/financial_accounts/financial_account_entry.dart';

class CustomerCollectionRecord {
  const CustomerCollectionRecord({
    required this.id,
    required this.customerId,
    required this.date,
    required this.amountQirsh,
    required this.createdAt,
    required this.createdByUserId,
    this.createdByUserName,
    this.notes,
    this.financialAccountId,
    this.paymentMethod,
  });

  final String id;
  final String customerId;
  final DateTime date;
  final int amountQirsh;
  final DateTime createdAt;
  final String createdByUserId;
  final String? createdByUserName;
  final String? notes;
  final String? financialAccountId;
  final PaymentMethod? paymentMethod;

  bool get hasValidId => id.trim().isNotEmpty;
}

class CustomerCollectionDraft {
  const CustomerCollectionDraft({
    required this.customerId,
    required this.date,
    required this.amountQirsh,
    required this.createdByUserId,
    this.createdByUserName,
    this.notes,
    this.financialAccountId,
    this.paymentMethod,
  });

  final String customerId;
  final DateTime date;
  final int amountQirsh;
  final String createdByUserId;
  final String? createdByUserName;
  final String? notes;
  final String? financialAccountId;
  final PaymentMethod? paymentMethod;
}
