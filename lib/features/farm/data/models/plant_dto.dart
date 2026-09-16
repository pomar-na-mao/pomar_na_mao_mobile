import '../../domain/plant.dart';

class PlantDto {
  const PlantDto({
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

  factory PlantDto.fromJson(Map<String, dynamic> json) {
    return PlantDto(
      id: json['id'] as String,
      latitude: (json['latitude'] as num).toDouble(),
      longitude: (json['longitude'] as num).toDouble(),
      location: json['location'],
      gpsTimestamp: (json['gps_timestamp'] as num?)?.toInt(),
      varietyId: (json['variety_id'] as num?)?.toInt(),
      zoneId: json['zone_id'] as String?,
      mass: json['mass'] as String?,
      harvest: json['harvest'] as String?,
      description: json['description'] as String?,
      plantingDate: _dateTimeOrNull(json['planting_date']),
      lifeOfTheTree: json['life_of_the_tree'] as String?,
      isDead: json['is_dead'] as bool? ?? false,
      isNew: json['is_new'] as bool? ?? false,
      nonExistent: json['non_existent'] as bool? ?? false,
      localId: json['local_id'] as String?,
      deviceId: json['device_id'] as String?,
      syncStatus: json['sync_status'] as String? ?? 'synced',
      syncedAt: _dateTimeOrNull(json['synced_at']),
      createdAt: _dateTimeOrNull(json['created_at']) ??
          DateTime.fromMillisecondsSinceEpoch(0),
      updatedAt: _dateTimeOrNull(json['updated_at']) ??
          DateTime.fromMillisecondsSinceEpoch(0),
    );
  }

  static DateTime? _dateTimeOrNull(Object? value) {
    return value is String ? DateTime.tryParse(value) : null;
  }

  Plant toDomain() => Plant(
        id: id,
        latitude: latitude,
        longitude: longitude,
        isDead: isDead,
        isNew: isNew,
        nonExistent: nonExistent,
        syncStatus: syncStatus,
        createdAt: createdAt,
        updatedAt: updatedAt,
        location: location,
        gpsTimestamp: gpsTimestamp,
        varietyId: varietyId,
        zoneId: zoneId,
        mass: mass,
        harvest: harvest,
        description: description,
        plantingDate: plantingDate,
        lifeOfTheTree: lifeOfTheTree,
        localId: localId,
        deviceId: deviceId,
        syncedAt: syncedAt,
      );
}
