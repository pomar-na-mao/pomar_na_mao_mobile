import 'dart:math' as math;

import 'user_location.dart';

double userDistanceMeters(double lat1, double lon1, double lat2, double lon2) {
  const radius = 6371000.0;
  final dLat = (lat2 - lat1) * math.pi / 180;
  final dLon = (lon2 - lon1) * math.pi / 180;
  final a =
      math.sin(dLat / 2) * math.sin(dLat / 2) +
      math.cos(lat1 * math.pi / 180) *
          math.cos(lat2 * math.pi / 180) *
          math.sin(dLon / 2) *
          math.sin(dLon / 2);
  return radius * 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));
}

typedef UserDistance = double Function(
  double lat1,
  double lon1,
  double lat2,
  double lon2,
);

class UserLocationFilter {
  UserLocationFilter({this.distance = userDistanceMeters});

  final UserDistance distance;
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
        heading: location.heading,
        speed: location.speed,
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
      heading: location.heading,
      speed: location.speed,
    );
    final meters = distance(
      _accepted!.latitude,
      _accepted!.longitude,
      candidate.latitude,
      candidate.longitude,
    );
    final deadband = math.max(2.5, math.min(4.0, accuracy * 0.75));
    if (meters < deadband) return null;

    final elapsedSeconds =
        timestamp.difference(_accepted!.timestamp ?? timestamp).inMilliseconds /
        1000;
    if (meters > math.max(8.0, elapsedSeconds * 12 + accuracy)) return null;

    _accepted = candidate;
    return candidate;
  }
}

class UserSignalStabilizer {
  UserSignalStabilizer({this.distance = userDistanceMeters});

  final UserDistance distance;
  final List<UserLocation> _samples = [];

  void reset() => _samples.clear();

  UserLocation? add(UserLocation location, {DateTime? now}) {
    final receivedAt = (now ?? DateTime.now()).toUtc();
    final timestamp = location.timestamp?.toUtc();
    final accuracy = location.accuracy;
    if (timestamp == null ||
        accuracy == null ||
        !accuracy.isFinite ||
        accuracy <= 0 ||
        accuracy > 12 ||
        !location.latitude.isFinite ||
        !location.longitude.isFinite ||
        location.latitude.abs() > 90 ||
        location.longitude.abs() > 180 ||
        receivedAt.difference(timestamp) > const Duration(seconds: 5) ||
        receivedAt.difference(timestamp) < const Duration(seconds: -2)) {
      reset();
      return null;
    }

    if (_samples.isNotEmpty) {
      final previous = _samples.last;
      final elapsed =
          timestamp.difference(previous.timestamp!).inMilliseconds / 1000;
      final meters = distance(
        previous.latitude,
        previous.longitude,
        location.latitude,
        location.longitude,
      );
      if (elapsed <= 0 || elapsed > 3 || meters > 6 * elapsed + 3) {
        reset();
      }
    }

    _samples.add(location);
    if (_samples.length > 4) _samples.removeAt(0);
    if (_samples.length >= 3 &&
        timestamp.difference(_samples.first.timestamp!) >=
            const Duration(seconds: 2)) {
      return location;
    }
    return null;
  }
}

class UserPositionTracker {
  UserLocationFilter _filter = UserLocationFilter();
  final UserSignalStabilizer _stabilizer = UserSignalStabilizer();
  bool _stable = false;

  void reset() {
    _filter = UserLocationFilter();
    _stabilizer.reset();
    _stable = false;
  }

  UserLocation? add(UserLocation location, {DateTime? now}) {
    if (!_stable) {
      final stable = _stabilizer.add(location, now: now);
      if (stable == null) return null;
      _stable = true;
      return _filter.add(stable, now: now);
    }
    return _filter.add(location, now: now);
  }
}
