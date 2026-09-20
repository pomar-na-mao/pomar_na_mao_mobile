import 'package:flutter_test/flutter_test.dart';
import 'package:pomar_na_mao_mobile/features/operations/domain/inspection_models.dart';

void main() {
  group('OccurrenceType', () {
    test('serializes and deserializes correctly', () {
      const type = OccurrenceType(id: 'type-1', name: 'Praga', code: 'pest');
      final json = type.toJson();
      expect(json, {'id': 'type-1', 'name': 'Praga', 'code': 'pest'});

      final fromJson = OccurrenceType.fromJson(json);
      expect(fromJson.id, 'type-1');
      expect(fromJson.name, 'Praga');
      expect(fromJson.code, 'pest');
    });
  });

  group('InspectionPlant', () {
    test('coordinate validation', () {
      final valid = InspectionPlant(id: 'p-1', latitude: -23.5, longitude: -46.6);
      expect(valid.hasValidCoordinates, isTrue);

      final noLat = InspectionPlant(id: 'p-2', latitude: null, longitude: -46.6);
      expect(noLat.hasValidCoordinates, isFalse);

      final invalidLat = InspectionPlant(id: 'p-3', latitude: 95.0, longitude: -46.6);
      expect(invalidLat.hasValidCoordinates, isFalse);

      final invalidLng = InspectionPlant(id: 'p-4', latitude: -23.5, longitude: 185.0);
      expect(invalidLng.hasValidCoordinates, isFalse);
    });

    test('label generation', () {
      final withDesc = InspectionPlant(id: 'uuid-12345678', description: 'Árvore 42');
      expect(withDesc.label, 'Árvore 42');

      final withoutDesc = InspectionPlant(id: '12345678-abcd');
      expect(withoutDesc.label, 'Planta 12345678');
    });

    test('withState updates types and eligibility', () {
      final plant = InspectionPlant(id: 'p-1', openTypeIds: {'t1'});
      final updated = plant.withState({'t1', 't2'}, eligible: false);
      expect(updated.openTypeIds, {'t1', 't2'});
      expect(updated.eligible, isFalse);
    });

    test('serializes and deserializes', () {
      final plant = InspectionPlant(
        id: 'p-1',
        latitude: -23.5,
        longitude: -46.6,
        description: 'Planta A',
        zoneId: 'z-1',
        openTypeIds: {'t1', 't2'},
        eligible: true,
      );
      final json = plant.toJson();
      final fromJson = InspectionPlant.fromJson(json);
      expect(fromJson.id, plant.id);
      expect(fromJson.latitude, plant.latitude);
      expect(fromJson.longitude, plant.longitude);
      expect(fromJson.description, plant.description);
      expect(fromJson.zoneId, plant.zoneId);
      expect(fromJson.openTypeIds, plant.openTypeIds);
      expect(fromJson.eligible, plant.eligible);
    });
  });

  group('InspectionSnapshot', () {
    test('enforces UTC loadedAt and unmodifiable collections', () {
      final now = DateTime.now();
      final snapshot = InspectionSnapshot(
        plants: [InspectionPlant(id: 'p-1')],
        types: [const OccurrenceType(id: 't-1', name: 'Seca', code: 'drought')],
        loadedAt: now,
      );
      expect(snapshot.loadedAt.isUtc, isTrue);
      expect(() => snapshot.plants.add(InspectionPlant(id: 'p-2')), throwsUnsupportedError);
      expect(() => snapshot.types.add(const OccurrenceType(id: 't-2', name: 'N', code: 'c')), throwsUnsupportedError);
    });
  });

  group('InspectionChange', () {
    test('payload generation with exact contract keys and UTC', () {
      final change = InspectionChange(
        id: 'c-1',
        plantId: 'p-1',
        typeId: 't-1',
        added: true,
        sequence: 1,
        changedAt: DateTime.parse('2026-09-18T20:00:00Z'),
        latitude: -23.5,
        longitude: -46.6,
        accuracy: 5.0,
        distance: 2.5,
      );
      final payload = change.toPayload();
      expect(payload['localChangeId'], 'c-1');
      expect(payload['occurrenceTypeId'], 't-1');
      expect(payload['changeType'], 'add_occurrence');
      expect(payload['changedAt'], '2026-09-18T20:00:00.000Z');
      expect(payload['latitude'], -23.5);
      expect(payload['longitude'], -46.6);
      expect(payload['gpsAccuracyM'], 5.0);
      expect(payload['distanceToPlantMeters'], 2.5);

      final removal = InspectionChange(
        id: 'c-2',
        plantId: 'p-1',
        typeId: 't-1',
        added: false,
        sequence: 2,
        changedAt: DateTime.utc(2026, 9, 18, 20, 1),
      );
      final removalPayload = removal.toPayload();
      expect(removalPayload['changeType'], 'remove_occurrence');
      expect(removalPayload.containsKey('latitude'), isFalse);
      expect(removalPayload.containsKey('gpsAccuracyM'), isFalse);
    });
  });

  group('LocalInspection', () {
    test('status label and draft status', () {
      final draft = LocalInspection(
        id: 'i-1',
        startedAt: DateTime.now(),
        status: InspectionSyncStatus.pending,
        plantsCount: 2,
        changesCount: 3,
      );
      expect(draft.isDraft, isTrue);
      expect(draft.statusLabel, 'Em andamento');

      final finishedPending = LocalInspection(
        id: 'i-2',
        startedAt: DateTime.now(),
        finishedAt: DateTime.now(),
        status: InspectionSyncStatus.pending,
        plantsCount: 2,
        changesCount: 3,
        payloadJson: '{}',
      );
      expect(finishedPending.isDraft, isFalse);
      expect(finishedPending.statusLabel, 'Pendente');
      expect(finishedPending.payload, isEmpty);

      final finishedSyncing = LocalInspection(
        id: 'i-3',
        startedAt: DateTime.now(),
        finishedAt: DateTime.now(),
        status: InspectionSyncStatus.syncing,
        plantsCount: 1,
        changesCount: 1,
      );
      expect(finishedSyncing.statusLabel, 'Enviando');

      final finishedError = LocalInspection(
        id: 'i-4',
        startedAt: DateTime.now(),
        finishedAt: DateTime.now(),
        status: InspectionSyncStatus.error,
        plantsCount: 1,
        changesCount: 1,
      );
      expect(finishedError.statusLabel, 'Erro no envio');

      final synced = LocalInspection(
        id: 'i-5',
        startedAt: DateTime.now(),
        finishedAt: DateTime.now(),
        status: InspectionSyncStatus.synced,
        plantsCount: 1,
        changesCount: 1,
      );
      expect(synced.statusLabel, 'Sincronizada');
    });
  });

  group('InspectionSyncResult', () {
    test('parses canonical response correctly', () {
      final response = [
        {
          'field_operation_id': 'op-uuid-123',
          'created_occurrences_count': 1,
          'updated_occurrences_count': 2,
          'resolved_occurrences_count': 3,
        }
      ];
      final result = InspectionSyncResult.fromRpc(response);
      expect(result.operationId, 'op-uuid-123');
      expect(result.created, 1);
      expect(result.updated, 2);
      expect(result.resolved, 3);
    });

    test('throws on invalid format or counts', () {
      expect(() => InspectionSyncResult.fromRpc([]), throwsA(isA<FormatException>()));
      expect(() => InspectionSyncResult.fromRpc({}), throwsA(isA<FormatException>()));
      expect(
        () => InspectionSyncResult.fromRpc([
          {
            'field_operation_id': '',
            'created_occurrences_count': 0,
            'updated_occurrences_count': 0,
            'resolved_occurrences_count': 0,
          }
        ]),
        throwsA(isA<FormatException>()),
      );
      expect(
        () => InspectionSyncResult.fromRpc([
          {
            'field_operation_id': 'op-1',
            'created_occurrences_count': -1,
            'updated_occurrences_count': 0,
            'resolved_occurrences_count': 0,
          }
        ]),
        throwsA(isA<FormatException>()),
      );
    });
  });
}
