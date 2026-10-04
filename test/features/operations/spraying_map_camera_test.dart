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
}
