import 'dart:async';
import 'dart:ui' as ui;

import 'package:flutter_test/flutter_test.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:pomar_na_mao_mobile/features/farm/domain/user_location.dart';
import 'package:pomar_na_mao_mobile/features/farm/presentation/user_map_navigation.dart';

void main() {
  test('renders the directional marker at its declared canvas size', () async {
    final bytes = await createDirectionalUserLocationMarkerBytes();
    final codec = await ui.instantiateImageCodec(bytes);
    final frame = await codec.getNextFrame();
    addTearDown(() {
      frame.image.dispose();
      codec.dispose();
    });

    expect(frame.image.width, directionalUserMarkerCanvasSize);
    expect(frame.image.height, directionalUserMarkerCanvasSize);
    expect(directionalUserMarkerDisplaySize, 32);
  });

  group('UserMapNavigator course', () {
    test('exposes a valid GPS course while moving', () {
      final navigator = UserMapNavigator();

      navigator.observe(
        const UserLocation(
          latitude: -21,
          longitude: -47,
          heading: 90,
          speed: 2,
        ),
      );

      expect(navigator.course, 90);
    });

    test('derives course from sufficient displacement', () {
      final navigator = UserMapNavigator();

      navigator.observe(
        const UserLocation(
          latitude: -21,
          longitude: -47,
          accuracy: 3,
          speed: 0.5,
        ),
      );
      navigator.observe(
        const UserLocation(
          latitude: -21,
          longitude: -46.99995,
          accuracy: 3,
          speed: 0.5,
        ),
      );

      expect(navigator.course, closeTo(90, 1));
    });

    test('does not expose an invalid or unavailable course', () {
      final navigator = UserMapNavigator();

      expect(navigator.course, isNull);
      navigator.observe(
        const UserLocation(
          latitude: -21,
          longitude: -47,
          heading: 360,
          speed: 2,
        ),
      );
      expect(navigator.course, isNull);
    });
  });

  group('UserMapLocationState', () {
    test('publishes valid movement below the operational deadband', () {
      final state = UserMapLocationState();
      final now = DateTime.utc(2026, 11, 16, 12);

      expect(
        state.add(
          UserLocation(
            latitude: -21,
            longitude: -47,
            accuracy: 3,
            timestamp: now,
          ),
          now: now,
        ),
        isTrue,
      );
      expect(
        state.add(
          UserLocation(
            latitude: -20.999999,
            longitude: -47,
            accuracy: 3,
            timestamp: now.add(const Duration(milliseconds: 250)),
          ),
          now: now.add(const Duration(milliseconds: 250)),
        ),
        isTrue,
      );
      expect(state.location!.latitude, -20.999999);
    });

    test(
      'updates course from a valid heading without operational movement',
      () {
        final state = UserMapLocationState();
        final now = DateTime.utc(2026, 11, 16, 12);

        state.add(
          UserLocation(
            latitude: -21,
            longitude: -47,
            accuracy: 3,
            timestamp: now,
            heading: 135,
            speed: 1,
          ),
          now: now,
        );

        expect(state.course, 135);
      },
    );

    test('rejects invalid samples and clears between sessions', () {
      final state = UserMapLocationState();
      final now = DateTime.utc(2026, 11, 16, 12);

      expect(
        state.add(
          UserLocation(
            latitude: 100,
            longitude: -47,
            accuracy: 3,
            timestamp: now,
          ),
          now: now,
        ),
        isFalse,
      );
      state.add(
        UserLocation(
          latitude: -21,
          longitude: -47,
          accuracy: 3,
          timestamp: now,
          heading: 90,
          speed: 1,
        ),
        now: now,
      );
      state.clear();

      expect(state.location, isNull);
      expect(state.course, isNull);
    });
  });

  test('maps cardinal and invalid courses to shared marker presentation', () {
    for (final course in [0.0, 90.0, 180.0, 270.0]) {
      final marker = userMapMarkerForCourse(course);
      expect(marker.kind, UserMapMarkerKind.directional);
      expect(marker.rotation, course);
      expect(marker.flat, isTrue);
      expect(marker.anchor, userMapMarkerAnchor);
    }
    expect(userMapMarkerForCourse(null).kind, UserMapMarkerKind.neutral);
    expect(userMapMarkerForCourse(360).kind, UserMapMarkerKind.neutral);
    expect(userMapMarkerForCourse(double.nan).kind, UserMapMarkerKind.neutral);
  });

  test('cancels a pending follow decision when it becomes inactive', () async {
    final navigator = UserMapNavigator();
    final bounds = Completer<LatLngBounds>();
    var active = true;
    var animations = 0;

    final follow = navigator.followWithCallbacks(
      location: const UserLocation(latitude: -21, longitude: -47),
      getVisibleRegion: () => bounds.future,
      animateCamera: (_) async => animations++,
      camera: () =>
          const CameraPosition(target: LatLng(-22, -48), zoom: userFollowZoom),
      isActive: () => active,
    );

    active = false;
    bounds.complete(
      LatLngBounds(
        southwest: const LatLng(-22.1, -48.1),
        northeast: const LatLng(-21.9, -47.9),
      ),
    );
    await follow;

    expect(animations, 0);
  });
}
