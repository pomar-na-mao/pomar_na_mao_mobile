import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/data/shared_read_repository.dart';
import '../domain/farm_point.dart';
import '../domain/farm_repository.dart';
import 'datasources/farm_remote_data_source.dart';
import 'models/farm_point_dto.dart';

class SupabaseFarmRepository implements FarmRepository {
  SupabaseFarmRepository(
    SupabaseClient client, {
    FarmRemoteDataSource? remoteDataSource,
  }) : this.fromDataSource(
         remoteDataSource ?? SupabaseFarmRemoteDataSource(client),
       );

  const SupabaseFarmRepository.fromDataSource(this._remoteDataSource)
    : _sharedReadRepository = null;

  const SupabaseFarmRepository.fromShared(this._sharedReadRepository)
    : _remoteDataSource = null;

  final FarmRemoteDataSource? _remoteDataSource;
  final SharedReadRepository? _sharedReadRepository;

  @override
  Future<List<FarmPoint>> fetchFarmBoundary() async {
    final rows = _sharedReadRepository != null
        ? await _sharedReadRepository.getFarmBoundaryRows()
        : await _remoteDataSource!.fetchFarmBoundaryRows();
    return rows
        .map((row) => FarmPointDto.fromJson(row).toDomain())
        .toList(growable: false);
  }
}
