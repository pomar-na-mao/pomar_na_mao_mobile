import 'package:supabase_flutter/supabase_flutter.dart';

import '../../farm/data/datasources/farm_remote_data_source.dart';
import '../domain/inspection_models.dart';

abstract interface class InspectionRemoteDataSource {
  Future<List<OccurrenceType>> fetchOccurrenceTypes();
  Future<List<InspectionPlant>> fetchPlants({int pageSize = 1000});
  Future<Map<String, Set<String>>> fetchOpenOccurrences(
    List<String> plantIds, {
    int batchSize = 500,
  });
  Future<InspectionSnapshot> fetchSnapshot({int pageSize = 1000});
  Future<InspectionSyncResult> syncInspection(Map<String, dynamic> payload);
  Future<List<AddedPlantSyncResult>> syncAddedPlants(
    Map<String, dynamic> payload,
  );
}

class SupabaseInspectionRemoteDataSource implements InspectionRemoteDataSource {
  const SupabaseInspectionRemoteDataSource(
    this._client, {
    this.rpcName = 'sync_manual_inspection_v2',
    this.addedPlantsRpcName = 'sync_inspection_added_plants',
  });

  final SupabaseClient _client;
  final String rpcName;
  final String addedPlantsRpcName;

  @override
  Future<List<OccurrenceType>> fetchOccurrenceTypes() async {
    final rows = await _client
        .from('occurrence_types')
        .select('id, name, code')
        .order('name');
    return (rows as List<dynamic>)
        .map(
          (r) => OccurrenceType.fromJson(Map<String, dynamic>.from(r as Map)),
        )
        .toList();
  }

  @override
  Future<List<InspectionPlant>> fetchPlants({int pageSize = 1000}) async {
    const columns = 'id, latitude, longitude, description, zone_id, non_existent';
    final rows = await fetchAllPlantPages((from, to) async {
      final rows = await _client
          .from('plants')
          .select(columns)
          .order('id')
          .range(from, to);
      return List<Map<String, dynamic>>.from(rows as List<dynamic>);
    }, pageSize: pageSize);

    return rows.map(InspectionPlant.fromJson).toList();
  }

  @override
  Future<Map<String, Set<String>>> fetchOpenOccurrences(
    List<String> plantIds, {
    int batchSize = 500,
  }) async {
    final openMap = <String, Set<String>>{};

    // If plantIds is a small subset (e.g. <= 50 in unit tests), filter directly by plant_id.
    // When fetching for the whole farm (thousands of plants), querying open occurrences
    // directly avoids HTTP 414 (Request-URI Too Large) caused by massive URL query strings.
    if (plantIds.isNotEmpty && plantIds.length <= 50) {
      final rows = await _client
          .from('plant_occurrences')
          .select('id, plant_id, occurrence_type_id')
          .inFilter('plant_id', plantIds)
          .eq('status', 'open')
          .order('id')
          .order('plant_id')
          .order('occurrence_type_id');

      for (final r in rows as List<dynamic>) {
        final map = Map<String, dynamic>.from(r as Map);
        final pId = map['plant_id'] as String;
        final tId = map['occurrence_type_id'] as String;
        (openMap[pId] ??= {}).add(tId);
      }
      return openMap;
    }

    final plantIdSet = plantIds.toSet();
    const pageSize = 1000;
    final rows = await fetchAllPlantPages((from, to) async {
      final rows = await _client
          .from('plant_occurrences')
          .select('id, plant_id, occurrence_type_id')
          .eq('status', 'open')
          .order('id')
          .order('plant_id')
          .order('occurrence_type_id')
          .range(from, from + pageSize - 1);
      return List<Map<String, dynamic>>.from(rows as List<dynamic>);
    });

    for (final map in rows) {
      final pId = map['plant_id'] as String;
      final tId = map['occurrence_type_id'] as String;
      if (plantIdSet.isEmpty || plantIdSet.contains(pId)) {
        (openMap[pId] ??= {}).add(tId);
      }
    }

    return openMap;
  }

  @override
  Future<InspectionSnapshot> fetchSnapshot({int pageSize = 1000}) async {
    final types = await fetchOccurrenceTypes();
    final plants = await fetchPlants(pageSize: pageSize);
    final plantIds = plants.map((p) => p.id).toList();
    final openMap = await fetchOpenOccurrences(plantIds);

    final resolvedPlants = plants.map((p) {
      final openTypes = openMap[p.id] ?? const <String>{};
      return p.withState(openTypes);
    }).toList();

    return InspectionSnapshot(
      plants: resolvedPlants,
      types: types,
      loadedAt: DateTime.now().toUtc(),
    );
  }

  @override
  Future<InspectionSyncResult> syncInspection(
    Map<String, dynamic> payload,
  ) async {
    final response = await _client.rpc(rpcName, params: {'p_payload': payload});
    return InspectionSyncResult.fromRpc(response);
  }

  @override
  Future<List<AddedPlantSyncResult>> syncAddedPlants(
    Map<String, dynamic> payload,
  ) async {
    final response = await _client.rpc(
      addedPlantsRpcName,
      params: {'p_payload': payload},
    );
    return AddedPlantSyncResult.listFromRpc(response);
  }
}
