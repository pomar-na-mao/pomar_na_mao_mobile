import '../../domain/zone.dart';

class ZoneDto {
  const ZoneDto({
    required this.id,
    required this.name,
    this.code,
    this.description,
  });

  final String id;
  final String name;
  final String? code;
  final String? description;

  factory ZoneDto.fromJson(Map<String, dynamic> json) {
    return ZoneDto(
      id: json['id'] as String,
      name: json['name'] as String,
      code: json['code'] as String?,
      description: json['description'] as String?,
    );
  }

  Zone toDomain() => Zone(
        id: id,
        name: name,
        code: code,
        description: description,
      );
}
