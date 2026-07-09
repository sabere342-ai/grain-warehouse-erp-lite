class PhoneNumberNormalizer {
  PhoneNumberNormalizer._();

  /// Normalizes an Egyptian phone number to international format without '+'.
  ///
  /// Accepts: 010xxxxxxxx (11 digits), +2010xxxxxxxx (13 digits),
  ///          002010xxxxxxxx (14 digits), 2010xxxxxxxx (12 digits).
  ///
  /// Returns null if the number is empty or invalid.
  static String? normalize(String? raw) {
    if (raw == null || raw.trim().isEmpty) return null;

    var cleaned = raw.trim().replaceAll(RegExp(r'[\s\-\(\)\.]'), '');

    // Strip leading '+'
    if (cleaned.startsWith('+')) {
      cleaned = cleaned.substring(1);
    }

    // Strip country code prefix '002' or '20'
    if (cleaned.startsWith('002')) {
      cleaned = cleaned.substring(3);
    } else if (cleaned.startsWith('20') && cleaned.length == 13) {
      // Already in 2010xxxxxxxx format (13 chars with 20 prefix)
      // Keep as is, validation below will check length
    } else if (cleaned.startsWith('20') && cleaned.length > 12) {
      // 20xxxxxxxxx format but may include leading 0, handle below
    }

    // Egyptian mobile: 01X XXXXXXXX (11 digits) -> normalize to 2010xxxxxxxx (12)
    if (cleaned.startsWith('01') && cleaned.length == 11) {
      // Strip leading '0' then prepend '20'
      cleaned = '20${cleaned.substring(1)}';
    }

    if (!_isValidEgyptianNumber(cleaned)) return null;

    return cleaned;
  }

  /// Validates a normalized number (must be 12 digits, start with 201).
  static bool _isValidEgyptianNumber(String normalized) {
    if (normalized.length != 12) return false;
    if (!normalized.startsWith('201')) return false;
    final prefix = normalized.substring(0, 4);
    return ['2010', '2011', '2012', '2015'].contains(prefix);
  }
}
