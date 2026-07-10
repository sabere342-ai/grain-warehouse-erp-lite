class BusinessIdentity {
  const BusinessIdentity({
    this.establishmentName,
  });

  static const defaultDisplayName = 'نظام إدارة مخازن الحبوب';
  static const empty = BusinessIdentity();

  final String? establishmentName;

  String get displayName {
    final name = establishmentName?.trim();
    return name == null || name.isEmpty ? defaultDisplayName : name;
  }

  bool get hasCustomName {
    final name = establishmentName?.trim();
    return name != null && name.isNotEmpty;
  }

  BusinessIdentity copyWith({String? establishmentName}) {
    return BusinessIdentity(establishmentName: establishmentName);
  }

  Map<String, Object?> toJson() {
    return {
      'establishmentName': establishmentName,
    };
  }

  factory BusinessIdentity.fromJson(Object? value) {
    if (value is! Map<String, Object?>) {
      return empty;
    }
    final establishmentName = value['establishmentName'];
    return BusinessIdentity(
      establishmentName: establishmentName is String ? establishmentName : null,
    );
  }
}
