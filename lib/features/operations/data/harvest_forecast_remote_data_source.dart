import 'package:supabase_flutter/supabase_flutter.dart';

import '../domain/harvest_forecast_models.dart';

abstract interface class HarvestForecastRemoteDataSource {
  Future<List<HarvestForecastSyncResult>> syncMarkings(
    Map<String, dynamic> payload,
  );
}

class SupabaseHarvestForecastRemoteDataSource
    implements HarvestForecastRemoteDataSource {
  const SupabaseHarvestForecastRemoteDataSource(
    this._client, {
    this.rpcName = 'sync_harvest_forecasts',
  });

  final SupabaseClient _client;
  final String rpcName;

  @override
  Future<List<HarvestForecastSyncResult>> syncMarkings(
    Map<String, dynamic> payload,
  ) async => HarvestForecastSyncResult.listFromRpc(
    await _client.rpc(rpcName, params: {'p_payload': payload}),
  );
}
