import 'package:supabase_flutter/supabase_flutter.dart';

const sharedPlantColumns =
    'id, latitude, longitude, description, zone_id, non_existent';

typedef PlantPageLoader = Future<List<Map<String, dynamic>>> Function(
  int from,
  int to,
);

typedef RowStableKey = Object Function(Map<String, dynamic> row);

Future<List<Map<String, dynamic>>> fetchAllPlantPages(
  PlantPageLoader loadPage, {
  int pageSize = 1000,
  RowStableKey stableKey = _rowIdKey,
}) async {
  final allRows = <Map<String, dynamic>>[];
  final seenKeys = <Object>{};
  var from = 0;
  while (true) {
    final rows = await loadPage(from, from + pageSize - 1);
    if (rows.isEmpty) return allRows;
    for (final row in rows) {
      final key = stableKey(row);
      if (!seenKeys.add(key)) {
        throw StateError('Pagina remota repetiu o registro "$key".');
      }
    }
    allRows.addAll(rows);
    from += rows.length;
  }
}

Object _rowIdKey(Map<String, dynamic> row) {
  final id = row['id'];
  if (id == null) {
    throw StateError('Pagina remota sem coluna id para paginacao estavel.');
  }
  return id;
}

abstract interface class FarmRemoteDataSource {
  Future<List<Map<String, dynamic>>> fetchFarmBoundaryRows();
  Future<List<Map<String, dynamic>>> fetchPlantRowsPage({
    required int from,
    required int to,
  });
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
  Future<List<Map<String, dynamic>>> fetchPlantRowsPage({
    required int from,
    required int to,
  }) async {
    final rows = await _client
        .from('plants')
        .select(sharedPlantColumns)
        .order('id')
        .range(from, to);
    return List<Map<String, dynamic>>.from(rows);
  }

  @override
  Future<List<Map<String, dynamic>>> fetchPlantsRows({int pageSize = 1000}) =>
      fetchAllPlantPages(
        (from, to) => fetchPlantRowsPage(from: from, to: to),
        pageSize: pageSize,
      );

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
