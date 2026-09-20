import 'dart:async';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

import '../../../core/di/app_scope.dart';
import '../../farm/domain/user_location.dart';
import '../../farm/presentation/farm_map_geometry.dart';
import '../data/inspection_database.dart';
import '../data/inspection_local_store.dart';
import '../data/inspection_remote_data_source.dart';
import '../data/inspection_repository.dart';
import '../domain/inspection_models.dart';
import 'inspection_view_model.dart';
import 'widgets/inspection_action_card.dart';
import 'widgets/plant_editor_modal.dart';

class InspectionMapConfig {
  const InspectionMapConfig({
    required this.plants,
    required this.onSelectPlant,
    this.polygons = const {},
    this.userLocation,
    this.canShowUserLocation = false,
  });

  final List<InspectionPlant> plants;
  final ValueChanged<InspectionPlant> onSelectPlant;
  final Set<Polygon> polygons;
  final UserLocation? userLocation;
  final bool canShowUserLocation;
}

typedef InspectionMapBuilder = Widget Function(
  BuildContext context,
  InspectionMapConfig config,
);

class InspectionView extends StatefulWidget {
  const InspectionView({
    this.viewModel,
    this.mapBuilder,
    super.key,
  });

  final InspectionViewModel? viewModel;
  final InspectionMapBuilder? mapBuilder;

  @override
  State<InspectionView> createState() => _InspectionViewState();
}

class _InspectionViewState extends State<InspectionView> {
  static const _fallbackPosition = defaultFarmMapPosition;
  static const _clusterManagerId = ClusterManagerId('inspection_plants');

  GoogleMapController? _mapController;
  BitmapDescriptor? _plantMarkerIcon;
  Set<Marker> _markers = const {};
  String? _lastMarkerSignature;
  String? _lastFittedFilterSignature;

  bool _hasSetInitialCamera = false;
  bool _userHasInteractedWithMap = false;

  late final _clusterManager = ClusterManager(
    clusterManagerId: _clusterManagerId,
    onClusterTap: (Cluster cluster) async {
      final controller = _mapController;
      if (controller == null) return;
      final currentZoom = await controller.getZoomLevel();
      await controller.animateCamera(
        CameraUpdate.newLatLngZoom(cluster.position, currentZoom + 2),
      );
    },
  );

  @override
  void initState() {
    super.initState();
    unawaited(_loadPlantMarkerIcon());
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final vm = _effectiveViewModel;
      final scope = AppScope.maybeOf(context);
      if (scope?.zonesRepository != null && vm.zones.isEmpty) {
        vm.attachZonesRepository(scope!.zonesRepository);
      }
      unawaited(vm.initialize());
    });
  }

  InspectionViewModel? _fallbackVm;

  InspectionViewModel get _effectiveViewModel {
    final scope = AppScope.maybeOf(context);
    final vm = widget.viewModel ??
        scope?.inspectionViewModel ??
        (_fallbackVm ??= InspectionViewModel(
          repository: DefaultInspectionRepository(
            localStore: InspectionLocalStore(InspectionDatabase(projectUrl: '')),
            remoteDataSource: const _DummyRemoteDataSource(),
          ),
          zonesRepository: scope?.zonesRepository,
          locationService: const _DummyLocationService(),
        ));
    if (scope?.zonesRepository != null && vm.zones.isEmpty) {
      vm.attachZonesRepository(scope!.zonesRepository);
    }
    return vm;
  }

  @override
  void dispose() {
    _mapController?.dispose();
    super.dispose();
  }

  Future<void> _loadPlantMarkerIcon() async {
    const size = 64;
    const center = Offset(size / 2, size / 2);
    const radius = 22.0;
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);

    canvas.drawCircle(center, radius + 5, Paint()..color = Colors.white);
    canvas.drawCircle(center, radius, Paint()..color = const Color(0xFF2E7D32));
    canvas.drawCircle(
      center.translate(-7, -7),
      6,
      Paint()..color = const Color(0xFF66BB6A),
    );

    final image = await recorder.endRecording().toImage(size, size);
    final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
    if (!mounted) return;
    setState(() {
      _plantMarkerIcon = BitmapDescriptor.bytes(
        bytes!.buffer.asUint8List(),
        width: 28,
        height: 28,
      );
    });
  }

  void _updateMarkers(InspectionViewModel vm) {
    final plants = vm.plants.where((p) => p.hasValidCoordinates).toList();
    final signature =
        '${vm.selectedOccurrenceFilterId}_${vm.selectedZoneFilterId}_${plants.length}_${_plantMarkerIcon != null}';
    if (_lastMarkerSignature == signature) return;
    _lastMarkerSignature = signature;

    final defaultGreen = BitmapDescriptor.defaultMarkerWithHue(
      BitmapDescriptor.hueGreen,
    );
    final icon = _plantMarkerIcon ?? defaultGreen;

    _markers = plants.map((plant) {
      return Marker(
        markerId: MarkerId(plant.id),
        position: LatLng(plant.latitude!, plant.longitude!),
        infoWindow: InfoWindow(title: plant.label),
        clusterManagerId: _clusterManagerId,
        icon: icon,
        anchor: const Offset(0.5, 0.5),
        onTap: () {
          vm.selectPlantById(plant.id);
          PlantEditorModal.show(context, vm);
        },
      );
    }).toSet();
  }

  Future<void> _fitCamera(InspectionViewModel vm) async {
    final controller = _mapController;
    if (controller == null) return;

    final currentSignature =
        '${vm.selectedOccurrenceFilterId}_${vm.selectedZoneFilterId}_${vm.selectedZonePoints.length}';
    final filterChanged = _lastFittedFilterSignature != currentSignature;

    if (!filterChanged && (_hasSetInitialCamera || _userHasInteractedWithMap)) {
      // Do not force recenter if user has already interacted manually and filter didn't change
      return;
    }

    _lastFittedFilterSignature = currentSignature;

    final userLoc = vm.userLocation;
    final validPlants = vm.plants.where((p) => p.hasValidCoordinates);
    final zonePoints = vm.selectedZonePoints;

    if (userLoc != null && !filterChanged) {
      _hasSetInitialCamera = true;
      await controller.animateCamera(
        CameraUpdate.newLatLngZoom(
          LatLng(userLoc.latitude, userLoc.longitude),
          17,
        ),
      );
      return;
    }

    final plantCoordinates = validPlants.map((p) => LatLng(p.latitude!, p.longitude!));
    final zoneCoordinates = zonePoints.map((p) => LatLng(p.latitude, p.longitude));
    final coordinates = [...plantCoordinates, ...zoneCoordinates];

    if (coordinates.isNotEmpty) {
      _hasSetInitialCamera = true;
      final viewport = calculateMapCameraViewport(coordinates, fallback: _fallbackPosition);
      final bounds = viewport.bounds;
      await controller.animateCamera(
        bounds == null
            ? CameraUpdate.newLatLngZoom(viewport.target, 17)
            : CameraUpdate.newLatLngBounds(bounds, 64),
      );
    }
  }

  String _buildFilterBadgeLabel(InspectionViewModel vm) {
    final parts = <String>[];
    if (vm.selectedZoneFilter case final zone?) {
      parts.add(zone.name);
    }
    if (vm.selectedOccurrenceFilter case final occ?) {
      parts.add(occ.name);
    }
    final text = parts.isEmpty ? 'Filtro ativo' : parts.join(' • ');
    return '$text (${vm.plants.length})';
  }

  @override
  Widget build(BuildContext context) {
    final vm = _effectiveViewModel;

    return ListenableBuilder(
      listenable: vm,
      builder: (context, _) {
        _updateMarkers(vm);

        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) unawaited(_fitCamera(vm));
        });

        final mapConfig = InspectionMapConfig(
          plants: vm.plants,
          onSelectPlant: (plant) {
            vm.selectPlantById(plant.id);
            PlantEditorModal.show(context, vm);
          },
          polygons: vm.polygons,
          userLocation: vm.userLocation,
          canShowUserLocation: vm.canShowUserLocation,
        );

        return Scaffold(
          backgroundColor: const Color(0xFFF4F7F2),
          appBar: AppBar(
            backgroundColor: const Color(0xFFF4F7F2),
            surfaceTintColor: Colors.transparent,
            title: const Text('Inspeção'),
          ),
          body: Column(
            children: [
              // Map Area
              Expanded(
                child: Stack(
                  children: [
                    if (widget.mapBuilder != null)
                      widget.mapBuilder!(context, mapConfig)
                    else
                      Listener(
                        onPointerDown: (_) => _userHasInteractedWithMap = true,
                        child: GoogleMap(
                          key: const ValueKey('inspection-google-map'),
                          mapType: MapType.satellite,
                          initialCameraPosition: const CameraPosition(
                            target: _fallbackPosition,
                            zoom: 17,
                          ),
                          clusterManagers: {_clusterManager},
                          markers: _markers,
                          polygons: vm.polygons,
                          myLocationEnabled: vm.canShowUserLocation,
                          myLocationButtonEnabled: vm.canShowUserLocation,
                          onMapCreated: (controller) {
                            _mapController = controller;
                            unawaited(_fitCamera(vm));
                          },
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

                    // Status Banners
                    if (vm.loadStatus == InspectionLoadStatus.empty)
                      _StatusBanner(
                        key: const ValueKey('inspection-empty-banner'),
                        message: 'Nenhuma planta encontrada.',
                        icon: Icons.info_outline,
                      ),

                    if (vm.loadStatus == InspectionLoadStatus.error)
                      _StatusBanner(
                        key: const ValueKey('inspection-error-banner'),
                        message: vm.errorMessage ?? 'Erro ao carregar plantas.',
                        icon: Icons.error_outline,
                        actionLabel: 'Tentar novamente',
                        onAction: () => vm.loadPlants(),
                      ),

                    // Active filter badge (Zone and/or Occurrence)
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
                              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    vm.selectedOccurrenceFilter != null
                                        ? Icons.pest_control_outlined
                                        : Icons.grid_view_rounded,
                                    size: 18,
                                    color: Theme.of(context).colorScheme.primary,
                                  ),
                                  const SizedBox(width: 8),
                                  Flexible(
                                    child: Text(
                                      _buildFilterBadgeLabel(vm),
                                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                        fontWeight: FontWeight.bold,
                                      ),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  InkWell(
                                    key: const ValueKey('clear-occurrence-filter-button'),
                                    borderRadius: BorderRadius.circular(12),
                                    onTap: () => vm.clearAllFilters(),
                                    child: Padding(
                                      padding: const EdgeInsets.all(2),
                                      child: Icon(
                                        Icons.close,
                                        size: 18,
                                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),

                    // Empty filter banner
                    if (vm.loadStatus == InspectionLoadStatus.success && vm.isFiltered && vm.plants.isEmpty)
                      _StatusBanner(
                        key: const ValueKey('inspection-empty-filter-banner'),
                        message: 'Nenhuma planta encontrada com os filtros selecionados.',
                        icon: Icons.filter_alt_off_outlined,
                        actionLabel: 'Mostrar todas',
                        onAction: () => vm.clearAllFilters(),
                      ),

                    if (vm.locationMessage case final message?)
                      Positioned(
                        bottom: 8,
                        left: 16,
                        right: 16,
                        child: _StatusBanner(
                          message: message,
                          icon: Icons.location_off_outlined,
                        ),
                      ),
                  ],
                ),
              ),

              // Bottom Action Card
              InspectionActionCard(viewModel: vm),
            ],
          ),
        );
      },
    );
  }
}

class _StatusBanner extends StatelessWidget {
  const _StatusBanner({
    required this.message,
    required this.icon,
    this.actionLabel,
    this.onAction,
    super.key,
  });

  final String message;
  final IconData icon;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return SafeArea(
      minimum: const EdgeInsets.all(12),
      child: Center(
        child: Material(
          elevation: 3,
          borderRadius: BorderRadius.circular(16),
          color: colorScheme.surface,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(icon, size: 20, color: colorScheme.primary),
                const SizedBox(width: 10),
                Flexible(
                  child: Text(
                    message,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
                if (actionLabel != null) ...[
                  const SizedBox(width: 8),
                  TextButton(
                    onPressed: onAction,
                    child: Text(actionLabel!),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _DummyLocationService implements LocationService {
  const _DummyLocationService();

  @override
  Future<LocationResult> getCurrentLocation() async =>
      const LocationResult.serviceDisabled();

  @override
  Stream<LocationResult> watchLocation() => const Stream.empty();
}

class _DummyRemoteDataSource implements InspectionRemoteDataSource {
  const _DummyRemoteDataSource();

  @override
  Future<List<OccurrenceType>> fetchOccurrenceTypes() async => const [];

  @override
  Future<List<InspectionPlant>> fetchPlants({int pageSize = 1000}) async => const [];

  @override
  Future<Map<String, Set<String>>> fetchOpenOccurrences(
    List<String> plantIds, {
    int batchSize = 500,
  }) async => const {};

  @override
  Future<InspectionSnapshot> fetchSnapshot({int pageSize = 1000}) async =>
      InspectionSnapshot(plants: const [], types: const [], loadedAt: DateTime.now());

  @override
  Future<InspectionSyncResult> syncInspection(Map<String, dynamic> payload) async =>
      const InspectionSyncResult(operationId: '', created: 0, updated: 0, resolved: 0);
}
