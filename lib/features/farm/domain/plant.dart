import '../data/models/plant_dto.dart';

class Plant {
  const Plant({
    required this.id,
    required this.latitude,
    required this.longitude,
    required this.isDead,
    required this.isNew,
    required this.nonExistent,
    required this.syncStatus,
    required this.createdAt,
    required this.updatedAt,
    this.location,
    this.gpsTimestamp,
    this.varietyId,
    this.zoneId,
    this.mass,
    this.harvest,
    this.description,
    this.plantingDate,
    this.lifeOfTheTree,
    this.localId,
    this.deviceId,
    this.syncedAt,
  });

  final String id;
  final double latitude;
  final double longitude;
  final Object? location;
  final int? gpsTimestamp;
  final int? varietyId;
  final String? zoneId;
  final String? mass;
  final String? harvest;
  final String? description;
  final DateTime? plantingDate;
  final String? lifeOfTheTree;
  final bool isDead;
  final bool isNew;
  final bool nonExistent;
  final String? localId;
  final String? deviceId;
  final String syncStatus;
  final DateTime? syncedAt;
  final DateTime createdAt;
  final DateTime updatedAt;

  factory Plant.fromJson(Map<String, dynamic> json) =>
      PlantDto.fromJson(json).toDomain();
}
