import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../farm/domain/farm_point.dart';
import '../../farm/domain/farm_repository.dart';
import '../../farm/domain/region_point.dart';
import '../../farm/domain/zones_repository.dart';
import '../domain/inventory_property_profile.dart';
import '../domain/inventory_repository.dart';
import '../domain/inventory_summary.dart';

enum InventoryLoadStatus { initial, loading, success, error }

class InventoryViewModel extends ChangeNotifier {
  InventoryViewModel(
    this._inventoryRepository,
    this._farmRepository,
    this._zonesRepository, {
    this.profile = InventoryPropertyProfile.sitioSaoFrancisco,
    Stream<void>? plantChanges,
  }) {
    _plantChangesSubscription = plantChanges?.listen((_) {
      if (_summaryStatus == InventoryLoadStatus.initial ||
          _summaryStatus == InventoryLoadStatus.loading ||
          _isDisposed) {
        return;
      }
      unawaited(loadSummary());
    });
  }

  final InventoryRepository _inventoryRepository;
  final FarmRepository _farmRepository;
  final ZonesRepository _zonesRepository;
  final InventoryPropertyProfile profile;

  InventoryLoadStatus _summaryStatus = InventoryLoadStatus.initial;
  InventoryLoadStatus get summaryStatus => _summaryStatus;

  InventoryLoadStatus _mapStatus = InventoryLoadStatus.initial;
  InventoryLoadStatus get mapStatus => _mapStatus;

  InventorySummary? _summary;
  InventorySummary? get summary => _summary;

  List<FarmPoint> _farmBoundaryPoints = const [];
  List<FarmPoint> get farmBoundaryPoints => _farmBoundaryPoints;

  Map<String, List<RegionPoint>> _zonePointsById = const {};
  Map<String, List<RegionPoint>> get zonePointsById => _zonePointsById;

  String? _mapMessage;
  String? get mapMessage => _mapMessage;

  bool _initializationStarted = false;
  bool _isDisposed = false;
  StreamSubscription<void>? _plantChangesSubscription;

  Future<void> initialize() async {
    if (_initializationStarted || _isDisposed) return;
    _initializationStarted = true;
    await Future.wait([loadSummary(), loadMapData()]);
  }

  Future<void> loadSummary() async {
    if (_summaryStatus == InventoryLoadStatus.loading || _isDisposed) return;
    _summaryStatus = InventoryLoadStatus.loading;
    _notifySafely();

    try {
      final summary = await _inventoryRepository.fetchSummary();
      if (_isDisposed) return;
      _summary = summary;
      _summaryStatus = InventoryLoadStatus.success;
    } on Exception {
      if (_isDisposed) return;
      _summaryStatus = InventoryLoadStatus.error;
    }
    _notifySafely();
  }

  Future<void> loadMapData() async {
    if (_mapStatus == InventoryLoadStatus.loading || _isDisposed) return;
    _mapStatus = InventoryLoadStatus.loading;
    _mapMessage = null;
    _notifySafely();

    var farmPoints = <FarmPoint>[];
    var zonePointsById = <String, List<RegionPoint>>{};
    var farmFailed = false;
    var zoneFailed = false;

    await Future.wait([
      () async {
        try {
          farmPoints = await _farmRepository.fetchFarmBoundary();
        } on Exception {
          farmFailed = true;
        }
      }(),
      () async {
        try {
          final zones = await _zonesRepository.fetchZones();
          if (zones.isEmpty) {
            zoneFailed = true;
            return;
          }
          final results = await Future.wait(
            zones.map((zone) async {
              try {
                final points = await _zonesRepository.fetchRegionsForZone(
                  zone.id,
                );
                return (zoneId: zone.id, points: points, failed: false);
              } on Exception {
                return (zoneId: zone.id, points: <RegionPoint>[], failed: true);
              }
            }),
          );
          zoneFailed = results.any((result) => result.failed);
          zonePointsById = {
            for (final result in results) result.zoneId: result.points,
          };
        } on Exception {
          zoneFailed = true;
        }
      }(),
    ]);

    if (_isDisposed) return;
    _farmBoundaryPoints = farmPoints;
    _zonePointsById = zonePointsById;

    final hasFarmPolygon = farmPoints.length >= 3;
    final hasZonePolygon = zonePointsById.values.any(
      (points) => points.length >= 3,
    );
    final bothSourcesFailed = farmFailed && zoneFailed && !hasZonePolygon;

    if (bothSourcesFailed) {
      _mapStatus = InventoryLoadStatus.error;
      _mapMessage = 'Não foi possível carregar os limites da propriedade.';
    } else {
      _mapStatus = InventoryLoadStatus.success;
      if (!hasFarmPolygon && !hasZonePolygon) {
        _mapMessage = 'Os limites da propriedade estão indisponíveis.';
      } else if (!hasFarmPolygon) {
        _mapMessage = 'O limite da fazenda não pôde ser exibido.';
      } else if (!hasZonePolygon) {
        _mapMessage = 'As zonas não puderam ser exibidas.';
      } else if (zoneFailed) {
        _mapMessage = 'Algumas zonas não puderam ser exibidas.';
      }
    }

    _notifySafely();
  }

  void _notifySafely() {
    if (!_isDisposed) notifyListeners();
  }

  @override
  void dispose() {
    _isDisposed = true;
    unawaited(_plantChangesSubscription?.cancel());
    super.dispose();
  }
}
