import 'dart:async';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

import '../../../core/di/app_scope.dart';
import '../../../core/ui/map_activity.dart';
import '../../farm/domain/user_location.dart';
import '../../farm/presentation/bounded_plant_markers.dart';
import '../../farm/presentation/farm_map_geometry.dart';
import '../../farm/presentation/plant_spatial_index.dart';
import '../../farm/presentation/user_map_navigation.dart';
import '../data/inspection_database.dart';
import '../data/inspection_local_store.dart';
import '../data/inspection_remote_data_source.dart';
import '../data/inspection_repository.dart';
import '../data/spraying_database.dart';
import '../data/spraying_local_store.dart';
import '../data/spraying_remote_data_source.dart';
import '../data/spraying_repository.dart';
import '../domain/inspection_models.dart';
import '../domain/spraying_models.dart';
import 'inspection_view_model.dart';
import 'spraying_heading.dart';
import 'spraying_map_camera.dart';
import 'spraying_view_model.dart';
import 'widgets/spraying_action_card.dart';
import 'widgets/spraying_review_action_bar.dart';
import 'widgets/spraying_signal_overlay.dart';

class SprayingMapConfig {
  const SprayingMapConfig({
    required this.plants,
    required this.polylines,
    required this.polygons,
    required this.onSelectPlant,
    this.initialPosition,
  });

  final List<InspectionPlant> plants;
  final Set<Polyline> polylines;
  final Set<Polygon> polygons;
  final ValueChanged<InspectionPlant> onSelectPlant;
  final CameraPosition? initialPosition;
}

typedef SprayingMapBuilder = Widget Function(
  BuildContext context,
  SprayingMapConfig config,
);

class SprayingView extends StatefulWidget {
  const SprayingView({this.viewModel, this.mapBuilder, super.key});

  final SprayingViewModel? viewModel;
  final SprayingMapBuilder? mapBuilder;

  @override
  State<SprayingView> createState() => _SprayingViewState();
}

class _SprayingViewState extends State<SprayingView> {
  static const _fallbackPosition = defaultFarmMapPosition;
  static const _recordingStartZoom = userFollowZoom;

  GoogleMapController? _mapController;
  CameraPosition? _savedCamera;
  BitmapDescriptor? _plantMarkerIcon;
  BitmapDescriptor? _pulverizedPlantMarkerIcon;
  BitmapDescriptor? _userMarkerIcon;
  final SprayingCourseTracker _courseTracker = SprayingCourseTracker();
  Set<Marker> _markers = const {};
  final _plantLayer = BoundedPlantMarkers();
  String? _lastZoneSignature;
  String? _lastReviewingOpId;
  bool _userHasInteractedWithMap = false;
  SprayingSessionState? _lastSessionState;
  bool _needsInitialFocus = false;
  bool _checkingVisibleRegion = false;
  UserLocation? _lastCheckedLocation;
  UserLocation? _queuedLocation;

  void _markersChanged() {
    if (mounted) setState(() => _markers = _plantLayer.markers);
  }

  @override
  void initState() {
    super.initState();
    _plantLayer.addListener(_markersChanged);
    unawaited(_loadPlantMarkerIcons());

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final vm = _effectiveViewModel;
      final scope = AppScope.maybeOf(context);
      if (scope?.zonesRepository != null && vm.zones.isEmpty) {
        vm.loadZones(repo: scope!.zonesRepository);
      }
      vm.startLocationTracking();
      if (vm.allPlants.isEmpty) {
        unawaited(vm.loadPlants());
      }
    });
  }

  Future<void> _loadPlantMarkerIcons() async {
    final icons = await Future.wait([
      _createPlantMarkerIcon(
        color: const Color(0xFF2E7D32),
        highlightColor: const Color(0xFF66BB6A),
      ),
      _createPlantMarkerIcon(
        color: const Color(0xFF1D4ED8),
        highlightColor: const Color(0xFF60A5FA),
      ),
      createUserLocationMarkerIcon(),
    ]);
    if (!mounted) return;
    _plantMarkerIcon = icons[0];
    _pulverizedPlantMarkerIcon = icons[1];
    _userMarkerIcon = icons[2];
    _updateMarkers(_effectiveViewModel);
    setState(() {});
  }

  Future<BitmapDescriptor> _createPlantMarkerIcon({
    required Color color,
    required Color highlightColor,
  }) async {
    const size = 64;
    const center = Offset(size / 2, size / 2);
    const radius = 22.0;
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);

    canvas.drawCircle(center, radius + 5, Paint()..color = Colors.white);
    canvas.drawCircle(center, radius, Paint()..color = color);
    canvas.drawCircle(
      center.translate(-7, -7),
      6,
      Paint()..color = highlightColor,
    );

    final picture = recorder.endRecording();
    final image = await picture.toImage(size, size);
    picture.dispose();
    final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
    image.dispose();
    return BitmapDescriptor.bytes(
      bytes!.buffer.asUint8List(),
      width: 28,
      height: 28,
    );
  }

  SprayingViewModel? _fallbackVm;

  SprayingViewModel get _effectiveViewModel {
    final scope = AppScope.maybeOf(context);
    final vm =
        widget.viewModel ??
        scope?.sprayingViewModel ??
        (_fallbackVm ??= SprayingViewModel(
          sprayingRepository: DefaultSprayingRepository(
            localStore: SprayingLocalStore(SprayingDatabase(projectUrl: '')),
            remoteDataSource: const _DummySprayingRemoteDataSource(),
          ),
          inspectionRepository: DefaultInspectionRepository(
            localStore: InspectionLocalStore(
              InspectionDatabase(projectUrl: ''),
            ),
            remoteDataSource: const _DummyInspectionRemoteDataSource(),
          ),
          locationService: const _DummyLocationService(),
          zonesRepository: scope?.zonesRepository,
        ));
    return vm;
  }

  @override
  void dispose() {
    _plantLayer.removeListener(_markersChanged);
    _plantLayer.dispose();
    _mapController = null;
    _fallbackVm?.dispose();
    super.dispose();
  }

  void _updateMarkers(SprayingViewModel vm) {
    if (widget.mapBuilder != null) return;
    final regularIcon =
        _plantMarkerIcon ??
        BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueGreen);
    final pulverizedIcon =
        _pulverizedPlantMarkerIcon ??
        BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueAzure);

    void select(String id) {
      final plant = vm.plantById(id);
      if (plant != null) {
        vm.toggleAffectedPlant(plant);
      }
    }

    _plantLayer.update(
      revision: (
        vm.displayedPlants,
        vm.reviewedPlantIds,
        _plantMarkerIcon,
        _pulverizedPlantMarkerIcon,
      ),
      plants: () => vm.displayedPlants
          .where((p) => p.hasValidCoordinates && !p.nonExistent)
          .map((p) => SpatialPlant(p.id, p.latitude!, p.longitude!))
          .toList(growable: false),
      markerFor: (node) {
        final plant = vm.plantById(node.plantId!);
        final isPulverized = vm.reviewedPlantIds.contains(node.plantId);
        return Marker(
          markerId: MarkerId(node.plantId!),
          position: LatLng(node.latitude, node.longitude),
          icon: isPulverized ? pulverizedIcon : regularIcon,
          infoWindow: InfoWindow(
            title: plant?.label,
            snippet: isPulverized ? 'Planta Atingida (Azul)' : null,
          ),
          anchor: const Offset(0.5, 0.5),
          onTap: () => select(node.plantId!),
        );
      },
      onClusterTap: (node) => showPlantClusterMembers(
        context,
        layer: _plantLayer,
        node: node,
        labelFor: (id) => vm.plantById(id)?.label ?? id,
        onSelect: select,
      ),
    );
  }

  void _recenterOnUser(SprayingViewModel vm, {double zoom = 19}) {
    final loc = vm.userLocation;
    final controller = _mapController;
    if (loc == null || controller == null) return;
    _needsInitialFocus = false;
    _lastCheckedLocation = loc;
    final position = LatLng(loc.latitude, loc.longitude);
    final course = vm.sessionState == SprayingSessionState.recording
        ? _courseTracker.course
        : null;
    controller.animateCamera(
      course == null
          ? CameraUpdate.newLatLngZoom(position, zoom)
          : CameraUpdate.newCameraPosition(
              CameraPosition(
                target: position,
                zoom: zoom,
                tilt: _savedCamera?.tilt ?? 0,
                bearing: course,
              ),
            ),
    );
  }

  Future<void> _keepUserVisible(
    UserLocation location,
    SprayingViewModel vm,
  ) async {
    if (!mounted ||
        vm.sessionState != SprayingSessionState.recording ||
        _needsInitialFocus ||
        identical(_lastCheckedLocation, location)) {
      return;
    }
    if (_checkingVisibleRegion) {
      _queuedLocation = location;
      return;
    }
    final controller = _mapController;
    if (controller == null) return;

    _checkingVisibleRegion = true;
    try {
      final bounds = await controller.getVisibleRegion();
      if (!mounted ||
          _mapController != controller ||
          vm.sessionState != SprayingSessionState.recording) {
        return;
      }
      _lastCheckedLocation = location;
      final outsideFocusArea = !isInsideSprayingFocusArea(
        bounds,
        LatLng(location.latitude, location.longitude),
      );
      final camera = _savedCamera;
      final bearing = nextSprayingMapBearing(
        camera?.bearing ?? 0,
        _courseTracker.course,
      );
      final position = sprayingFollowCameraPosition(
        current:
            camera ??
            CameraPosition(
              target: LatLng(location.latitude, location.longitude),
              zoom: _recordingStartZoom,
            ),
        user: LatLng(location.latitude, location.longitude),
        outsideFocusArea: outsideFocusArea,
        bearing: bearing,
      );
      if (position != null) {
        await controller.animateCamera(
          CameraUpdate.newCameraPosition(position),
        );
      }
    } catch (error) {
      debugPrint('Erro ao acompanhar localizacao no mapa: $error');
    } finally {
      _checkingVisibleRegion = false;
      final queued = _queuedLocation;
      _queuedLocation = null;
      if (queued != null) {
        _lastCheckedLocation = null;
        unawaited(_keepUserVisible(queued, vm));
      }
    }
  }

  void _fitRouteBounds(SprayingOperation op) {
    if (_mapController == null || op.trackPoints.length < 2) return;
    var minLat = double.infinity;
    var maxLat = -double.infinity;
    var minLon = double.infinity;
    var maxLon = -double.infinity;

    for (final p in op.trackPoints) {
      if (p.latitude < minLat) minLat = p.latitude;
      if (p.latitude > maxLat) maxLat = p.latitude;
      if (p.longitude < minLon) minLon = p.longitude;
      if (p.longitude > maxLon) maxLon = p.longitude;
    }

    _mapController!.animateCamera(
      CameraUpdate.newLatLngBounds(
        LatLngBounds(
          southwest: LatLng(minLat, minLon),
          northeast: LatLng(maxLat, maxLon),
        ),
        56,
      ),
    );
  }

  void _fitZoneBounds(SprayingViewModel vm) {
    final points = vm.selectedZonePoints;
    if (points.length < 3 || _mapController == null) return;

    final signature = '${vm.selectedZoneFilterId}:${points.length}';
    if (_lastZoneSignature == signature) return;
    _lastZoneSignature = signature;

    var minLat = double.infinity;
    var maxLat = -double.infinity;
    var minLon = double.infinity;
    var maxLon = -double.infinity;

    for (final p in points) {
      if (p.latitude < minLat) minLat = p.latitude;
      if (p.latitude > maxLat) maxLat = p.latitude;
      if (p.longitude < minLon) minLon = p.longitude;
      if (p.longitude > maxLon) maxLon = p.longitude;
    }

    _mapController!.animateCamera(
      CameraUpdate.newLatLngBounds(
        LatLngBounds(
          southwest: LatLng(minLat, minLon),
          northeast: LatLng(maxLat, maxLon),
        ),
        48,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final vm = _effectiveViewModel;

    return ListenableBuilder(
      listenable: vm,
      builder: (context, _) {
        _updateMarkers(vm);
        if (vm.selectedZonePoints.length >= 3) {
          WidgetsBinding.instance.addPostFrameCallback(
            (_) => _fitZoneBounds(vm),
          );
        }

        if (vm.isReviewing && vm.reviewingOperation != null) {
          final reviewOpId = vm.reviewingOperation!.localId;
          if (_lastReviewingOpId != reviewOpId) {
            _lastReviewingOpId = reviewOpId;
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (mounted && vm.reviewingOperation != null) {
                _fitRouteBounds(vm.reviewingOperation!);
              }
            });
          }
        } else {
          _lastReviewingOpId = null;
        }

        // Exibe feedback se houver
        if (vm.feedbackMessage != null) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(vm.feedbackMessage!),
                  backgroundColor: const Color(0xFF15803D),
                ),
              );
              vm.clearMessages();
            }
          });
        }

        if (vm.errorMessage != null &&
            (ModalRoute.of(context)?.isCurrent ?? true)) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(vm.errorMessage!),
                  backgroundColor: Colors.red,
                ),
              );
              vm.clearMessages();
            }
          });
        }

        if (_lastSessionState != vm.sessionState) {
          if (vm.sessionState == SprayingSessionState.recording &&
              _lastSessionState != SprayingSessionState.paused) {
            _courseTracker.reset();
            _needsInitialFocus = true;
            _lastCheckedLocation = null;
            _userHasInteractedWithMap = false;
            if (vm.userLocation != null) {
              WidgetsBinding.instance.addPostFrameCallback((_) {
                if (mounted) {
                  _recenterOnUser(vm, zoom: _recordingStartZoom);
                }
              });
            }
          }
          _lastSessionState = vm.sessionState;
        }

        if (vm.sessionState == SprayingSessionState.recording &&
            vm.userLocation != null) {
          final loc = vm.userLocation!;
          _courseTracker.add(loc);
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (!mounted) return;
            if (_needsInitialFocus) {
              _recenterOnUser(vm, zoom: _recordingStartZoom);
            } else {
              unawaited(_keepUserVisible(loc, vm));
            }
          });
        }

        return Scaffold(
          backgroundColor: const Color(0xFFF4F7F2),
          appBar: AppBar(
            backgroundColor: const Color(0xFFF4F7F2),
            surfaceTintColor: Colors.transparent,
            title: const Text('Pulverização'),
            actions: [
              if (vm.userLocation != null)
                IconButton(
                  icon: const Icon(Icons.my_location),
                  tooltip: 'Minha localização',
                  onPressed: () => _recenterOnUser(vm),
                ),
            ],
          ),
          body: Stack(
            children: [
              Column(
                children: [
                  Expanded(
                    child: Stack(
                      children: [
                        if (widget.mapBuilder != null)
                          widget.mapBuilder!(
                            context,
                            SprayingMapConfig(
                              plants: vm.displayedPlants,
                              polylines: vm.polylines,
                              polygons: vm.polygons,
                              onSelectPlant: (p) => vm.toggleAffectedPlant(p),
                              initialPosition: const CameraPosition(
                                target: _fallbackPosition,
                                zoom: 17,
                              ),
                            ),
                          )
                        else
                          Listener(
                            onPointerDown: (_) {
                              _userHasInteractedWithMap = true;
                            },
                            child: ActiveMapSurface(
                              onActivityChanged: (active) {
                                if (active) {
                                  vm.startLocationTracking();
                                } else {
                                  vm.stopLocationTracking();
                                  _mapController = null;
                                  _plantLayer.controller = null;
                                }
                              },
                              builder: (_) => GoogleMap(
                                key: const ValueKey('spraying-google-map'),
                                mapType: MapType.satellite,
                                initialCameraPosition:
                                    _savedCamera ??
                                    const CameraPosition(
                                      target: _fallbackPosition,
                                      zoom: 17,
                                    ),
                                onCameraIdle: () {
                                  _plantLayer.cameraIdle();
                                  final loc = vm.userLocation;
                                  if (vm.sessionState ==
                                          SprayingSessionState.recording &&
                                      loc != null) {
                                    _lastCheckedLocation = null;
                                    unawaited(_keepUserVisible(loc, vm));
                                  }
                                },
                                onCameraMove: (position) =>
                                    _savedCamera = position,
                                markers: {
                                  ..._markers,
                                  if (vm.userLocation case final loc?)
                                    Marker(
                                      markerId: const MarkerId('spraying_user'),
                                      position: LatLng(
                                        loc.latitude,
                                        loc.longitude,
                                      ),
                                      icon:
                                          _userMarkerIcon ??
                                          BitmapDescriptor.defaultMarkerWithHue(
                                            BitmapDescriptor.hueAzure,
                                          ),
                                      anchor: const Offset(0.5, 0.5),
                                      zIndexInt: 1000,
                                    ),
                                },
                                polygons: vm.polygons,
                                polylines: vm.polylines,
                                myLocationEnabled: false,
                                myLocationButtonEnabled: false,
                                zoomControlsEnabled: false,
                                mapToolbarEnabled: false,
                                onMapCreated: (ctrl) {
                                  _mapController = ctrl;
                                  _plantLayer.controller = ctrl;
                                  _plantLayer.cameraIdle();
                                  if (vm.userLocation != null &&
                                      (_needsInitialFocus ||
                                          !_userHasInteractedWithMap)) {
                                    _recenterOnUser(
                                      vm,
                                      zoom: _needsInitialFocus
                                          ? _recordingStartZoom
                                          : 19,
                                    );
                                  }
                                },
                              ),
                            ),
                          ),

                        // Loading overlay
                        if (vm.loadStatus == InspectionLoadStatus.loading)
                          const Positioned(
                            top: 0,
                            left: 0,
                            right: 0,
                            child: LinearProgressIndicator(),
                          ),

                        // Badge de Filtro Ativo
                        if (vm.isFiltered)
                          Positioned(
                            top: 12,
                            left: 16,
                            right: 16,
                            child: Center(
                              child: Material(
                                elevation: 4,
                                borderRadius: BorderRadius.circular(20),
                                color: Theme.of(context).colorScheme.surface,
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 14,
                                    vertical: 8,
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(
                                        Icons.grid_view_rounded,
                                        size: 18,
                                        color: Theme.of(context)
                                            .colorScheme
                                            .primary,
                                      ),
                                      const SizedBox(width: 8),
                                      Flexible(
                                        child: Text(
                                          vm.zones.any(
                                                (z) =>
                                                    z.id ==
                                                    vm.selectedZoneFilterId,
                                              )
                                              ? vm.zones
                                                    .firstWhere(
                                                      (z) =>
                                                          z.id ==
                                                          vm.selectedZoneFilterId,
                                                    )
                                                    .name
                                              : 'Zona filtrada',
                                          style: Theme.of(context)
                                              .textTheme
                                              .bodyMedium
                                              ?.copyWith(
                                                fontWeight: FontWeight.bold,
                                              ),
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      InkWell(
                                        borderRadius: BorderRadius.circular(12),
                                        onTap: () => vm.setZoneFilter(null),
                                        child: Padding(
                                          padding: const EdgeInsets.all(2),
                                          child: Icon(
                                            Icons.close,
                                            size: 18,
                                            color: Theme.of(context)
                                                .colorScheme
                                                .onSurfaceVariant,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),

                  // Card de Ações abaixo do mapa
                  if (vm.isReviewing)
                    SprayingReviewActionBar(viewModel: vm)
                  else
                    SprayingActionCard(viewModel: vm),
                ],
              ),
              if (vm.isPreparingSession)
                Positioned.fill(
                  child: SprayingSignalOverlay(
                    onCancel: vm.sessionState == SprayingSessionState.idle
                        ? vm.cancelSessionPreparation
                        : null,
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}

class _DummySprayingRemoteDataSource implements SprayingRemoteDataSource {
  const _DummySprayingRemoteDataSource();

  @override
  Future<SprayingSyncResult> syncSprayingOperation(
    Map<String, dynamic> payload,
  ) async => SprayingSyncResult(
    fieldOperationId: '',
    routeId: '',
    trackPointsCount: 0,
    inputsCount: 0,
    confirmedPlantsCount: 0,
    syncedAt: DateTime.now().toUtc(),
  );

  @override
  Future<List<Map<String, dynamic>>> recalculateAffectedPlants({
    required Map<String, dynamic> geojson,
    String? zoneId,
    double maxDistanceMeters = 9.0,
  }) async => const [];
}

class _DummyInspectionRemoteDataSource implements InspectionRemoteDataSource {
  const _DummyInspectionRemoteDataSource();

  @override
  Future<List<OccurrenceType>> fetchOccurrenceTypes() async => const [];

  @override
  Future<List<InspectionPlant>> fetchPlants({int pageSize = 1000}) async =>
      const [];

  @override
  Future<Map<String, Set<String>>> fetchOpenOccurrences(
    List<String> plantIds, {
    int batchSize = 500,
  }) async => const {};

  @override
  Future<InspectionSnapshot> fetchSnapshot({int pageSize = 1000}) async =>
      InspectionSnapshot(
        plants: const [],
        types: const [],
        loadedAt: DateTime.now(),
      );

  @override
  Future<InspectionSyncResult> syncInspection(
    Map<String, dynamic> payload,
  ) async => const InspectionSyncResult(
    operationId: '',
    created: 0,
    updated: 0,
    resolved: 0,
  );

  @override
  Future<List<AddedPlantSyncResult>> syncAddedPlants(
    Map<String, dynamic> payload,
  ) async => const [];
}

class _DummyLocationService implements LocationService {
  const _DummyLocationService();

  @override
  Future<LocationResult> getCurrentLocation() async =>
      const LocationResult.permissionDenied();

  @override
  Stream<LocationResult> watchLocation() => const Stream.empty();
}
