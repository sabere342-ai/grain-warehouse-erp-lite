abstract interface class ApplicationClock {
  /// Returns an instant with [DateTime.isUtc] equal to true.
  DateTime nowUtc();
}

final class SystemApplicationClock implements ApplicationClock {
  const SystemApplicationClock();

  @override
  DateTime nowUtc() => DateTime.now().toUtc();
}

DateTime requireUtcInstant(DateTime value, String argumentName) {
  if (!value.isUtc) {
    throw ArgumentError.value(value, argumentName, 'UTC instant required.');
  }
  return value;
}

/// Date-only value interpreted under the fixed v1 Africa/Cairo policy.
final class BusinessDate {
  factory BusinessDate(String value) {
    final match = RegExp(r'^(\d{4})-(\d{2})-(\d{2})$').firstMatch(value);
    if (match == null) throw ArgumentError.value(value, 'businessDate');
    final year = int.parse(match.group(1)!);
    final month = int.parse(match.group(2)!);
    final day = int.parse(match.group(3)!);
    final parsed = DateTime.utc(year, month, day);
    if (parsed.year != year || parsed.month != month || parsed.day != day) {
      throw ArgumentError.value(value, 'businessDate');
    }
    return BusinessDate._(value);
  }

  const BusinessDate._(this.value);

  final String value;

  static BusinessDate fromCairoInstant(DateTime instantUtc) {
    requireUtcInstant(instantUtc, 'instantUtc');
    final local =
        instantUtc.add(Duration(hours: _cairoOffsetHours(instantUtc)));
    return BusinessDate(
      '${local.year.toString().padLeft(4, '0')}-'
      '${local.month.toString().padLeft(2, '0')}-'
      '${local.day.toString().padLeft(2, '0')}',
    );
  }

  // Egypt's current statutory rule (reintroduced in 2023): DST begins at
  // 00:00 on the last Friday in April and ends at 00:00 after the last
  // Thursday in October. Database authority still uses the IANA zone.
  static int _cairoOffsetHours(DateTime utc) {
    if (utc.year < 2023) return 2;
    final aprilLast =
        DateTime.utc(utc.year, 5).subtract(const Duration(days: 1));
    final lastFridayApril = aprilLast.subtract(
      Duration(days: (aprilLast.weekday - DateTime.friday) % 7),
    );
    final startUtc = DateTime.utc(
      utc.year,
      4,
      lastFridayApril.day,
    ).subtract(const Duration(hours: 2));
    final octoberLast =
        DateTime.utc(utc.year, 11).subtract(const Duration(days: 1));
    final lastThursdayOctober = octoberLast.subtract(
      Duration(days: (octoberLast.weekday - DateTime.thursday) % 7),
    );
    final endUtc = DateTime.utc(
      utc.year,
      10,
      lastThursdayOctober.day + 1,
    ).subtract(const Duration(hours: 3));
    return !utc.isBefore(startUtc) && utc.isBefore(endUtc) ? 3 : 2;
  }

  @override
  bool operator ==(Object other) =>
      other is BusinessDate && other.value == value;

  @override
  int get hashCode => value.hashCode;

  @override
  String toString() => value;
}
