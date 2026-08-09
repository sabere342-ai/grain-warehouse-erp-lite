const trialDuration = Duration(days: 14);
const trialStateVersion = 1;

enum TrialAccessStatus {
  active,
  expired,
  clockRollbackDetected,
  invalidState,
}

class TrialPersistentState {
  const TrialPersistentState({
    required this.version,
    required this.startedAtUtc,
    required this.lastAcceptedRunAtUtc,
    required this.tamperDetected,
    required this.expired,
  });

  final int version;
  final DateTime startedAtUtc;
  final DateTime lastAcceptedRunAtUtc;
  final bool tamperDetected;
  final bool expired;

  TrialPersistentState copyWith({
    DateTime? lastAcceptedRunAtUtc,
    bool? tamperDetected,
    bool? expired,
  }) {
    return TrialPersistentState(
      version: version,
      startedAtUtc: startedAtUtc,
      lastAcceptedRunAtUtc: lastAcceptedRunAtUtc ?? this.lastAcceptedRunAtUtc,
      tamperDetected: tamperDetected ?? this.tamperDetected,
      expired: expired ?? this.expired,
    );
  }
}

class TrialEvaluation {
  const TrialEvaluation._({
    required this.status,
    this.startedAtUtc,
    this.lastAcceptedRunAtUtc,
    this.expiresAtUtc,
    this.remaining = Duration.zero,
  });

  factory TrialEvaluation.active(
    TrialPersistentState state,
    DateTime nowUtc,
  ) {
    final expiresAtUtc = state.startedAtUtc.add(trialDuration);
    return TrialEvaluation._(
      status: TrialAccessStatus.active,
      startedAtUtc: state.startedAtUtc,
      lastAcceptedRunAtUtc: state.lastAcceptedRunAtUtc,
      expiresAtUtc: expiresAtUtc,
      remaining: expiresAtUtc.difference(nowUtc),
    );
  }

  factory TrialEvaluation.blocked(
    TrialAccessStatus status, {
    TrialPersistentState? state,
  }) {
    assert(status != TrialAccessStatus.active);
    return TrialEvaluation._(
      status: status,
      startedAtUtc: state?.startedAtUtc,
      lastAcceptedRunAtUtc: state?.lastAcceptedRunAtUtc,
      expiresAtUtc: state?.startedAtUtc.add(trialDuration),
    );
  }

  final TrialAccessStatus status;
  final DateTime? startedAtUtc;
  final DateTime? lastAcceptedRunAtUtc;
  final DateTime? expiresAtUtc;
  final Duration remaining;

  bool get allowsAccess => status == TrialAccessStatus.active;

  int get daysRemaining {
    if (!allowsAccess || remaining <= Duration.zero) return 0;
    const microsecondsPerDay = Duration.microsecondsPerDay;
    return (remaining.inMicroseconds + microsecondsPerDay - 1) ~/
        microsecondsPerDay;
  }
}
