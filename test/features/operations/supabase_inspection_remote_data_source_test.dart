import 'package:flutter_test/flutter_test.dart';
import 'package:pomar_na_mao_mobile/core/config/app_config.dart';
import 'package:pomar_na_mao_mobile/features/operations/data/inspection_remote_data_source.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

void main() {
  test('SupabaseInspectionRemoteDataSource exposes dedicated added plants rpc name', () {
    final client = SupabaseClient(
      AppConfig.supabaseUrl,
      AppConfig.supabasePublishableKey,
    );
    final remoteDataSource = SupabaseInspectionRemoteDataSource(
      client,
      addedPlantsRpcName: 'custom_added_plants_rpc',
    );

    expect(remoteDataSource.rpcName, 'sync_manual_inspection_v2');
    expect(remoteDataSource.addedPlantsRpcName, 'custom_added_plants_rpc');
  });

  test(
    'fetchOccurrenceTypes and fetchPlants from Supabase',
    () async {
    final client = SupabaseClient(
      AppConfig.supabaseUrl,
      AppConfig.supabasePublishableKey,
    );

    final remoteDataSource = SupabaseInspectionRemoteDataSource(client);

    final types = await remoteDataSource.fetchOccurrenceTypes();
    final pestDiseaseRows = await client
        .from('occurrence_types')
        .select('id')
        .eq('category', 'PEST_DISEASE');
    final pestDiseaseIds = (pestDiseaseRows as List<dynamic>)
        .map((row) => (row as Map<String, dynamic>)['id'] as String)
        .toSet();
    expect(types, isNotEmpty);
    expect(types.any((t) => t.code.isNotEmpty), isTrue);
    expect(
      types.map((type) => type.id),
      everyElement(isNot(isIn(pestDiseaseIds))),
    );

    final plants = await remoteDataSource.fetchPlants(pageSize: 50);
    expect(plants, isNotEmpty);
    expect(plants.any((p) => p.hasValidCoordinates), isTrue);
  }, timeout: const Timeout(Duration(seconds: 90)));
}
