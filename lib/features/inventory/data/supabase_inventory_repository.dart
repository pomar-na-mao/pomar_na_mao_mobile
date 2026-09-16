import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

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

  const SupabaseInventoryRepository.fromDataSource(this._remoteDataSource);

  @visibleForTesting
  SupabaseInventoryRepository.withCountQuery(InventoryCountQuery countQuery)
      : _remoteDataSource = _FunctionalInventoryRemoteDataSource(countQuery);

  final InventoryRemoteDataSource _remoteDataSource;

  @override
  Future<InventorySummary> fetchSummary() async {
    final counts = await Future.wait([
      _remoteDataSource.countPlants(nonExistent: false),
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
