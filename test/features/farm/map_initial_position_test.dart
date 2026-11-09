import 'package:flutter_test/flutter_test.dart';
import 'package:pomar_na_mao_mobile/features/farm/domain/farm_point.dart';
import 'package:pomar_na_mao_mobile/features/farm/domain/farm_repository.dart';
import 'package:pomar_na_mao_mobile/features/farm/domain/map_initial_position.dart';
import 'package:pomar_na_mao_mobile/features/farm/domain/user_location.dart';

void main() {
  test('prioriza a posição atual do usuário', () async {
    final resolver = MapInitialPositionResolver(
      locationService: _LocationService(
        LocationResult.available(
          const UserLocation(latitude: -22.1, longitude: -48.2),
        ),
      ),
      farmRepository: _FarmRepository(),
    );

    final result = await resolver.resolve();

    expect(result?.source, MapInitialPositionSource.user);
    expect(result?.latitude, -22.1);
    expect(result?.longitude, -48.2);
  });

  test('usa somente o ponto order 1 da fazenda sem localização', () async {
    final resolver = MapInitialPositionResolver(
      locationService: _LocationService(
        const LocationResult.permissionDenied(),
      ),
      farmRepository: _FarmRepository(),
    );

    final result = await resolver.resolve();

    expect(result?.source, MapInitialPositionSource.farm);
    expect(result?.latitude, -21.5);
    expect(result?.longitude, -47.5);
  });

  test('não inventa coordenada quando GPS e order 1 não existem', () async {
    final resolver = MapInitialPositionResolver(
      locationService: _LocationService(const LocationResult.error()),
      farmRepository: _FarmRepository(includeOrderOne: false),
    );

    expect(await resolver.resolve(), isNull);
  });
}

class _LocationService implements LocationService {
  const _LocationService(this.result);

  final LocationResult result;

  @override
  Future<LocationResult> getCurrentLocation() async => result;

  @override
  Stream<LocationResult> watchLocation() => const Stream.empty();
}

class _FarmRepository implements FarmRepository {
  _FarmRepository({this.includeOrderOne = true});

  final bool includeOrderOne;

  @override
  Future<List<FarmPoint>> fetchFarmBoundary() async => [
    const FarmPoint(
      id: 'second',
      latitude: -20.0,
      longitude: -46.0,
      boundaryOrder: 2,
    ),
    if (includeOrderOne)
      const FarmPoint(
        id: 'first',
        latitude: -21.5,
        longitude: -47.5,
        boundaryOrder: 1,
      ),
  ];
}
