import 'package:supabase_flutter/supabase_flutter.dart';

import '../domain/inspection_models.dart';

abstract interface class InspectionRemoteDataSource {
  Future<List<OccurrenceType>> fetchOccurrenceTypes();
  Future<List<InspectionPlant>> fetchPlants({int pageSize = 1000});
  Future<Map<String, Set<String>>> fetchOpenOccurrences(List<String> plantIds, {int batchSize = 500});
  Future<InspectionSnapshot> fetchSnapshot({int pageSize = 1000});
  Future<InspectionSyncResult> syncInspection(Map<String, dynamic> payload);
}

class SupabaseInspectionRemoteDataSource implements InspectionRemoteDataSource {
  const SupabaseInspectionRemoteDataSource(
    this._client, {
    this.rpcName = 'sync_manual_inspection_v2',
  });

  final SupabaseClient _client;
  final String rpcName;

  @override
  Future<List<OccurrenceType>> fetchOccurrenceTypes() async {
    final rows = await _client
        .from('occurrence_types')
        .select('id, name, code')
        .order('name');
    return (rows as List<dynamic>)
        .map((r) => OccurrenceType.fromJson(Map<String, dynamic>.from(r as Map)))
        .toList();
  }

  @override
  Future<List<InspectionPlant>> fetchPlants({int pageSize = 1000}) async {
    const columns = 'id, latitude, longitude, description, zone_id';
    final allPlants = <InspectionPlant>[];
    var from = 0;

    while (true) {
      final to = from + pageSize - 1;
      final rows = await _client
          .from('plants')
          .select(columns)
          .eq('non_existent', false)
          .order('id')
          .range(from, to);

      final list = rows as List<dynamic>;
      for (final r in list) {
        allPlants.add(InspectionPlant.fromJson(Map<String, dynamic>.from(r as Map)));
      }

      if (list.length < pageSize) {
        break;
      }
      from += pageSize;
    }

    return allPlants;
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
          .select('plant_id, occurrence_type_id')
          .inFilter('plant_id', plantIds)
          .eq('status', 'open');

      for (final r in rows as List<dynamic>) {
        final map = Map<String, dynamic>.from(r as Map);
        final pId = map['plant_id'] as String;
        final tId = map['occurrence_type_id'] as String;
        (openMap[pId] ??= {}).add(tId);
      }
      return openMap;
    }

    final plantIdSet = plantIds.toSet();
    var from = 0;
    const pageSize = 1000;
    while (true) {
      final rows = await _client
          .from('plant_occurrences')
          .select('plant_id, occurrence_type_id')
          .eq('status', 'open')
          .range(from, from + pageSize - 1);

      final list = rows as List<dynamic>;
      for (final r in list) {
        final map = Map<String, dynamic>.from(r as Map);
        final pId = map['plant_id'] as String;
        final tId = map['occurrence_type_id'] as String;
        if (plantIdSet.isEmpty || plantIdSet.contains(pId)) {
          (openMap[pId] ??= {}).add(tId);
        }
      }
      if (list.length < pageSize) break;
      from += pageSize;
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
  Future<InspectionSyncResult> syncInspection(Map<String, dynamic> payload) async {
    final response = await _client.rpc(
      rpcName,
      params: {'p_payload': payload},
    );
    return InspectionSyncResult.fromRpc(response);
  }
}
