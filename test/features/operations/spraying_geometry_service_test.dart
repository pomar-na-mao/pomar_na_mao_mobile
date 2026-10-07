import 'package:flutter_test/flutter_test.dart';
import 'package:pomar_na_mao_mobile/features/operations/domain/inspection_models.dart';
import 'package:pomar_na_mao_mobile/features/operations/domain/spraying_geometry_service.dart';
import 'package:pomar_na_mao_mobile/features/operations/domain/spraying_models.dart';

void main() {
  const service = SprayingGeometryService();

  group('SprayingGeometryService', () {
    test('calculateTotalDistanceMeters returns zero for less than two points', () {
      expect(service.calculateTotalDistanceMeters([]), 0.0);
      expect(
        service.calculateTotalDistanceMeters([
          SprayingTrackPoint(
            localId: '1',
            recordedAt: DateTime.now(),
            latitude: -23.0,
            longitude: -47.0,
          ),
        ]),
        0.0,
      );
    });

    test('calculateTotalDistanceMeters calculates distance between two points', () {
      final points = [
        SprayingTrackPoint(
          localId: '1',
          recordedAt: DateTime.now(),
          latitude: -23.000000,
          longitude: -47.000000,
        ),
        SprayingTrackPoint(
          localId: '2',
          recordedAt: DateTime.now(),
          latitude: -23.001000,
          longitude: -47.000000,
        ),
      ];

      final dist = service.calculateTotalDistanceMeters(points);
      // ~111 meters for 0.001 deg latitude
      expect(dist, greaterThan(110.0));
      expect(dist, lessThan(112.0));
    });

    test('calculateAffectedPlants identifies plants within 9m and ignores distant plants', () {
      // Route going along longitude -47.000000 from lat -23.000000 to -23.001000
      final points = [
        SprayingTrackPoint(
          localId: 'p1',
          recordedAt: DateTime.parse('2026-10-02T10:00:00Z'),
          latitude: -23.000000,
          longitude: -47.000000,
        ),
        SprayingTrackPoint(
          localId: 'p2',
          recordedAt: DateTime.parse('2026-10-02T10:01:00Z'),
          latitude: -23.001000,
          longitude: -47.000000,
        ),
      ];

      // Plant 1: 5 meters away (0.000045 deg lat ~ 5m)
      final closePlant = InspectionPlant(
        id: 'close-1',
        latitude: -23.000500,
        longitude: -47.000045, // ~4.6 meters in longitude
      );

      // Plant 2: 50 meters away
      final farPlant = InspectionPlant(
        id: 'far-1',
        latitude: -23.000500,
        longitude: -47.000500, // ~51 meters in longitude
      );

      // Plant 3: Non-existent plant (should be excluded)
      final nonExistentPlant = InspectionPlant(
        id: 'non-existent',
        latitude: -23.000500,
        longitude: -47.000010,
        nonExistent: true,
      );

      final affected = service.calculateAffectedPlants(
        candidatePlants: [closePlant, farPlant, nonExistentPlant],
        trackPoints: points,
        maxDistanceMeters: 9.0,
      );

      expect(affected.length, 1);
      expect(affected.first.plantId, 'close-1');
      expect(affected.first.matchSource, SprayingMatchSource.autoMatched);
      expect(affected.first.distanceMeters, lessThanOrEqualTo(9.0));
    });

    test('buildLineStringGeoJson builds valid GeoJSON coordinates', () {
      final points = [
        SprayingTrackPoint(
          localId: 'p1',
          recordedAt: DateTime.now(),
          latitude: -23.0,
          longitude: -47.0,
        ),
        SprayingTrackPoint(
          localId: 'p2',
          recordedAt: DateTime.now(),
          latitude: -23.1,
          longitude: -47.1,
        ),
      ];

      final geojson = service.buildLineStringGeoJson(points);
      expect(geojson['type'], 'LineString');
      expect(geojson['coordinates'], [
        [-47.0, -23.0],
        [-47.1, -23.1],
      ]);
    });
  });
}
