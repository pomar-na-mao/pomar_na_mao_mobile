import 'dart:async';
import 'dart:collection';
import 'dart:convert';
import 'dart:developer';

enum RuntimeStage {
  databaseOpen,
  localRead,
  decode,
  projection,
  occurrences,
  persistence,
  publication,
  markers,
  lifecycle,
  flutterError,
  asynchronousError,
}

enum RuntimeOutcome { success, failure, timeout, started, stopped }

/// Only fixed labels and numeric aggregates can enter an exported event.
class RuntimeDiagnostics {
  RuntimeDiagnostics({this.capacity = 200}) {
    if (capacity < 1 || capacity > 200) {
      throw RangeError.range(capacity, 1, 200, 'capacity');
    }
  }

  static final instance = RuntimeDiagnostics();
  final int capacity;
  final Queue<Map<String, Object>> _events = Queue();

  void record(
    RuntimeStage stage, {
    RuntimeOutcome outcome = RuntimeOutcome.success,
    int? elapsedUs,
    int? count,
    int? revision,
    int? activeMaps,
  }) {
    if (_events.length == capacity) _events.removeFirst();
    _events.add({
      'time': DateTime.now().toUtc().toIso8601String(),
      'stage': stage.name,
      'outcome': outcome.name,
      'elapsedUs': ?elapsedUs,
      'count': ?count,
      'revision': ?revision,
      'activeMaps': ?activeMaps,
    });
  }

  Future<T> track<T>(RuntimeStage stage, Future<T> Function() action) async {
    final watch = Stopwatch()..start();
    final timeline = TimelineTask()..start(stage.name);
    var outcome = RuntimeOutcome.success;
    try {
      return await action();
    } on TimeoutException {
      outcome = RuntimeOutcome.timeout;
      rethrow;
    } catch (_) {
      outcome = RuntimeOutcome.failure;
      rethrow;
    } finally {
      timeline.finish();
      record(stage, outcome: outcome, elapsedUs: watch.elapsedMicroseconds);
    }
  }

  String exportJson() => jsonEncode({'version': 1, 'events': _events.toList()});

  T measure<T>(RuntimeStage stage, T Function() action) {
    final watch = Stopwatch()..start();
    Timeline.startSync(stage.name);
    var outcome = RuntimeOutcome.success;
    try {
      return action();
    } catch (_) {
      outcome = RuntimeOutcome.failure;
      rethrow;
    } finally {
      Timeline.finishSync();
      record(stage, outcome: outcome, elapsedUs: watch.elapsedMicroseconds);
    }
  }
}
