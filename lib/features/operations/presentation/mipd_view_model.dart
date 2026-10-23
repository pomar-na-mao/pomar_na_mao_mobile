import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../farm/domain/user_location.dart';
import '../../farm/domain/user_position_tracker.dart';
import '../data/mipd_photo_service.dart';
import '../data/mipd_repository.dart';
import '../domain/inspection_models.dart';
import '../domain/mipd_models.dart';

enum MipdLoadStatus { initial, loading, success, empty, error }

class MipdViewModel extends ChangeNotifier {
  MipdViewModel({
    required this.repository,
    required this.locationService,
    required this.photoService,
  });

  final MipdRepository repository;
  final LocationService locationService;
  final MipdPhotoService photoService;
  List<InspectionPlant> plants = const [];
  List<OccurrenceType> catalog = const [];
  List<MipdMarking> markings = const [];
  MipdLoadStatus status = MipdLoadStatus.initial;
  String? errorMessage;
  bool syncing = false;
  StreamSubscription<LocationResult>? _locationSubscription;
  final UserPositionTracker _positionTracker = UserPositionTracker();
  Timer? _stableLocationTimeout;
  LocationResult? _locationResult;
  bool _isLocationActive = false;
  bool _isWaitingForStableLocation = false;
  bool _disposed = false;

  UserLocation? get userLocation => _locationResult?.location;
  bool get isWaitingForStableLocation => _isWaitingForStableLocation;

  String? get locationMessage => switch (_locationResult?.availability) {
    LocationAvailability.permissionDenied =>
      'Permita o acesso à localização para ver sua posição.',
    LocationAvailability.serviceDisabled =>
      'Ative o serviço de localização para ver sua posição.',
    LocationAvailability.error => 'Não foi possível obter sua localização.',
    LocationAvailability.available || null => null,
  };

  Future<void> initialize() async {
    await Future.wait([loadPlants(forceRemote: false), loadMarkings()]);
  }

  void resumeLocation() {
    if (_disposed || _isLocationActive) return;
    _isLocationActive = true;
    _locationSubscription?.cancel();
    _positionTracker.reset();
    if (_locationResult == null) {
      _isWaitingForStableLocation = true;
      _stableLocationTimeout?.cancel();
      _stableLocationTimeout = Timer(const Duration(seconds: 30), () {
        if (_disposed || !_isWaitingForStableLocation) return;
        _isWaitingForStableLocation = false;
        _locationResult = const LocationResult.error();
        notifyListeners();
      });
      scheduleMicrotask(notifyListeners);
    }
    _locationSubscription = locationService.watchLocation().listen(
      (result) {
        if (_disposed || !_isLocationActive) return;
        if (result.location case final location?) {
          final accepted = _positionTracker.add(location);
          if (accepted == null) return;
          _finishWaitingForStableLocation();
          _locationResult = LocationResult.available(accepted);
        } else {
          _positionTracker.reset();
          _finishWaitingForStableLocation();
          _locationResult = result;
        }
        notifyListeners();
      },
      onError: (Object _) {
        if (_disposed || !_isLocationActive) return;
        _positionTracker.reset();
        _finishWaitingForStableLocation();
        _locationResult = const LocationResult.error();
        notifyListeners();
      },
      onDone: () {
        if (_disposed || !_isLocationActive) return;
        _isLocationActive = false;
        _locationSubscription = null;
        _positionTracker.reset();
        _finishWaitingForStableLocation();
        _locationResult = const LocationResult.error();
        notifyListeners();
      },
    );
  }

  void cancelStableLocationWait() {
    if (!_isWaitingForStableLocation) return;
    _finishWaitingForStableLocation();
    notifyListeners();
  }

  void _finishWaitingForStableLocation() {
    _isWaitingForStableLocation = false;
    _stableLocationTimeout?.cancel();
    _stableLocationTimeout = null;
  }

  Future<void> loadPlants({bool forceRemote = true}) async {
    status = MipdLoadStatus.loading;
    errorMessage = null;
    notifyListeners();
    try {
      final snapshot = await repository.loadSnapshot(forceRemote: forceRemote);
      plants =
          snapshot?.plants
              .where((plant) => plant.hasValidCoordinates)
              .toList() ??
          const [];
      catalog = snapshot?.types ?? const [];
      status = plants.isEmpty ? MipdLoadStatus.empty : MipdLoadStatus.success;
    } catch (error) {
      errorMessage = error.toString();
      status = MipdLoadStatus.error;
    }
    notifyListeners();
  }

  String createLocalId() => repository.createLocalId();

  Future<String?> capturePhoto(String localId) =>
      photoService.captureAndPersist(localId);

  Future<void> removePhoto(String? path) => photoService.remove(path);

  Future<void> save({
    required String localId,
    required InspectionPlant plant,
    required OccurrenceType occurrenceType,
    required Set<MipdPlantPart> plantParts,
    String? localPhotoPath,
  }) async {
    await repository.save(
      localId: localId,
      plantId: plant.id,
      occurrenceType: occurrenceType,
      plantParts: plantParts,
      localPhotoPath: localPhotoPath,
    );
    await loadMarkings();
  }

  Future<void> loadMarkings() async {
    markings = await repository.list();
    notifyListeners();
  }

  Future<bool> syncOne(String id) => _sync(() => repository.syncOne(id));
  Future<bool> syncAll() => _sync(repository.syncAll);

  Future<bool> _sync(Future<bool> Function() action) async {
    if (syncing) return false;
    syncing = true;
    notifyListeners();
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
    _positionTracker.reset();
    final wasWaiting = _isWaitingForStableLocation;
    _finishWaitingForStableLocation();
    if (wasWaiting) scheduleMicrotask(notifyListeners);
  }

  @override
  void dispose() {
    _disposed = true;
    pauseLocation();
    super.dispose();
  }
}
