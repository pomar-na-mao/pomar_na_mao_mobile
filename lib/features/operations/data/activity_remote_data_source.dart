import 'package:supabase_flutter/supabase_flutter.dart';

import '../domain/activity_models.dart';

abstract interface class ActivityRemoteDataSource {
  Future<List<Map<String, dynamic>>> fetchInputPage({
    required int from,
    required int to,
  });

  Future<List<Map<String, dynamic>>> fetchMixturePage({
    required int from,
    required int to,
  });

  Future<List<Map<String, dynamic>>> fetchMachinePage({
    required int from,
    required int to,
  });

  Future<List<ActivitySyncResult>> syncEntries(Map<String, dynamic> payload);
}

class SupabaseActivityRemoteDataSource implements ActivityRemoteDataSource {
  const SupabaseActivityRemoteDataSource(
    this._client, {
    this.rpcName = 'sync_activity_entries',
  });

  final SupabaseClient _client;
  final String rpcName;

  @override
  Future<List<Map<String, dynamic>>> fetchInputPage({
    required int from,
    required int to,
  }) async {
    final response = await _client
        .from('inputs')
        .select('id,name,type,active_ingredient,label_dose,dose_unit')
        .order('name')
        .order('id')
        .range(from, to);
    return List<Map<String, dynamic>>.from(response as List<dynamic>);
  }

  @override
  Future<List<Map<String, dynamic>>> fetchMixturePage({
    required int from,
    required int to,
  }) async {
    final response = await _client
        .from('mixtures')
        .select(
          'id,name,is_active,observations,'
          'components:mixture_inputs('
          'id,input_id,dose,dose_unit,'
          'input:inputs(id,name,type,active_ingredient,label_dose,dose_unit))',
        )
        .eq('is_active', true)
        .order('name')
        .order('id')
        .range(from, to);
    return List<Map<String, dynamic>>.from(response as List<dynamic>);
  }

  @override
  Future<List<Map<String, dynamic>>> fetchMachinePage({
    required int from,
    required int to,
  }) async {
    final response = await _client
        .from('machines')
        .select(
          'id,name,brand,acquisition_date,manufacturing_year,quantity,'
          'observations',
        )
        .order('name')
        .order('id')
        .range(from, to);
    return List<Map<String, dynamic>>.from(response as List<dynamic>);
  }

  @override
  Future<List<ActivitySyncResult>> syncEntries(
    Map<String, dynamic> payload,
  ) async {
    final response = await _client.rpc(rpcName, params: {'p_payload': payload});
    return ActivitySyncResult.listFromRpc(response);
  }
}
