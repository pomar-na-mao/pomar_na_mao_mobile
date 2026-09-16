import 'package:supabase_flutter/supabase_flutter.dart';

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
  Future<List<Map<String, dynamic>>> fetchPlantsRows({int pageSize = 1000}) async {
    const columns = 'id, latitude, longitude, zone_id, non_existent';
    final allRows = <Map<String, dynamic>>[];
    var from = 0;

    while (true) {
      final to = from + pageSize - 1;
      final rows = await _client
          .from('plants')
          .select(columns)
          .order('id')
          .range(from, to);

      allRows.addAll(List<Map<String, dynamic>>.from(rows));

      if (rows.length < pageSize) {
        break;
      }
      from += pageSize;
    }

    return allRows;
  }

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
        .order('created_at', ascending: true);
    return List<Map<String, dynamic>>.from(rows);
  }
}
