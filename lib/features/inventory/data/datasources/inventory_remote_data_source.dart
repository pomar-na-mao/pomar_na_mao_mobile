import 'package:supabase_flutter/supabase_flutter.dart';

abstract interface class InventoryRemoteDataSource {
  Future<int> countPlants({required bool nonExistent});
  Future<int> countZones();
  Future<int> countRegionPoints();
  Future<int> countFarmBoundaryPoints();
}

class SupabaseInventoryRemoteDataSource implements InventoryRemoteDataSource {
  const SupabaseInventoryRemoteDataSource(this._client);

  final SupabaseClient _client;

  @override
  Future<int> countPlants({required bool nonExistent}) {
    return _client
        .from('plants')
        .count(CountOption.exact)
        .eq('non_existent', nonExistent);
  }

  @override
  Future<int> countZones() {
    return _client.from('zones').count(CountOption.exact);
  }

  @override
  Future<int> countRegionPoints() {
    return _client.from('regions').count(CountOption.exact);
  }

  @override
  Future<int> countFarmBoundaryPoints() {
    return _client.from('farm').count(CountOption.exact);
  }
}
