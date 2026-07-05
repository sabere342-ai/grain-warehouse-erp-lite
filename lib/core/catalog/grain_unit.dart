enum GrainUnit {
  kilogram,
  ton;

  String get labelAr {
    switch (this) {
      case GrainUnit.kilogram:
        return 'كجم';
      case GrainUnit.ton:
        return 'طن';
    }
  }

  String get wireName {
    switch (this) {
      case GrainUnit.kilogram:
        return 'kilogram';
      case GrainUnit.ton:
        return 'ton';
    }
  }

  static GrainUnit fromWireName(String value) {
    switch (value) {
      case 'kilogram':
        return GrainUnit.kilogram;
      case 'ton':
        return GrainUnit.ton;
      default:
        throw ArgumentError.value(value, 'value', 'Unknown grain unit.');
    }
  }
}

class GrainUnitConverter {
  const GrainUnitConverter._();

  static const int kilogramsPerTon = 1000;

  static int tonsToKilograms(int tons) {
    if (tons < 0) {
      throw ArgumentError.value(tons, 'tons', 'Tons must not be negative.');
    }

    return tons * kilogramsPerTon;
  }
}
