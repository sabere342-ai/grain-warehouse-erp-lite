class PricingUtils {
  const PricingUtils._();

  static int calculateLineTotalPiasters({
    required int quantityGrams,
    required int pricePiastersPerKg,
  }) {
    if (quantityGrams <= 0) {
      throw ArgumentError.value(
        quantityGrams,
        'quantityGrams',
        'Quantity must be positive.',
      );
    }
    if (pricePiastersPerKg <= 0) {
      throw ArgumentError.value(
        pricePiastersPerKg,
        'pricePiastersPerKg',
        'Price must be positive.',
      );
    }

    final raw = quantityGrams * pricePiastersPerKg;
    return (raw + 500) ~/ 1000;
  }
}
