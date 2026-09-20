import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

import '../domain/farm_point.dart';
import '../domain/region_point.dart';

const defaultFarmMapPosition = LatLng(-21.2349, -47.790694);
const farmBoundaryStrokeColor = Color(0xFF1565C0);
const farmBoundaryFillColor = Color(0x1A1976D2);
const zoneBoundaryStrokeColor = Color(0xFF1B5E20);
const zoneBoundaryFillColor = Color(0x334CAF50);

Set<Polygon> buildFarmPolygons({
  required List<FarmPoint> farmPoints,
  List<RegionPoint> zonePoints = const [],
  String? zoneId,
  Map<String, List<RegionPoint>> zonePointsById = const {},
  bool showZoneStroke = true,
}) {
  final polygons = <Polygon>{};

  if (farmPoints.length >= 3) {
    polygons.add(
      Polygon(
        polygonId: const PolygonId('farm_boundary'),
        points: farmPoints
            .map((point) => LatLng(point.latitude, point.longitude))
            .toList(growable: false),
        strokeColor: farmBoundaryStrokeColor,
        strokeWidth: 3,
        fillColor: farmBoundaryFillColor,
        geodesic: true,
        zIndex: 0,
      ),
    );
  }

  final allZonePoints = <String, List<RegionPoint>>{
    ...zonePointsById,
    ?zoneId: zonePoints,
  };
  for (final MapEntry(key: id, value: points) in allZonePoints.entries) {
    if (points.length < 3) continue;
    polygons.add(
      Polygon(
        polygonId: PolygonId('zone_$id'),
        points: points
            .map((point) => LatLng(point.latitude, point.longitude))
            .toList(growable: false),
        strokeColor: showZoneStroke
            ? zoneBoundaryStrokeColor
            : Colors.transparent,
        strokeWidth: showZoneStroke ? 3 : 0,
        fillColor: zoneBoundaryFillColor,
        geodesic: true,
        zIndex: 1,
      ),
    );
  }

  return polygons;
}

Set<Polyline> buildDottedZoneBoundaries(
  Map<String, List<RegionPoint>> zonePointsById,
) {
  final boundaries = <Polyline>{};
  for (final MapEntry(key: id, value: points) in zonePointsById.entries) {
    if (points.length < 3) continue;
    final coordinates = points
        .map((point) => LatLng(point.latitude, point.longitude))
        .toList(growable: true);
    coordinates.add(coordinates.first);
    boundaries.add(
      Polyline(
        polylineId: PolylineId('zone_dotted_$id'),
        points: coordinates,
        color: zoneBoundaryStrokeColor,
        width: 3,
        patterns: [PatternItem.dot, PatternItem.gap(8)],
        geodesic: true,
        zIndex: 2,
      ),
    );
  }
  return boundaries;
}

class MapCameraViewport {
  const MapCameraViewport({required this.target, this.bounds});

  final LatLng target;
  final LatLngBounds? bounds;
}

MapCameraViewport calculateMapCameraViewport(
  Iterable<LatLng> coordinates, {
  LatLng fallback = defaultFarmMapPosition,
}) {
  final points = coordinates.toList(growable: false);
  if (points.isEmpty) return MapCameraViewport(target: fallback);

  var minLatitude = points.first.latitude;
  var maxLatitude = minLatitude;
  var minLongitude = points.first.longitude;
  var maxLongitude = minLongitude;

  for (final coordinate in points.skip(1)) {
    minLatitude = math.min(minLatitude, coordinate.latitude);
    maxLatitude = math.max(maxLatitude, coordinate.latitude);
    minLongitude = math.min(minLongitude, coordinate.longitude);
    maxLongitude = math.max(maxLongitude, coordinate.longitude);
  }

  final target = LatLng(
    (minLatitude + maxLatitude) / 2,
    (minLongitude + maxLongitude) / 2,
  );
  final hasArea = minLatitude != maxLatitude || minLongitude != maxLongitude;

  return MapCameraViewport(
    target: target,
    bounds: hasArea
        ? LatLngBounds(
            southwest: LatLng(minLatitude, minLongitude),
            northeast: LatLng(maxLatitude, maxLongitude),
          )
        : null,
  );
}
