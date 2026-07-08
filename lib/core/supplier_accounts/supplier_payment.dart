class SupplierPaymentRecord {
  const SupplierPaymentRecord({
    required this.id,
    required this.supplierId,
    required this.date,
    required this.amountQirsh,
    required this.createdAt,
    required this.createdByUserId,
    this.createdByUserName,
    this.notes,
  });

  final String id;
  final String supplierId;
  final DateTime date;
  final int amountQirsh;
  final DateTime createdAt;
  final String createdByUserId;
  final String? createdByUserName;
  final String? notes;

  bool get hasValidId => id.trim().isNotEmpty;
}

class SupplierPaymentDraft {
  const SupplierPaymentDraft({
    required this.supplierId,
    required this.date,
    required this.amountQirsh,
    required this.createdByUserId,
    this.createdByUserName,
    this.notes,
  });

  final String supplierId;
  final DateTime date;
  final int amountQirsh;
  final String createdByUserId;
  final String? createdByUserName;
  final String? notes;
}
