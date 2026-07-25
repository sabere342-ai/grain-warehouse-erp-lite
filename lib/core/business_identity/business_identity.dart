class LogoMetadata {
  const LogoMetadata({
    required this.managedFileName,
    required this.mimeType,
    required this.sha256,
    required this.byteLength,
    required this.width,
    required this.height,
  });

  final String managedFileName;
  final String mimeType;
  final String sha256;
  final int byteLength;
  final int width;
  final int height;

  Map<String, Object?> toJson() {
    return {
      'managedFileName': managedFileName,
      'mimeType': mimeType,
      'sha256': sha256,
      'byteLength': byteLength,
      'width': width,
      'height': height,
    };
  }

  factory LogoMetadata.fromJson(Object? value) {
    if (value is! Map<String, Object?>) {
      return const LogoMetadata(
        managedFileName: '',
        mimeType: '',
        sha256: '',
        byteLength: 0,
        width: 0,
        height: 0,
      );
    }
    return LogoMetadata(
      managedFileName: value['managedFileName'] as String? ?? '',
      mimeType: value['mimeType'] as String? ?? '',
      sha256: value['sha256'] as String? ?? '',
      byteLength: value['byteLength'] as int? ?? 0,
      width: value['width'] as int? ?? 0,
      height: value['height'] as int? ?? 0,
    );
  }

  bool get isValid {
    return managedFileName.isNotEmpty &&
        mimeType.isNotEmpty &&
        sha256.isNotEmpty &&
        byteLength > 0;
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is LogoMetadata &&
        other.managedFileName == managedFileName &&
        other.mimeType == mimeType &&
        other.sha256 == sha256 &&
        other.byteLength == byteLength &&
        other.width == width &&
        other.height == height;
  }

  @override
  int get hashCode => Object.hash(
        managedFileName,
        mimeType,
        sha256,
        byteLength,
        width,
        height,
      );
}

class BusinessIdentity {
  const BusinessIdentity({
    this.establishmentName,
    this.logo,
    this.taxNumber,
    this.address,
    this.phone,
  });

  static const defaultDisplayName = 'غلال';
  static const empty = BusinessIdentity();

  final String? establishmentName;
  final LogoMetadata? logo;
  final String? taxNumber;
  final String? address;
  final String? phone;

  bool get hasLogo => logo != null && logo!.isValid;

  String get displayName {
    final name = establishmentName?.trim();
    return name == null || name.isEmpty ? defaultDisplayName : name;
  }

  bool get hasCustomName {
    final name = establishmentName?.trim();
    return name != null && name.isNotEmpty;
  }

  String? get trimmedTaxNumber {
    final value = taxNumber?.trim();
    return value == null || value.isEmpty ? null : value;
  }

  String? get trimmedAddress {
    final value = address?.trim();
    return value == null || value.isEmpty ? null : value;
  }

  String? get trimmedPhone {
    final value = phone?.trim();
    return value == null || value.isEmpty ? null : value;
  }

  bool get hasAddress => trimmedAddress != null;
  bool get hasPhone => trimmedPhone != null;
  bool get hasTaxNumber => trimmedTaxNumber != null;

  BusinessIdentity copyWith({
    String? establishmentName,
    LogoMetadata? logo,
    bool clearLogo = false,
    String? taxNumber,
    bool clearTaxNumber = false,
    String? address,
    bool clearAddress = false,
    String? phone,
    bool clearPhone = false,
  }) {
    return BusinessIdentity(
      establishmentName: establishmentName ?? this.establishmentName,
      logo: clearLogo ? null : (logo ?? this.logo),
      taxNumber: clearTaxNumber ? null : (taxNumber ?? this.taxNumber),
      address: clearAddress ? null : (address ?? this.address),
      phone: clearPhone ? null : (phone ?? this.phone),
    );
  }

  Map<String, Object?> toJson() {
    return {
      'establishmentName': establishmentName,
      if (logo != null) 'logo': logo!.toJson(),
      if (taxNumber != null) 'taxNumber': taxNumber,
      if (address != null) 'address': address,
      if (phone != null) 'phone': phone,
    };
  }

  factory BusinessIdentity.fromJson(Object? value) {
    if (value is! Map<String, Object?>) {
      return empty;
    }
    final establishmentName = value['establishmentName'];
    final logoData = value['logo'];
    return BusinessIdentity(
      establishmentName: establishmentName is String ? establishmentName : null,
      logo: logoData != null ? LogoMetadata.fromJson(logoData) : null,
      taxNumber:
          value['taxNumber'] is String ? value['taxNumber'] as String : null,
      address: value['address'] is String ? value['address'] as String : null,
      phone: value['phone'] is String ? value['phone'] as String : null,
    );
  }
}
