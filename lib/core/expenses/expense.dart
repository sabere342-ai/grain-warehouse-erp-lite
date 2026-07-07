class ExpenseRecord {
  const ExpenseRecord({
    required this.id,
    required this.date,
    required this.category,
    required this.amountQirsh,
    required this.createdAt,
    this.notes,
  });

  final String id;
  final DateTime date;
  final String category;
  final int amountQirsh;
  final String? notes;
  final DateTime createdAt;

  bool get hasValidId => id.trim().isNotEmpty;
}

class ExpenseDraft {
  const ExpenseDraft({
    required this.date,
    required this.category,
    required this.amountQirsh,
    this.notes,
  });

  final DateTime date;
  final String category;
  final int amountQirsh;
  final String? notes;
}
