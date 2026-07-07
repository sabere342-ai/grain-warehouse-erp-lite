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
  });

  final String id;
  final String customerId;
  final DateTime date;
  final int amountQirsh;
  final DateTime createdAt;
  final String createdByUserId;
  final String? createdByUserName;
  final String? notes;

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
  });

  final String customerId;
  final DateTime date;
  final int amountQirsh;
  final String createdByUserId;
  final String? createdByUserName;
  final String? notes;
}
