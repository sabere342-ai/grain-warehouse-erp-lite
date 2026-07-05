import 'package:grain_warehouse_erp_lite/core/validation/number_validation.dart';

class WeightUtils {
  const WeightUtils._();

  static const int gramsPerKg = 1000;
  static const int gramsPerTon = 1000000;

  static int parseKgToGrams(
    String input, {
    bool allowZero = false,
    bool allowNegative = false,
  }) {
    return NumberValidation.parseScaledDecimal(
      input,
      scale: gramsPerKg,
      maxFractionDigits: 3,
      allowZero: allowZero,
      allowNegative: allowNegative,
      fieldName: 'weight',
    );
  }

  static int parseTonToGrams(
    String input, {
    bool allowZero = false,
    bool allowNegative = false,
  }) {
    return NumberValidation.parseScaledDecimal(
      input,
      scale: gramsPerTon,
      maxFractionDigits: 6,
      allowZero: allowZero,
      allowNegative: allowNegative,
      fieldName: 'weight',
    );
  }

  static String formatGramsAsKg(int grams) {
    final value = NumberValidation.formatScaledInteger(
      grams,
      scale: gramsPerKg,
      fractionDigits: 3,
    );

    return '${NumberValidation.trimTrailingFractionZeros(value)} كجم';
  }

  static String formatGramsAsTon(int grams) {
    final value = NumberValidation.formatScaledInteger(
      grams,
      scale: gramsPerTon,
      fractionDigits: 6,
    );

    return '${NumberValidation.trimTrailingFractionZeros(value)} طن';
  }
}
