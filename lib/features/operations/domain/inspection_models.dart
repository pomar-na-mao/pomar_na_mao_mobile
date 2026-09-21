import 'dart:convert';

class OccurrenceType {
  const OccurrenceType({
    required this.id,
    required this.name,
    required this.code,
  });
  final String id;
  final String name;
  final String code;
  factory OccurrenceType.fromJson(Map<String, dynamic> json) => OccurrenceType(
    id: json['id'] as String,
    name: json['name'] as String,
    code: json['code'] as String,
  );
  Map<String, dynamic> toJson() => {'id': id, 'name': name, 'code': code};
}

class InspectionPlant {
  InspectionPlant({
    required this.id,
    this.latitude,
    this.longitude,
    this.description,
    this.zoneId,
    Set<String> openTypeIds = const {},
    this.eligible = true,
    this.nonExistent = false,
  }) : openTypeIds = Set.unmodifiable(openTypeIds);
  final String id;
  final double? latitude;
  final double? longitude;
  final String? description;
  final String? zoneId;
  final Set<String> openTypeIds;
  final bool eligible;
  final bool nonExistent;
  bool get hasValidCoordinates =>
      latitude != null &&
      longitude != null &&
      latitude!.isFinite &&
      longitude!.isFinite &&
      latitude!.abs() <= 90 &&
      longitude!.abs() <= 180;
  String get label => description?.trim().isNotEmpty == true
      ? description!
      : 'Planta ${id.substring(0, id.length < 8 ? id.length : 8)}';
  InspectionPlant withState(Set<String> types, {bool? eligible}) =>
      InspectionPlant(
        id: id,
        latitude: latitude,
        longitude: longitude,
        description: description,
        zoneId: zoneId,
        openTypeIds: types,
        eligible: eligible ?? this.eligible,
        nonExistent: nonExistent,
      );
  factory InspectionPlant.fromJson(Map<String, dynamic> json) =>
      InspectionPlant(
        id: json['id'] as String,
        latitude: (json['latitude'] as num?)?.toDouble(),
        longitude: (json['longitude'] as num?)?.toDouble(),
        description: json['description'] as String?,
        zoneId: json['zone_id'] as String?,
        eligible: json['eligible'] as bool? ?? true,
        nonExistent: json['non_existent'] as bool? ?? false,
        openTypeIds: (json['openTypeIds'] as List<dynamic>? ?? [])
            .cast<String>()
            .toSet(),
      );
  Map<String, dynamic> toJson() => {
    'id': id,
    'latitude': latitude,
    'longitude': longitude,
    'description': description,
    'zone_id': zoneId,
    'non_existent': nonExistent,
    'openTypeIds': openTypeIds.toList(),
    'eligible': eligible,
  };
}

class InspectionSnapshot {
  InspectionSnapshot({
    required List<InspectionPlant> plants,
    required List<OccurrenceType> types,
    required DateTime loadedAt,
  }) : plants = List.unmodifiable(plants),
       types = List.unmodifiable(types),
       loadedAt = loadedAt.toUtc();
  final List<InspectionPlant> plants;
  final List<OccurrenceType> types;
  final DateTime loadedAt;
}

enum InspectionSyncStatus { pending, syncing, error, synced }

class InspectionChange {
  InspectionChange({
    required this.id,
    required this.plantId,
    required this.typeId,
    required this.added,
    required this.sequence,
    required DateTime changedAt,
    this.latitude,
    this.longitude,
    this.accuracy,
    this.distance,
  }) : changedAt = changedAt.toUtc();
  final String id;
  final String plantId;
  final String typeId;
  final bool added;
  final int sequence;
  final DateTime changedAt;
  final double? latitude;
  final double? longitude;
  final double? accuracy;
  final double? distance;
  Map<String, dynamic> toPayload() => {
    'localChangeId': id,
    'occurrenceTypeId': typeId,
    'changeType': added ? 'add_occurrence' : 'remove_occurrence',
    'changedAt': changedAt.toIso8601String(),
    if (latitude != null) 'latitude': latitude,
    if (longitude != null) 'longitude': longitude,
    if (accuracy != null) 'gpsAccuracyM': accuracy,
    if (distance != null) 'distanceToPlantMeters': distance,
  };
}

class LocalInspection {
  LocalInspection({
    required this.id,
    required DateTime startedAt,
    DateTime? finishedAt,
    required this.status,
    required this.plantsCount,
    required this.changesCount,
    this.error,
    this.remoteId,
    DateTime? syncedAt,
    this.payloadJson,
  }) : startedAt = startedAt.toUtc(),
       finishedAt = finishedAt?.toUtc(),
       syncedAt = syncedAt?.toUtc();
  final String id;
  final DateTime startedAt;
  final DateTime? finishedAt;
  final InspectionSyncStatus status;
  final int plantsCount;
  final int changesCount;
  final String? error;
  final String? remoteId;
  final DateTime? syncedAt;
  final String? payloadJson;
  bool get isDraft => finishedAt == null;
  Map<String, dynamic> get payload =>
      jsonDecode(payloadJson!) as Map<String, dynamic>;

  bool get isNetworkError {
    if (error == null) return false;
    final lower = error!.toLowerCase();
    return lower.contains('sem internet') ||
        lower.contains('socketexception') ||
        lower.contains('failed host lookup') ||
        lower.contains('network') ||
        lower.contains('clientexception') ||
        lower.contains('offline') ||
        lower.contains('sem conexão') ||
        lower.contains('sem conexao') ||
        lower.contains('connection refused') ||
        lower.contains('connection reset') ||
        lower.contains('connection timed out') ||
        lower.contains('timeoutexception') ||
        lower.contains('handshakeexception') ||
        lower.contains('unreachable');
  }

  String? get displayErrorMessage {
    if (error == null) return null;
    if (isNetworkError) {
      return 'Sem internet';
    }
    return error;
  }

  String get statusLabel => isDraft
      ? 'Em andamento'
      : switch (status) {
          InspectionSyncStatus.pending => 'Pendente',
          InspectionSyncStatus.syncing => 'Enviando',
          InspectionSyncStatus.error => 'Erro no envio',
          InspectionSyncStatus.synced => 'Sincronizada',
        };
}

class InspectionSyncResult {
  const InspectionSyncResult({
    required this.operationId,
    required this.created,
    required this.updated,
    required this.resolved,
  });
  final String operationId;
  final int created;
  final int updated;
  final int resolved;
  factory InspectionSyncResult.fromRpc(Object? response) {
    if (response is! List || response.length != 1 || response.single is! Map) {
      throw const FormatException('Resposta de sincronização inválida');
    }
    final row = response.single as Map;
    final id = row['field_operation_id'];
    final counts = [
      'created_occurrences_count',
      'updated_occurrences_count',
      'resolved_occurrences_count',
    ].map((key) => row[key]).toList();
    if (id is! String || id.isEmpty || counts.any((n) => n is! int || n < 0)) {
      throw const FormatException('Contrato de sincronização incompatível');
    }
    return InspectionSyncResult(
      operationId: id,
      created: counts[0] as int,
      updated: counts[1] as int,
      resolved: counts[2] as int,
    );
  }
}
