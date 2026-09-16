import '../../domain/region_point.dart';

class RegionPointDto {
  const RegionPointDto({
    required this.latitude,
    required this.longitude,
    this.region,
    this.zoneId,
  });

  final double latitude;
  final double longitude;
  final String? region;
  final String? zoneId;

  factory RegionPointDto.fromJson(Map<String, dynamic> json) {
    return RegionPointDto(
      latitude: (json['latitude'] as num).toDouble(),
      longitude: (json['longitude'] as num).toDouble(),
      region: json['region'] as String?,
      zoneId: json['zone_id'] as String?,
    );
  }

  RegionPoint toDomain() => RegionPoint(
        latitude: latitude,
        longitude: longitude,
        region: region,
        zoneId: zoneId,
      );
}
