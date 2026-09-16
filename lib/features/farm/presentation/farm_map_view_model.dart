import 'dart:async';

import 'package:flutter/foundation.dart';

import '../domain/farm_point.dart';
import '../domain/farm_repository.dart';
import '../domain/plant.dart';
import '../domain/plants_repository.dart';
import '../domain/region_point.dart';
import '../domain/user_location.dart';
import '../domain/zone.dart';
import '../domain/zones_repository.dart';

enum PlantsLoadStatus { initial, loading, success, empty, error }

class FarmMapViewModel extends ChangeNotifier {
  FarmMapViewModel(
    this._plantsRepository,
    this._zonesRepository,
    this._locationService,
    this._farmRepository,
  );

  final PlantsRepository _plantsRepository;
  final ZonesRepository _zonesRepository;
  final LocationService _locationService;
  final FarmRepository _farmRepository;
  StreamSubscription<LocationResult>? _locationSubscription;

  PlantsLoadStatus _plantsStatus = PlantsLoadStatus.initial;
  PlantsLoadStatus get plantsStatus => _plantsStatus;

  List<Plant> _allPlants = const [];
  List<Plant> get plants {
    final zoneId = _selectedZoneId;
    if (zoneId == null) return _allPlants;
    return _allPlants
        .where((plant) => plant.zoneId == zoneId)
        .toList(growable: false);
  }

  List<Zone> _zones = const [];
  List<Zone> get zones => _zones;

  List<FarmPoint> _farmBoundaryPoints = const [];
  List<FarmPoint> get farmBoundaryPoints => _farmBoundaryPoints;

  final Map<String, List<RegionPoint>> _zoneRegionsCache = {};
  List<RegionPoint> _selectedZonePoints = const [];
  List<RegionPoint> get selectedZonePoints => _selectedZonePoints;

  String? _selectedZoneId;
  String? get selectedZoneId => _selectedZoneId;

  LocationResult? _locationResult;
  LocationResult? get locationResult => _locationResult;

  String? _errorMessage;
  String? get errorMessage => _errorMessage;

  UserLocation? get userLocation => _locationResult?.location;
  bool get canShowUserLocation =>
      _locationResult?.availability == LocationAvailability.available;

  Future<void> initialize() async {
    if (_plantsStatus != PlantsLoadStatus.initial) return;
    await Future.wait([loadFarmData(), loadUserLocation()]);
  }

  Future<void> loadFarmData() async {
    _plantsStatus = PlantsLoadStatus.loading;
    _errorMessage = null;
    notifyListeners();

    try {
      final plantsFuture = _plantsRepository.fetchPlants();
      final zonesFuture = _zonesRepository.fetchZones();
      final farmBoundaryFuture = _loadFarmBoundarySilently();
      _allPlants = await plantsFuture;
      _zones = await zonesFuture;
      _farmBoundaryPoints = await farmBoundaryFuture;
      _plantsStatus = plants.isEmpty
          ? PlantsLoadStatus.empty
          : PlantsLoadStatus.success;
    } on Exception {
      _plantsStatus = PlantsLoadStatus.error;
      _errorMessage = 'Não foi possível carregar as plantas.';
    }
    notifyListeners();
  }

  Future<void> loadPlants() => loadFarmData();

  Future<List<FarmPoint>> _loadFarmBoundarySilently() async {
    try {
      return await _farmRepository.fetchFarmBoundary();
    } catch (_) {
      return const [];
    }
  }

  void selectZone(String? zoneId) {
    if (_selectedZoneId == zoneId) return;

    _selectedZoneId = zoneId;
    _selectedZonePoints =
        (zoneId != null && _zoneRegionsCache.containsKey(zoneId))
        ? _zoneRegionsCache[zoneId]!
        : const [];

    if (_plantsStatus != PlantsLoadStatus.loading &&
        _plantsStatus != PlantsLoadStatus.error) {
      _plantsStatus = plants.isEmpty
          ? PlantsLoadStatus.empty
          : PlantsLoadStatus.success;
    }
    notifyListeners();

    if (zoneId != null && !_zoneRegionsCache.containsKey(zoneId)) {
      unawaited(_loadZoneRegions(zoneId));
    }
  }

  Future<void> _loadZoneRegions(String zoneId) async {
    try {
      final points = await _zonesRepository.fetchRegionsForZone(zoneId);
      _zoneRegionsCache[zoneId] = points;
      if (_selectedZoneId == zoneId) {
        _selectedZonePoints = points;
        notifyListeners();
      }
    } catch (_) {
      // Falha silenciosa no polígono para manter o mapa operacional
    }
  }

  Future<void> loadUserLocation() async {
    await _locationSubscription?.cancel();
    _locationSubscription = _locationService.watchLocation().listen((result) {
      _locationResult = result;
      notifyListeners();
    });
  }

  String? get locationMessage => switch (_locationResult?.availability) {
    LocationAvailability.permissionDenied =>
      'Permita o acesso à localização para ver sua posição.',
    LocationAvailability.serviceDisabled =>
      'Ative o serviço de localização para ver sua posição.',
    LocationAvailability.error => 'Não foi possível obter sua localização.',
    LocationAvailability.available || null => null,
  };

  @override
  void dispose() {
    unawaited(_locationSubscription?.cancel());
    super.dispose();
  }
}
