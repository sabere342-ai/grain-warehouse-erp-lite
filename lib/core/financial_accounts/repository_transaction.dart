import 'dart:async';

class RepositoryTransaction {
  RepositoryTransaction._();

  static final Object _transactionZoneKey = Object();
  static Future<void> _tail = Future<void>.value();

  static bool get isActive => Zone.current[_transactionZoneKey] == true;

  static Future<T> execute<T>(
    List<SnapshotHolder> snapshots,
    Future<T> Function() operation,
  ) async {
    if (isActive) {
      throw StateError('Nested repository transactions are not supported.');
    }
    final completion = Completer<void>();
    final previous = _tail;
    _tail = completion.future;
    await previous.catchError((_) {});
    try {
      return await runZoned(
        () => _executeWithinBoundary(snapshots, operation),
        zoneValues: <Object?, Object?>{_transactionZoneKey: true},
      );
    } finally {
      completion.complete();
    }
  }

  static Future<T> _executeWithinBoundary<T>(
    List<SnapshotHolder> snapshots,
    Future<T> Function() operation,
  ) async {
    for (final snapshot in snapshots) {
      snapshot.capture();
    }
    try {
      return await operation();
    } catch (error) {
      for (final snapshot in snapshots.reversed) {
        try {
          snapshot.rollback();
        } catch (_) {
          // Preserve the original operation error. Rollback targets are
          // independent and remaining targets must still restore.
        }
      }
      rethrow;
    }
  }
}

abstract class SnapshotHolder {
  void capture();
  void rollback();
}

class ListSnapshot<T> extends SnapshotHolder {
  ListSnapshot(this._source);

  final List<T> _source;
  List<T>? _original;

  @override
  void capture() {
    _original = List<T>.from(_source);
  }

  @override
  void rollback() {
    if (_original != null) {
      _source.clear();
      _source.addAll(_original!);
    }
  }
}

class CounterSnapshot extends SnapshotHolder {
  CounterSnapshot(this._source);

  final List<int> _source;
  int? _original;

  @override
  void capture() {
    _original = _source[0];
  }

  @override
  void rollback() {
    if (_original != null) {
      _source[0] = _original!;
    }
  }
}

/// Implemented by the in-memory repositories that can participate in one
/// rollback boundary. Production coordinators fail closed when a required
/// participant does not expose this capability.
abstract class TransactionSnapshotProvider {
  SnapshotHolder createTransactionSnapshot();
}

class CompositeSnapshot extends SnapshotHolder {
  CompositeSnapshot(this._snapshots);

  final List<SnapshotHolder> _snapshots;

  @override
  void capture() {
    for (final snapshot in _snapshots) {
      snapshot.capture();
    }
  }

  @override
  void rollback() {
    for (final snapshot in _snapshots.reversed) {
      snapshot.rollback();
    }
  }
}

class ObjectStateSnapshot<T> extends SnapshotHolder {
  ObjectStateSnapshot({required this.captureState, required this.restoreState});

  final T Function() captureState;
  final void Function(T value) restoreState;
  T? _original;

  @override
  void capture() => _original = captureState();

  @override
  void rollback() {
    final original = _original;
    if (original != null) restoreState(original);
  }
}

class CallbackSnapshot extends SnapshotHolder {
  CallbackSnapshot(
      {required this.captureCallback, required this.rollbackCallback});

  final void Function() captureCallback;
  final void Function() rollbackCallback;

  @override
  void capture() => captureCallback();

  @override
  void rollback() => rollbackCallback();
}

class MapSnapshot<K, V> extends SnapshotHolder {
  MapSnapshot(this._source);

  final Map<K, V> _source;
  Map<K, V>? _original;

  @override
  void capture() {
    _original = Map<K, V>.from(_source);
  }

  @override
  void rollback() {
    if (_original != null) {
      _source.clear();
      _source.addAll(_original!);
    }
  }
}
