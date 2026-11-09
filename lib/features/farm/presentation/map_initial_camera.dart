import 'package:google_maps_flutter/google_maps_flutter.dart';

import '../domain/map_initial_position.dart';

const userInitialMapZoom = 19.0;
const farmInitialMapZoom = 17.0;

CameraPosition mapInitialCamera(MapInitialPosition position) => CameraPosition(
  target: LatLng(position.latitude, position.longitude),
  zoom: position.source == MapInitialPositionSource.user
      ? userInitialMapZoom
      : farmInitialMapZoom,
);
