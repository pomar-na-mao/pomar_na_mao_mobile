import 'dart:convert';

import 'inspection_models.dart';

enum MipdPlantPart {
  leaf('LEAF', 'Folha'),
  branch('BRANCH', 'Ramo'),
  trunk('TRUNK', 'Tronco'),
  root('ROOT', 'Raiz'),
  fruit('FRUIT', 'Fruto');

  const MipdPlantPart(this.value, this.label);

  final String value;
  final String label;

  static MipdPlantPart parse(String value) => values.firstWhere(
    (part) => part.value == value,
    orElse: () => throw FormatException('Parte da planta inválida: $value'),
  );
}

enum MipdSyncStatus { pending, syncing, error, synced }

class MipdMarking {
  MipdMarking({
    required this.localId,
    required this.plantId,
    required this.occurrenceTypeId,
    required Iterable<MipdPlantPart> plantParts,
    required DateTime observedAt,
    this.localPhotoPath,
    this.remotePhotoPath,
    this.status = MipdSyncStatus.pending,
    this.error,
    this.remoteOperationId,
    this.remoteOccurrenceId,
    this.remoteMarkingId,
    DateTime? syncedAt,
  }) : plantParts = Set.unmodifiable(plantParts),
       observedAt = observedAt.toUtc(),
       syncedAt = syncedAt?.toUtc() {
    if (this.plantParts.isEmpty) {
      throw ArgumentError.value(plantParts, 'plantParts', 'Informe uma parte');
    }
  }

  final String localId;
  final String plantId;
  final String occurrenceTypeId;
  final Set<MipdPlantPart> plantParts;
  final DateTime observedAt;
  final String? localPhotoPath;
  final String? remotePhotoPath;
  final MipdSyncStatus status;
  final String? error;
  final String? remoteOperationId;
  final String? remoteOccurrenceId;
  final String? remoteMarkingId;
  final DateTime? syncedAt;

  Map<String, dynamic> toPayload() => {
    'localMarkingId': localId,
    'plantId': plantId,
    'occurrenceTypeId': occurrenceTypeId,
    'plantParts': plantParts.map((part) => part.value).toList()..sort(),
    'observedAt': observedAt.toIso8601String(),
    if (remotePhotoPath != null) 'photoObjectPath': remotePhotoPath,
  };

  Map<String, Object?> toRow() => {
    'local_id': localId,
    'plant_id': plantId,
    'occurrence_type_id': occurrenceTypeId,
    'plant_parts': jsonEncode(
      plantParts.map((part) => part.value).toList()..sort(),
    ),
    'observed_at': observedAt.toIso8601String(),
    'local_photo_path': localPhotoPath,
    'remote_photo_path': remotePhotoPath,
    'sync_status': status.name,
    'error': error,
    'remote_operation_id': remoteOperationId,
    'remote_occurrence_id': remoteOccurrenceId,
    'remote_marking_id': remoteMarkingId,
    'synced_at': syncedAt?.toIso8601String(),
  };

  factory MipdMarking.fromRow(Map<String, Object?> row) => MipdMarking(
    localId: row['local_id']! as String,
    plantId: row['plant_id']! as String,
    occurrenceTypeId: row['occurrence_type_id']! as String,
    plantParts: (jsonDecode(row['plant_parts']! as String) as List<dynamic>)
        .cast<String>()
        .map(MipdPlantPart.parse),
    observedAt: DateTime.parse(row['observed_at']! as String),
    localPhotoPath: row['local_photo_path'] as String?,
    remotePhotoPath: row['remote_photo_path'] as String?,
    status: MipdSyncStatus.values.byName(row['sync_status']! as String),
    error: row['error'] as String?,
    remoteOperationId: row['remote_operation_id'] as String?,
    remoteOccurrenceId: row['remote_occurrence_id'] as String?,
    remoteMarkingId: row['remote_marking_id'] as String?,
    syncedAt: row['synced_at'] == null
        ? null
        : DateTime.parse(row['synced_at']! as String),
  );

  MipdMarking copyWith({
    String? remotePhotoPath,
    bool clearRemotePhotoPath = false,
    MipdSyncStatus? status,
    String? error,
    bool clearError = false,
    String? remoteOperationId,
    String? remoteOccurrenceId,
    String? remoteMarkingId,
    DateTime? syncedAt,
  }) => MipdMarking(
    localId: localId,
    plantId: plantId,
    occurrenceTypeId: occurrenceTypeId,
    plantParts: plantParts,
    observedAt: observedAt,
    localPhotoPath: localPhotoPath,
    remotePhotoPath: clearRemotePhotoPath
        ? null
        : remotePhotoPath ?? this.remotePhotoPath,
    status: status ?? this.status,
    error: clearError ? null : error ?? this.error,
    remoteOperationId: remoteOperationId ?? this.remoteOperationId,
    remoteOccurrenceId: remoteOccurrenceId ?? this.remoteOccurrenceId,
    remoteMarkingId: remoteMarkingId ?? this.remoteMarkingId,
    syncedAt: syncedAt ?? this.syncedAt,
  );
}

class MipdSyncResult {
  const MipdSyncResult({
    required this.localMarkingId,
    required this.operationId,
    required this.occurrenceId,
    required this.markingId,
    required this.syncedAt,
  });

  final String localMarkingId;
  final String operationId;
  final String occurrenceId;
  final String markingId;
  final DateTime syncedAt;

  factory MipdSyncResult.fromJson(Map<String, dynamic> json) => MipdSyncResult(
    localMarkingId: json['localMarkingId'] as String,
    operationId: json['operationId'] as String,
    occurrenceId: json['occurrenceId'] as String,
    markingId: json['markingId'] as String,
    syncedAt: DateTime.parse(json['syncedAt'] as String).toUtc(),
  );

  static List<MipdSyncResult> listFromRpc(Object? response) {
    final rows = switch (response) {
      final List<dynamic> list => list,
      {'markings': final List<dynamic> list} => list,
      _ => throw const FormatException(
        'Resposta inválida da sincronização MIPD',
      ),
    };
    return rows
        .map(
          (row) =>
              MipdSyncResult.fromJson(Map<String, dynamic>.from(row as Map)),
        )
        .toList(growable: false);
  }
}

void validatePestDiseaseType(OccurrenceType type) {
  if (!type.isPestDisease) {
    throw ArgumentError.value(
      type.category,
      'occurrenceType',
      'A marcação MIPD aceita somente PEST_DISEASE',
    );
  }
}
