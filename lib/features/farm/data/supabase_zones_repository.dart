import 'package:supabase_flutter/supabase_flutter.dart';

import '../domain/region_point.dart';
import '../domain/zone.dart';
import '../domain/zones_repository.dart';
import 'datasources/farm_remote_data_source.dart';
import 'models/region_point_dto.dart';
import 'models/zone_dto.dart';

class SupabaseZonesRepository implements ZonesRepository {
  SupabaseZonesRepository(
    SupabaseClient client, {
    FarmRemoteDataSource? remoteDataSource,
  }) : this.fromDataSource(
          remoteDataSource ?? SupabaseFarmRemoteDataSource(client),
        );

  const SupabaseZonesRepository.fromDataSource(this._remoteDataSource);

  final FarmRemoteDataSource _remoteDataSource;

  @override
  Future<List<Zone>> fetchZones() async {
    final rows = await _remoteDataSource.fetchZonesRows();
    return rows
        .map((row) => ZoneDto.fromJson(row).toDomain())
        .toList(growable: false);
  }

  @override
  Future<List<RegionPoint>> fetchRegionsForZone(String zoneId) async {
    final rows = await _remoteDataSource.fetchRegionsRows(zoneId);
    return rows
        .map((row) => RegionPointDto.fromJson(row).toDomain())
        .toList(growable: false);
  }
}
