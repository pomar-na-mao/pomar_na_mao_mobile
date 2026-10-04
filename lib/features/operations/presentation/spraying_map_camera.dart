import 'package:google_maps_flutter/google_maps_flutter.dart';

bool isInsideSprayingFocusArea(
  LatLngBounds bounds,
  LatLng position, {
  double edgeMargin = 0.12,
}) {
  final south = bounds.southwest.latitude;
  final north = bounds.northeast.latitude;
  final latitudeMargin = (north - south) * edgeMargin;
  if (position.latitude < south + latitudeMargin ||
      position.latitude > north - latitudeMargin) {
    return false;
  }

  final west = bounds.southwest.longitude;
  final east = bounds.northeast.longitude;
  final longitudeSpan = east >= west ? east - west : east + 360 - west;
  final longitudeOffset = (position.longitude - west + 360) % 360;
  final longitudeMargin = longitudeSpan * edgeMargin;
  return longitudeOffset >= longitudeMargin &&
      longitudeOffset <= longitudeSpan - longitudeMargin;
}
