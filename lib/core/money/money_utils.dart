import 'package:grain_warehouse_erp_lite/core/validation/number_validation.dart';

class MoneyUtils {
  const MoneyUtils._();

  static const int piastersPerEgp = 100;

  static int parseEgpToPiasters(
    String input, {
    bool allowZero = true,
    bool allowNegative = false,
  }) {
    return NumberValidation.parseScaledDecimal(
      input,
      scale: piastersPerEgp,
      maxFractionDigits: 2,
      allowZero: allowZero,
      allowNegative: allowNegative,
      fieldName: 'money',
    );
  }

  static String formatPiastersAsEgp(int piasters) {
    final value = formatPiastersAsEgpNumber(piasters);

    return '$value ج.م';
  }

  static String formatPiastersAsEgpNumber(int piasters) {
    final value = NumberValidation.formatScaledInteger(
      piasters,
      scale: piastersPerEgp,
      fractionDigits: 2,
    );

    return value;
  }
}
