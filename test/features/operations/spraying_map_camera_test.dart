import 'package:flutter_test/flutter_test.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:pomar_na_mao_mobile/features/operations/presentation/spraying_map_camera.dart';

void main() {
  test('keeps the camera still while the user is well inside the view', () {
    final bounds = LatLngBounds(
      southwest: const LatLng(-21.18, -47.82),
      northeast: const LatLng(-21.17, -47.80),
    );

    expect(
      isInsideSprayingFocusArea(bounds, const LatLng(-21.175, -47.81)),
      isTrue,
    );
    expect(
      isInsideSprayingFocusArea(bounds, const LatLng(-21.1705, -47.81)),
      isFalse,
    );
    expect(
      isInsideSprayingFocusArea(bounds, const LatLng(-21.175, -47.801)),
      isFalse,
    );
  });

  test('handles a viewport that crosses the date line', () {
    final bounds = LatLngBounds(
      southwest: const LatLng(-1, 179),
      northeast: const LatLng(1, -179),
    );

    expect(isInsideSprayingFocusArea(bounds, const LatLng(0, 180)), isTrue);
    expect(isInsideSprayingFocusArea(bounds, const LatLng(0, -170)), isFalse);
  });

  test('rotates around the current target without changing zoom', () {
    const current = CameraPosition(
      target: LatLng(-21.17, -47.81),
      zoom: 20.5,
      bearing: 0,
    );
    final next = sprayingFollowCameraPosition(
      current: current,
      user: const LatLng(-21.171, -47.811),
      outsideFocusArea: false,
      bearing: 60,
    );
    expect(next?.target, current.target);
    expect(next?.zoom, 20.5);
    expect(next?.bearing, 60);
  });

  test('repositions only when the user leaves the focus area', () {
    const current = CameraPosition(
      target: LatLng(-21.17, -47.81),
      zoom: 20.5,
      bearing: 90,
    );
    const user = LatLng(-21.171, -47.811);
    expect(
      sprayingFollowCameraPosition(
        current: current,
        user: user,
        outsideFocusArea: false,
      ),
      isNull,
    );
    final next = sprayingFollowCameraPosition(
      current: current,
      user: user,
      outsideFocusArea: true,
    );
    expect(next?.target, user);
    expect(next?.zoom, current.zoom);
    expect(next?.bearing, current.bearing);
  });
}
