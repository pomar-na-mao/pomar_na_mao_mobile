enum HarvestForecastClassification {
  n('N', 'Nenhuma'),
  p('P', 'Pequena'),
  m('M', 'Média'),
  g('G', 'Grande'),
  gg('GG', 'Muito grande');

  const HarvestForecastClassification(this.code, this.label);

  final String code;
  final String label;

  static HarvestForecastClassification parse(String code) {
    final normalized = code.trim().toUpperCase();
    return values.firstWhere(
      (item) => item.code == normalized,
      orElse: () => throw FormatException(
        'Classificação de previsão de safra inválida: $code',
      ),
    );
  }
}

enum HarvestForecastSyncStatus { pending, syncing, error, synced }

class HarvestForecastMarking {
  HarvestForecastMarking({
    required this.localId,
    required this.latitude,
    required this.longitude,
    required this.classification,
    required DateTime createdAt,
    this.status = HarvestForecastSyncStatus.pending,
    this.error,
    this.remoteId,
    this.remotePlantId,
    this.remoteZoneId,
    DateTime? syncedAt,
  }) : createdAt = createdAt.toUtc(),
       syncedAt = syncedAt?.toUtc() {
    if (localId.trim().isEmpty) {
      throw ArgumentError.value(localId, 'localId', 'Informe o localId');
    }
    if (!latitude.isFinite || latitude < -90 || latitude > 90) {
      throw ArgumentError.value(latitude, 'latitude', 'Latitude inválida');
    }
    if (!longitude.isFinite || longitude < -180 || longitude > 180) {
      throw ArgumentError.value(longitude, 'longitude', 'Longitude inválida');
    }
  }

  final String localId;
  final double latitude;
  final double longitude;
  final HarvestForecastClassification classification;
  final DateTime createdAt;
  final HarvestForecastSyncStatus status;
  final String? error;
  final String? remoteId;
  final String? remotePlantId;
  final String? remoteZoneId;
  final DateTime? syncedAt;

  Map<String, dynamic> toPayload() => {
    'localMarkingId': localId,
    'latitude': latitude,
    'longitude': longitude,
    'classification': classification.code,
    'createdAt': createdAt.toIso8601String(),
  };

  Map<String, Object?> toRow() => {
    'local_id': localId,
    'latitude': latitude,
    'longitude': longitude,
    'classification': classification.code,
    'created_at': createdAt.toIso8601String(),
    'sync_status': status.name,
    'error': error,
    'remote_id': remoteId,
    'remote_plant_id': remotePlantId,
    'remote_zone_id': remoteZoneId,
    'synced_at': syncedAt?.toIso8601String(),
  };

  factory HarvestForecastMarking.fromRow(Map<String, Object?> row) =>
      HarvestForecastMarking(
        localId: row['local_id']! as String,
        latitude: (row['latitude']! as num).toDouble(),
        longitude: (row['longitude']! as num).toDouble(),
        classification: HarvestForecastClassification.parse(
          row['classification']! as String,
        ),
        createdAt: DateTime.parse(row['created_at']! as String),
        status: HarvestForecastSyncStatus.values.byName(
          row['sync_status']! as String,
        ),
        error: row['error'] as String?,
        remoteId: row['remote_id'] as String?,
        remotePlantId: row['remote_plant_id'] as String?,
        remoteZoneId: row['remote_zone_id'] as String?,
        syncedAt: row['synced_at'] == null
            ? null
            : DateTime.parse(row['synced_at']! as String),
      );

  HarvestForecastMarking copyWith({
    HarvestForecastClassification? classification,
    HarvestForecastSyncStatus? status,
    String? error,
    bool clearError = false,
    String? remoteId,
    String? remotePlantId,
    String? remoteZoneId,
    bool clearRemoteZoneId = false,
    DateTime? syncedAt,
    bool clearSyncedAt = false,
  }) => HarvestForecastMarking(
    localId: localId,
    latitude: latitude,
    longitude: longitude,
    classification: classification ?? this.classification,
    createdAt: createdAt,
    status: status ?? this.status,
    error: clearError ? null : error ?? this.error,
    remoteId: remoteId ?? this.remoteId,
    remotePlantId: remotePlantId ?? this.remotePlantId,
    remoteZoneId: clearRemoteZoneId ? null : remoteZoneId ?? this.remoteZoneId,
    syncedAt: clearSyncedAt ? null : syncedAt ?? this.syncedAt,
  );
}

class HarvestForecastSyncResult {
  const HarvestForecastSyncResult({
    required this.localMarkingId,
    required this.id,
    required this.plantId,
    this.zoneId,
    required this.syncedAt,
  });

  final String localMarkingId;
  final String id;
  final String plantId;
  final String? zoneId;
  final DateTime syncedAt;

  factory HarvestForecastSyncResult.fromJson(Map<String, dynamic> json) =>
      HarvestForecastSyncResult(
        localMarkingId: (json['localMarkingId'] ?? json['local_marking_id'])
            as String,
        id: json['id'] as String,
        plantId: (json['plantId'] ?? json['plant_id']) as String,
        zoneId: (json['zoneId'] ?? json['zone_id']) as String?,
        syncedAt: DateTime.parse(
          (json['syncedAt'] ??
                  json['synced_at'] ??
                  json['updatedAt'] ??
                  json['updated_at'])
              as String,
        ).toUtc(),
      );

  static List<HarvestForecastSyncResult> listFromRpc(Object? response) {
    final rows = switch (response) {
      final List<dynamic> list => list,
      {'markings': final List<dynamic> list} => list,
      _ => throw const FormatException(
        'Resposta inválida da sincronização de Previsão de Safra',
      ),
    };
    return rows
        .map(
          (row) => HarvestForecastSyncResult.fromJson(
            Map<String, dynamic>.from(row as Map),
          ),
        )
        .toList(growable: false);
  }
}
