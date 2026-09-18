import 'package:flutter_test/flutter_test.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:pomar_na_mao_mobile/features/farm/domain/farm_point.dart';
import 'package:pomar_na_mao_mobile/features/farm/domain/region_point.dart';
import 'package:pomar_na_mao_mobile/features/farm/presentation/farm_map_geometry.dart';

void main() {
  const farmPoints = [
    FarmPoint(id: '1', latitude: -22.10, longitude: -48.90, boundaryOrder: 1),
    FarmPoint(id: '2', latitude: -22.20, longitude: -48.95, boundaryOrder: 2),
    FarmPoint(id: '3', latitude: -22.15, longitude: -48.80, boundaryOrder: 3),
  ];
  const zonePoints = [
    RegionPoint(latitude: -22.12, longitude: -48.88, zoneId: 'zone-a'),
    RegionPoint(latitude: -22.16, longitude: -48.90, zoneId: 'zone-a'),
    RegionPoint(latitude: -22.14, longitude: -48.84, zoneId: 'zone-a'),
  ];

  test('builds farm and zone polygons with the established style', () {
    final polygons = buildFarmPolygons(
      farmPoints: farmPoints,
      zonePoints: zonePoints,
      zoneId: 'zone-a',
    );

    expect(polygons, hasLength(2));
    final farm = polygons.singleWhere(
      (polygon) => polygon.polygonId == const PolygonId('farm_boundary'),
    );
    final zone = polygons.singleWhere(
      (polygon) => polygon.polygonId == const PolygonId('zone_zone-a'),
    );
    expect(farm.strokeColor, farmBoundaryStrokeColor);
    expect(farm.fillColor, farmBoundaryFillColor);
    expect(farm.strokeWidth, 3);
    expect(farm.geodesic, isTrue);
    expect(farm.zIndex, 0);
    expect(zone.strokeColor, zoneBoundaryStrokeColor);
    expect(zone.fillColor, zoneBoundaryFillColor);
    expect(zone.strokeWidth, 3);
    expect(zone.geodesic, isTrue);
    expect(zone.zIndex, 1);
  });

  test('omits polygons with fewer than three points', () {
    final polygons = buildFarmPolygons(
      farmPoints: farmPoints.take(2).toList(),
      zonePoints: zonePoints.take(2).toList(),
      zoneId: 'zone-a',
    );

    expect(polygons, isEmpty);
  });

  test('builds a polygon for every zone with enough points', () {
    final polygons = buildFarmPolygons(
      farmPoints: const [],
      zonePointsById: {
        'zone-a': zonePoints,
        'zone-b': zonePoints
            .map(
              (point) => RegionPoint(
                latitude: point.latitude + 0.01,
                longitude: point.longitude + 0.01,
                zoneId: 'zone-b',
              ),
            )
            .toList(),
      },
    );

    expect(polygons, hasLength(2));
    expect(
      polygons.map((polygon) => polygon.polygonId.value),
      containsAll(['zone_zone-a', 'zone_zone-b']),
    );
  });

  test('builds closed dotted boundaries for all valid zones', () {
    final boundaries = buildDottedZoneBoundaries({
      'zone-a': zonePoints,
      'zone-invalid': zonePoints.take(2).toList(),
    });

    expect(boundaries, hasLength(1));
    final boundary = boundaries.single;
    expect(boundary.polylineId, const PolylineId('zone_dotted_zone-a'));
    expect(boundary.points.first, boundary.points.last);
    expect(boundary.points, hasLength(zonePoints.length + 1));
    expect(boundary.color, zoneBoundaryStrokeColor);
    expect(boundary.patterns.first.toJson(), ['dot']);
    expect(boundary.patterns.last.toJson(), ['gap', 8.0]);
  });

  test('calculates bounds and center for multiple coordinates', () {
    final viewport = calculateMapCameraViewport(const [
      LatLng(-22.20, -48.95),
      LatLng(-22.10, -48.80),
    ]);

    expect(viewport.bounds, isNotNull);
    expect(viewport.bounds!.southwest.latitude, -22.20);
    expect(viewport.bounds!.southwest.longitude, -48.95);
    expect(viewport.bounds!.northeast.latitude, -22.10);
    expect(viewport.bounds!.northeast.longitude, -48.80);
    expect(viewport.target.latitude, closeTo(-22.15, 0.000001));
    expect(viewport.target.longitude, closeTo(-48.875, 0.000001));
  });

  test('uses the coordinate directly when only one is available', () {
    const point = LatLng(-22.12, -48.91);
    final viewport = calculateMapCameraViewport(const [point]);

    expect(viewport.bounds, isNull);
    expect(viewport.target, point);
  });

  test('uses the supplied fallback when there are no coordinates', () {
    const fallback = LatLng(-20, -47);
    final viewport = calculateMapCameraViewport(const [], fallback: fallback);

    expect(viewport.bounds, isNull);
    expect(viewport.target, fallback);
  });
}
