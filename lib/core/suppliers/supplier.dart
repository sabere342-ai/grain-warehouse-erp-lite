class Supplier {
  const Supplier({
    required this.id,
    required this.name,
    required this.isActive,
    required this.createdAt,
    required this.updatedAt,
    this.phone,
    this.address,
    this.notes,
  });

  final String id;
  final String name;
  final String? phone;
  final String? address;
  final String? notes;
  final bool isActive;
  final DateTime createdAt;
  final DateTime updatedAt;

  bool get hasValidId => id.trim().isNotEmpty;

  Supplier copyWith({
    String? id,
    String? name,
    String? phone,
    String? address,
    String? notes,
    bool? isActive,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return Supplier(
      id: id ?? this.id,
      name: name ?? this.name,
      phone: phone ?? this.phone,
      address: address ?? this.address,
      notes: notes ?? this.notes,
      isActive: isActive ?? this.isActive,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}

class SupplierDraft {
  const SupplierDraft({
    required this.name,
    this.phone,
    this.address,
    this.notes,
  });

  final String name;
  final String? phone;
  final String? address;
  final String? notes;
}
