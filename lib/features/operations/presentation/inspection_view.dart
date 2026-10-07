import 'dart:async';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

import '../../../core/di/app_scope.dart';
import '../../farm/domain/user_location.dart';
import '../../farm/presentation/farm_map_geometry.dart';
import '../../farm/presentation/bounded_plant_markers.dart';
import '../../farm/presentation/plant_spatial_index.dart';
import '../../farm/presentation/user_map_navigation.dart';
import '../../../core/ui/map_activity.dart';
import '../../../core/ui/map_camera.dart';
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
    required this.onMapLongPress,
    required this.onRemoveAddedPlant,
    this.addedPlants = const [],
    this.polygons = const {},
    this.userLocation,
    this.canShowUserLocation = false,
  });

  final List<InspectionPlant> plants;
  final ValueChanged<InspectionPlant> onSelectPlant;
  final ValueChanged<LatLng> onMapLongPress;
  final ValueChanged<AddedInspectionPlant> onRemoveAddedPlant;
  final List<AddedInspectionPlant> addedPlants;
  final Set<Polygon> polygons;
  final UserLocation? userLocation;
  final bool canShowUserLocation;
}

typedef InspectionMapBuilder = Widget Function(
  BuildContext context,
  InspectionMapConfig config,
);

class InspectionView extends StatefulWidget {
  const InspectionView({this.viewModel, this.mapBuilder, super.key});

  final InspectionViewModel? viewModel;
  final InspectionMapBuilder? mapBuilder;

  @override
  State<InspectionView> createState() => _InspectionViewState();
}

class _InspectionViewState extends State<InspectionView> {
  static const _fallbackPosition = defaultFarmMapPosition;

  GoogleMapController? _mapController;
  CameraPosition? _savedCamera;
  BitmapDescriptor? _plantMarkerIcon;
  BitmapDescriptor? _nonExistentPlantMarkerIcon;
  BitmapDescriptor? _addedPlantMarkerIcon;
  BitmapDescriptor? _userMarkerIcon;
  final UserMapNavigator _userMapNavigator = UserMapNavigator();
  UserLocation? _lastUserLocation;
  bool _hasFocusedOnUser = false;
  Set<Marker> _markers = const {};
  final _plantLayer = BoundedPlantMarkers();
  String? _lastFittedFilterSignature;
  String? _lastTappedAddedPlantId;
  DateTime? _lastTappedAddedPlantAt;

  bool _hasSetInitialCamera = false;
  bool _userHasInteractedWithMap = false;
  String? _focusedZoneFilterId;
  String? _focusedOccurrenceFilterId;

  void _markersChanged() {
    if (mounted) setState(() => _markers = _plantLayer.markers);
  }

  @override
  void initState() {
    super.initState();
    _plantLayer.addListener(_markersChanged);
    unawaited(_loadPlantMarkerIcon());
    unawaited(_loadUserMarkerIcon());
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
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
    final vm =
        widget.viewModel ??
        scope?.inspectionViewModel ??
        (_fallbackVm ??= InspectionViewModel(
          repository: DefaultInspectionRepository(
            localStore: InspectionLocalStore(
              InspectionDatabase(projectUrl: ''),
            ),
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
    _plantLayer.dispose();
    _mapController = null;
    _fallbackVm?.dispose();
    super.dispose();
  }

  Future<void> _loadUserMarkerIcon() async {
    final icon = await createUserLocationMarkerIcon();
    if (mounted) setState(() => _userMarkerIcon = icon);
  }

  void _followUser(UserLocation location) {
    final controller = _mapController;
    if (controller == null) return;
    if (!_hasFocusedOnUser) {
      _hasFocusedOnUser = true;
      final vm = _effectiveViewModel;
      _focusedZoneFilterId = vm.selectedZoneFilterId;
      _focusedOccurrenceFilterId = vm.selectedOccurrenceFilterId;
      unawaited(
        _userMapNavigator.focus(
          controller,
          location,
          tilt: _savedCamera?.tilt ?? 0,
          bearing: _savedCamera?.bearing ?? 0,
        ),
      );
      return;
    }
    unawaited(
      _userMapNavigator.follow(
        location: location,
        controller: controller,
        camera: () => _savedCamera,
        isActive: () => mounted && _mapController == controller,
      ),
    );
  }

  Future<void> _loadPlantMarkerIcon() async {
    final icons = await Future.wait([
      _createPlantMarkerIcon(
        color: const Color(0xFF2E7D32),
        highlightColor: const Color(0xFF66BB6A),
      ),
      _createPlantMarkerIcon(
        color: const Color(0xFFF9A825),
        highlightColor: const Color(0xFFFFD54F),
      ),
      _createPlantMarkerIcon(
        color: const Color(0xFF0F766E),
        highlightColor: const Color(0xFF5EEAD4),
      ),
    ]);
    if (!mounted) return;
    _plantMarkerIcon = icons[0];
    _nonExistentPlantMarkerIcon = icons[1];
    _addedPlantMarkerIcon = icons[2];
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

  void _updateMarkers(InspectionViewModel vm) {
    if (widget.mapBuilder != null) return;
    final regularIcon =
        _plantMarkerIcon ??
        BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueGreen);
    final nonExistentIcon =
        _nonExistentPlantMarkerIcon ??
        BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueYellow);
    void select(String id) {
      if (!mounted) return;
      vm.selectPlantById(id);
      PlantEditorModal.show(context, vm);
    }

    _plantLayer.update(
      revision: (
        vm.allPlants,
        vm.selectedOccurrenceFilterId,
        vm.selectedZoneFilterId,
        _plantMarkerIcon,
        _nonExistentPlantMarkerIcon,
      ),
      plants: () => vm.plants
          .where((p) => p.hasValidCoordinates)
          .map((p) => SpatialPlant(p.id, p.latitude!, p.longitude!))
          .toList(growable: false),
      markerFor: (node) {
        final plant = vm.plantById(node.plantId!);
        final isNonExistent = plant?.nonExistent ?? false;
        return Marker(
          markerId: MarkerId(node.plantId!),
          position: LatLng(node.latitude, node.longitude),
          icon: isNonExistent ? nonExistentIcon : regularIcon,
          infoWindow: InfoWindow(title: plant?.label),
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

  Future<void> _fitCamera(InspectionViewModel vm) async {
    final controller = _mapController;
    if (controller == null) return;
    if (_hasFocusedOnUser &&
        _focusedZoneFilterId == vm.selectedZoneFilterId &&
        _focusedOccurrenceFilterId == vm.selectedOccurrenceFilterId) {
      return;
    }

    final currentSignature =
        '${vm.selectedOccurrenceFilterId}_${vm.selectedZoneFilterId}_${vm.selectedZonePoints.length}_'
        '${_plantLayer.bounds?.south}_${_plantLayer.bounds?.west}_'
        '${_plantLayer.bounds?.north}_${_plantLayer.bounds?.east}';
    final filterChanged = _lastFittedFilterSignature != currentSignature;

    if (!filterChanged && (_hasSetInitialCamera || _userHasInteractedWithMap)) {
      // Do not force recenter if user has already interacted manually and filter didn't change
      return;
    }

    _lastFittedFilterSignature = currentSignature;
    _focusedZoneFilterId = vm.selectedZoneFilterId;
    _focusedOccurrenceFilterId = vm.selectedOccurrenceFilterId;

    final userLoc = vm.userLocation;
    final zonePoints = vm.selectedZonePoints;

    if (userLoc != null && !filterChanged) {
      _hasSetInitialCamera = true;
      await animateMapCamera(
        controller,
        CameraUpdate.newLatLngZoom(
          LatLng(userLoc.latitude, userLoc.longitude),
          17,
        ),
      );
      return;
    }

    final zoneCoordinates = zonePoints.map(
      (p) => LatLng(p.latitude, p.longitude),
    );
    final plantBounds = _plantLayer.bounds;
    if (zoneCoordinates.isEmpty && plantBounds != null) {
      _hasSetInitialCamera = true;
      await animateMapCamera(
        controller,
        _cameraUpdateForSpatialBounds(plantBounds),
      );
      return;
    }

    final coordinates = [...zoneCoordinates];

    if (coordinates.isNotEmpty) {
      _hasSetInitialCamera = true;
      final viewport = calculateMapCameraViewport(
        coordinates,
        fallback: _fallbackPosition,
      );
      final bounds = viewport.bounds;
      await animateMapCamera(
        controller,
        bounds == null
            ? CameraUpdate.newLatLngZoom(viewport.target, 17)
            : CameraUpdate.newLatLngBounds(bounds, 64),
      );
    }
  }

  CameraUpdate _cameraUpdateForSpatialBounds(SpatialBounds bounds) {
    if (!bounds.hasArea) {
      return CameraUpdate.newLatLngZoom(
        LatLng(bounds.centerLatitude, bounds.centerLongitude),
        17,
      );
    }
    return CameraUpdate.newLatLngBounds(
      LatLngBounds(
        southwest: LatLng(bounds.south, bounds.west),
        northeast: LatLng(bounds.north, bounds.east),
      ),
      64,
    );
  }

  void _recenterOnUser(InspectionViewModel vm) {
    final loc = vm.userLocation;
    final controller = _mapController;
    if (loc != null && controller != null) {
      _hasFocusedOnUser = true;
      unawaited(
        _userMapNavigator.focus(
          controller,
          loc,
          tilt: _savedCamera?.tilt ?? 0,
          bearing: _savedCamera?.bearing ?? 0,
        ),
      );
    }
  }

  Set<Marker> _addedPlantMarkers(InspectionViewModel vm) {
    final icon =
        _addedPlantMarkerIcon ??
        BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueAzure);
    return {
      for (final plant in vm.addedPlants)
        if (plant.hasValidCoordinates &&
            (plant.status != InspectionSyncStatus.synced ||
                plant.remotePlantId == null ||
                vm.plantById(plant.remotePlantId!) == null))
          Marker(
            markerId: MarkerId('added-${plant.localId}'),
            position: LatLng(plant.latitude, plant.longitude),
            icon: icon,
            consumeTapEvents: true,
            infoWindow: InfoWindow(
              title: plant.nonExistent
                  ? 'Planta adicionada inexistente'
                  : 'Planta adicionada',
              snippet: plant.statusLabel,
            ),
            anchor: const Offset(0.5, 0.5),
            onTap: () => _handleAddedPlantMarkerTap(vm, plant),
          ),
    };
  }

  void _handleAddedPlantMarkerTap(
    InspectionViewModel vm,
    AddedInspectionPlant plant,
  ) {
    final now = DateTime.now();
    final isDoubleTap =
        _lastTappedAddedPlantId == plant.localId &&
        _lastTappedAddedPlantAt != null &&
        now.difference(_lastTappedAddedPlantAt!) <
            const Duration(milliseconds: 650);
    _lastTappedAddedPlantId = plant.localId;
    _lastTappedAddedPlantAt = now;
    if (isDoubleTap) {
      _lastTappedAddedPlantId = null;
      _lastTappedAddedPlantAt = null;
      unawaited(vm.removeAddedPlant(plant.localId));
    }
  }

  Future<void> _showAddPlantModal(
    InspectionViewModel vm,
    LatLng position,
  ) async {
    var nonExistent = false;
    String? selectedZoneId =
        vm.zones.any((z) => z.id == vm.selectedZoneFilterId)
        ? vm.selectedZoneFilterId
        : null;
    final shouldSave = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        final theme = Theme.of(context);
        final colorScheme = theme.colorScheme;
        return StatefulBuilder(
          builder: (context, setModalState) {
            return Material(
              color: colorScheme.surface,
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(24),
              ),
              clipBehavior: Clip.antiAlias,
              child: SafeArea(
                top: false,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Center(
                        child: Container(
                          width: 36,
                          height: 4,
                          decoration: BoxDecoration(
                            color: colorScheme.outlineVariant.withValues(
                              alpha: 0.6,
                            ),
                            borderRadius: BorderRadius.circular(2),
                          ),
                        ),
                      ),
                      const SizedBox(height: 18),
                      Row(
                        children: [
                          Icon(
                            Icons.add_location_alt_outlined,
                            color: colorScheme.secondary,
                            size: 24,
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              'Adicionar planta',
                              style: theme.textTheme.titleLarge?.copyWith(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      Text(
                        '${position.latitude.toStringAsFixed(6)}, ${position.longitude.toStringAsFixed(6)}',
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: colorScheme.onSurfaceVariant,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 18),
                      Text(
                        'Zona',
                        style: theme.textTheme.labelLarge?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: colorScheme.onSurface,
                        ),
                      ),
                      const SizedBox(height: 6),
                      InputDecorator(
                        decoration: InputDecoration(
                          prefixIcon: const Icon(Icons.grid_view_rounded),
                          filled: true,
                          fillColor: colorScheme.surfaceContainerHighest
                              .withValues(alpha: 0.35),
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 4,
                          ),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(14),
                            borderSide: BorderSide(
                              color: colorScheme.outlineVariant,
                            ),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(14),
                            borderSide: BorderSide(
                              color: colorScheme.outlineVariant,
                            ),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(14),
                            borderSide: BorderSide(
                              color: colorScheme.primary,
                              width: 2,
                            ),
                          ),
                        ),
                        child: DropdownButtonHideUnderline(
                          child: DropdownButton<String?>(
                            key: const ValueKey('added-plant-zone-dropdown'),
                            value: vm.zones.any((z) => z.id == selectedZoneId)
                                ? selectedZoneId
                                : null,
                            isExpanded: true,
                            hint: Text(
                              vm.zones.isEmpty
                                  ? 'Sem zona'
                                  : 'Selecione a zona',
                            ),
                            items: [
                              const DropdownMenuItem<String?>(
                                value: null,
                                child: Text('Sem zona'),
                              ),
                              for (final zone in vm.zones)
                                DropdownMenuItem<String?>(
                                  value: zone.id,
                                  child: Text(
                                    zone.name,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                            ],
                            onChanged: (newZoneId) {
                              setModalState(() => selectedZoneId = newZoneId);
                            },
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      SwitchListTile(
                        contentPadding: EdgeInsets.zero,
                        secondary: Icon(
                          nonExistent
                              ? Icons.hide_source_outlined
                              : Icons.spa_outlined,
                        ),
                        title: const Text('Marcar como inexistente'),
                        value: nonExistent,
                        onChanged: (value) {
                          setModalState(() => nonExistent = value);
                        },
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton(
                              onPressed: () => Navigator.of(context).pop(false),
                              child: const Text('Cancelar'),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: FilledButton.icon(
                              key: const ValueKey('confirm-added-plant-button'),
                              onPressed: () => Navigator.of(context).pop(true),
                              icon: const Icon(Icons.check_rounded),
                              label: const Text('Salvar'),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );

    if (shouldSave == true) {
      await vm.addPlantAt(
        latitude: position.latitude,
        longitude: position.longitude,
        nonExistent: nonExistent,
        zoneId: selectedZoneId,
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

        final location = vm.userLocation;
        if (location == null) {
          if (_lastUserLocation != null) _userMapNavigator.reset();
          _lastUserLocation = null;
          _hasFocusedOnUser = false;
        } else {
          _userMapNavigator.observe(location);
          if (!identical(_lastUserLocation, location)) {
            _lastUserLocation = location;
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (mounted) _followUser(location);
            });
          }
        }

        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) unawaited(_fitCamera(vm));
        });

        final mapConfig = InspectionMapConfig(
          plants: vm.plants,
          onSelectPlant: (plant) {
            vm.selectPlantById(plant.id);
            PlantEditorModal.show(context, vm);
          },
          onMapLongPress: (position) => _showAddPlantModal(vm, position),
          onRemoveAddedPlant: (plant) => vm.removeAddedPlant(plant.localId),
          addedPlants: vm.addedPlants,
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
            actions: [
              if (vm.userLocation != null)
                IconButton(
                  icon: const Icon(Icons.my_location),
                  tooltip: 'Minha localização',
                  onPressed: () => _recenterOnUser(vm),
                ),
            ],
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
                        child: ActiveMapSurface(
                          onActivityChanged: (active) {
                            if (active) {
                              vm.resumeLocation();
                            } else {
                              vm.pauseLocation();
                              _mapController = null;
                              _plantLayer.controller = null;
                            }
                          },
                          builder: (_) => GoogleMap(
                            key: const ValueKey('inspection-google-map'),
                            mapType: MapType.satellite,
                            initialCameraPosition:
                                _savedCamera ??
                                const CameraPosition(
                                  target: _fallbackPosition,
                                  zoom: 17,
                                ),
                            onCameraIdle: () {
                              _plantLayer.cameraIdle();
                              if (vm.userLocation case final location?) {
                                _userMapNavigator.invalidate();
                                _followUser(location);
                              }
                            },
                            onCameraMove: (position) => _savedCamera = position,
                            markers: {
                              ..._markers,
                              ..._addedPlantMarkers(vm),
                              if (vm.userLocation case final location?)
                                Marker(
                                  markerId: const MarkerId('inspection_user'),
                                  position: LatLng(
                                    location.latitude,
                                    location.longitude,
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
                            myLocationEnabled: false,
                            myLocationButtonEnabled: false,
                            onLongPress: (position) =>
                                _showAddPlantModal(vm, position),
                            onMapCreated: (controller) {
                              _mapController = controller;
                              _plantLayer.controller = controller;
                              _plantLayer.cameraIdle();
                              unawaited(_fitCamera(vm));
                              if (vm.userLocation case final location?) {
                                _followUser(location);
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
                              padding: const EdgeInsets.symmetric(
                                horizontal: 14,
                                vertical: 8,
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    vm.selectedOccurrenceFilter != null
                                        ? Icons.pest_control_outlined
                                        : Icons.grid_view_rounded,
                                    size: 18,
                                    color: Theme.of(context)
                                        .colorScheme
                                        .primary,
                                  ),
                                  const SizedBox(width: 8),
                                  Flexible(
                                    child: Text(
                                      _buildFilterBadgeLabel(vm),
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
                                    key: const ValueKey(
                                      'clear-occurrence-filter-button',
                                    ),
                                    borderRadius: BorderRadius.circular(12),
                                    onTap: () => vm.clearAllFilters(),
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

                    // Empty filter banner
                    if (vm.loadStatus == InspectionLoadStatus.success &&
                        vm.isFiltered &&
                        vm.plants.isEmpty)
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
                  TextButton(onPressed: onAction, child: Text(actionLabel!)),
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
