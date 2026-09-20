import 'package:flutter_test/flutter_test.dart';
import 'package:pomar_na_mao_mobile/core/config/app_config.dart';
import 'package:pomar_na_mao_mobile/features/operations/data/inspection_remote_data_source.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

void main() {
  test('fetchOccurrenceTypes and fetchPlants from Supabase', () async {
    final client = SupabaseClient(
      AppConfig.supabaseUrl,
      AppConfig.supabasePublishableKey,
    );

    final remoteDataSource = SupabaseInspectionRemoteDataSource(client);

    final types = await remoteDataSource.fetchOccurrenceTypes();
    expect(types, isNotEmpty);
    expect(types.any((t) => t.code.isNotEmpty), isTrue);

    final plants = await remoteDataSource.fetchPlants(pageSize: 50);
    expect(plants, isNotEmpty);
    expect(plants.any((p) => p.hasValidCoordinates), isTrue);
  });
}
