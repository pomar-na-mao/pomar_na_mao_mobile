import 'dart:collection';
import 'dart:convert';
import 'dart:math' as math;

enum ActivityGeometryType {
  route('route', 'Rota'),
  area('area', 'Área');

  const ActivityGeometryType(this.value, this.label);
  final String value;
  final String label;

  static ActivityGeometryType parse(String value) => values.firstWhere(
    (item) => item.value == value,
    orElse: () => throw FormatException('Tipo de geometria inválido: $value'),
  );
}

class ActivityPoint {
  const ActivityPoint(this.latitude, this.longitude);

  final double latitude;
  final double longitude;

  bool get isValid =>
      latitude.isFinite &&
      longitude.isFinite &&
      latitude >= -90 &&
      latitude <= 90 &&
      longitude >= -180 &&
      longitude <= 180;

  List<double> toCoordinate() => [longitude, latitude];

  factory ActivityPoint.fromCoordinate(Object? raw) {
    if (raw is! List || raw.length < 2) {
      throw const FormatException('Coordenada inválida');
    }
    final longitude = raw[0];
    final latitude = raw[1];
    if (latitude is! num || longitude is! num) {
      throw const FormatException('Coordenada inválida');
    }
    return ActivityPoint(latitude.toDouble(), longitude.toDouble());
  }

  double distanceMetersTo(ActivityPoint other) {
    const earthRadius = 6371000.0;
    final lat1 = latitude * math.pi / 180;
    final lat2 = other.latitude * math.pi / 180;
    final deltaLat = (other.latitude - latitude) * math.pi / 180;
    final deltaLng = (other.longitude - longitude) * math.pi / 180;
    final a =
        math.sin(deltaLat / 2) * math.sin(deltaLat / 2) +
        math.cos(lat1) *
            math.cos(lat2) *
            math.sin(deltaLng / 2) *
            math.sin(deltaLng / 2);
    return earthRadius * 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));
  }

  @override
  bool operator ==(Object other) =>
      other is ActivityPoint &&
      latitude == other.latitude &&
      longitude == other.longitude;

  @override
  int get hashCode => Object.hash(latitude, longitude);
}

class ActivityGeometry {
  ActivityGeometry({
    required this.type,
    required Iterable<ActivityPoint> points,
  }) : points = List.unmodifiable(points);

  factory ActivityGeometry.fromGeoJson(Map<String, dynamic> json) {
    final geoType = json['type'];
    final coordinates = json['coordinates'];
    if (geoType == 'LineString' && coordinates is List) {
      return ActivityGeometry(
        type: ActivityGeometryType.route,
        points: coordinates.map(ActivityPoint.fromCoordinate),
      );
    }
    if (geoType == 'Polygon' && coordinates is List && coordinates.isNotEmpty) {
      final ring = coordinates.first;
      if (ring is! List) throw const FormatException('Anel inválido');
      final parsed = ring.map(ActivityPoint.fromCoordinate).toList();
      if (parsed.length > 1 && parsed.first == parsed.last) parsed.removeLast();
      return ActivityGeometry(type: ActivityGeometryType.area, points: parsed);
    }
    throw const FormatException('GeoJSON deve ser LineString ou Polygon');
  }

  final ActivityGeometryType type;
  final List<ActivityPoint> points;

  String? validate() {
    if (points.length > ActivityGeometryBuilder.maxPoints) {
      return 'O desenho excede ${ActivityGeometryBuilder.maxPoints} pontos.';
    }
    if (points.any((point) => !point.isValid)) {
      return 'O desenho contém coordenadas inválidas.';
    }
    final minimum = type == ActivityGeometryType.route ? 2 : 3;
    if (points.length < minimum) {
      return type == ActivityGeometryType.route
          ? 'A rota precisa de pelo menos dois pontos.'
          : 'A área precisa de pelo menos três vértices e fechamento.';
    }
    for (var index = 1; index < points.length; index++) {
      if (points[index - 1].distanceMetersTo(points[index]) < 0.01) {
        return 'O desenho contém segmentos de comprimento nulo.';
      }
    }
    if (type == ActivityGeometryType.area) {
      if (points.last.distanceMetersTo(points.first) < 0.01) {
        return 'O desenho contém segmentos de comprimento nulo.';
      }
      if (_hasSelfIntersection(points)) {
        return 'A área possui cruzamentos. Ajuste ou refaça o desenho.';
      }
    }
    return null;
  }

  Map<String, dynamic> toGeoJson() {
    if (type == ActivityGeometryType.route) {
      return {
        'type': 'LineString',
        'coordinates': points.map((point) => point.toCoordinate()).toList(),
      };
    }
    return {
      'type': 'Polygon',
      'coordinates': [
        [
          ...points.map((point) => point.toCoordinate()),
          points.first.toCoordinate(),
        ],
      ],
    };
  }

  static bool _hasSelfIntersection(List<ActivityPoint> vertices) {
    final segments = <(ActivityPoint, ActivityPoint)>[
      for (var index = 0; index < vertices.length; index++)
        (vertices[index], vertices[(index + 1) % vertices.length]),
    ];
    for (var first = 0; first < segments.length; first++) {
      for (var second = first + 1; second < segments.length; second++) {
        if (second == first + 1 ||
            (first == 0 && second == segments.length - 1)) {
          continue;
        }
        if (_intersects(segments[first], segments[second])) return true;
      }
    }
    return false;
  }

  static bool _intersects(
    (ActivityPoint, ActivityPoint) a,
    (ActivityPoint, ActivityPoint) b,
  ) {
    double direction(ActivityPoint p, ActivityPoint q, ActivityPoint r) =>
        (q.longitude - p.longitude) * (r.latitude - p.latitude) -
        (q.latitude - p.latitude) * (r.longitude - p.longitude);

    final d1 = direction(a.$1, a.$2, b.$1);
    final d2 = direction(a.$1, a.$2, b.$2);
    final d3 = direction(b.$1, b.$2, a.$1);
    final d4 = direction(b.$1, b.$2, a.$2);
    return ((d1 > 0 && d2 < 0) || (d1 < 0 && d2 > 0)) &&
        ((d3 > 0 && d4 < 0) || (d3 < 0 && d4 > 0));
  }
}

class ActivityGeometryBuilder {
  ActivityGeometryBuilder({
    this.type = ActivityGeometryType.route,
    this.minimumSampleDistanceMeters = 0.5,
  });

  static const maxPoints = 2000;
  ActivityGeometryType type;
  final double minimumSampleDistanceMeters;
  final List<ActivityPoint> _points = [];

  List<ActivityPoint> get points => List.unmodifiable(_points);
  bool get isEmpty => _points.isEmpty;

  bool add(ActivityPoint point) {
    if (!point.isValid || _points.length >= maxPoints) return false;
    if (_points.isNotEmpty &&
        _points.last.distanceMetersTo(point) < minimumSampleDistanceMeters) {
      return false;
    }
    _points.add(point);
    return true;
  }

  void undo() {
    if (_points.isNotEmpty) _points.removeLast();
  }

  void clear() => _points.clear();

  void changeType(ActivityGeometryType next) {
    type = next;
    clear();
  }

  ActivityGeometry build() => ActivityGeometry(type: type, points: _points);
}

class FieldInputCatalogItem {
  const FieldInputCatalogItem({
    required this.id,
    required this.name,
    required this.type,
    this.activeIngredient,
    this.labelDose,
    this.doseUnit,
  });

  factory FieldInputCatalogItem.fromJson(Map<String, dynamic> json) {
    final id = json['id'];
    final name = json['name'];
    final type = json['type'];
    if (id is! String ||
        id.isEmpty ||
        name is! String ||
        name.isEmpty ||
        type is! String ||
        type.isEmpty) {
      throw const FormatException('Insumo remoto inválido');
    }
    return FieldInputCatalogItem(
      id: id,
      name: name,
      type: type,
      activeIngredient: json['active_ingredient'] as String?,
      labelDose: json['label_dose'] as String?,
      doseUnit: json['dose_unit'] as String?,
    );
  }

  final String id;
  final String name;
  final String type;
  final String? activeIngredient;
  final String? labelDose;
  final String? doseUnit;

  String get suggestedDose {
    final parts = <String>[];
    if (labelDose?.trim().isNotEmpty ?? false) parts.add(labelDose!.trim());
    if (doseUnit?.trim().isNotEmpty ?? false) parts.add(doseUnit!.trim());
    return parts.join(' ');
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'type': type,
    'active_ingredient': activeIngredient,
    'label_dose': labelDose,
    'dose_unit': doseUnit,
  };
}

class MixtureInputCatalogItem {
  const MixtureInputCatalogItem({
    required this.inputId,
    required this.name,
    required this.dose,
    this.activeIngredient,
    this.labelDose,
    this.doseUnit,
  });

  factory MixtureInputCatalogItem.fromJson(Map<String, dynamic> json) {
    final input = Map<String, dynamic>.from(json['input'] as Map? ?? const {});
    final inputId = json['input_id'] ?? input['id'];
    final name = input['name'];
    final dose = json['dose'];
    if (inputId is! String ||
        inputId.isEmpty ||
        name is! String ||
        name.trim().isEmpty ||
        dose is! String ||
        dose.trim().isEmpty) {
      throw const FormatException('Composição de calda inválida');
    }
    return MixtureInputCatalogItem(
      inputId: inputId,
      name: name.trim(),
      dose: dose.trim(),
      activeIngredient: input['active_ingredient'] as String?,
      labelDose: input['label_dose'] as String?,
      doseUnit: (json['dose_unit'] ?? input['dose_unit']) as String?,
    );
  }

  final String inputId;
  final String name;
  final String dose;
  final String? activeIngredient;
  final String? labelDose;
  final String? doseUnit;

  String get formattedDose => [
    dose,
    if (doseUnit?.trim().isNotEmpty ?? false) doseUnit!.trim(),
  ].join(' ');

  Map<String, dynamic> toJson() => {
    'input_id': inputId,
    'dose': dose,
    'dose_unit': doseUnit,
    'input': {
      'id': inputId,
      'name': name,
      'active_ingredient': activeIngredient,
      'label_dose': labelDose,
      'dose_unit': doseUnit,
    },
  };
}

class MixtureCatalogItem {
  MixtureCatalogItem({
    required this.id,
    required String name,
    required this.isActive,
    required Iterable<MixtureInputCatalogItem> inputs,
    this.observations,
  }) : name = name.trim(),
       inputs = UnmodifiableListView(inputs) {
    if (id.isEmpty || this.name.isEmpty || this.inputs.isEmpty) {
      throw const FormatException('Calda inválida');
    }
  }

  factory MixtureCatalogItem.fromJson(Map<String, dynamic> json) {
    final id = json['id'];
    final name = json['name'];
    final components = json['components'] ?? json['mixture_inputs'];
    if (id is! String || name is! String || components is! List) {
      throw const FormatException('Calda remota inválida');
    }
    return MixtureCatalogItem(
      id: id,
      name: name,
      isActive: json['is_active'] as bool? ?? true,
      observations: json['observations'] as String?,
      inputs: components.map(
        (item) => MixtureInputCatalogItem.fromJson(
          Map<String, dynamic>.from(item as Map),
        ),
      ),
    );
  }

  final String id;
  final String name;
  final bool isActive;
  final String? observations;
  final List<MixtureInputCatalogItem> inputs;

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'is_active': isActive,
    'observations': observations,
    'components': inputs.map((item) => item.toJson()).toList(),
  };
}

class MachineCatalogItem {
  MachineCatalogItem({
    required this.id,
    required String name,
    this.brand,
    this.acquisitionDate,
    this.manufacturingYear,
    this.quantity = 1,
    this.observations,
  }) : name = name.trim() {
    if (id.isEmpty || this.name.isEmpty || quantity < 1) {
      throw const FormatException('Máquina inválida');
    }
  }

  factory MachineCatalogItem.fromJson(Map<String, dynamic> json) {
    final id = json['id'];
    final name = json['name'];
    if (id is! String || name is! String) {
      throw const FormatException('Máquina remota inválida');
    }
    return MachineCatalogItem(
      id: id,
      name: name,
      brand: json['brand'] as String?,
      acquisitionDate: json['acquisition_date'] as String?,
      manufacturingYear: json['manufacturing_year'] as int?,
      quantity: json['quantity'] as int? ?? 1,
      observations: json['observations'] as String?,
    );
  }

  final String id;
  final String name;
  final String? brand;
  final String? acquisitionDate;
  final int? manufacturingYear;
  final int quantity;
  final String? observations;

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'brand': brand,
    'acquisition_date': acquisitionDate,
    'manufacturing_year': manufacturingYear,
    'quantity': quantity,
    'observations': observations,
  };
}

class ActivityInput {
  const ActivityInput({
    required this.localId,
    required this.inputId,
    required this.nameSnapshot,
    required this.appliedDose,
    this.activeIngredientSnapshot,
    this.labelDoseSnapshot,
    this.doseUnitSnapshot,
  });

  factory ActivityInput.fromCatalog(
    FieldInputCatalogItem item, {
    required String localId,
  }) => ActivityInput(
    localId: localId,
    inputId: item.id,
    nameSnapshot: item.name,
    activeIngredientSnapshot: item.activeIngredient,
    labelDoseSnapshot: item.labelDose,
    doseUnitSnapshot: item.doseUnit,
    appliedDose: item.suggestedDose,
  );

  final String localId;
  final String inputId;
  final String nameSnapshot;
  final String? activeIngredientSnapshot;
  final String? labelDoseSnapshot;
  final String? doseUnitSnapshot;
  final String appliedDose;

  ActivityInput copyWith({String? appliedDose}) => ActivityInput(
    localId: localId,
    inputId: inputId,
    nameSnapshot: nameSnapshot,
    activeIngredientSnapshot: activeIngredientSnapshot,
    labelDoseSnapshot: labelDoseSnapshot,
    doseUnitSnapshot: doseUnitSnapshot,
    appliedDose: appliedDose ?? this.appliedDose,
  );

  Map<String, dynamic> toPayload() => {
    'localId': localId,
    'inputId': inputId,
    'name': nameSnapshot,
    'activeIngredient': activeIngredientSnapshot,
    'labelDose': labelDoseSnapshot,
    'doseUnit': doseUnitSnapshot,
    'appliedDose': appliedDose.trim(),
  };
}

enum ActivitySyncStatus { pending, syncing, error, synced }

class ActivityEntry {
  ActivityEntry({
    required this.localId,
    required this.geometry,
    required String activity,
    required this.performedAt,
    required String responsible,
    this.mixtureId,
    this.mixtureNameSnapshot,
    this.machineId,
    this.machineNameSnapshot,
    this.machineBrandSnapshot,
    Iterable<ActivityInput> inputs = const [],
    this.syncStatus = ActivitySyncStatus.pending,
    this.error,
    this.remoteFieldOperationId,
    this.remoteEntryId,
    this.syncedAt,
  }) : activity = activity.trim(),
       responsible = responsible.trim(),
       inputs = UnmodifiableListView(inputs) {
    final geometryError = geometry.validate();
    if (geometryError != null) throw ArgumentError(geometryError);
    if (this.activity.isEmpty) throw ArgumentError('Atividade obrigatória');
    if (this.activity.length > 200) {
      throw ArgumentError('Atividade acima de 200 caracteres');
    }
    if (this.responsible.isEmpty) {
      throw ArgumentError('Responsável obrigatório');
    }
    if (this.responsible.length > 160) {
      throw ArgumentError('Responsável acima de 160 caracteres');
    }
    if ((mixtureId == null) != (mixtureNameSnapshot == null)) {
      throw ArgumentError('Referência de calda incompleta');
    }
    if (mixtureNameSnapshot != null && mixtureNameSnapshot!.trim().isEmpty) {
      throw ArgumentError('Nome da calda obrigatório');
    }
    if ((machineId == null) != (machineNameSnapshot == null)) {
      throw ArgumentError('Referência de máquina incompleta');
    }
    if (machineNameSnapshot != null && machineNameSnapshot!.trim().isEmpty) {
      throw ArgumentError('Nome da máquina obrigatório');
    }
    if (machineBrandSnapshot != null && machineId == null) {
      throw ArgumentError('Marca da máquina sem referência');
    }
    if (this.inputs.length > 100) throw ArgumentError('Máximo de 100 insumos');
    final ids = this.inputs.map((item) => item.inputId).toSet();
    if (ids.length != this.inputs.length) {
      throw ArgumentError('Insumo duplicado');
    }
    if (this.inputs.any((item) => item.appliedDose.trim().isEmpty)) {
      throw ArgumentError('Dose aplicada obrigatória para insumo selecionado');
    }
    if (this.inputs.any(
      (item) =>
          item.nameSnapshot.trim().isEmpty ||
          item.nameSnapshot.trim().length > 200 ||
          item.appliedDose.trim().length > 200,
    )) {
      throw ArgumentError('Snapshot ou dose do insumo inválido');
    }
  }

  final String localId;
  final ActivityGeometry geometry;
  final String activity;
  final DateTime performedAt;
  final String responsible;
  final String? mixtureId;
  final String? mixtureNameSnapshot;
  final String? machineId;
  final String? machineNameSnapshot;
  final String? machineBrandSnapshot;
  final List<ActivityInput> inputs;
  final ActivitySyncStatus syncStatus;
  final String? error;
  final String? remoteFieldOperationId;
  final String? remoteEntryId;
  final DateTime? syncedAt;

  Map<String, dynamic> toPayload() => {
    'localId': localId,
    'geometryType': geometry.type.value,
    'geometry': geometry.toGeoJson(),
    'activity': activity,
    'performedAt': performedAt.toUtc().toIso8601String(),
    'responsible': responsible,
    if (mixtureId != null) 'mixtureId': mixtureId,
    if (machineId != null) 'machineId': machineId,
    'inputs': mixtureId == null
        ? inputs.map((item) => item.toPayload()).toList()
        : const <Map<String, dynamic>>[],
  };

  String get canonicalPayload => jsonEncode(toPayload());

  ActivityEntry copyWith({
    ActivitySyncStatus? syncStatus,
    String? error,
    bool clearError = false,
    String? remoteFieldOperationId,
    String? remoteEntryId,
    DateTime? syncedAt,
  }) => ActivityEntry(
    localId: localId,
    geometry: geometry,
    activity: activity,
    performedAt: performedAt,
    responsible: responsible,
    mixtureId: mixtureId,
    mixtureNameSnapshot: mixtureNameSnapshot,
    machineId: machineId,
    machineNameSnapshot: machineNameSnapshot,
    machineBrandSnapshot: machineBrandSnapshot,
    inputs: inputs,
    syncStatus: syncStatus ?? this.syncStatus,
    error: clearError ? null : error ?? this.error,
    remoteFieldOperationId:
        remoteFieldOperationId ?? this.remoteFieldOperationId,
    remoteEntryId: remoteEntryId ?? this.remoteEntryId,
    syncedAt: syncedAt ?? this.syncedAt,
  );
}

class ActivitySyncResult {
  const ActivitySyncResult({
    required this.localId,
    required this.fieldOperationId,
    required this.entryId,
    required this.inputsCount,
    required this.syncedAt,
  });

  factory ActivitySyncResult.fromJson(Map<String, dynamic> json) =>
      ActivitySyncResult(
        localId: (json['local_id'] ?? json['localId']) as String,
        fieldOperationId:
            (json['field_operation_id'] ?? json['fieldOperationId']) as String,
        entryId: (json['entry_id'] ?? json['entryId']) as String,
        inputsCount: (json['inputs_count'] ?? json['inputsCount']) as int? ?? 0,
        syncedAt: DateTime.parse(
          (json['synced_at'] ?? json['syncedAt']) as String,
        ),
      );

  static List<ActivitySyncResult> listFromRpc(Object? response) {
    if (response is! List) throw const FormatException('Resposta RPC inválida');
    return response
        .map(
          (row) => ActivitySyncResult.fromJson(
            Map<String, dynamic>.from(row as Map),
          ),
        )
        .toList(growable: false);
  }

  final String localId;
  final String fieldOperationId;
  final String entryId;
  final int inputsCount;
  final DateTime syncedAt;
}

DateTime composeActivityDateTime(DateTime date, int hour, int minute) {
  if (hour < 0 || hour > 23 || minute < 0 || minute > 59) {
    throw ArgumentError('Hora inválida');
  }
  return DateTime(date.year, date.month, date.day, hour, minute);
}
