import 'package:supabase_flutter/supabase_flutter.dart';

import '../domain/spraying_models.dart';

abstract interface class SprayingRemoteDataSource {
  Future<SprayingSyncResult> syncSprayingOperation(
    Map<String, dynamic> payload,
  );

  Future<List<Map<String, dynamic>>> recalculateAffectedPlants({
    required Map<String, dynamic> geojson,
    String? zoneId,
    double maxDistanceMeters = 9.0,
  });
}

class SupabaseSprayingRemoteDataSource implements SprayingRemoteDataSource {
  const SupabaseSprayingRemoteDataSource(
    this._client, {
    this.rpcName = 'sync_reviewed_spraying_operation',
    this.recalculateRpcName = 'recalculate_operation_affected_plants',
  });

  final SupabaseClient _client;
  final String rpcName;
  final String recalculateRpcName;

  @override
  Future<SprayingSyncResult> syncSprayingOperation(
    Map<String, dynamic> payload,
  ) async {
    final response = await _client.rpc(
      rpcName,
      params: {'p_payload': payload},
    );
    return SprayingSyncResult.fromRpc(response);
  }

  @override
  Future<List<Map<String, dynamic>>> recalculateAffectedPlants({
    required Map<String, dynamic> geojson,
    String? zoneId,
    double maxDistanceMeters = 9.0,
  }) async {
    final response = await _client.rpc(
      recalculateRpcName,
      params: {
        'p_geojson': geojson,
        'p_zone_id': ?zoneId,
        'p_max_distance_meters': maxDistanceMeters,
      },
    );

    if (response is List) {
      return response.map((e) => Map<String, dynamic>.from(e as Map)).toList();
    }
    return const [];
  }
}
