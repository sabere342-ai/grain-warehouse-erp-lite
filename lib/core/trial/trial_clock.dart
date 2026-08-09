abstract interface class TrialClock {
  DateTime nowUtc();
}

class SystemTrialClock implements TrialClock {
  const SystemTrialClock();

  @override
  DateTime nowUtc() => DateTime.now().toUtc();
}
