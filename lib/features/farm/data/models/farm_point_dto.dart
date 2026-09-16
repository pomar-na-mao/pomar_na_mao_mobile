import '../../domain/farm_point.dart';

class FarmPointDto {
  const FarmPointDto({
    required this.id,
    required this.latitude,
    required this.longitude,
    required this.boundaryOrder,
  });

  final String id;
  final double latitude;
  final double longitude;
  final int boundaryOrder;

  factory FarmPointDto.fromJson(Map<String, dynamic> json) {
    return FarmPointDto(
      id: json['id'].toString(),
      latitude: (json['latitude'] as num).toDouble(),
      longitude: (json['longitude'] as num).toDouble(),
      boundaryOrder: (json['order'] as num).toInt(),
    );
  }

  FarmPoint toDomain() => FarmPoint(
        id: id,
        latitude: latitude,
        longitude: longitude,
        boundaryOrder: boundaryOrder,
      );
}
