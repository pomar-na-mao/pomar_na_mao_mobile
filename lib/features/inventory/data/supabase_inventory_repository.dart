import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/data/shared_read_repository.dart';
import '../domain/inventory_repository.dart';
import '../domain/inventory_summary.dart';
import 'datasources/inventory_remote_data_source.dart';

typedef InventoryCountQuery = Future<int> Function(bool nonExistent);

class SupabaseInventoryRepository implements InventoryRepository {
  SupabaseInventoryRepository(
    SupabaseClient client, {
    InventoryRemoteDataSource? remoteDataSource,
  }) : this.fromDataSource(
         remoteDataSource ?? SupabaseInventoryRemoteDataSource(client),
       );

  const SupabaseInventoryRepository.fromDataSource(this._remoteDataSource)
    : _sharedReadRepository = null;

  const SupabaseInventoryRepository.fromShared(this._sharedReadRepository)
    : _remoteDataSource = null;

  @visibleForTesting
  SupabaseInventoryRepository.withCountQuery(InventoryCountQuery countQuery)
    : _remoteDataSource = _FunctionalInventoryRemoteDataSource(countQuery),
      _sharedReadRepository = null;

  final InventoryRemoteDataSource? _remoteDataSource;
  final SharedReadRepository? _sharedReadRepository;

  @override
  Future<InventorySummary> fetchSummary() async {
    final shared = _sharedReadRepository;
    if (shared != null) {
      final plants = await shared.getPlantRows();
      var existing = 0;
      var available = 0;
      for (final plant in plants) {
        if (plant['non_existent'] == true) {
          available++;
        } else {
          existing++;
        }
      }
      return InventorySummary(
        existingPlants: existing,
        availablePlantingSpots: available,
      );
    }

    final counts = await Future.wait([
      _remoteDataSource!.countPlants(nonExistent: false),
      _remoteDataSource.countPlants(nonExistent: true),
    ]);

    return InventorySummary(
      existingPlants: counts[0],
      availablePlantingSpots: counts[1],
    );
  }
}

class _FunctionalInventoryRemoteDataSource
    implements InventoryRemoteDataSource {
  const _FunctionalInventoryRemoteDataSource(this._countQuery);

  final InventoryCountQuery _countQuery;

  @override
  Future<int> countPlants({required bool nonExistent}) =>
      _countQuery(nonExistent);
}
