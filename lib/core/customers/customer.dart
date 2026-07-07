class Customer {
  const Customer({
    required this.id,
    required this.name,
    required this.isActive,
    required this.createdAt,
    required this.updatedAt,
    this.phone,
    this.notes,
  });

  final String id;
  final String name;
  final String? phone;
  final String? notes;
  final bool isActive;
  final DateTime createdAt;
  final DateTime updatedAt;

  bool get hasValidId => id.trim().isNotEmpty;

  Customer copyWith({
    String? name,
    String? phone,
    String? notes,
    bool? isActive,
    DateTime? updatedAt,
  }) {
    return Customer(
      id: id,
      name: name ?? this.name,
      phone: phone ?? this.phone,
      notes: notes ?? this.notes,
      isActive: isActive ?? this.isActive,
      createdAt: createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}

class CustomerDraft {
  const CustomerDraft({
    required this.name,
    this.phone,
    this.notes,
    this.isActive = true,
  });

  final String name;
  final String? phone;
  final String? notes;
  final bool isActive;
}
