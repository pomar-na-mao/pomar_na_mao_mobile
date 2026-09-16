import '../data/models/farm_point_dto.dart';

class FarmPoint {
  const FarmPoint({
    required this.id,
    required this.latitude,
    required this.longitude,
    required this.boundaryOrder,
  });

  final String id;
  final double latitude;
  final double longitude;
  final int boundaryOrder;

  factory FarmPoint.fromJson(Map<String, dynamic> json) =>
      FarmPointDto.fromJson(json).toDomain();
}
