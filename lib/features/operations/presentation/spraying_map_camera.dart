import 'package:google_maps_flutter/google_maps_flutter.dart';

import '../../farm/presentation/user_map_navigation.dart';

bool isInsideSprayingFocusArea(
  LatLngBounds bounds,
  LatLng position, {
  double edgeMargin = 0.12,
}) => isInsideUserFocusArea(bounds, position, edgeMargin: edgeMargin);

CameraPosition? sprayingFollowCameraPosition({
  required CameraPosition current,
  required LatLng user,
  required bool outsideFocusArea,
  double? bearing,
}) => userFollowCameraPosition(
  current: current,
  user: user,
  outsideFocusArea: outsideFocusArea,
  bearing: bearing,
);
