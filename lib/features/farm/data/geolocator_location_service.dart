import 'package:geolocator/geolocator.dart';

import '../domain/user_location.dart';

class GeolocatorLocationService implements LocationService {
  static const _locationSettings = LocationSettings(
    accuracy: LocationAccuracy.bestForNavigation,
    distanceFilter: 1,
  );

  @override
  Future<LocationResult> getCurrentLocation() async {
    try {
      final unavailableResult = await _ensureLocationAccess();
      if (unavailableResult != null) return unavailableResult;

      final position = await Geolocator.getCurrentPosition(
        locationSettings: _locationSettings,
      );
      return _toLocationResult(position);
    } on Exception {
      return const LocationResult.error();
    }
  }

  @override
  Stream<LocationResult> watchLocation() async* {
    final initialResult = await getCurrentLocation();
    yield initialResult;

    if (initialResult.availability != LocationAvailability.available) return;

    try {
      await for (final position in Geolocator.getPositionStream(
        locationSettings: _locationSettings,
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
      ),
    );
  }
}
