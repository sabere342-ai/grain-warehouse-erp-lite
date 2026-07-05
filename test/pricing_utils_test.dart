import 'package:flutter_test/flutter_test.dart';
import 'package:grain_warehouse_erp_lite/core/pricing/pricing_utils.dart';

void main() {
  group('PricingUtils.calculateLineTotalPiasters', () {
    test('calculates full kg line totals with integer arithmetic', () {
      expect(
        PricingUtils.calculateLineTotalPiasters(
          quantityGrams: 1000,
          pricePiastersPerKg: 2000,
        ),
        2000,
      );
    });

    test('calculates partial kg line totals', () {
      expect(
        PricingUtils.calculateLineTotalPiasters(
          quantityGrams: 500,
          pricePiastersPerKg: 2000,
        ),
        1000,
      );
    });

    test('rounds to nearest piaster after multiplication and division', () {
      expect(
        PricingUtils.calculateLineTotalPiasters(
          quantityGrams: 250,
          pricePiastersPerKg: 1999,
        ),
        500,
      );
      expect(
        PricingUtils.calculateLineTotalPiasters(
          quantityGrams: 333,
          pricePiastersPerKg: 1000,
        ),
        333,
      );
      expect(
        PricingUtils.calculateLineTotalPiasters(
          quantityGrams: 999,
          pricePiastersPerKg: 1,
        ),
        1,
      );
    });

    test('validates positive quantity and positive price', () {
      expect(
        () => PricingUtils.calculateLineTotalPiasters(
          quantityGrams: 0,
          pricePiastersPerKg: 2000,
        ),
        throwsArgumentError,
      );
      expect(
        () => PricingUtils.calculateLineTotalPiasters(
          quantityGrams: 1000,
          pricePiastersPerKg: 0,
        ),
        throwsArgumentError,
      );
      expect(
        () => PricingUtils.calculateLineTotalPiasters(
          quantityGrams: -1,
          pricePiastersPerKg: 2000,
        ),
        throwsArgumentError,
      );
    });
  });
}
