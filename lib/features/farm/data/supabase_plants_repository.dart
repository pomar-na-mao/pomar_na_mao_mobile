import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/data/shared_read_repository.dart';
import '../domain/plant.dart';
import '../domain/plants_repository.dart';
import 'datasources/farm_remote_data_source.dart';
import 'models/plant_dto.dart';

class SupabasePlantsRepository implements PlantsRepository {
  SupabasePlantsRepository(
    SupabaseClient client, {
    FarmRemoteDataSource? remoteDataSource,
  }) : this.fromDataSource(
         remoteDataSource ?? SupabaseFarmRemoteDataSource(client),
       );

  const SupabasePlantsRepository.fromDataSource(this._remoteDataSource)
    : _sharedReadRepository = null;

  const SupabasePlantsRepository.fromShared(this._sharedReadRepository)
    : _remoteDataSource = null;

  final FarmRemoteDataSource? _remoteDataSource;
  final SharedReadRepository? _sharedReadRepository;

  @override
  Future<List<Plant>> fetchPlants() async {
    final allRows = _sharedReadRepository != null
        ? await _sharedReadRepository.getPlantRows()
        : await _remoteDataSource!.fetchPlantsRows();
    return compute(_parsePlants, allRows);
  }

  static List<Plant> _parsePlants(List<Map<String, dynamic>> rows) {
    return rows
        .where((row) => row['latitude'] is num && row['longitude'] is num)
        .map((row) => PlantDto.fromJson(row).toDomain())
        .toList(growable: false);
  }
}
