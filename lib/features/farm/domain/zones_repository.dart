import 'region_point.dart';
import 'zone.dart';

abstract interface class ZonesRepository {
  Future<List<Zone>> fetchZones();
  Future<List<RegionPoint>> fetchRegionsForZone(String zoneId);
}
