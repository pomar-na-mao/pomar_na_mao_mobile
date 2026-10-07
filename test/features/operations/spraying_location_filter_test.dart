import 'package:flutter_test/flutter_test.dart';
import 'package:pomar_na_mao_mobile/features/farm/domain/user_location.dart';
import 'package:pomar_na_mao_mobile/features/operations/domain/spraying_location_filter.dart';

void main() {
  final start = DateTime.utc(2026, 10, 3, 12);

  UserLocation sample(double latitude, int second, {double accuracy = 3}) =>
      UserLocation(
        latitude: latitude,
        longitude: -47.81,
        accuracy: accuracy,
        timestamp: start.add(Duration(seconds: second)),
      );

  test('shows first accurate fix without a warm-up window', () {
    final filter = SprayingLocationFilter();
    final fix = sample(-21.177, 0);

    expect(filter.add(fix, now: start)?.latitude, fix.latitude);
    expect(filter.current?.latitude, -21.177);
  });

  test('rejects stale, out-of-order and inaccurate fixes', () {
    final filter = SprayingLocationFilter();
    expect(filter.add(sample(-21.177, 0), now: start), isNotNull);
    expect(
      filter.add(
        sample(-21.178, 1, accuracy: 30),
        now: start.add(const Duration(seconds: 1)),
      ),
      isNull,
    );
    expect(
      filter.add(
        sample(-21.178, 2),
        now: start.add(const Duration(seconds: 10)),
      ),
      isNull,
    );
    expect(filter.add(sample(-21.178, 0), now: start), isNull);
    expect(filter.current?.latitude, -21.177);
  });

  test('ignores a single excursion and stationary noise', () {
    final filter = SprayingLocationFilter();
    final latitudes = [-21.177, -21.17695, -21.177, -21.17701, -21.177];
    for (var i = 0; i < latitudes.length; i++) {
      filter.add(sample(latitudes[i], i), now: start.add(Duration(seconds: i)));
    }
    expect(filter.current?.latitude, -21.177);
  });

  test('follows sustained movement without accepting a teleport', () {
    final filter = SprayingLocationFilter();
    expect(filter.add(sample(-21.177, 0), now: start), isNotNull);
    expect(
      filter.add(
        sample(-21.1765, 1),
        now: start.add(const Duration(seconds: 1)),
      ),
      isNull,
    );
    expect(
      filter.add(
        sample(-21.177, 2),
        now: start.add(const Duration(seconds: 2)),
      ),
      isNull,
    );
    expect(filter.current?.latitude, -21.177);
    expect(
      filter.add(
        sample(-21.177, 3),
        now: start.add(const Duration(seconds: 3)),
      ),
      isNull,
    );
    final moved = filter.add(
      sample(-21.17694, 4),
      now: start.add(const Duration(seconds: 4)),
    );
    expect(moved, isNull);
    final confirmed = filter.add(
      sample(-21.17689, 5),
      now: start.add(const Duration(seconds: 5)),
    );
    expect(confirmed?.latitude, -21.17694);
  });
}
