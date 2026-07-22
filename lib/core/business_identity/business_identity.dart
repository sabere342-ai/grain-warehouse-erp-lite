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
  });

  static const defaultDisplayName = 'غلال';
  static const empty = BusinessIdentity();

  final String? establishmentName;
  final LogoMetadata? logo;

  bool get hasLogo => logo != null && logo!.isValid;

  String get displayName {
    final name = establishmentName?.trim();
    return name == null || name.isEmpty ? defaultDisplayName : name;
  }

  bool get hasCustomName {
    final name = establishmentName?.trim();
    return name != null && name.isNotEmpty;
  }

  BusinessIdentity copyWith({
    String? establishmentName,
    LogoMetadata? logo,
    bool clearLogo = false,
  }) {
    return BusinessIdentity(
      establishmentName: establishmentName ?? this.establishmentName,
      logo: clearLogo ? null : (logo ?? this.logo),
    );
  }

  Map<String, Object?> toJson() {
    return {
      'establishmentName': establishmentName,
      if (logo != null) 'logo': logo!.toJson(),
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
    );
  }
}
