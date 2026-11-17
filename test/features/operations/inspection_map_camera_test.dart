import 'package:flutter_test/flutter_test.dart';
import 'package:pomar_na_mao_mobile/features/operations/presentation/inspection_map_camera.dart';

void main() {
  test('starts following, suspends for a gesture, and resumes explicitly', () {
    final state = InspectionCameraFollowState();

    expect(state.isFollowing, isTrue);

    state.pointerDown();
    expect(state.cameraMoveStarted(), isTrue);
    expect(state.isFollowing, isFalse);

    state.pointerUp();
    expect(state.resume(), isTrue);
    expect(state.isFollowing, isTrue);
  });

  test('does not suspend for programmatic movement or a simple tap', () {
    final state = InspectionCameraFollowState();

    expect(state.cameraMoveStarted(), isFalse);
    state.pointerDown();
    state.pointerUp();
    expect(state.cameraMoveStarted(), isFalse);
    expect(state.isFollowing, isTrue);
  });

  test('a new gesture suspends following again after recentering', () {
    final state = InspectionCameraFollowState();

    expect(state.suspend(), isTrue);
    expect(state.resume(), isTrue);
    state.pointerDown();
    expect(state.cameraMoveStarted(), isTrue);
    expect(state.isFollowing, isFalse);
  });

  test('uses a neutral centered marker without a reliable course', () {
    final marker = inspectionUserMarkerForCourse(null);

    expect(marker.kind, InspectionUserMarkerKind.neutral);
    expect(marker.rotation, 0);
    expect(marker.flat, isFalse);
    expect(marker.anchor, const Offset(0.5, 0.5));
  });

  test('maps cardinal courses to a flat directional marker', () {
    for (final course in [0.0, 90.0, 180.0, 270.0]) {
      final marker = inspectionUserMarkerForCourse(course);

      expect(marker.kind, InspectionUserMarkerKind.directional);
      expect(marker.rotation, course);
      expect(marker.flat, isTrue);
      expect(marker.anchor, const Offset(0.5, 0.5));
    }
  });

  test('rejects invalid directional courses', () {
    expect(
      inspectionUserMarkerForCourse(360).kind,
      InspectionUserMarkerKind.neutral,
    );
    expect(
      inspectionUserMarkerForCourse(double.nan).kind,
      InspectionUserMarkerKind.neutral,
    );
  });
}
