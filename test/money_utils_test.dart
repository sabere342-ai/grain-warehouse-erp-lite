import 'package:flutter_test/flutter_test.dart';
import 'package:grain_warehouse_erp_lite/core/money/money_utils.dart';

void main() {
  group('MoneyUtils.parseEgpToPiasters', () {
    test('converts EGP text to integer piasters', () {
      expect(MoneyUtils.parseEgpToPiasters('125'), 12500);
      expect(MoneyUtils.parseEgpToPiasters('125.50'), 12550);
      expect(MoneyUtils.parseEgpToPiasters('0.25'), 25);
      expect(MoneyUtils.parseEgpToPiasters('12.5'), 1250);
    });

    test('supports Arabic and Persian digits', () {
      expect(MoneyUtils.parseEgpToPiasters('١٢٥.٥٠'), 12550);
      expect(MoneyUtils.parseEgpToPiasters('۱۲۵.۵۰'), 12550);
    });

    test('rejects invalid money input', () {
      expect(() => MoneyUtils.parseEgpToPiasters('abc'), throwsFormatException);
      expect(
          () => MoneyUtils.parseEgpToPiasters('12.345'), throwsFormatException);
      expect(
          () => MoneyUtils.parseEgpToPiasters('12..50'), throwsFormatException);
      expect(() => MoneyUtils.parseEgpToPiasters(''), throwsFormatException);
    });

    test('rejects negative values by default', () {
      expect(() => MoneyUtils.parseEgpToPiasters('-1'), throwsFormatException);
    });

    test('can reject zero when required', () {
      expect(
        () => MoneyUtils.parseEgpToPiasters('0', allowZero: false),
        throwsFormatException,
      );
    });
  });

  group('MoneyUtils.formatPiastersAsEgp', () {
    test('formats integer piasters as Arabic-friendly EGP display', () {
      expect(MoneyUtils.formatPiastersAsEgp(12500), '125.00 ج.م');
      expect(MoneyUtils.formatPiastersAsEgp(12550), '125.50 ج.م');
      expect(MoneyUtils.formatPiastersAsEgp(25), '0.25 ج.م');
    });
  });
}
