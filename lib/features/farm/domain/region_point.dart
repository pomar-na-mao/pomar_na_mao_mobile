import '../data/models/region_point_dto.dart';

class RegionPoint {
  const RegionPoint({
    required this.latitude,
    required this.longitude,
    this.region,
    this.zoneId,
  });

  final double latitude;
  final double longitude;
  final String? region;
  final String? zoneId;

  factory RegionPoint.fromJson(Map<String, dynamic> json) =>
      RegionPointDto.fromJson(json).toDomain();
}
