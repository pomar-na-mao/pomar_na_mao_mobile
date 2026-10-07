import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';

import '../domain/user_location.dart';

class GeolocatorLocationService implements LocationService {
  static LocationSettings _createLocationSettings() {
    if (defaultTargetPlatform == TargetPlatform.android) {
      return AndroidSettings(
        accuracy: LocationAccuracy.bestForNavigation,
        distanceFilter: 0,
        intervalDuration: const Duration(seconds: 1),
      );
    }
    if (defaultTargetPlatform == TargetPlatform.iOS ||
        defaultTargetPlatform == TargetPlatform.macOS) {
      return AppleSettings(
        accuracy: LocationAccuracy.bestForNavigation,
        activityType: ActivityType.fitness,
        distanceFilter: 0,
        pauseLocationUpdatesAutomatically: false,
        showBackgroundLocationIndicator: false,
      );
    }
    return const LocationSettings(
      accuracy: LocationAccuracy.bestForNavigation,
      distanceFilter: 0,
    );
  }

  @override
  Future<LocationResult> getCurrentLocation() async {
    try {
      final unavailableResult = await _ensureLocationAccess();
      if (unavailableResult != null) return unavailableResult;

      final position = await Geolocator.getCurrentPosition(
        locationSettings: _createLocationSettings(),
      );
      return _toLocationResult(position);
    } on Exception {
      return const LocationResult.error();
    }
  }

  @override
  Stream<LocationResult> watchLocation() async* {
    try {
      final unavailableResult = await _ensureLocationAccess();
      if (unavailableResult != null) {
        yield unavailableResult;
        return;
      }
      await for (final position in Geolocator.getPositionStream(
        locationSettings: _createLocationSettings(),
      )) {
        yield _toLocationResult(position);
      }
    } on Exception {
      yield const LocationResult.error();
    }
  }

  Future<LocationResult?> _ensureLocationAccess() async {
    if (!await Geolocator.isLocationServiceEnabled()) {
      return const LocationResult.serviceDisabled();
    }

    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }
    if (permission == LocationPermission.denied ||
        permission == LocationPermission.deniedForever) {
      return const LocationResult.permissionDenied();
    }

    return null;
  }

  LocationResult _toLocationResult(Position position) {
    return LocationResult.available(
      UserLocation(
        latitude: position.latitude,
        longitude: position.longitude,
        accuracy: position.accuracy,
        timestamp: position.timestamp,
        heading: position.heading,
        speed: position.speed,
      ),
    );
  }
}
