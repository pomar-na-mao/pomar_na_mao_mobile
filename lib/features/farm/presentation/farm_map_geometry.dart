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
  required List<RegionPoint> zonePoints,
  required String? zoneId,
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

  if (zonePoints.length >= 3 && zoneId != null) {
    polygons.add(
      Polygon(
        polygonId: PolygonId('zone_$zoneId'),
        points: zonePoints
            .map((point) => LatLng(point.latitude, point.longitude))
            .toList(growable: false),
        strokeColor: zoneBoundaryStrokeColor,
        strokeWidth: 3,
        fillColor: zoneBoundaryFillColor,
        geodesic: true,
        zIndex: 1,
      ),
    );
  }

  return polygons;
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
