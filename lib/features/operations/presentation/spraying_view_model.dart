import 'dart:async';

import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';

import '../../farm/data/supabase_zones_repository.dart';
import '../../farm/domain/region_point.dart';
import '../../farm/domain/user_location.dart';
import '../../farm/domain/zone.dart';
import '../../farm/domain/zones_repository.dart';
import '../../farm/presentation/farm_map_geometry.dart';
import '../data/inspection_repository.dart';
import '../data/spraying_repository.dart';
import '../domain/inspection_models.dart';
import '../domain/spraying_geometry_service.dart';
import '../domain/spraying_location_filter.dart';
import '../domain/spraying_models.dart';
import 'inspection_view_model.dart';

class SprayingViewModel extends ChangeNotifier {
  SprayingViewModel({
    required this.sprayingRepository,
    required this.locationService,
    required this.inspectionRepository,
    this.zonesRepository,
    this.geometryService = const SprayingGeometryService(),
  }) {
    unawaited(loadZones());
    unawaited(loadLocalOperations());
  }

  final SprayingRepository sprayingRepository;
  final InspectionRepository inspectionRepository;
  final LocationService locationService;
  final SprayingGeometryService geometryService;
  ZonesRepository? zonesRepository;

  // --- Zonas ---
  List<Zone> _zones = const [];
  List<Zone> get zones => _zones;

  String? _selectedZoneFilterId;
  String? get selectedZoneFilterId => _selectedZoneFilterId;

  List<RegionPoint> _selectedZonePoints = const [];
  List<RegionPoint> get selectedZonePoints => _selectedZonePoints;

  final Map<String, List<RegionPoint>> _zoneRegionsCache = {};

  bool get isFiltered => _selectedZoneFilterId != null;

  Set<Polygon> get polygons {
    final zoneId = _selectedZoneFilterId;
    if (zoneId == null || _selectedZonePoints.length < 3) {
      return const {};
    }
    return buildFarmPolygons(
      farmPoints: const [],
      zonePoints: _selectedZonePoints,
      zoneId: zoneId,
    );
  }

  // --- Localização ---
  UserLocation? _userLocation;
  UserLocation? get userLocation => _userLocation;
  final SprayingLocationFilter _locationFilter = SprayingLocationFilter();

  StreamSubscription<LocationResult>? _locationSubscription;
  bool _isLocationActive = false;
  bool get isLocationActive => _isLocationActive;

  // --- Plantas ---
  InspectionLoadStatus _loadStatus = InspectionLoadStatus.initial;
  InspectionLoadStatus get loadStatus => _loadStatus;

  List<InspectionPlant> _allPlants = const [];
  List<InspectionPlant> get allPlants => _allPlants;

  Map<String, InspectionPlant>? _plantsById;
  InspectionPlant? plantById(String id) {
    _plantsById ??= {for (final p in _allPlants) p.id: p};
    return _plantsById![id];
  }

  List<InspectionPlant> get displayedPlants {
    if (_selectedZoneFilterId == null) {
      return _allPlants;
    }
    return _allPlants.where((p) => p.zoneId == _selectedZoneFilterId).toList();
  }

  // --- Sessão de Pulverização ---
  SprayingSessionState _sessionState = SprayingSessionState.idle;
  SprayingSessionState get sessionState => _sessionState;

  SprayingOperation? _currentOperation;
  SprayingOperation? get currentOperation => _currentOperation;

  SprayingOperation? _reviewingOperation;
  SprayingOperation? get reviewingOperation => _reviewingOperation;
  bool get isReviewing => _reviewingOperation != null;

  List<SprayingTrackPoint> _activeTrackPoints = [];
  List<SprayingTrackPoint> get activeTrackPoints =>
      List.unmodifiable(_activeTrackPoints);

  double _totalDistanceMeters = 0.0;
  double get totalDistanceMeters => _totalDistanceMeters;

  // Plantas confirmadas/revisadas para a operação atual ou em revisão
  List<SprayingConfirmedPlant> _reviewedPlants = [];
  List<SprayingConfirmedPlant> get reviewedPlants =>
      List.unmodifiable(_reviewedPlants);

  Set<String> get reviewedPlantIds =>
      _reviewedPlants.map((p) => p.plantId).toSet();

  // Histórico de pulverizações salvas
  List<SprayingOperation> _localOperations = const [];
  List<SprayingOperation> get localOperations => _localOperations;

  bool _isSyncing = false;
  bool get isSyncing => _isSyncing;

  String? _feedbackMessage;
  String? get feedbackMessage => _feedbackMessage;

  String? _errorMessage;
  String? get errorMessage => _errorMessage;

  void clearMessages() {
    _feedbackMessage = null;
    _errorMessage = null;
    notifyListeners();
  }

  // --- Rascunho persistido do modal de Registro de Insumos (SprayingInputsModal) ---
  String? draftOperatorName;
  String? draftMachineName;
  String? draftTractorIdentifier;
  String? draftTitle;
  String? draftNotes;
  List<SprayingInput> draftInputs = [];
  String draftInputType = 'fungicide';
  String draftProductName = '';
  String draftActiveIngredient = '';
  String draftDose = '';
  String draftDoseUnit = '';
  String draftTotalQuantity = '';
  String draftTotalQuantityUnit = '';
  String draftInputNotes = '';

  void resetInputsDraft() {
    draftOperatorName = null;
    draftMachineName = null;
    draftTractorIdentifier = null;
    draftTitle = null;
    draftNotes = null;
    draftInputs = [];
    draftInputType = 'fungicide';
    draftProductName = '';
    draftActiveIngredient = '';
    draftDose = '';
    draftDoseUnit = '';
    draftTotalQuantity = '';
    draftTotalQuantityUnit = '';
    draftInputNotes = '';
  }

  // --- Polylines da Rota ---
  Set<Polyline> get polylines {
    if (_sessionState == SprayingSessionState.recording ||
        _sessionState == SprayingSessionState.paused) {
      final points = _activeTrackPoints
          .map((tp) => LatLng(tp.latitude, tp.longitude))
          .toList();

      if (points.length < 2) return const {};

      return {
        Polyline(
          polylineId: const PolylineId('spraying_active_route'),
          color: const Color(0xFF16A34A), // Green primary
          width: 6,
          patterns: <PatternItem>[PatternItem.dot, PatternItem.gap(10)],
          jointType: JointType.round,
          startCap: Cap.roundCap,
          endCap: Cap.roundCap,
          points: points,
        ),
      };
    }
    if (_reviewingOperation != null) {
      final pts = _reviewingOperation!.trackPoints;
      if (pts.length >= 2) {
        return {
          Polyline(
            polylineId: const PolylineId('spraying_review_route'),
            color: const Color(0xFF2563EB), // Blue review route
            width: 6,
            patterns: <PatternItem>[PatternItem.dot, PatternItem.gap(10)],
            jointType: JointType.round,
            startCap: Cap.roundCap,
            endCap: Cap.roundCap,
            points: pts.map((tp) => LatLng(tp.latitude, tp.longitude)).toList(),
          ),
        };
      }
    }
    return const {};
  }

  // --- Inicialização de Zonas ---
  Future<void> loadZones({ZonesRepository? repo}) async {
    var effectiveRepo = repo ?? zonesRepository;
    if (effectiveRepo == null) {
      try {
        final client = Supabase.instance.client;
        effectiveRepo = SupabaseZonesRepository(client);
        zonesRepository = effectiveRepo;
      } catch (_) {}
    }
    if (effectiveRepo == null) return;
    try {
      final fetched = await effectiveRepo.fetchZones();
      _zones = List<Zone>.from(fetched)
        ..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
      notifyListeners();
    } catch (e) {
      debugPrint('Erro ao carregar zonas: $e');
    }
  }

  // --- Filtro de Zona ---
  Future<void> setZoneFilter(String? zoneId) async {
    _selectedZoneFilterId = zoneId;
    _selectedZonePoints = const [];

    if (zoneId != null) {
      if (_zoneRegionsCache.containsKey(zoneId)) {
        _selectedZonePoints = _zoneRegionsCache[zoneId]!;
      } else {
        final effectiveRepo = zonesRepository;
        if (effectiveRepo != null) {
          try {
            final points = await effectiveRepo.fetchRegionsForZone(zoneId);
            _zoneRegionsCache[zoneId] = points;
            if (_selectedZoneFilterId == zoneId) {
              _selectedZonePoints = points;
            }
          } catch (e) {
            debugPrint('Erro ao carregar pontos da zona $zoneId: $e');
          }
        }
      }
    }

    notifyListeners();
  }

  // --- Carregamento de Plantas ---
  Future<void> loadPlants({bool forceRemote = false}) async {
    _loadStatus = InspectionLoadStatus.loading;
    _errorMessage = null;
    notifyListeners();

    try {
      final snapshot = await inspectionRepository.loadSnapshot(
        forceRemote: forceRemote,
      );
      _plantsById = null;
      if (snapshot == null || snapshot.plants.isEmpty) {
        _allPlants = const [];
        _loadStatus = InspectionLoadStatus.empty;
      } else {
        _allPlants = snapshot.plants;
        _loadStatus = InspectionLoadStatus.success;
      }
    } catch (e) {
      _loadStatus = InspectionLoadStatus.error;
      _errorMessage = 'Falha ao carregar plantas: $e';
    }
    notifyListeners();
  }

  // --- Rastreamento de Localização GPS ---
  void startLocationTracking() {
    if (_isLocationActive) return;
    _isLocationActive = true;
    _locationSubscription = locationService.watchLocation().listen((result) {
      if (result.availability == LocationAvailability.available &&
          result.location != null) {
        final accepted = _locationFilter.add(result.location!);
        if (accepted == null) return;
        _userLocation = accepted;
        if (_sessionState == SprayingSessionState.recording) {
          _recordTrackPoint(accepted);
        }
        notifyListeners();
      }
    });
  }

  void stopLocationTracking() {
    _locationSubscription?.cancel();
    _locationSubscription = null;
    _isLocationActive = false;
  }

  void _recordTrackPoint(UserLocation loc) {
    if (loc.accuracy == null || loc.accuracy! > 12) return;

    if (_activeTrackPoints.isNotEmpty) {
      final last = _activeTrackPoints.last;
      final dist = geometryService.haversineDistanceMeters(
        last.latitude,
        last.longitude,
        loc.latitude,
        loc.longitude,
      );
      if (dist < 2.5) return;
    }

    final tp = SprayingTrackPoint(
      localId: const Uuid().v4(),
      recordedAt: loc.timestamp?.toUtc() ?? DateTime.now().toUtc(),
      latitude: loc.latitude,
      longitude: loc.longitude,
      accuracyM: loc.accuracy,
    );

    _activeTrackPoints.add(tp);
    _totalDistanceMeters = geometryService.calculateTotalDistanceMeters(
      _activeTrackPoints,
    );

    if (_currentOperation != null) {
      unawaited(
        sprayingRepository.addTrackPoint(_currentOperation!.localId, tp),
      );
    }
    notifyListeners();
  }

  // --- Ciclo da Sessão de Pulverização ---

  /// Inicia uma nova sessão de pulverização.
  Future<void> startSession({
    String? zoneId,
    String? operatorName,
    String? title,
    String? machineName,
    String? tractorIdentifier,
    String? notes,
  }) async {
    final opId = const Uuid().v4();
    final now = DateTime.now().toUtc();
    final resolvedZoneId =
        zoneId ??
        _selectedZoneFilterId ??
        (_zones.isNotEmpty ? _zones.first.id : 'geral');
    final resolvedOperator =
        (operatorName != null && operatorName.trim().isNotEmpty)
        ? operatorName.trim()
        : 'Operador';

    _currentOperation = SprayingOperation(
      localId: opId,
      zoneId: resolvedZoneId,
      startedAt: now,
      finishedAt: now,
      operatorName: resolvedOperator,
      title: title,
      machineName: machineName,
      tractorIdentifier: tractorIdentifier,
      notes: notes,
      syncStatus: SprayingSyncStatus.draft,
    );

    _activeTrackPoints = [];
    _totalDistanceMeters = 0.0;
    _reviewedPlants = [];
    _sessionState = SprayingSessionState.recording;

    await sprayingRepository.saveOperation(_currentOperation!);

    if (_userLocation != null &&
        _userLocation!.timestamp != null &&
        DateTime.now().toUtc().difference(_userLocation!.timestamp!.toUtc()) <
            const Duration(seconds: 5)) {
      _recordTrackPoint(_userLocation!);
    }

    notifyListeners();
  }

  /// Pausa a gravação da rota.
  void pauseSession() {
    if (_sessionState == SprayingSessionState.recording) {
      _sessionState = SprayingSessionState.paused;
      notifyListeners();
    }
  }

  /// Retoma a gravação da rota pausada.
  void resumeSession() {
    if (_sessionState == SprayingSessionState.paused) {
      _sessionState = SprayingSessionState.recording;
      notifyListeners();
    }
  }

  /// Finaliza a gravação da rota e salva a operação localmente em modo offline (sem chamar RPC).
  Future<void> finishSession() async {
    if (_sessionState != SprayingSessionState.recording &&
        _sessionState != SprayingSessionState.paused) {
      return;
    }

    final wasRecording = _sessionState == SprayingSessionState.recording;
    _sessionState = SprayingSessionState.finished;
    final now = DateTime.now().toUtc();

    if (_currentOperation != null) {
      // Garante captura do ponto final se houver localização atual
      if (wasRecording &&
          _userLocation != null &&
          _userLocation!.timestamp != null &&
          now.difference(_userLocation!.timestamp!.toUtc()) <
              const Duration(seconds: 5)) {
        if (_activeTrackPoints.isEmpty) {
          _recordTrackPoint(_userLocation!);
        } else {
          final last = _activeTrackPoints.last;
          final dist = geometryService.haversineDistanceMeters(
            last.latitude,
            last.longitude,
            _userLocation!.latitude,
            _userLocation!.longitude,
          );
          if (dist >= 1.0) {
            _recordTrackPoint(_userLocation!);
          }
        }
      }

      // Persiste em lote todos os pontos acumulados em memória
      await sprayingRepository.addTrackPoints(
        _currentOperation!.localId,
        _activeTrackPoints,
      );

      final routeId = const Uuid().v4();
      final geojson = geometryService.buildLineStringGeoJson(
        _activeTrackPoints,
      );
      final dist = geometryService.calculateTotalDistanceMeters(
        _activeTrackPoints,
      );

      final route = SprayingRoute(
        localId: routeId,
        geojson: geojson,
        distanceMeters: dist,
        startedAt: _currentOperation!.startedAt,
        finishedAt: now,
      );

      _currentOperation = _currentOperation!.copyWith(
        finishedAt: now,
        route: route,
        trackPoints: _activeTrackPoints,
        syncStatus: SprayingSyncStatus.draft,
      );

      await sprayingRepository.saveRoute(_currentOperation!.localId, route);
      await sprayingRepository.saveOperation(_currentOperation!);

      _feedbackMessage = 'Pulverização finalizada e salva localmente! Abra a lista de pulverizações para revisar e sincronizar.';
      _sessionState = SprayingSessionState.idle;
      _currentOperation = null;
      _activeTrackPoints = [];
      _reviewedPlants = [];

      await loadLocalOperations();
    }

    notifyListeners();
  }

  /// Inicia o modo de revisão para uma operação específica salva localmente.
  /// Chama a RPC ou cálculo offline para determinar plantas afetadas e carrega a rota.
  Future<void> startReviewingOperation(SprayingOperation op) async {
    _reviewingOperation = op;
    _errorMessage = null;

    if (_allPlants.isEmpty) {
      await loadPlants();
    }

    if (op.confirmedPlants.isNotEmpty) {
      _reviewedPlants = List.from(op.confirmedPlants);
    } else {
      try {
        final calculated = await sprayingRepository.calculateAffectedPlants(
          operation: op,
          candidatePlants: displayedPlants,
          maxDistanceMeters: 9.0,
        );
        _reviewedPlants = List.from(calculated);
        await sprayingRepository.saveConfirmedPlants(
          op.localId,
          _reviewedPlants,
        );
      } catch (e) {
        _errorMessage = 'Erro ao determinar plantas afetadas: $e';
      }
    }

    // Carrega rascunhos de insumos se houver
    if (op.inputs.isNotEmpty) {
      draftInputs = List.from(op.inputs);
    }
    if (op.operatorName.isNotEmpty) draftOperatorName = op.operatorName;
    if (op.machineName != null) draftMachineName = op.machineName;
    if (op.tractorIdentifier != null) {
      draftTractorIdentifier = op.tractorIdentifier;
    }
    if (op.title != null) draftTitle = op.title;
    if (op.notes != null) draftNotes = op.notes;

    _feedbackMessage =
        '${_reviewedPlants.length} plantas afetadas identificadas e marcadas em azul!';
    notifyListeners();
  }

  /// Cancela o modo de revisão ativo.
  void cancelReviewing() {
    _reviewingOperation = null;
    _reviewedPlants = [];
    resetInputsDraft();
    notifyListeners();
  }

  /// Alterna a marcação de uma planta afetada na revisão manual.
  void toggleAffectedPlant(InspectionPlant plant) {
    final existingIdx = _reviewedPlants.indexWhere(
      (p) => p.plantId == plant.id,
    );

    if (existingIdx >= 0) {
      // Remove da lista
      _reviewedPlants.removeAt(existingIdx);
    } else {
      // Adiciona manualmente
      _reviewedPlants.add(
        SprayingConfirmedPlant(
          localId: const Uuid().v4(),
          plantId: plant.id,
          matchSource: SprayingMatchSource.manualAdded,
          matchedAt: DateTime.now().toUtc(),
          notes: 'Adicionada manualmente pelo operador',
        ),
      );
    }

    if (_reviewingOperation != null) {
      unawaited(
        sprayingRepository.saveConfirmedPlants(
          _reviewingOperation!.localId,
          _reviewedPlants,
        ),
      );
    }

    notifyListeners();
  }

  /// Salva os insumos e finaliza a revisão, deixando a operação pronta para sincronização.
  Future<void> saveInputsAndComplete({
    required List<SprayingInput> inputs,
    String? operatorName,
    String? title,
    String? machineName,
    String? tractorIdentifier,
    String? notes,
  }) async {
    final targetOp = _reviewingOperation ?? _currentOperation;
    if (targetOp == null) return;

    if (inputs.isEmpty) {
      _errorMessage = 'Ao menos um insumo agrícola é obrigatório';
      notifyListeners();
      return;
    }

    final opId = targetOp.localId;
    await sprayingRepository.saveInputs(opId, inputs);
    await sprayingRepository.saveConfirmedPlants(opId, _reviewedPlants);

    final updatedOp = targetOp.copyWith(
      operatorName: operatorName ?? targetOp.operatorName,
      title: title ?? targetOp.title,
      machineName: machineName ?? targetOp.machineName,
      tractorIdentifier: tractorIdentifier ?? targetOp.tractorIdentifier,
      notes: notes ?? targetOp.notes,
      syncStatus: SprayingSyncStatus.reviewed,
      inputs: inputs,
      confirmedPlants: _reviewedPlants,
    );

    await sprayingRepository.saveOperation(updatedOp);

    resetInputsDraft();

    _feedbackMessage =
        'Pulverização revisada com sucesso e pronta para sincronizar!';
    _sessionState = SprayingSessionState.idle;
    _currentOperation = null;
    _reviewingOperation = null;
    _activeTrackPoints = [];
    _reviewedPlants = [];

    await loadLocalOperations();
    notifyListeners();
  }

  /// Descarta a sessão atual em andamento.
  Future<void> cancelSession() async {
    if (_currentOperation != null) {
      await sprayingRepository.deleteOperation(_currentOperation!.localId);
    }
    resetInputsDraft();
    _sessionState = SprayingSessionState.idle;
    _currentOperation = null;
    _activeTrackPoints = [];
    _reviewedPlants = [];
    notifyListeners();
  }

  // --- Operações Locais e Sincronização ---
  Future<void> loadLocalOperations() async {
    try {
      _localOperations = await sprayingRepository.listOperations();
      notifyListeners();
    } catch (e) {
      debugPrint('Erro ao listar operações locais: $e');
    }
  }

  Future<bool> syncOperation(String operationLocalId) async {
    _isSyncing = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final result = await sprayingRepository.syncOperation(operationLocalId);
      _feedbackMessage =
          'Sincronizado com sucesso! (${result.confirmedPlantsCount} plantas, ${result.inputsCount} insumos)';
      await loadLocalOperations();
      _isSyncing = false;
      notifyListeners();
      return true;
    } catch (e) {
      _isSyncing = false;
      _errorMessage = 'Falha ao sincronizar: $e';
      await loadLocalOperations();
      notifyListeners();
      return false;
    }
  }

  Future<int> syncAllReviewedOperations() async {
    _isSyncing = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final syncedCount = await sprayingRepository.syncAllReviewed();
      _feedbackMessage =
          '$syncedCount pulverizações sincronizadas com sucesso!';
      await loadLocalOperations();
      _isSyncing = false;
      notifyListeners();
      return syncedCount;
    } catch (e) {
      _isSyncing = false;
      _errorMessage = 'Falha ao sincronizar pulverizações: $e';
      await loadLocalOperations();
      notifyListeners();
      return 0;
    }
  }

  Future<void> deleteLocalOperation(String operationLocalId) async {
    try {
      await sprayingRepository.deleteOperation(operationLocalId);
      await loadLocalOperations();
    } catch (e) {
      _errorMessage = 'Erro ao excluir operação: $e';
      notifyListeners();
    }
  }

  @override
  void dispose() {
    stopLocationTracking();
    super.dispose();
  }
}
