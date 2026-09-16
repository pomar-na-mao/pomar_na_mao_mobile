import '../data/models/zone_dto.dart';

class Zone {
  const Zone({
    required this.id,
    required this.name,
    this.code,
    this.description,
  });

  final String id;
  final String name;
  final String? code;
  final String? description;

  String get displayName {
    final trimmedCode = code?.trim();
    if (trimmedCode == null || trimmedCode.isEmpty) return name;
    return '$name ($trimmedCode)';
  }

  factory Zone.fromJson(Map<String, dynamic> json) =>
      ZoneDto.fromJson(json).toDomain();
}
