import 'package:flutter_test/flutter_test.dart';
import 'package:pomar_na_mao_mobile/features/farm/domain/user_location.dart';
import 'package:pomar_na_mao_mobile/features/farm/domain/user_position_tracker.dart';

void main() {
  final start = DateTime.utc(2026, 10, 4, 12);

  UserLocation fix(double latitude, int seconds, {double accuracy = 3}) =>
      UserLocation(
        latitude: latitude,
        longitude: -47.81,
        accuracy: accuracy,
        timestamp: start.add(Duration(seconds: seconds)),
      );

  test('holds the first position until three consistent fixes arrive', () {
    final tracker = UserPositionTracker();
    expect(tracker.add(fix(-21.177, 0), now: start), isNull);
    expect(
      tracker.add(
        fix(-21.177001, 1),
        now: start.add(const Duration(seconds: 1)),
      ),
      isNull,
    );
    final stable = tracker.add(
      fix(-21.177002, 2),
      now: start.add(const Duration(seconds: 2)),
    );
    expect(stable?.latitude, -21.177002);
  });

  test('rejects inaccurate start and isolated location jumps', () {
    final tracker = UserPositionTracker();
    expect(tracker.add(fix(-21.177, 0, accuracy: 25), now: start), isNull);
    for (var second = 1; second <= 3; second++) {
      tracker.add(
        fix(-21.177, second),
        now: start.add(Duration(seconds: second)),
      );
    }
    expect(
      tracker.add(fix(-21.1765, 4), now: start.add(const Duration(seconds: 4))),
      isNull,
    );
    expect(
      tracker.add(fix(-21.177, 5), now: start.add(const Duration(seconds: 5))),
      isNull,
    );
  });

  test('reset requires stabilization again', () {
    final tracker = UserPositionTracker();
    for (var second = 0; second <= 2; second++) {
      tracker.add(
        fix(-21.177, second),
        now: start.add(Duration(seconds: second)),
      );
    }
    tracker.reset();
    expect(
      tracker.add(fix(-21.177, 3), now: start.add(const Duration(seconds: 3))),
      isNull,
    );
  });
}
