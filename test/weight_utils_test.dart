import 'package:flutter_test/flutter_test.dart';
import 'package:grain_warehouse_erp_lite/core/weight/weight_utils.dart';

void main() {
  group('WeightUtils.parseKgToGrams', () {
    test('converts kg text to integer grams', () {
      expect(WeightUtils.parseKgToGrams('1'), 1000);
      expect(WeightUtils.parseKgToGrams('0.5'), 500);
      expect(WeightUtils.parseKgToGrams('12.125'), 12125);
    });

    test('supports Arabic and Persian digits', () {
      expect(WeightUtils.parseKgToGrams('١.٥'), 1500);
      expect(WeightUtils.parseKgToGrams('۱.۵'), 1500);
    });

    test('rejects invalid, zero, and negative kg quantities', () {
      expect(() => WeightUtils.parseKgToGrams('abc'), throwsFormatException);
      expect(() => WeightUtils.parseKgToGrams('1.1234'), throwsFormatException);
      expect(() => WeightUtils.parseKgToGrams('0'), throwsFormatException);
      expect(() => WeightUtils.parseKgToGrams('-1'), throwsFormatException);
    });
  });

  group('WeightUtils.parseTonToGrams', () {
    test('converts ton text to integer grams', () {
      expect(WeightUtils.parseTonToGrams('1'), 1000000);
      expect(WeightUtils.parseTonToGrams('1.25'), 1250000);
      expect(WeightUtils.parseTonToGrams('0.0005'), 500);
    });

    test('rejects invalid, zero, and negative ton quantities', () {
      expect(() => WeightUtils.parseTonToGrams('abc'), throwsFormatException);
      expect(() => WeightUtils.parseTonToGrams('1.1234567'),
          throwsFormatException);
      expect(() => WeightUtils.parseTonToGrams('0'), throwsFormatException);
      expect(() => WeightUtils.parseTonToGrams('-1'), throwsFormatException);
    });
  });

  group('WeightUtils formatting', () {
    test('formats grams as kg and ton displays', () {
      expect(WeightUtils.formatGramsAsKg(1000), '1 كجم');
      expect(WeightUtils.formatGramsAsKg(500), '0.5 كجم');
      expect(WeightUtils.formatGramsAsKg(1250), '1.25 كجم');
      expect(WeightUtils.formatGramsAsTon(1000000), '1 طن');
      expect(WeightUtils.formatGramsAsTon(1250000), '1.25 طن');
    });
  });
}
