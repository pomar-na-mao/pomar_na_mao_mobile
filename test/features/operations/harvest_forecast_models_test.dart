import 'package:flutter_test/flutter_test.dart';
import 'package:pomar_na_mao_mobile/features/operations/domain/harvest_forecast_models.dart';

void main() {
  group('HarvestForecastClassification', () {
    test('parse resolves N, P, M, G and GG case-insensitively', () {
      expect(
        HarvestForecastClassification.parse('N'),
        HarvestForecastClassification.n,
      );
      expect(
        HarvestForecastClassification.parse('p'),
        HarvestForecastClassification.p,
      );
      expect(
        HarvestForecastClassification.parse('M'),
        HarvestForecastClassification.m,
      );
      expect(
        HarvestForecastClassification.parse('G'),
        HarvestForecastClassification.g,
      );
      expect(
        HarvestForecastClassification.parse('gg'),
        HarvestForecastClassification.gg,
      );
    });

    test('parse throws FormatException on invalid code', () {
      expect(
        () => HarvestForecastClassification.parse('X'),
        throwsFormatException,
      );
    });
  });

  group('HarvestForecastMarking', () {
    test('serializes toRow/fromRow and toPayload preserving fields', () {
      final createdAt = DateTime.utc(2026, 11, 19, 12, 30, 0);
      final syncedAt = DateTime.utc(2026, 11, 19, 12, 35, 0);
      final marking = HarvestForecastMarking(
        localId: 'local-1',
        latitude: -23.123456,
        longitude: -46.654321,
        classification: HarvestForecastClassification.gg,
        createdAt: createdAt,
        status: HarvestForecastSyncStatus.synced,
        remoteId: 'remote-uuid-1',
        remotePlantId: 'plant-uuid-1',
        remoteZoneId: 'zone-uuid-1',
        syncedAt: syncedAt,
      );

      final row = marking.toRow();
      final restored = HarvestForecastMarking.fromRow(row);
      expect(restored.localId, 'local-1');
      expect(restored.latitude, -23.123456);
      expect(restored.longitude, -46.654321);
      expect(restored.classification, HarvestForecastClassification.gg);
      expect(restored.createdAt, createdAt);
      expect(restored.status, HarvestForecastSyncStatus.synced);
      expect(restored.remoteId, 'remote-uuid-1');
      expect(restored.remotePlantId, 'plant-uuid-1');
      expect(restored.remoteZoneId, 'zone-uuid-1');
      expect(restored.syncedAt, syncedAt);

      final payload = marking.toPayload();
      expect(payload, {
        'localMarkingId': 'local-1',
        'latitude': -23.123456,
        'longitude': -46.654321,
        'classification': 'GG',
        'createdAt': '2026-11-19T12:30:00.000Z',
      });
    });

    test('validates latitude, longitude and localId', () {
      expect(
        () => HarvestForecastMarking(
          localId: '',
          latitude: -23.0,
          longitude: -46.0,
          classification: HarvestForecastClassification.n,
          createdAt: DateTime.utc(2026, 11, 19),
        ),
        throwsArgumentError,
      );
      expect(
        () => HarvestForecastMarking(
          localId: 'id-1',
          latitude: -95.0,
          longitude: -46.0,
          classification: HarvestForecastClassification.n,
          createdAt: DateTime.utc(2026, 11, 19),
        ),
        throwsArgumentError,
      );
      expect(
        () => HarvestForecastMarking(
          localId: 'id-1',
          latitude: -23.0,
          longitude: 190.0,
          classification: HarvestForecastClassification.n,
          createdAt: DateTime.utc(2026, 11, 19),
        ),
        throwsArgumentError,
      );
    });
  });

  group('HarvestForecastSyncResult', () {
    test('listFromRpc parses both list and map response formats', () {
      final listResponse = [
        {
          'localMarkingId': 'local-1',
          'id': 'hf-1',
          'plantId': 'plant-1',
          'zoneId': 'zone-1',
          'syncedAt': '2026-11-19T12:40:00.000Z',
        },
      ];
      final resultsFromList = HarvestForecastSyncResult.listFromRpc(
        listResponse,
      );
      expect(resultsFromList, hasLength(1));
      expect(resultsFromList.single.localMarkingId, 'local-1');
      expect(resultsFromList.single.id, 'hf-1');
      expect(resultsFromList.single.plantId, 'plant-1');
      expect(resultsFromList.single.zoneId, 'zone-1');
      expect(
        resultsFromList.single.syncedAt,
        DateTime.utc(2026, 11, 19, 12, 40),
      );

      final mapResponse = {'markings': listResponse};
      expect(
        HarvestForecastSyncResult.listFromRpc(mapResponse),
        hasLength(1),
      );
    });
  });
}
