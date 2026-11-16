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
