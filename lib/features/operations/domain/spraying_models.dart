import 'dart:convert';

/// Estado do ciclo de gravação da rota de pulverização no dispositivo.
enum SprayingSessionState {
  idle,
  recording,
  paused,
  finished,
}

/// Estado de sincronização e ciclo de vida da operação local.
enum SprayingSyncStatus {
  draft,
  reviewed,
  syncing,
  synced,
  error;

  static SprayingSyncStatus fromString(String? value) {
    switch (value) {
      case 'reviewed':
        return SprayingSyncStatus.reviewed;
      case 'syncing':
        return SprayingSyncStatus.syncing;
      case 'synced':
        return SprayingSyncStatus.synced;
      case 'error':
        return SprayingSyncStatus.error;
      case 'draft':
      default:
        return SprayingSyncStatus.draft;
    }
  }

  String toDbValue() => name;
}

/// Origem de inclusão da planta na operação de pulverização.
enum SprayingMatchSource {
  autoMatched('auto_matched'),
  manualAdded('manual_added');

  const SprayingMatchSource(this.value);
  final String value;

  static SprayingMatchSource fromString(String? val) {
    if (val == 'manual_added') return SprayingMatchSource.manualAdded;
    return SprayingMatchSource.autoMatched;
  }
}

/// Ponto geográfico de rastreamento da rota da máquina/trator.
class SprayingTrackPoint {
  const SprayingTrackPoint({
    required this.localId,
    required this.recordedAt,
    required this.latitude,
    required this.longitude,
    this.speedMps,
    this.accuracyM,
  });

  final String localId;
  final DateTime recordedAt;
  final double latitude;
  final double longitude;
  final double? speedMps;
  final double? accuracyM;

  Map<String, dynamic> toJson() => {
    'localId': localId,
    'recordedAt': recordedAt.toUtc().toIso8601String(),
    'latitude': latitude,
    'longitude': longitude,
    if (speedMps != null) 'speedMps': speedMps,
    if (accuracyM != null) 'accuracyM': accuracyM,
  };

  factory SprayingTrackPoint.fromJson(Map<String, dynamic> json) =>
      SprayingTrackPoint(
        localId: json['localId'] as String? ?? json['local_id'] as String,
        recordedAt: DateTime.parse(
          json['recordedAt'] as String? ?? json['recorded_at'] as String,
        ),
        latitude: (json['latitude'] as num).toDouble(),
        longitude: (json['longitude'] as num).toDouble(),
        speedMps: (json['speedMps'] ?? json['speed_mps'] as num?)?.toDouble(),
        accuracyM: (json['accuracyM'] ?? json['accuracy_m'] as num?)
            ?.toDouble(),
      );
}

/// Geometria e métricas da rota percorrida na pulverização.
class SprayingRoute {
  const SprayingRoute({
    required this.localId,
    required this.geojson,
    required this.distanceMeters,
    required this.startedAt,
    required this.finishedAt,
  });

  final String localId;
  final Map<String, dynamic> geojson;
  final double distanceMeters;
  final DateTime startedAt;
  final DateTime finishedAt;

  Map<String, dynamic> toJson() => {
    'localId': localId,
    'geojson': geojson,
    'distanceMeters': distanceMeters,
    'startedAt': startedAt.toUtc().toIso8601String(),
    'finishedAt': finishedAt.toUtc().toIso8601String(),
  };

  factory SprayingRoute.fromJson(Map<String, dynamic> json) {
    final rawGeo = json['geojson'];
    final Map<String, dynamic> parsedGeo;
    if (rawGeo is String) {
      parsedGeo = jsonDecode(rawGeo) as Map<String, dynamic>;
    } else {
      parsedGeo = Map<String, dynamic>.from(rawGeo as Map);
    }

    return SprayingRoute(
      localId: json['localId'] as String? ?? json['local_id'] as String,
      geojson: parsedGeo,
      distanceMeters:
          (json['distanceMeters'] ?? json['distance_meters'] as num).toDouble(),
      startedAt: DateTime.parse(
        json['startedAt'] as String? ?? json['started_at'] as String,
      ),
      finishedAt: DateTime.parse(
        json['finishedAt'] as String? ?? json['finished_at'] as String,
      ),
    );
  }
}

/// Insumo agrícola aplicado na calda/pulverização.
class SprayingInput {
  const SprayingInput({
    required this.localId,
    required this.inputType,
    required this.productName,
    this.activeIngredient,
    this.dose,
    this.doseUnit,
    this.totalQuantity,
    this.totalQuantityUnit,
    this.notes,
  });

  final String localId;
  final String inputType;
  final String productName;
  final String? activeIngredient;
  final double? dose;
  final String? doseUnit;
  final double? totalQuantity;
  final String? totalQuantityUnit;
  final String? notes;

  Map<String, dynamic> toJson() => {
    'localId': localId,
    'inputType': inputType,
    'productName': productName,
    if (activeIngredient != null && activeIngredient!.isNotEmpty)
      'activeIngredient': activeIngredient,
    if (dose != null) 'dose': dose,
    if (doseUnit != null && doseUnit!.isNotEmpty) 'doseUnit': doseUnit,
    if (totalQuantity != null) 'totalQuantity': totalQuantity,
    if (totalQuantityUnit != null && totalQuantityUnit!.isNotEmpty)
      'totalQuantityUnit': totalQuantityUnit,
    if (notes != null && notes!.isNotEmpty) 'notes': notes,
  };

  factory SprayingInput.fromJson(Map<String, dynamic> json) => SprayingInput(
    localId: json['localId'] as String? ?? json['local_id'] as String,
    inputType: json['inputType'] as String? ?? json['input_type'] as String,
    productName:
        json['productName'] as String? ?? json['product_name'] as String,
    activeIngredient:
        json['activeIngredient'] as String? ??
        json['active_ingredient'] as String?,
    dose: (json['dose'] as num?)?.toDouble(),
    doseUnit: json['doseUnit'] as String? ?? json['dose_unit'] as String?,
    totalQuantity:
        (json['totalQuantity'] ?? json['total_quantity'] as num?)?.toDouble(),
    totalQuantityUnit:
        json['totalQuantityUnit'] as String? ??
        json['total_quantity_unit'] as String?,
    notes: json['notes'] as String?,
  );
}

/// Registro de planta afetada/confirmada na pulverização.
class SprayingConfirmedPlant {
  const SprayingConfirmedPlant({
    required this.localId,
    required this.plantId,
    required this.matchSource,
    this.matchedAt,
    this.nearestTrackPointLocalId,
    this.distanceMeters,
    this.notes,
  });

  final String localId;
  final String plantId;
  final SprayingMatchSource matchSource;
  final DateTime? matchedAt;
  final String? nearestTrackPointLocalId;
  final double? distanceMeters;
  final String? notes;

  Map<String, dynamic> toJson() => {
    'localId': localId,
    'plantId': plantId,
    'matchSource': matchSource.value,
    if (matchedAt != null) 'matchedAt': matchedAt!.toUtc().toIso8601String(),
    if (nearestTrackPointLocalId != null && nearestTrackPointLocalId!.isNotEmpty)
      'nearestTrackPointLocalId': nearestTrackPointLocalId,
    if (distanceMeters != null) 'distanceMeters': distanceMeters,
    if (notes != null && notes!.isNotEmpty) 'notes': notes,
  };

  factory SprayingConfirmedPlant.fromJson(Map<String, dynamic> json) =>
      SprayingConfirmedPlant(
        localId: json['localId'] as String? ?? json['local_id'] as String,
        plantId: json['plantId'] as String? ?? json['plant_id'] as String,
        matchSource: SprayingMatchSource.fromString(
          json['matchSource'] as String? ?? json['match_source'] as String?,
        ),
        matchedAt: json['matchedAt'] != null
            ? DateTime.parse(json['matchedAt'] as String)
            : json['matched_at'] != null
            ? DateTime.parse(json['matched_at'] as String)
            : null,
        nearestTrackPointLocalId:
            json['nearestTrackPointLocalId'] as String? ??
            json['nearest_track_point_local_id'] as String?,
        distanceMeters:
            (json['distanceMeters'] ?? json['distance_meters'] as num?)
                ?.toDouble(),
        notes: json['notes'] as String?,
      );
}

/// Operação de pulverização consolidada.
class SprayingOperation {
  const SprayingOperation({
    required this.localId,
    required this.zoneId,
    required this.startedAt,
    required this.finishedAt,
    required this.operatorName,
    this.title,
    this.machineName,
    this.tractorIdentifier,
    this.notes,
    this.syncStatus = SprayingSyncStatus.draft,
    this.remoteFieldOperationId,
    this.syncedAt,
    this.route,
    this.trackPoints = const [],
    this.inputs = const [],
    this.confirmedPlants = const [],
  });

  final String localId;
  final String zoneId;
  final DateTime startedAt;
  final DateTime finishedAt;
  final String operatorName;
  final String? title;
  final String? machineName;
  final String? tractorIdentifier;
  final String? notes;
  final SprayingSyncStatus syncStatus;
  final String? remoteFieldOperationId;
  final DateTime? syncedAt;

  final SprayingRoute? route;
  final List<SprayingTrackPoint> trackPoints;
  final List<SprayingInput> inputs;
  final List<SprayingConfirmedPlant> confirmedPlants;

  SprayingOperation copyWith({
    String? localId,
    String? zoneId,
    DateTime? startedAt,
    DateTime? finishedAt,
    String? operatorName,
    String? title,
    String? machineName,
    String? tractorIdentifier,
    String? notes,
    SprayingSyncStatus? syncStatus,
    String? remoteFieldOperationId,
    DateTime? syncedAt,
    SprayingRoute? route,
    List<SprayingTrackPoint>? trackPoints,
    List<SprayingInput>? inputs,
    List<SprayingConfirmedPlant>? confirmedPlants,
  }) => SprayingOperation(
    localId: localId ?? this.localId,
    zoneId: zoneId ?? this.zoneId,
    startedAt: startedAt ?? this.startedAt,
    finishedAt: finishedAt ?? this.finishedAt,
    operatorName: operatorName ?? this.operatorName,
    title: title ?? this.title,
    machineName: machineName ?? this.machineName,
    tractorIdentifier: tractorIdentifier ?? this.tractorIdentifier,
    notes: notes ?? this.notes,
    syncStatus: syncStatus ?? this.syncStatus,
    remoteFieldOperationId:
        remoteFieldOperationId ?? this.remoteFieldOperationId,
    syncedAt: syncedAt ?? this.syncedAt,
    route: route ?? this.route,
    trackPoints: trackPoints ?? this.trackPoints,
    inputs: inputs ?? this.inputs,
    confirmedPlants: confirmedPlants ?? this.confirmedPlants,
  );

  /// Serializa para o payload exato esperado pela RPC `sync_reviewed_spraying_operation`.
  Map<String, dynamic> toRpcPayload({required String deviceId}) {
    if (route == null) {
      throw StateError('A operação não possui rota associada');
    }
    return {
      'localOperationId': localId,
      'deviceId': deviceId,
      'operation': {
        'zoneId': zoneId,
        'startedAt': startedAt.toUtc().toIso8601String(),
        'finishedAt': finishedAt.toUtc().toIso8601String(),
        'operatorName': operatorName,
        if (title != null && title!.isNotEmpty) 'title': title,
        if (machineName != null && machineName!.isNotEmpty)
          'machineName': machineName,
        if (tractorIdentifier != null && tractorIdentifier!.isNotEmpty)
          'tractorIdentifier': tractorIdentifier,
        if (notes != null && notes!.isNotEmpty) 'notes': notes,
      },
      'route': route!.toJson(),
      'trackPoints': trackPoints.map((tp) => tp.toJson()).toList(),
      'inputs': inputs.map((i) => i.toJson()).toList(),
      'confirmedPlants': confirmedPlants.map((cp) => cp.toJson()).toList(),
    };
  }
}

/// Resultado da execução da RPC `sync_reviewed_spraying_operation`.
class SprayingSyncResult {
  const SprayingSyncResult({
    required this.fieldOperationId,
    required this.routeId,
    required this.trackPointsCount,
    required this.inputsCount,
    required this.confirmedPlantsCount,
    required this.syncedAt,
  });

  final String fieldOperationId;
  final String routeId;
  final int trackPointsCount;
  final int inputsCount;
  final int confirmedPlantsCount;
  final DateTime syncedAt;

  factory SprayingSyncResult.fromRpc(dynamic response) {
    final Map<String, dynamic> map;
    if (response is List && response.isNotEmpty) {
      map = Map<String, dynamic>.from(response.first as Map);
    } else if (response is Map) {
      map = Map<String, dynamic>.from(response);
    } else {
      throw FormatException('Formato de resposta RPC inválido: $response');
    }

    return SprayingSyncResult(
      fieldOperationId:
          map['field_operation_id'] as String? ??
          map['fieldOperationId'] as String,
      routeId: map['route_id'] as String? ?? map['routeId'] as String,
      trackPointsCount:
          map['track_points_count'] as int? ??
          map['trackPointsCount'] as int? ??
          0,
      inputsCount:
          map['inputs_count'] as int? ?? map['inputsCount'] as int? ?? 0,
      confirmedPlantsCount:
          map['confirmed_plants_count'] as int? ??
          map['confirmedPlantsCount'] as int? ??
          0,
      syncedAt: DateTime.parse(
        map['synced_at'] as String? ?? map['syncedAt'] as String,
      ),
    );
  }
}
