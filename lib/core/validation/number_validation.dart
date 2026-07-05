class NumberValidation {
  const NumberValidation._();

  static String normalizeNumericText(String input) {
    final buffer = StringBuffer();

    for (final rune in input.trim().runes) {
      final char = String.fromCharCode(rune);
      final normalizedDigit = _normalizeDigit(rune);

      if (normalizedDigit != null) {
        buffer.write(normalizedDigit);
      } else if (char == '\u066b' || char == '\u066c' || char == ',') {
        buffer.write('.');
      } else if (char == ' ' || char == '\u00a0') {
        continue;
      } else {
        buffer.write(char);
      }
    }

    return buffer.toString();
  }

  static int parseScaledDecimal(
    String input, {
    required int scale,
    required int maxFractionDigits,
    bool allowZero = true,
    bool allowNegative = false,
    String fieldName = 'value',
  }) {
    if (scale <= 0) {
      throw ArgumentError.value(scale, 'scale', 'Scale must be positive.');
    }
    if (maxFractionDigits < 0) {
      throw ArgumentError.value(
        maxFractionDigits,
        'maxFractionDigits',
        'Fraction digits must not be negative.',
      );
    }

    final normalized = normalizeNumericText(input);
    final match = RegExp(r'^([+-]?)(\d+)(?:\.(\d+))?$').firstMatch(normalized);

    if (match == null) {
      throw FormatException('Invalid numeric input for $fieldName.', input);
    }

    final sign = match.group(1);
    if (sign == '-' && !allowNegative) {
      throw FormatException('Negative $fieldName is not allowed.', input);
    }
    if (sign == '+') {
      throw FormatException('Plus sign is not allowed for $fieldName.', input);
    }

    final wholeText = match.group(2)!;
    final fractionText = match.group(3) ?? '';

    if (fractionText.length > maxFractionDigits) {
      throw FormatException(
        '$fieldName supports at most $maxFractionDigits decimal places.',
        input,
      );
    }

    final whole = int.parse(wholeText);
    final fractionPadded = fractionText.padRight(maxFractionDigits, '0');
    final fraction = fractionPadded.isEmpty ? 0 : int.parse(fractionPadded);
    final value = (whole * scale) + fraction;
    final signedValue = sign == '-' ? -value : value;

    if (!allowZero && signedValue == 0) {
      throw FormatException('Zero $fieldName is not allowed.', input);
    }

    return signedValue;
  }

  static String formatScaledInteger(
    int value, {
    required int scale,
    required int fractionDigits,
  }) {
    if (scale <= 0) {
      throw ArgumentError.value(scale, 'scale', 'Scale must be positive.');
    }
    if (fractionDigits < 0) {
      throw ArgumentError.value(
        fractionDigits,
        'fractionDigits',
        'Fraction digits must not be negative.',
      );
    }

    final isNegative = value < 0;
    final absolute = value.abs();
    final whole = absolute ~/ scale;
    final fraction = absolute % scale;
    final fractionText = fraction.toString().padLeft(fractionDigits, '0');
    final sign = isNegative ? '-' : '';

    if (fractionDigits == 0) {
      return '$sign$whole';
    }

    return '$sign$whole.$fractionText';
  }

  static String trimTrailingFractionZeros(String decimalText) {
    if (!decimalText.contains('.')) {
      return decimalText;
    }

    var trimmed = decimalText;
    while (trimmed.endsWith('0')) {
      trimmed = trimmed.substring(0, trimmed.length - 1);
    }

    if (trimmed.endsWith('.')) {
      trimmed = trimmed.substring(0, trimmed.length - 1);
    }

    return trimmed;
  }

  static String? _normalizeDigit(int rune) {
    if (rune >= 0x30 && rune <= 0x39) {
      return String.fromCharCode(rune);
    }
    if (rune >= 0x660 && rune <= 0x669) {
      return String.fromCharCode(0x30 + (rune - 0x660));
    }
    if (rune >= 0x6f0 && rune <= 0x6f9) {
      return String.fromCharCode(0x30 + (rune - 0x6f0));
    }

    return null;
  }
}
