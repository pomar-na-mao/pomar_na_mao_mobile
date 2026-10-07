import 'package:flutter_test/flutter_test.dart';
import 'package:pomar_na_mao_mobile/features/farm/domain/user_location.dart';
import 'package:pomar_na_mao_mobile/features/operations/domain/spraying_signal_stabilizer.dart';

void main() {
  final now = DateTime.utc(2026, 10, 4, 12);

  UserLocation sample(
    int seconds, {
    double latitude = -21.177,
    double accuracy = 5,
  }) => UserLocation(
    latitude: latitude,
    longitude: -47.81,
    accuracy: accuracy,
    timestamp: now.add(Duration(seconds: seconds)),
  );

  test('requires three recent consistent samples over two seconds', () {
    final stabilizer = SprayingSignalStabilizer();
    expect(stabilizer.add(sample(0), now: now), isNull);
    expect(
      stabilizer.add(sample(1), now: now.add(const Duration(seconds: 1))),
      isNull,
    );
    expect(
      stabilizer.add(sample(2), now: now.add(const Duration(seconds: 2))),
      isNotNull,
    );
  });

  test('restarts after a large jump or inaccurate sample', () {
    final stabilizer = SprayingSignalStabilizer();
    stabilizer.add(sample(0), now: now);
    stabilizer.add(sample(1), now: now.add(const Duration(seconds: 1)));
    expect(
      stabilizer.add(
        sample(2, latitude: -21.176),
        now: now.add(const Duration(seconds: 2)),
      ),
      isNull,
    );
    expect(
      stabilizer.add(
        sample(3, latitude: -21.176, accuracy: 20),
        now: now.add(const Duration(seconds: 3)),
      ),
      isNull,
    );
    expect(
      stabilizer.add(
        sample(4, latitude: -21.176),
        now: now.add(const Duration(seconds: 4)),
      ),
      isNull,
    );
  });
}
