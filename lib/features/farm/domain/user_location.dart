class UserLocation {
  const UserLocation({
    required this.latitude,
    required this.longitude,
    this.accuracy,
  });

  final double latitude;
  final double longitude;
  final double? accuracy;
}

enum LocationAvailability {
  available,
  permissionDenied,
  serviceDisabled,
  error,
}

class LocationResult {
  const LocationResult._(this.availability, this.location);

  const LocationResult.available(UserLocation location)
    : this._(LocationAvailability.available, location);

  const LocationResult.permissionDenied()
    : this._(LocationAvailability.permissionDenied, null);

  const LocationResult.serviceDisabled()
    : this._(LocationAvailability.serviceDisabled, null);

  const LocationResult.error() : this._(LocationAvailability.error, null);

  final LocationAvailability availability;
  final UserLocation? location;
}

abstract interface class LocationService {
  Future<LocationResult> getCurrentLocation();

  Stream<LocationResult> watchLocation();
}
