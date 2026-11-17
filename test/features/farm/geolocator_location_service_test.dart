import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:geolocator/geolocator.dart';
import 'package:pomar_na_mao_mobile/features/farm/data/geolocator_location_service.dart';

void main() {
  test('requests high-frequency navigation updates on Android', () {
    final settings =
        GeolocatorLocationService.createLocationSettingsForPlatform(
          TargetPlatform.android,
        ) as AndroidSettings;

    expect(settings.accuracy, LocationAccuracy.bestForNavigation);
    expect(settings.distanceFilter, 0);
    expect(settings.intervalDuration, const Duration(milliseconds: 250));
  });

  test('keeps continuous navigation updates on Apple platforms', () {
    final settings =
        GeolocatorLocationService.createLocationSettingsForPlatform(
          TargetPlatform.iOS,
        ) as AppleSettings;

    expect(settings.accuracy, LocationAccuracy.bestForNavigation);
    expect(settings.distanceFilter, 0);
    expect(settings.pauseLocationUpdatesAutomatically, isFalse);
  });
}
