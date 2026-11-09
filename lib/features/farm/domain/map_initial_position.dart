import 'farm_repository.dart';
import 'user_location.dart';

enum MapInitialPositionSource { user, farm }

class MapInitialPosition {
  const MapInitialPosition({
    required this.latitude,
    required this.longitude,
    required this.source,
  });

  final double latitude;
  final double longitude;
  final MapInitialPositionSource source;
}

class MapInitialPositionResolver {
  const MapInitialPositionResolver({
    required this.locationService,
    required this.farmRepository,
  });

  final LocationService locationService;
  final FarmRepository farmRepository;

  Future<MapInitialPosition?> resolve() async {
    try {
      final result = await locationService.getCurrentLocation();
      final location = result.location;
      if (location != null &&
          _isValidCoordinate(location.latitude, location.longitude)) {
        return MapInitialPosition(
          latitude: location.latitude,
          longitude: location.longitude,
          source: MapInitialPositionSource.user,
        );
      }
    } on Exception {
      // A leitura do ponto principal da fazenda permanece como fallback.
    }

    try {
      final points = await farmRepository.fetchFarmBoundary();
      for (final point in points) {
        if (point.boundaryOrder == 1 &&
            _isValidCoordinate(point.latitude, point.longitude)) {
          return MapInitialPosition(
            latitude: point.latitude,
            longitude: point.longitude,
            source: MapInitialPositionSource.farm,
          );
        }
      }
    } on Exception {
      // Sem GPS e sem o ponto order 1, a tela informa a indisponibilidade.
    }
    return null;
  }
}

bool _isValidCoordinate(double latitude, double longitude) =>
    latitude.isFinite &&
    longitude.isFinite &&
    latitude.abs() <= 90 &&
    longitude.abs() <= 180;
