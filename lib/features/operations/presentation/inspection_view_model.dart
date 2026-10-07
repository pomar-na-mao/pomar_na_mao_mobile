import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';

import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../farm/data/supabase_zones_repository.dart';
import '../../farm/domain/region_point.dart';
import '../../farm/domain/user_location.dart';
import '../../farm/domain/user_position_tracker.dart';
import '../../farm/domain/zone.dart';
import '../../farm/domain/zones_repository.dart';
import '../../farm/presentation/farm_map_geometry.dart';
import '../data/inspection_repository.dart';
import '../domain/inspection_models.dart';

enum InspectionLoadStatus { initial, loading, success, empty, error }

class AlteredPlantItem {
  const AlteredPlantItem({
    required this.plantId,
    required this.plantLabel,
    required this.changesSummary,
  });

  final String plantId;
  final String plantLabel;
  final List<String> changesSummary;
}

class InspectionViewModel extends ChangeNotifier {
  InspectionViewModel({
    required this.repository,
    required this.locationService,
    this.zonesRepository,
    Stream<void>? plantChanges,
  }) {
    _plantChangesSubscription = plantChanges?.listen((_) {
      if (_loadStatus == InspectionLoadStatus.loading) return;
      unawaited(_loadExistingSnapshotSilently());
    });
  }

  final InspectionRepository repository;
  final LocationService locationService;
  ZonesRepository? zonesRepository;

  void attachZonesRepository(ZonesRepository repo) {
    zonesRepository = repo;
    unawaited(loadZones());
  }

  List<Zone> _zones = const [];
  List<Zone> get zones => _zones;

  void setZones(List<Zone> zones) {
    _zones = zones;
    notifyListeners();
  }

  Future<void> loadZones({ZonesRepository? repo}) async {
    var effectiveRepo = repo ?? zonesRepository;
    if (effectiveRepo == null) {
      try {
        final client = Supabase.instance.client;
        effectiveRepo = SupabaseZonesRepository(client);
        zonesRepository = effectiveRepo;
      } catch (_) {
        // Supabase instance is not available (e.g. In unit tests)
      }
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

  StreamSubscription<LocationResult>? _locationSubscription;
  StreamSubscription<void>? _plantChangesSubscription;
  bool _isLocationActive = false;
  final UserPositionTracker _positionTracker = UserPositionTracker();

  InspectionLoadStatus _loadStatus = InspectionLoadStatus.initial;
  InspectionLoadStatus get loadStatus => _loadStatus;

  String? _errorMessage;
  String? get errorMessage => _errorMessage;

  String? _feedbackMessage;
  String? get feedbackMessage => _feedbackMessage;

  String? _diagnosticCode;
  String? get diagnosticCode => _diagnosticCode;

  String? _selectedOccurrenceFilterId;
  String? get selectedOccurrenceFilterId => _selectedOccurrenceFilterId;

  String? _selectedZoneFilterId;
  String? get selectedZoneFilterId => _selectedZoneFilterId;

  List<RegionPoint> _selectedZonePoints = const [];
  List<RegionPoint> get selectedZonePoints => _selectedZonePoints;

  final Map<String, List<RegionPoint>> _zoneRegionsCache = {};

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

  @visibleForTesting
  void setZonePoints(String zoneId, List<RegionPoint> points) {
    _zoneRegionsCache[zoneId] = points;
    if (_selectedZoneFilterId == zoneId) {
      _selectedZonePoints = points;
      notifyListeners();
    }
  }

  Zone? get selectedZoneFilter => _selectedZoneFilterId == null
      ? null
      : _zones.where((z) => z.id == _selectedZoneFilterId).firstOrNull;

  OccurrenceType? get selectedOccurrenceFilter =>
      _selectedOccurrenceFilterId == null
      ? null
      : _catalog.where((t) => t.id == _selectedOccurrenceFilterId).firstOrNull;

  bool get isFiltered =>
      _selectedOccurrenceFilterId != null || _selectedZoneFilterId != null;

  List<InspectionPlant> _plants = const [];
  List<InspectionPlant> get allPlants => _plants;
  List<InspectionPlant>? _indexedPlants;
  Map<String, InspectionPlant> _plantsById = {};
  InspectionPlant? plantById(String id) {
    if (!identical(_indexedPlants, _plants)) {
      _indexedPlants = _plants;
      _plantsById = {for (final plant in _plants) plant.id: plant};
    }
    return _plantsById[id];
  }

  Object? _filterKey;
  List<InspectionPlant> _filteredPlants = const [];

  List<InspectionPlant> get plants {
    final key = (_plants, _selectedZoneFilterId, _selectedOccurrenceFilterId);
    if (_filterKey == key) return _filteredPlants;
    _filterKey = key;
    return _filteredPlants = _plants.where((plant) {
      if (_selectedZoneFilterId != null &&
          plant.zoneId != _selectedZoneFilterId) {
        return false;
      }
      if (_selectedOccurrenceFilterId != null &&
          !plant.openTypeIds.contains(_selectedOccurrenceFilterId)) {
        return false;
      }
      return true;
    }).toList();
  }

  List<InspectionPlant> get filteredPlants => plants;

  List<OccurrenceType> _catalog = const [];
  List<OccurrenceType> get catalog => _catalog;

  InspectionPlant? _selectedPlant;
  InspectionPlant? get selectedPlant => _selectedPlant;

  Set<String> _stagedOccurrenceTypeIds = const {};
  Set<String> get stagedOccurrenceTypeIds => _stagedOccurrenceTypeIds;

  bool _stagedNonExistent = false;
  bool get stagedNonExistent => _stagedNonExistent;

  bool isOccurrenceChecked(String typeId) =>
      _stagedOccurrenceTypeIds.contains(typeId);

  bool get hasStagedChanges {
    if (_selectedPlant == null) return false;
    return !setEquals(_stagedOccurrenceTypeIds, _selectedPlant!.openTypeIds) ||
        _stagedNonExistent != _selectedPlant!.nonExistent;
  }

  List<LocalInspection> _localInspections = const [];
  List<LocalInspection> get localInspections => _localInspections;

  Map<String, List<InspectionChange>> _inspectionChanges = {};
  Map<String, List<InspectionChange>> get inspectionChanges =>
      _inspectionChanges;

  bool _isSavingLocal = false;
  bool get isSavingLocal => _isSavingLocal;

  bool _isSyncing = false;
  bool get isSyncing => _isSyncing;

  bool _isSyncingAddedPlants = false;
  bool get isSyncingAddedPlants => _isSyncingAddedPlants;

  List<AddedInspectionPlant> _addedPlants = const [];
  List<AddedInspectionPlant> get addedPlants => _addedPlants;

  LocationResult? _locationResult;
  LocationResult? get locationResult => _locationResult;
  UserLocation? get userLocation => _locationResult?.location;

  bool get canShowUserLocation =>
      _locationResult?.availability == LocationAvailability.available;

  String? get locationMessage => switch (_locationResult?.availability) {
    LocationAvailability.permissionDenied =>
      'Permita o acesso à localização para ver sua posição.',
    LocationAvailability.serviceDisabled =>
      'Ative o serviço de localização para ver sua posição.',
    LocationAvailability.error => 'Não foi possível obter sua localização.',
    LocationAvailability.available || null => null,
  };

  int get changedPlantsCountInCurrentDraft {
    final drafts = _localInspections.where((i) => i.isDraft);
    if (drafts.isEmpty) return 0;
    return drafts.first.plantsCount;
  }

  Future<void> initialize() async {
    await _loadExistingSnapshotSilently();
    await loadZones();
    await refreshLocalInspections();
    await refreshAddedPlants();
  }

  Future<void> _loadExistingSnapshotSilently() async {
    try {
      final snapshot = await repository.loadSnapshot(forceRemote: false);
      if (snapshot != null) {
        _plants = snapshot.plants;
        _mergeSyncedAddedPlantsIntoInspectionPlants();
        _catalog = snapshot.types;
        _loadStatus = _plants.isEmpty
            ? InspectionLoadStatus.empty
            : InspectionLoadStatus.success;
        notifyListeners();
      }
    } catch (_) {}
  }

  Future<void> loadPlants({bool forceRemote = true}) async {
    _loadStatus = InspectionLoadStatus.loading;
    _errorMessage = null;
    notifyListeners();

    try {
      unawaited(loadZones());
      final snapshot = await repository.loadSnapshot(forceRemote: forceRemote);
      if (snapshot == null || snapshot.plants.isEmpty) {
        _plants = const [];
        _mergeSyncedAddedPlantsIntoInspectionPlants();
        _catalog = snapshot?.types ?? const [];
        _loadStatus = _plants.isEmpty
            ? InspectionLoadStatus.empty
            : InspectionLoadStatus.success;
      } else {
        _plants = snapshot.plants;
        _mergeSyncedAddedPlantsIntoInspectionPlants();
        _catalog = snapshot.types;
        _loadStatus = InspectionLoadStatus.success;
      }
      await refreshLocalInspections();
      await refreshAddedPlants();
    } catch (e) {
      _loadStatus = InspectionLoadStatus.error;
      _errorMessage = 'Não foi possível carregar as plantas.';
    }

    notifyListeners();
  }

  void selectPlant(InspectionPlant? plant) {
    if (plant == null) {
      _selectedPlant = null;
      _stagedOccurrenceTypeIds = const {};
      _stagedNonExistent = false;
    } else {
      _selectedPlant = _plants.firstWhere(
        (p) => p.id == plant.id,
        orElse: () => plant,
      );
      _stagedOccurrenceTypeIds = Set<String>.from(_selectedPlant!.openTypeIds);
      _stagedNonExistent = _selectedPlant!.nonExistent;
    }
    notifyListeners();
  }

  void selectPlantById(String id) {
    _selectedPlant = _plants.firstWhere(
      (p) => p.id == id,
      orElse: () => InspectionPlant(id: id),
    );
    _stagedOccurrenceTypeIds = Set<String>.from(_selectedPlant!.openTypeIds);
    _stagedNonExistent = _selectedPlant!.nonExistent;
    notifyListeners();
  }

  void toggleStagedNonExistent([bool? value]) {
    if (_selectedPlant == null) return;
    _stagedNonExistent = value ?? !_stagedNonExistent;
    notifyListeners();
  }

  void toggleStagedOccurrence(String typeId) {
    if (_selectedPlant == null || _stagedNonExistent) return;
    final updated = Set<String>.from(_stagedOccurrenceTypeIds);
    if (updated.contains(typeId)) {
      updated.remove(typeId);
    } else {
      updated.add(typeId);
    }
    _stagedOccurrenceTypeIds = updated;
    notifyListeners();
  }

  void selectDiagnosticCode(String code) {
    _diagnosticCode = code;
    final match = _catalog.where((t) => t.code == code).firstOrNull;
    if (match != null) {
      _selectedOccurrenceFilterId = match.id;
    }
    debugPrint(code);
    notifyListeners();
  }

  void filterByOccurrence(String? typeId) {
    _selectedOccurrenceFilterId = typeId;
    if (typeId != null) {
      final match = _catalog.where((t) => t.id == typeId).firstOrNull;
      if (match != null) {
        _diagnosticCode = match.code;
      }
    } else {
      _diagnosticCode = null;
    }
    notifyListeners();
  }

  void clearOccurrenceFilter() => filterByOccurrence(null);

  void filterByZone(String? zoneId) {
    if (_selectedZoneFilterId == zoneId) return;

    _selectedZoneFilterId = zoneId;
    _selectedZonePoints =
        (zoneId != null && _zoneRegionsCache.containsKey(zoneId))
        ? _zoneRegionsCache[zoneId]!
        : const [];
    notifyListeners();

    if (zoneId != null && !_zoneRegionsCache.containsKey(zoneId)) {
      unawaited(_loadZoneRegions(zoneId));
    }
  }

  Future<void> _loadZoneRegions(String zoneId) async {
    var effectiveRepo = zonesRepository;
    if (effectiveRepo == null) {
      try {
        final client = Supabase.instance.client;
        effectiveRepo = SupabaseZonesRepository(client);
        zonesRepository = effectiveRepo;
      } catch (_) {}
    }
    if (effectiveRepo == null) return;
    try {
      final points = await effectiveRepo.fetchRegionsForZone(zoneId);
      _zoneRegionsCache[zoneId] = points;
      if (_selectedZoneFilterId == zoneId) {
        _selectedZonePoints = points;
        notifyListeners();
      }
    } catch (e) {
      debugPrint('Erro ao carregar região da zona $zoneId: $e');
    }
  }

  void clearZoneFilter() => filterByZone(null);

  void clearAllFilters() {
    _selectedOccurrenceFilterId = null;
    _diagnosticCode = null;
    _selectedZoneFilterId = null;
    _selectedZonePoints = const [];
    notifyListeners();
  }

  Future<void> togglePlantOccurrence(String typeId) async {
    final plant = _selectedPlant;
    if (plant == null || _isSavingLocal) return;

    _isSavingLocal = true;
    _feedbackMessage = null;
    notifyListeners();

    try {
      double? distance;
      if (userLocation != null && plant.hasValidCoordinates) {
        distance = Geolocator.distanceBetween(
          userLocation!.latitude,
          userLocation!.longitude,
          plant.latitude!,
          plant.longitude!,
        );
      }

      await repository.togglePlantOccurrence(
        plant.id,
        typeId,
        location: userLocation,
        distance: distance,
      );

      final openTypes = Set<String>.from(plant.openTypeIds);
      if (openTypes.contains(typeId)) {
        openTypes.remove(typeId);
      } else {
        openTypes.add(typeId);
      }
      final updatedPlant = plant.withState(openTypes);
      final plantIndex = _plants.indexWhere((p) => p.id == plant.id);
      if (plantIndex != -1) {
        final newPlants = List<InspectionPlant>.from(_plants);
        newPlants[plantIndex] = updatedPlant;
        _plants = newPlants;
        _indexedPlants = null;
      }
      _selectedPlant = updatedPlant;
      _stagedOccurrenceTypeIds = Set<String>.from(updatedPlant.openTypeIds);
      _stagedNonExistent = updatedPlant.nonExistent;
      _feedbackMessage = 'Salvo no dispositivo';
      await refreshLocalInspections();
    } catch (e) {
      _feedbackMessage = 'Erro ao salvar alteração localmente';
    } finally {
      _isSavingLocal = false;
      notifyListeners();
    }
  }

  Future<void> savePlantChanges() async {
    final plant = _selectedPlant;
    if (plant == null || _isSavingLocal) return;

    final initialTypes = plant.openTypeIds;
    final stagedTypes = _stagedOccurrenceTypeIds;

    final addedTypes = stagedTypes.difference(initialTypes);
    final removedTypes = initialTypes.difference(stagedTypes);
    final nonExistentChanged = _stagedNonExistent != plant.nonExistent;

    if (addedTypes.isEmpty && removedTypes.isEmpty && !nonExistentChanged) {
      return;
    }

    _isSavingLocal = true;
    _feedbackMessage = null;
    notifyListeners();

    try {
      if (nonExistentChanged) {
        await repository.setPlantNonExistent(plant.id, _stagedNonExistent);
      }

      double? distance;
      if (userLocation != null && plant.hasValidCoordinates) {
        distance = Geolocator.distanceBetween(
          userLocation!.latitude,
          userLocation!.longitude,
          plant.latitude!,
          plant.longitude!,
        );
      }

      for (final typeId in addedTypes) {
        await repository.togglePlantOccurrence(
          plant.id,
          typeId,
          location: userLocation,
          distance: distance,
        );
      }

      for (final typeId in removedTypes) {
        await repository.togglePlantOccurrence(
          plant.id,
          typeId,
          location: userLocation,
          distance: distance,
        );
      }

      final updatedPlant = plant.withState(
        stagedTypes,
        eligible: true,
        nonExistent: _stagedNonExistent,
      );
      final plantIndex = _plants.indexWhere((p) => p.id == plant.id);
      if (plantIndex != -1) {
        final newPlants = List<InspectionPlant>.from(_plants);
        newPlants[plantIndex] = updatedPlant;
        _plants = newPlants;
        _indexedPlants = null;
      }
      _selectedPlant = updatedPlant;
      _stagedOccurrenceTypeIds = Set<String>.from(updatedPlant.openTypeIds);
      _stagedNonExistent = updatedPlant.nonExistent;
      _feedbackMessage = 'Salvo no dispositivo';
      await refreshLocalInspections();
    } catch (e) {
      _feedbackMessage = 'Erro ao salvar alteração localmente';
    } finally {
      _isSavingLocal = false;
      notifyListeners();
    }
  }

  Future<void> savePlantChangesAndFinalize() async {
    await savePlantChanges();
    await finalizeInspection();
  }

  Future<void> finalizeInspection() async {
    if (_isSyncing) return;

    _isSyncing = true;
    _feedbackMessage = null;
    notifyListeners();

    try {
      final finalized = await repository.finalizeInspection();
      if (finalized == null) {
        _feedbackMessage = 'Nenhuma alteração para finalizar';
        return;
      }

      // Wait a moment for the sync to attempt
      final synced = await repository.syncPending();
      if (synced) {
        _feedbackMessage = 'Sincronizado com sucesso!';
      } else {
        _feedbackMessage = 'Salvo no dispositivo (envio pendente)';
      }

      // Reload local snapshot so _plants stays completely in sync with persisted occurrences
      final snapshot = await repository.loadSnapshot(forceRemote: false);
      if (snapshot != null) {
        _plants = snapshot.plants;
        _mergeSyncedAddedPlantsIntoInspectionPlants();
        if (_selectedPlant != null) {
          _selectedPlant = _plants.firstWhere(
            (p) => p.id == _selectedPlant!.id,
            orElse: () => _selectedPlant!,
          );
        }
      }

      await refreshLocalInspections();
    } catch (e) {
      _feedbackMessage = 'Salvo no dispositivo (envio pendente)';
    } finally {
      _isSyncing = false;
      notifyListeners();
    }
  }

  Future<void> syncPendingInspections() async {
    if (_isSyncing) return;

    _isSyncing = true;
    _feedbackMessage = null;
    notifyListeners();

    try {
      // If there is an active draft with changes, finalize it first so it joins the pending queue
      await repository.finalizeInspection();

      final success = await repository.syncPending();
      await refreshLocalInspections();
      final hasNetworkIssue = _localInspections.any((i) => i.isNetworkError);
      _feedbackMessage = success
          ? 'Sincronizado com sucesso!'
          : (hasNetworkIssue
                ? 'Sem internet'
                : 'Algumas inspeções não puderam ser sincronizadas.');

      final snapshot = await repository.loadSnapshot(forceRemote: false);
      if (snapshot != null) {
        _plants = snapshot.plants;
        _mergeSyncedAddedPlantsIntoInspectionPlants();
      }
      await refreshLocalInspections();
    } catch (e) {
      _feedbackMessage = 'Erro na sincronização';
    } finally {
      _isSyncing = false;
      notifyListeners();
    }
  }

  Future<void> addPlantAt({
    required double latitude,
    required double longitude,
    required bool nonExistent,
    String? zoneId,
  }) async {
    if (_isSavingLocal) return;

    _isSavingLocal = true;
    _feedbackMessage = null;
    notifyListeners();

    try {
      await repository.addPlant(
        latitude: latitude,
        longitude: longitude,
        nonExistent: nonExistent,
        zoneId: zoneId ?? selectedZoneFilterId,
      );
      await refreshAddedPlants();
      _feedbackMessage = 'Planta salva no dispositivo';
    } catch (e) {
      _feedbackMessage = 'Erro ao salvar planta localmente';
    } finally {
      _isSavingLocal = false;
      notifyListeners();
    }
  }

  Future<void> syncPendingAddedPlants() async {
    if (_isSyncingAddedPlants) return;

    _isSyncingAddedPlants = true;
    _feedbackMessage = null;
    notifyListeners();

    try {
      final success = await repository.syncPendingAddedPlants();
      await refreshAddedPlants();
      _feedbackMessage = success
          ? 'Plantas sincronizadas com sucesso!'
          : (_addedPlants.any((p) => p.error == 'Sem internet')
                ? 'Sem internet'
                : 'Algumas plantas nao puderam ser sincronizadas.');
    } catch (e) {
      _feedbackMessage = 'Erro na sincronizacao das plantas';
    } finally {
      _isSyncingAddedPlants = false;
      notifyListeners();
    }
  }

  Future<void> removeAddedPlant(String localId) async {
    try {
      await repository.removeAddedPlant(localId);
      await refreshAddedPlants();
      _feedbackMessage = 'Planta adicionada removida';
      notifyListeners();
    } catch (e) {
      _feedbackMessage = 'Erro ao remover planta adicionada';
      notifyListeners();
    }
  }

  List<AlteredPlantItem> getAlteredPlantsForInspection(String inspectionId) {
    final changes = _inspectionChanges[inspectionId] ?? const [];
    if (changes.isEmpty) {
      final inspection = _localInspections
          .where((i) => i.id == inspectionId)
          .firstOrNull;
      if (inspection?.payloadJson != null) {
        try {
          final payload = inspection!.payload;
          final plantsList = (payload['plantsChanged'] as List<dynamic>? ?? []);
          return plantsList.map((p) {
            final map = Map<String, dynamic>.from(p as Map);
            final plantId = map['plantId'] as String;
            final plant = _plants.where((pl) => pl.id == plantId).firstOrNull;
            final plantLabel =
                plant?.label ??
                'Planta ${plantId.substring(0, plantId.length < 8 ? plantId.length : 8)}';
            final changesList = (map['changes'] as List<dynamic>? ?? [])
                .map((c) => Map<String, dynamic>.from(c as Map))
                .toList();
            final summaries = changesList.map((c) {
              final typeId = c['occurrenceTypeId'] as String?;
              final added = c['changeType'] == 'add_occurrence';
              final type = _catalog.where((t) => t.id == typeId).firstOrNull;
              final typeName = type?.name ?? typeId ?? '';
              return added ? typeName : '$typeName (removida)';
            }).toList();
            return AlteredPlantItem(
              plantId: plantId,
              plantLabel: plantLabel,
              changesSummary: summaries,
            );
          }).toList();
        } catch (_) {}
      }
      return const [];
    }

    final grouped = <String, List<InspectionChange>>{};
    for (final c in changes) {
      (grouped[c.plantId] ??= []).add(c);
    }

    return grouped.entries.map((entry) {
      final plantId = entry.key;
      final plant = _plants.where((p) => p.id == plantId).firstOrNull;
      final plantLabel =
          plant?.label ??
          'Planta ${plantId.substring(0, plantId.length < 8 ? plantId.length : 8)}';

      final descriptions = entry.value.map((c) {
        final type = _catalog.where((t) => t.id == c.typeId).firstOrNull;
        final typeName = type?.name ?? c.typeId;
        return c.added ? typeName : '$typeName (removida)';
      }).toList();

      return AlteredPlantItem(
        plantId: plantId,
        plantLabel: plantLabel,
        changesSummary: descriptions,
      );
    }).toList();
  }

  Future<void> refreshLocalInspections() async {
    try {
      _localInspections = await repository.listLocalInspections();
      final changesMap = <String, List<InspectionChange>>{};
      for (final inspection in _localInspections) {
        changesMap[inspection.id] = await repository.getInspectionChanges(
          inspection.id,
        );
      }
      _inspectionChanges = changesMap;
      notifyListeners();
    } catch (_) {}
  }

  Future<void> refreshAddedPlants() async {
    try {
      _addedPlants = await repository.listAddedPlants();
      _mergeSyncedAddedPlantsIntoInspectionPlants();
      notifyListeners();
    } catch (_) {}
  }

  void _mergeSyncedAddedPlantsIntoInspectionPlants() {
    final syncedAddedPlants = _addedPlants.where(
      (plant) =>
          plant.status == InspectionSyncStatus.synced &&
          plant.remotePlantId != null &&
          plant.hasValidCoordinates,
    );
    if (syncedAddedPlants.isEmpty) return;

    final merged = List<InspectionPlant>.from(_plants);
    var changed = false;

    for (final addedPlant in syncedAddedPlants) {
      final remotePlantId = addedPlant.remotePlantId!;
      final index = merged.indexWhere((plant) => plant.id == remotePlantId);

      if (index == -1) {
        merged.add(
          InspectionPlant(
            id: remotePlantId,
            latitude: addedPlant.latitude,
            longitude: addedPlant.longitude,
            nonExistent: addedPlant.nonExistent,
            openTypeIds: const {},
            zoneId: addedPlant.zoneId,
            eligible: true,
          ),
        );
        changed = true;
      } else if (merged[index].zoneId == null && addedPlant.zoneId != null) {
        merged[index] = InspectionPlant(
          id: merged[index].id,
          latitude: merged[index].latitude,
          longitude: merged[index].longitude,
          zoneId: addedPlant.zoneId,
          description: merged[index].description,
          openTypeIds: merged[index].openTypeIds,
          eligible: merged[index].eligible,
          nonExistent: merged[index].nonExistent,
        );
        changed = true;
      }
    }

    if (!changed) return;
    _plants = List.unmodifiable(merged);
    _indexedPlants = null;
    _filterKey = null;
  }

  Future<void> deletePlantFromInspection({
    required String inspectionId,
    required String plantId,
  }) async {
    try {
      await repository.removePlantFromInspection(inspectionId, plantId);
      final snapshot = await repository.loadSnapshot(forceRemote: false);
      if (snapshot != null) {
        _plants = snapshot.plants;
        _mergeSyncedAddedPlantsIntoInspectionPlants();
        if (_selectedPlant != null && _selectedPlant!.id == plantId) {
          final updated = _plants.where((p) => p.id == plantId).firstOrNull;
          _selectedPlant = updated;
          if (updated != null) {
            _stagedOccurrenceTypeIds = {...updated.openTypeIds};
          }
        }
      }
      await refreshLocalInspections();
      _feedbackMessage = 'Planta removida com sucesso';
      notifyListeners();
    } catch (e) {
      _errorMessage = 'Falha ao remover planta da inspeção: $e';
      notifyListeners();
    }
  }

  void resumeLocation() {
    if (_disposed || _isLocationActive) return;
    _isLocationActive = true;
    _locationSubscription?.cancel();
    _positionTracker.reset();
    final hadResult = _locationResult != null;
    _locationResult = null;
    if (hadResult) scheduleMicrotask(notifyListeners);
    _locationSubscription = locationService.watchLocation().listen(
      (result) {
        if (_disposed || !_isLocationActive) return;
        if (result.location case final location?) {
          final accepted = _positionTracker.add(location);
          if (accepted == null) return;
          _locationResult = LocationResult.available(accepted);
        } else {
          _positionTracker.reset();
          _locationResult = result;
        }
        notifyListeners();
      },
      onError: (Object _) {
        if (_disposed || !_isLocationActive) return;
        _positionTracker.reset();
        _locationResult = const LocationResult.error();
        notifyListeners();
      },
      onDone: () {
        if (_disposed || !_isLocationActive) return;
        _isLocationActive = false;
        _locationSubscription = null;
        _positionTracker.reset();
        _locationResult = const LocationResult.error();
        notifyListeners();
      },
    );
  }

  void pauseLocation() {
    _isLocationActive = false;
    _locationSubscription?.cancel();
    _locationSubscription = null;
    _positionTracker.reset();
    final hadResult = _locationResult != null;
    _locationResult = null;
    if (hadResult) scheduleMicrotask(notifyListeners);
  }

  @override
  void dispose() {
    _disposed = true;
    pauseLocation();
    unawaited(_plantChangesSubscription?.cancel());
    super.dispose();
  }

  bool _disposed = false;
  @override
  void notifyListeners() {
    if (!_disposed) super.notifyListeners();
  }
}
