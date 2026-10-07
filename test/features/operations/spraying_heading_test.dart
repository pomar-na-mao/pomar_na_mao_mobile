import 'package:flutter_test/flutter_test.dart';
import 'package:pomar_na_mao_mobile/features/farm/domain/user_location.dart';
import 'package:pomar_na_mao_mobile/features/operations/presentation/spraying_heading.dart';

void main() {
  test('uses GPS course while moving and holds it when stopped', () {
    final tracker = SprayingCourseTracker();
    const moving = UserLocation(
      latitude: -21,
      longitude: -47,
      heading: 90,
      speed: 2,
    );
    const still = UserLocation(latitude: -21, longitude: -47, speed: 0);

    tracker.add(moving);
    expect(tracker.course, 90);
    tracker.add(still);
    expect(tracker.course, 90);
  });

  test('uses displacement for slow movement without a GPS course', () {
    final tracker = SprayingCourseTracker();
    tracker.add(
      const UserLocation(
        latitude: -21,
        longitude: -47,
        accuracy: 3,
        speed: 0.5,
      ),
    );
    tracker.add(
      const UserLocation(
        latitude: -21,
        longitude: -46.99995,
        accuracy: 3,
        speed: 0.5,
      ),
    );
    expect(tracker.course, closeTo(90, 1));
  });

  test('does not rotate from stationary GPS drift', () {
    final tracker = SprayingCourseTracker();
    tracker.add(const UserLocation(latitude: -21, longitude: -47, speed: 0));
    tracker.add(
      const UserLocation(latitude: -21, longitude: -46.99995, speed: 0),
    );
    expect(tracker.course, isNull);
  });

  test('turns by the shortest path with a limited step', () {
    expect(nextSprayingMapBearing(350, 10), 10);
    expect(nextSprayingMapBearing(10, 350), 350);
    expect(nextSprayingMapBearing(0, 90), 60);
    expect(nextSprayingMapBearing(90, 92), isNull);
    expect(nextSprayingMapBearing(90, null), isNull);
  });
}
