import 'package:supabase_flutter/supabase_flutter.dart';

const sharedPlantColumns =
    'id, latitude, longitude, description, zone_id, non_existent';

typedef PlantPageLoader = Future<List<Map<String, dynamic>>> Function(
  int from,
  int to,
);

Future<List<Map<String, dynamic>>> fetchAllPlantPages(
  PlantPageLoader loadPage, {
  int pageSize = 1000,
}) async {
  final allRows = <Map<String, dynamic>>[];
  var from = 0;
  while (true) {
    final rows = await loadPage(from, from + pageSize - 1);
    allRows.addAll(rows);
    if (rows.length < pageSize) return allRows;
    from += pageSize;
  }
}

abstract interface class FarmRemoteDataSource {
  Future<List<Map<String, dynamic>>> fetchFarmBoundaryRows();
  Future<List<Map<String, dynamic>>> fetchPlantsRows({int pageSize = 1000});
  Future<List<Map<String, dynamic>>> fetchZonesRows();
  Future<List<Map<String, dynamic>>> fetchRegionsRows(String zoneId);
}

class SupabaseFarmRemoteDataSource implements FarmRemoteDataSource {
  const SupabaseFarmRemoteDataSource(this._client);

  final SupabaseClient _client;

  @override
  Future<List<Map<String, dynamic>>> fetchFarmBoundaryRows() async {
    final rows = await _client
        .from('farm')
        .select('id, latitude, longitude, order')
        .order('order');
    return List<Map<String, dynamic>>.from(rows);
  }

  @override
  Future<List<Map<String, dynamic>>> fetchPlantsRows({int pageSize = 1000}) =>
      fetchAllPlantPages((from, to) async {
        final rows = await _client
            .from('plants')
            .select(sharedPlantColumns)
            .order('id')
            .range(from, to);
        return List<Map<String, dynamic>>.from(rows);
      }, pageSize: pageSize);

  @override
  Future<List<Map<String, dynamic>>> fetchZonesRows() async {
    final rows = await _client.from('zones').select().order('name');
    return List<Map<String, dynamic>>.from(rows);
  }

  @override
  Future<List<Map<String, dynamic>>> fetchRegionsRows(String zoneId) async {
    final rows = await _client
        .from('regions')
        .select('latitude, longitude, region, zone_id')
        .eq('zone_id', zoneId)
        .order('order', ascending: true);
    return List<Map<String, dynamic>>.from(rows);
  }
}
