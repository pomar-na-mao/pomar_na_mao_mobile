import 'package:supabase_flutter/supabase_flutter.dart';

abstract interface class InventoryRemoteDataSource {
  Future<int> countPlants({required bool nonExistent});
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
}
