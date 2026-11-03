import 'dart:math' as math;

import '../../farm/domain/user_location.dart';
import '../../farm/domain/user_position_tracker.dart';
import 'spraying_geometry_service.dart';

class SprayingLocationFilter extends UserLocationFilter {
  SprayingLocationFilter({
    SprayingGeometryService geometry = const SprayingGeometryService(),
    this.maxSpeedMps = 28.0, // ~100 km/h
    this.maxAccuracyMeters = 25.0,
  }) : super(distance: geometry.haversineDistanceMeters);

  final double maxSpeedMps;
  final double maxAccuracyMeters;

  final List<UserLocation> _sprayingSamples = [];
  UserLocation? _sprayingAccepted;
  DateTime? _sprayingLastTimestamp;
  UserLocation? _suspectRawLocation;
  int _consecutiveOutliers = 0;

  @override
  UserLocation? get current => _sprayingAccepted;

  @override
  UserLocation? add(UserLocation location, {DateTime? now}) {
    final receivedAt = (now ?? DateTime.now()).toUtc();
    var timestamp = (location.timestamp ?? receivedAt).toUtc();
    if (location.timestamp == null &&
        _sprayingLastTimestamp != null &&
        !timestamp.isAfter(_sprayingLastTimestamp!)) {
      timestamp = _sprayingLastTimestamp!.add(const Duration(microseconds: 1));
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
        accuracy > maxAccuracyMeters ||
        age > const Duration(seconds: 5) ||
        age < const Duration(seconds: -2) ||
        (_sprayingLastTimestamp != null &&
            !timestamp.isAfter(_sprayingLastTimestamp!))) {
      return null;
    }

    _sprayingLastTimestamp = timestamp;

    if (_sprayingAccepted == null) {
      _sprayingAccepted = UserLocation(
        latitude: location.latitude,
        longitude: location.longitude,
        accuracy: accuracy,
        timestamp: timestamp,
        heading: location.heading,
        speed: location.speed,
      );
      _sprayingSamples.clear();
      _sprayingSamples.add(_sprayingAccepted!);
      _consecutiveOutliers = 0;
      _suspectRawLocation = null;
      return _sprayingAccepted;
    }

    // 1. Verificar se a amostra bruta e um outlier/salto em relacao a posicao aceita
    final rawDistToAccepted = distance(
      _sprayingAccepted!.latitude,
      _sprayingAccepted!.longitude,
      location.latitude,
      location.longitude,
    );
    final elapsedFromAccepted = math.max(
      0.05,
      timestamp
              .difference(_sprayingAccepted!.timestamp ?? timestamp)
              .inMilliseconds /
          1000,
    );
    final maxAllowedFromAccepted = math.max(
      8.0,
      elapsedFromAccepted * maxSpeedMps +
          accuracy +
          (_sprayingAccepted!.accuracy ?? 0),
    );

    if (rawDistToAccepted > maxAllowedFromAccepted) {
      _consecutiveOutliers++;

      // Se temos um suspect anterior e esta nova amostra e consistente com ele,
      // confirma-se que o veiculo/usuario realmente se deslocou (ou houve gap de GPS).
      if (_suspectRawLocation != null) {
        final elapsedFromSuspect = math.max(
          0.05,
          timestamp
                  .difference(_suspectRawLocation!.timestamp ?? timestamp)
                  .inMilliseconds /
              1000,
        );
        final distFromSuspect = distance(
          _suspectRawLocation!.latitude,
          _suspectRawLocation!.longitude,
          location.latitude,
          location.longitude,
        );
        final maxAllowedFromSuspect = math.max(
          15.0,
          elapsedFromSuspect * maxSpeedMps +
              accuracy +
              (_suspectRawLocation!.accuracy ?? 0),
        );

        if (distFromSuspect <= maxAllowedFromSuspect) {
          final reSynced = UserLocation(
            latitude: location.latitude,
            longitude: location.longitude,
            accuracy: accuracy,
            timestamp: timestamp,
            heading: location.heading,
            speed: location.speed,
          );
          _sprayingAccepted = reSynced;
          _sprayingSamples
            ..clear()
            ..add(reSynced);
          _suspectRawLocation = null;
          _consecutiveOutliers = 0;
          return reSynced;
        }
      }

      // Se acumular 3 outliers consecutivos, forca a ressincronizacao para evitar lockout
      if (_consecutiveOutliers >= 3) {
        final reSynced = UserLocation(
          latitude: location.latitude,
          longitude: location.longitude,
          accuracy: accuracy,
          timestamp: timestamp,
          heading: location.heading,
          speed: location.speed,
        );
        _sprayingAccepted = reSynced;
        _sprayingSamples
          ..clear()
          ..add(reSynced);
        _suspectRawLocation = null;
        _consecutiveOutliers = 0;
        return reSynced;
      }

      _suspectRawLocation = location;
      return null;
    }

    // Amostra consistente: limpa suspeitas
    _suspectRawLocation = null;
    _consecutiveOutliers = 0;

    // 2. Filtro de mediana de 3 amostras para suavizacao de jitter normal
    _sprayingSamples.add(location);
    if (_sprayingSamples.length > 3) _sprayingSamples.removeAt(0);
    if (_sprayingSamples.length < 3) return null;

    final latitudes = _sprayingSamples.map((sample) => sample.latitude).toList()
      ..sort();
    final longitudes = _sprayingSamples.map((sample) => sample.longitude).toList()
      ..sort();
    final accuracies = _sprayingSamples.map((sample) => sample.accuracy!).toList()
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
      _sprayingAccepted!.latitude,
      _sprayingAccepted!.longitude,
      candidate.latitude,
      candidate.longitude,
    );
    final deadband = math.max(2.5, math.min(4.0, accuracy * 0.75));
    if (meters < deadband) return null;

    _sprayingAccepted = candidate;
    return candidate;
  }
}
