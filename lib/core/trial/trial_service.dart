import 'trial_clock.dart';
import 'trial_state.dart';
import 'trial_state_store.dart';

abstract interface class TrialEvaluator {
  Future<TrialEvaluation> evaluate();
}

class TrialService implements TrialEvaluator {
  const TrialService({
    required TrialStateStore store,
    required TrialClock clock,
  })  : _store = store,
        _clock = clock;

  static const rollbackTolerance = Duration.zero;

  final TrialStateStore _store;
  final TrialClock _clock;

  static Future<TrialService> production() async {
    return TrialService(
      store: await FileTrialStateStore.production(),
      clock: const SystemTrialClock(),
    );
  }

  @override
  Future<TrialEvaluation> evaluate() async {
    try {
      final nowUtc = _clock.nowUtc().toUtc();
      final loaded = await _store.read();
      switch (loaded.kind) {
        case TrialStateLoadKind.fresh:
          final state = TrialPersistentState(
            version: trialStateVersion,
            startedAtUtc: nowUtc,
            lastAcceptedRunAtUtc: nowUtc,
            tamperDetected: false,
            expired: false,
          );
          await _store.write(state);
          return TrialEvaluation.active(state, nowUtc);
        case TrialStateLoadKind.invalid:
          return TrialEvaluation.blocked(TrialAccessStatus.invalidState);
        case TrialStateLoadKind.loaded:
          return _evaluateExisting(loaded.state!, nowUtc);
      }
    } catch (_) {
      return TrialEvaluation.blocked(TrialAccessStatus.invalidState);
    }
  }

  Future<TrialEvaluation> _evaluateExisting(
    TrialPersistentState state,
    DateTime nowUtc,
  ) async {
    if (_isStructurallyInvalid(state)) {
      return TrialEvaluation.blocked(
        TrialAccessStatus.invalidState,
        state: state,
      );
    }
    if (state.tamperDetected) {
      return TrialEvaluation.blocked(
        TrialAccessStatus.clockRollbackDetected,
        state: state,
      );
    }
    if (state.expired) {
      return TrialEvaluation.blocked(
        TrialAccessStatus.expired,
        state: state,
      );
    }
    final earliestAcceptedNow =
        state.lastAcceptedRunAtUtc.subtract(rollbackTolerance);
    if (nowUtc.isBefore(earliestAcceptedNow)) {
      final stickyState = state.copyWith(tamperDetected: true);
      await _store.write(stickyState);
      return TrialEvaluation.blocked(
        TrialAccessStatus.clockRollbackDetected,
        state: stickyState,
      );
    }

    final expiresAtUtc = state.startedAtUtc.add(trialDuration);
    if (!nowUtc.isBefore(expiresAtUtc)) {
      final expiredState = state.copyWith(expired: true);
      await _store.write(expiredState);
      return TrialEvaluation.blocked(
        TrialAccessStatus.expired,
        state: expiredState,
      );
    }

    final acceptedState = nowUtc.isAtSameMomentAs(state.lastAcceptedRunAtUtc)
        ? state
        : state.copyWith(lastAcceptedRunAtUtc: nowUtc);
    if (!identical(acceptedState, state)) {
      await _store.write(acceptedState);
    }
    return TrialEvaluation.active(acceptedState, nowUtc);
  }

  bool _isStructurallyInvalid(TrialPersistentState state) {
    if (state.version != trialStateVersion) return true;
    if (state.startedAtUtc.isAfter(state.lastAcceptedRunAtUtc)) return true;
    final expiresAtUtc = state.startedAtUtc.add(trialDuration);
    if (!state.lastAcceptedRunAtUtc.isBefore(expiresAtUtc)) return true;
    return false;
  }
}
