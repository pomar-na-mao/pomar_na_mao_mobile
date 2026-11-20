import 'dart:async';

import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

import '../../farm/domain/map_initial_position.dart';
import '../../farm/domain/user_location.dart';
import '../../farm/presentation/user_map_navigation.dart';
import '../data/harvest_forecast_repository.dart';
import '../domain/harvest_forecast_models.dart';
import '../domain/inspection_models.dart';
import '../domain/spraying_geometry_service.dart';
import '../domain/spraying_location_filter.dart';

enum HarvestForecastLoadStatus { initial, loading, success, empty, error }

class HarvestForecastViewModel extends ChangeNotifier {
  HarvestForecastViewModel({
    required this.repository,
    required this.locationService,
    this.mapInitialPositionResolver,
    this.geometryService = const SprayingGeometryService(),
  });

  final HarvestForecastRepository repository;
  final LocationService locationService;
  final MapInitialPositionResolver? mapInitialPositionResolver;
  final SprayingGeometryService geometryService;

  MapInitialPosition? initialMapPosition;
  bool initialMapPositionResolved = false;
  List<InspectionPlant> plants = const [];
  List<HarvestForecastMarking> markings = const [];
  HarvestForecastLoadStatus status = HarvestForecastLoadStatus.initial;
  String? errorMessage;
  String? feedbackMessage;
  bool syncing = false;
  bool saving = false;
  bool deleting = false;

  StreamSubscription<LocationResult>? _locationSubscription;
  SprayingLocationFilter _locationFilter = SprayingLocationFilter();
  final UserMapLocationState mapLocation = UserMapLocationState(
    maxAccuracyMeters: 25,
  );
  final List<LatLng> _routePoints = [];
  LocationResult? _locationResult;
  bool _isLocationActive = false;
  bool _disposed = false;

  UserLocation? get userLocation => _locationResult?.location;

  List<LatLng> get routePoints => List.unmodifiable(_routePoints);

  Set<Polyline> get polylines {
    if (_routePoints.length < 2) return const {};
    return {
      Polyline(
        polylineId: const PolylineId('harvest_forecast_active_route'),
        color: const Color(0xFF16A34A),
        width: 6,
        patterns: <PatternItem>[PatternItem.dot, PatternItem.gap(10)],
        jointType: JointType.round,
        startCap: Cap.roundCap,
        endCap: Cap.roundCap,
        points: List<LatLng>.unmodifiable(_routePoints),
      ),
    };
  }

  String? get locationMessage => switch (_locationResult?.availability) {
    LocationAvailability.permissionDenied =>
      'Permita o acesso à localização para ver sua posição.',
    LocationAvailability.serviceDisabled =>
      'Ative o serviço de localização para ver sua posição.',
    LocationAvailability.error => 'Não foi possível obter sua localização.',
    LocationAvailability.available || null => null,
  };

  void clearMessages() {
    if (errorMessage == null && feedbackMessage == null) return;
    errorMessage = null;
    feedbackMessage = null;
    if (!_disposed) notifyListeners();
  }

  Future<void> initialize() async {
    await Future.wait([
      loadInitialMapPosition(),
      loadPlants(forceRemote: false),
      loadMarkings(),
    ]);
  }

  Future<void> loadInitialMapPosition() async {
    if (initialMapPositionResolved) return;
    initialMapPosition = await mapInitialPositionResolver?.resolve();
    initialMapPositionResolved = true;
    if (!_disposed) notifyListeners();
  }

  void resumeLocation() {
    if (_disposed || _isLocationActive) return;
    _isLocationActive = true;
    _locationSubscription?.cancel();
    _locationFilter = SprayingLocationFilter();
    _locationSubscription = locationService.watchLocation().listen(
      (result) {
        if (_disposed || !_isLocationActive) return;
        if (result.availability == LocationAvailability.available &&
            result.location != null) {
          final location = result.location!;
          mapLocation.add(location);
          final accepted = _locationFilter.add(location);
          if (accepted == null) return;
          _locationResult = LocationResult.available(accepted);
          _recordRoutePoint(accepted);
        } else {
          mapLocation.clear();
          _locationFilter = SprayingLocationFilter();
          _locationResult = result;
        }
        notifyListeners();
      },
      onError: (Object _) {
        if (_disposed || !_isLocationActive) return;
        mapLocation.clear();
        _locationFilter = SprayingLocationFilter();
        _locationResult = const LocationResult.error();
        notifyListeners();
      },
      onDone: () {
        if (_disposed || !_isLocationActive) return;
        _isLocationActive = false;
        _locationSubscription = null;
        mapLocation.clear();
        _locationFilter = SprayingLocationFilter();
        _locationResult = const LocationResult.error();
        notifyListeners();
      },
    );
  }

  void _recordRoutePoint(UserLocation loc) {
    if (loc.accuracy != null && loc.accuracy! > 25.0) return;
    if (_routePoints.isNotEmpty) {
      final last = _routePoints.last;
      final dist = geometryService.haversineDistanceMeters(
        last.latitude,
        last.longitude,
        loc.latitude,
        loc.longitude,
      );
      if (dist < 2.5) return;
    }
    _routePoints.add(LatLng(loc.latitude, loc.longitude));
  }

  Future<void> loadPlants({bool forceRemote = true}) async {
    status = HarvestForecastLoadStatus.loading;
    errorMessage = null;
    if (!_disposed) notifyListeners();
    try {
      final loaded = await repository.loadPlants(forceRemote: forceRemote);
      plants = loaded
          .where((plant) => plant.hasValidCoordinates && !plant.nonExistent)
          .toList(growable: false);
      status = plants.isEmpty
          ? HarvestForecastLoadStatus.empty
          : HarvestForecastLoadStatus.success;
    } catch (error) {
      errorMessage = error.toString();
      status = HarvestForecastLoadStatus.error;
    }
    if (!_disposed) notifyListeners();
  }

  Future<void> loadMarkings() async {
    markings = await repository.list();
    if (!_disposed) notifyListeners();
  }

  Future<HarvestForecastMarking?> recordClassification(
    HarvestForecastClassification classification,
  ) async {
    if (saving) return null;
    final loc = mapLocation.location ?? userLocation;
    if (loc == null) {
      errorMessage =
          locationMessage ??
          'Aguardando localização GPS para registrar a previsão de safra.';
      if (!_disposed) notifyListeners();
      return null;
    }
    return recordClassificationAt(
      latitude: loc.latitude,
      longitude: loc.longitude,
      classification: classification,
    );
  }

  Future<HarvestForecastMarking?> recordClassificationAt({
    required double latitude,
    required double longitude,
    HarvestForecastClassification classification =
        HarvestForecastClassification.n,
  }) async {
    if (saving) return null;
    saving = true;
    errorMessage = null;
    if (!_disposed) notifyListeners();
    try {
      final marking = await repository.save(
        latitude: latitude,
        longitude: longitude,
        classification: classification,
      );
      markings = await repository.list();
      feedbackMessage =
          'Previsão ${classification.code} (${classification.label}) registrada.';
      return marking;
    } catch (error) {
      errorMessage = 'Não foi possível salvar a marcação: $error';
      return null;
    } finally {
      saving = false;
      if (!_disposed) notifyListeners();
    }
  }

  Future<bool> updateClassification(
    String localId,
    HarvestForecastClassification classification,
  ) async {
    final updated = await repository.updateClassification(
      localId: localId,
      classification: classification,
    );
    await loadMarkings();
    return updated != null;
  }

  Future<bool> deleteMarking(String localId) async {
    if (deleting) return false;
    deleting = true;
    if (!_disposed) notifyListeners();
    try {
      return await repository.delete(localId);
    } finally {
      deleting = false;
      await loadMarkings();
    }
  }

  Future<bool> syncOne(String id) => _sync(() => repository.syncOne(id));
  Future<bool> syncAll() => _sync(repository.syncAll);

  Future<bool> _sync(Future<bool> Function() action) async {
    if (syncing) return false;
    syncing = true;
    if (!_disposed) notifyListeners();
    try {
      return await action();
    } finally {
      syncing = false;
      await loadMarkings();
    }
  }

  void pauseLocation() {
    _isLocationActive = false;
    unawaited(_locationSubscription?.cancel());
    _locationSubscription = null;
    mapLocation.clear();
    _locationFilter = SprayingLocationFilter();
  }

  @override
  void dispose() {
    _disposed = true;
    pauseLocation();
    mapLocation.dispose();
    super.dispose();
  }
}
