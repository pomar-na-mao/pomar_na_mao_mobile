import 'dart:async';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:pomar_na_mao_mobile/core/diagnostics/runtime_diagnostics.dart';

void main() {
  test('keeps only the most recent 200 aggregate events', () {
    final diagnostics = RuntimeDiagnostics();
    for (var i = 0; i < 250; i++) {
      diagnostics.record(RuntimeStage.markers, revision: i, count: 1000);
    }
    final events =
        (jsonDecode(diagnostics.exportJson()) as Map)['events'] as List;
    expect(events, hasLength(200));
    expect(events.first['revision'], 50);
    expect(events.last['revision'], 249);
  });

  test('records failure category without exporting error payload', () async {
    final diagnostics = RuntimeDiagnostics();
    final error = StateError('secret-token latitude=12.34 plant-id=private');
    await expectLater(
      diagnostics.track(RuntimeStage.localRead, () async => throw error),
      throwsA(same(error)),
    );
    final json = diagnostics.exportJson();
    expect(json, contains('failure'));
    expect(json, isNot(contains('secret-token')));
    expect(json, isNot(contains('12.34')));
    expect(json, isNot(contains('private')));
  });

  test(
    'tracks success and timeout while preserving result and error',
    () async {
      final diagnostics = RuntimeDiagnostics();
      expect(await diagnostics.track(RuntimeStage.decode, () async => 42), 42);
      await expectLater(
        diagnostics.track(
          RuntimeStage.localRead,
          () async => throw TimeoutException('timeout'),
        ),
        throwsA(isA<TimeoutException>()),
      );
      final events =
          (jsonDecode(diagnostics.exportJson()) as Map)['events'] as List;
      expect(events.map((event) => event['outcome']), ['success', 'timeout']);
      expect(events.every((event) => (event['elapsedUs'] as int) >= 0), isTrue);
    },
  );

  test('exports only aggregate diagnostic fields for every stage', () {
    final diagnostics = RuntimeDiagnostics();
    for (final stage in RuntimeStage.values) {
      diagnostics.record(stage, count: 7, revision: 3, activeMaps: 1);
    }

    final exported = diagnostics.exportJson();
    final decoded = jsonDecode(exported) as Map<String, Object?>;
    final events = decoded['events']! as List;
    const allowedKeys = {
      'time',
      'stage',
      'outcome',
      'elapsedUs',
      'count',
      'revision',
      'activeMaps',
    };

    expect(decoded['version'], 1);
    expect(events, hasLength(RuntimeStage.values.length));
    expect(
      events.map((event) => (event as Map)['stage']),
      RuntimeStage.values.map((stage) => stage.name),
    );
    for (final event in events.cast<Map>()) {
      expect(event.keys.toSet().difference(allowedKeys), isEmpty);
    }
    expect(exported, isNot(contains('latitude')));
    expect(exported, isNot(contains('longitude')));
    expect(exported, isNot(contains('payload')));
    expect(exported, isNot(contains('credential')));
    expect(exported, isNot(contains('token')));
  });
}
