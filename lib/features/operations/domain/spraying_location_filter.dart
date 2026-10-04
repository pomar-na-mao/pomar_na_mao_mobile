import 'dart:math' as math;

import '../../farm/domain/user_location.dart';
import 'spraying_geometry_service.dart';

/// Filters short GPS excursions before they reach the marker or saved route.
class SprayingLocationFilter {
  SprayingLocationFilter({this.geometry = const SprayingGeometryService()});

  final SprayingGeometryService geometry;
  final List<UserLocation> _samples = [];
  UserLocation? _accepted;
  DateTime? _lastTimestamp;

  UserLocation? get current => _accepted;

  UserLocation? add(UserLocation location, {DateTime? now}) {
    final receivedAt = (now ?? DateTime.now()).toUtc();
    var timestamp = (location.timestamp ?? receivedAt).toUtc();
    if (location.timestamp == null &&
        _lastTimestamp != null &&
        !timestamp.isAfter(_lastTimestamp!)) {
      timestamp = _lastTimestamp!.add(const Duration(microseconds: 1));
    }
    final age = receivedAt.difference(timestamp);
    final accuracy = location.accuracy;
    if (!location.latitude.isFinite ||
        !location.longitude.isFinite ||
        location.latitude.abs() > 90 ||
        location.longitude.abs() > 180 ||
        accuracy == null ||
        !accuracy.isFinite ||
        accuracy <= 0 ||
        accuracy > 12 ||
        age > const Duration(seconds: 5) ||
        age < const Duration(seconds: -2) ||
        (_lastTimestamp != null && !timestamp.isAfter(_lastTimestamp!))) {
      return null;
    }

    _lastTimestamp = timestamp;
    _samples.add(location);
    if (_samples.length > 3) _samples.removeAt(0);

    if (_accepted == null) {
      _accepted = UserLocation(
        latitude: location.latitude,
        longitude: location.longitude,
        accuracy: accuracy,
        timestamp: timestamp,
      );
      return _accepted;
    }
    if (_samples.length < 3) return null;

    final latitudes = _samples.map((sample) => sample.latitude).toList()
      ..sort();
    final longitudes = _samples.map((sample) => sample.longitude).toList()
      ..sort();
    final accuracies = _samples.map((sample) => sample.accuracy!).toList()
      ..sort();
    final candidate = UserLocation(
      latitude: latitudes[1],
      longitude: longitudes[1],
      accuracy: accuracies[1],
      timestamp: timestamp,
    );
    final distance = geometry.haversineDistanceMeters(
      _accepted!.latitude,
      _accepted!.longitude,
      candidate.latitude,
      candidate.longitude,
    );
    final deadband = math.max(2.5, math.min(4.0, accuracy * 0.75));
    if (distance < deadband) return null;

    final elapsedSeconds =
        timestamp.difference(_accepted!.timestamp ?? timestamp).inMilliseconds /
        1000;
    if (distance > math.max(8.0, elapsedSeconds * 12 + accuracy)) {
      return null;
    }

    _accepted = candidate;
    return candidate;
  }
}
