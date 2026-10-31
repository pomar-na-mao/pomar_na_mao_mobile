import 'dart:async';

import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

import '../../../core/ui/map_activity.dart';
import '../../farm/domain/user_location.dart';
import '../../farm/domain/region_point.dart';
import '../../farm/presentation/bounded_plant_markers.dart';
import '../../farm/presentation/farm_map_geometry.dart';
import '../../farm/presentation/plant_spatial_index.dart';
import '../../farm/presentation/user_map_navigation.dart';
import '../domain/activity_models.dart';
import '../domain/inspection_models.dart';
import 'activity_view_model.dart';
import 'operation_map_style.dart';
import 'widgets/activity_entry_modal.dart';
import 'widgets/activity_saved_entries.dart';
import 'widgets/activity_zone_filter_modal.dart';
import 'widgets/operation_action_button.dart';

class ActivityMapConfig {
  const ActivityMapConfig({
    required this.plants,
    required this.geometryType,
    required this.points,
    required this.onAddPoint,
    this.selectedZoneId,
    this.selectedZonePoints = const [],
    this.userLocation,
    this.initialCameraPosition = const CameraPosition(
      target: defaultFarmMapPosition,
      zoom: OperationMapStyle.initialZoom,
    ),
    this.onCameraMove,
  });

  final List<InspectionPlant> plants;
  final ActivityGeometryType geometryType;
  final List<ActivityPoint> points;
  final ValueChanged<ActivityPoint> onAddPoint;
  final String? selectedZoneId;
  final List<RegionPoint> selectedZonePoints;
  final UserLocation? userLocation;
  final CameraPosition initialCameraPosition;
  final ValueChanged<CameraPosition>? onCameraMove;
}

typedef ActivityMapBuilder = Widget Function(
  BuildContext context,
  ActivityMapConfig config,
);

class ActivityView extends StatefulWidget {
  const ActivityView({required this.viewModel, this.mapBuilder, super.key});

  final ActivityViewModel viewModel;
  final ActivityMapBuilder? mapBuilder;

  @override
  State<ActivityView> createState() => _ActivityViewState();
}

class _ActivityViewState extends State<ActivityView> {
  final _plantLayer = BoundedPlantMarkers();
  Set<Marker> _markers = const {};
  BitmapDescriptor? _plantIcon;
  BitmapDescriptor? _userIcon;
  GoogleMapController? _controller;
  GoogleMapController? _drawingController;
  Future<void> _drawingQueue = Future.value();
  final Set<String> _activeMapSurfaces = {};
  Timer? _pauseLocationTimer;
  CameraPosition _drawingCameraPosition = const CameraPosition(
    target: defaultFarmMapPosition,
    zoom: OperationMapStyle.initialZoom,
  );
  var _drawingEnabled = false;
  String? _lastFittedZoneSignature;
  String? _pendingFittedZoneSignature;
  String? _lastFittedDrawingZoneSignature;
  String? _pendingFittedDrawingZoneSignature;

  @override
  void initState() {
    super.initState();
    _plantLayer.addListener(_markersChanged);
    unawaited(_loadIcons());
    WidgetsBinding.instance.addPostFrameCallback(
      (_) => widget.viewModel.initialize(),
    );
  }

  Future<void> _loadIcons() async {
    final icons = await Future.wait([
      OperationMapStyle.createPlantMarkerIcon(
        color: OperationMapStyle.plantColor,
        highlightColor: OperationMapStyle.plantHighlightColor,
      ),
      createUserLocationMarkerIcon(),
    ]);
    if (!mounted) return;
    setState(() {
      _plantIcon = icons[0];
      _userIcon = icons[1];
    });
  }

  void _markersChanged() {
    if (mounted) setState(() => _markers = _plantLayer.markers);
  }

  void _setMapSurfaceActive(String surface, bool active) {
    final wasActive = _activeMapSurfaces.isNotEmpty;
    final changed = active
        ? _activeMapSurfaces.add(surface)
        : _activeMapSurfaces.remove(surface);
    if (!changed) return;
    final isActive = _activeMapSurfaces.isNotEmpty;
    if (wasActive == isActive) return;
    if (isActive) {
      _pauseLocationTimer?.cancel();
      _pauseLocationTimer = null;
      widget.viewModel.resumeLocation();
    } else {
      _pauseLocationTimer?.cancel();
      _pauseLocationTimer = Timer(const Duration(milliseconds: 300), () {
        _pauseLocationTimer = null;
        if (mounted && _activeMapSurfaces.isEmpty) {
          widget.viewModel.pauseLocation();
        }
      });
    }
  }

  void _queueScreenPoint(Offset localPosition) {
    final controller = _controller;
    if (!_drawingEnabled || controller == null) return;
    final pixelRatio = MediaQuery.devicePixelRatioOf(context);
    final coordinate = ScreenCoordinate(
      x: (localPosition.dx * pixelRatio).round(),
      y: (localPosition.dy * pixelRatio).round(),
    );
    _drawingQueue = _drawingQueue.then((_) async {
      final position = await controller.getLatLng(coordinate);
      if (!mounted || !_drawingEnabled) return;
      widget.viewModel.addPoint(
        ActivityPoint(position.latitude, position.longitude),
      );
    });
  }

  void _updateMarkers() {
    final vm = widget.viewModel;
    _plantLayer.update(
      revision: (vm.plants, _plantIcon),
      plants: () => [
        for (final plant in vm.plants)
          SpatialPlant(plant.id, plant.latitude!, plant.longitude!),
      ],
      markerFor: (node) => Marker(
        markerId: MarkerId('activity_${node.plantId}'),
        position: LatLng(node.latitude, node.longitude),
        icon:
            _plantIcon ??
            BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueGreen),
        anchor: OperationMapStyle.markerAnchor,
      ),
      onClusterTap: (node) => showPlantClusterMembers(
        context,
        layer: _plantLayer,
        node: node,
        labelFor: (plantId) {
          for (final plant in vm.plants) {
            if (plant.id == plantId) return plant.label;
          }
          return 'Planta';
        },
        onSelect: (_) {},
      ),
    );
  }

  Future<void> _selectType(ActivityGeometryType next) async {
    final vm = widget.viewModel;
    if (next == vm.geometryType) return;
    if (vm.points.isNotEmpty) {
      final discard = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Trocar tipo de desenho?'),
          content: const Text('Os pontos desenhados serão descartados.'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancelar'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Trocar'),
            ),
          ],
        ),
      );
      if (discard != true) return;
    }
    vm.changeGeometryType(next);
  }

  Future<bool> _continue() async {
    final vm = widget.viewModel;
    final error = vm.geometryError;
    if (error != null) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(error)));
      return false;
    }
    final saved = await ActivityEntryModal.show(context, vm);
    if (saved == true && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Lançamento salvo no dispositivo.')),
      );
      return true;
    }
    return false;
  }

  Future<void> _openDrawingModal() async {
    if (_drawingEnabled) setState(() => _drawingEnabled = false);
    _lastFittedDrawingZoneSignature = null;
    _pendingFittedDrawingZoneSignature = null;
    _prepareDrawingCameraForSelectedZone(widget.viewModel);
    final maxHeight = MediaQuery.sizeOf(context).height * 0.9;
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      enableDrag: false,
      backgroundColor: Colors.transparent,
      constraints: BoxConstraints(maxHeight: maxHeight),
      builder: (modalContext) => Padding(
        key: const ValueKey('activity-drawing-modal-top-margin'),
        padding: EdgeInsets.only(
          top: MediaQuery.paddingOf(modalContext).top + 24,
        ),
        child: StatefulBuilder(
          builder: (context, setModalState) => ListenableBuilder(
            listenable: widget.viewModel,
            builder: (context, _) {
              final vm = widget.viewModel;
              final drawingController = _drawingController;
              if (widget.mapBuilder == null && drawingController != null) {
                _fitDrawingMapToSelectedZone(vm, drawingController);
              }
              final config = ActivityMapConfig(
                plants: vm.plants,
                geometryType: vm.geometryType,
                points: vm.points,
                selectedZoneId: vm.selectedZoneFilterId,
                selectedZonePoints: vm.selectedZonePoints,
                userLocation: vm.userLocation,
                onAddPoint: vm.addPoint,
                initialCameraPosition: _drawingCameraPosition,
                onCameraMove: (position) {
                  _drawingCameraPosition = position;
                },
              );
              return _ActivityDrawingModal(
                map: ActiveMapSurface(
                  onActivityChanged: (active) =>
                      _setMapSurfaceActive('drawing', active),
                  builder: (_) => widget.mapBuilder != null
                      ? widget.mapBuilder!(context, config)
                      : _buildGoogleMap(vm, drawingSurface: true),
                ),
                viewModel: vm,
                drawingEnabled: _drawingEnabled,
                onSelectType: _selectType,
                onToggleDrawing: () {
                  setState(() => _drawingEnabled = !_drawingEnabled);
                  setModalState(() {});
                },
                onContinue: () async {
                  final saved = await _continue();
                  if (saved && modalContext.mounted) {
                    Navigator.of(modalContext).pop();
                  }
                },
              );
            },
          ),
        ),
      ),
    );
    _drawingController = null;
    _pendingFittedDrawingZoneSignature = null;
    if (mounted && _drawingEnabled) {
      setState(() => _drawingEnabled = false);
    }
  }

  @override
  void dispose() {
    _pauseLocationTimer?.cancel();
    _activeMapSurfaces.clear();
    widget.viewModel.pauseLocation();
    _plantLayer.dispose();
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: widget.viewModel,
    builder: (context, _) {
      final vm = widget.viewModel;
      if (widget.mapBuilder == null) {
        _updateMarkers();
        _fitSelectedZone(vm);
      }
      final config = ActivityMapConfig(
        plants: vm.plants,
        geometryType: vm.geometryType,
        points: vm.points,
        selectedZoneId: vm.selectedZoneFilterId,
        selectedZonePoints: vm.selectedZonePoints,
        userLocation: vm.userLocation,
        onAddPoint: vm.addPoint,
      );
      return Scaffold(
        backgroundColor: const Color(0xFFF4F7F2),
        appBar: AppBar(
          title: const Text('Atividade'),
          backgroundColor: const Color(0xFFF4F7F2),
          surfaceTintColor: Colors.transparent,
        ),
        body: Stack(
          children: [
            Column(
              children: [
                Expanded(
                  child: Stack(
                    children: [
                      Positioned.fill(
                        child: ActiveMapSurface(
                          onActivityChanged: (active) =>
                              _setMapSurfaceActive('main', active),
                          builder: (_) => widget.mapBuilder != null
                              ? widget.mapBuilder!(context, config)
                              : _buildGoogleMap(vm, drawingSurface: false),
                        ),
                      ),
                      if (vm.status == ActivityLoadStatus.loading)
                        const Positioned(
                          top: 0,
                          left: 0,
                          right: 0,
                          child: LinearProgressIndicator(),
                        ),
                      if (vm.isFiltered)
                        Positioned(
                          top: 12,
                          left: 16,
                          right: 16,
                          child: Center(
                            child: Material(
                              key: const ValueKey('activity-zone-filter-badge'),
                              color: Theme.of(context).colorScheme.surface,
                              elevation: 2,
                              borderRadius: BorderRadius.circular(18),
                              child: Padding(
                                padding: const EdgeInsets.only(left: 12),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    const Icon(
                                      Icons.grid_view_rounded,
                                      size: 18,
                                    ),
                                    const SizedBox(width: 6),
                                    Text(vm.selectedZone?.name ?? 'Zona'),
                                    IconButton(
                                      key: const ValueKey(
                                        'activity-clear-zone-filter',
                                      ),
                                      tooltip: 'Limpar filtro',
                                      visualDensity: VisualDensity.compact,
                                      onPressed: () => vm.setZoneFilter(null),
                                      icon: const Icon(Icons.close, size: 18),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ),
                      if (vm.errorMessage case final message?)
                        Positioned(
                          top: 8,
                          left: 12,
                          right: 12,
                          child: Material(
                            color: Colors.red.shade50,
                            borderRadius: BorderRadius.circular(12),
                            child: ListTile(
                              dense: true,
                              title: Text(message),
                              trailing: IconButton(
                                icon: const Icon(Icons.close),
                                onPressed: vm.clearError,
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
                _ActivityPrimaryActions(
                  viewModel: vm,
                  onDraw: _openDrawingModal,
                ),
              ],
            ),
          ],
        ),
      );
    },
  );

  Widget _buildGoogleMap(ActivityViewModel vm, {required bool drawingSurface}) {
    final positions = [
      for (final point in vm.points) LatLng(point.latitude, point.longitude),
    ];
    final polygons = buildFarmPolygons(
      farmPoints: const [],
      zonePoints: vm.selectedZonePoints,
      zoneId: vm.selectedZoneFilterId,
    );
    if (vm.geometryType == ActivityGeometryType.area && positions.length >= 3) {
      polygons.add(
        Polygon(
          polygonId: const PolygonId('activity_area'),
          points: positions,
          strokeColor: const Color(0xFF0F766E),
          fillColor: const Color(0x330F766E),
          strokeWidth: 4,
        ),
      );
    }
    return Stack(
      children: [
        Positioned.fill(
          child: IgnorePointer(
            ignoring: _drawingEnabled,
            child: GoogleMap(
              key: ValueKey(
                drawingSurface
                    ? 'activity-drawing-google-map'
                    : 'activity-main-google-map',
              ),
              mapType: OperationMapStyle.mapType,
              initialCameraPosition: drawingSurface
                  ? _drawingCameraPosition
                  : const CameraPosition(
                      target: defaultFarmMapPosition,
                      zoom: OperationMapStyle.initialZoom,
                    ),
              onCameraMove: drawingSurface
                  ? (position) {
                      _drawingCameraPosition = position;
                    }
                  : null,
              markers: {
                ..._markers,
                if (vm.userLocation case final location?)
                  Marker(
                    markerId: const MarkerId('activity_user'),
                    position: LatLng(location.latitude, location.longitude),
                    icon:
                        _userIcon ??
                        BitmapDescriptor.defaultMarkerWithHue(
                          BitmapDescriptor.hueAzure,
                        ),
                    anchor: OperationMapStyle.markerAnchor,
                  ),
              },
              polylines:
                  vm.geometryType == ActivityGeometryType.route &&
                      positions.length >= 2
                  ? {
                      Polyline(
                        polylineId: const PolylineId('activity_route'),
                        points: positions,
                        color: const Color(0xFF0F766E),
                        width: 5,
                      ),
                    }
                  : const {},
              polygons: polygons,
              onCameraIdle: _plantLayer.cameraIdle,
              onMapCreated: (controller) {
                _controller = controller;
                _plantLayer.controller = controller;
                _plantLayer.cameraIdle();
                if (drawingSurface) {
                  _drawingController = controller;
                  _fitDrawingMapToSelectedZone(vm, controller);
                } else {
                  _fitSelectedZone(vm);
                }
              },
              myLocationEnabled: false,
              myLocationButtonEnabled: false,
            ),
          ),
        ),
        if (_drawingEnabled)
          Positioned.fill(
            child: Listener(
              key: const ValueKey('activity-drawing-surface'),
              behavior: HitTestBehavior.opaque,
              onPointerDown: (event) => _queueScreenPoint(event.localPosition),
              onPointerMove: (event) => _queueScreenPoint(event.localPosition),
            ),
          ),
      ],
    );
  }

  void _prepareDrawingCameraForSelectedZone(ActivityViewModel vm) {
    final points = vm.selectedZonePoints;
    if (vm.selectedZoneFilterId == null || points.isEmpty) return;
    final viewport = calculateMapCameraViewport(
      points.map((point) => LatLng(point.latitude, point.longitude)),
    );
    _drawingCameraPosition = CameraPosition(
      target: viewport.target,
      zoom: OperationMapStyle.initialZoom,
    );
  }

  void _fitDrawingMapToSelectedZone(
    ActivityViewModel vm,
    GoogleMapController controller,
  ) {
    final zoneId = vm.selectedZoneFilterId;
    final points = vm.selectedZonePoints;
    if (zoneId == null || points.isEmpty) return;
    final signature = '$zoneId:${points.length}';
    if (_lastFittedDrawingZoneSignature == signature ||
        _pendingFittedDrawingZoneSignature == signature) {
      return;
    }
    _pendingFittedDrawingZoneSignature = signature;
    final viewport = calculateMapCameraViewport(
      points.map((point) => LatLng(point.latitude, point.longitude)),
    );
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted || vm.selectedZoneFilterId != zoneId) {
        if (_pendingFittedDrawingZoneSignature == signature) {
          _pendingFittedDrawingZoneSignature = null;
        }
        return;
      }
      try {
        await controller.animateCamera(
          viewport.bounds == null
              ? CameraUpdate.newLatLngZoom(viewport.target, 17)
              : CameraUpdate.newLatLngBounds(viewport.bounds!, 48),
        );
        if (mounted && vm.selectedZoneFilterId == zoneId) {
          _lastFittedDrawingZoneSignature = signature;
        }
      } catch (_) {
        // A posicao inicial ja usa o centro da zona se o mapa for recriado.
      } finally {
        if (_pendingFittedDrawingZoneSignature == signature) {
          _pendingFittedDrawingZoneSignature = null;
        }
      }
    });
  }

  void _fitSelectedZone(ActivityViewModel vm) {
    final zoneId = vm.selectedZoneFilterId;
    final points = vm.selectedZonePoints;
    if (zoneId == null) {
      _lastFittedZoneSignature = null;
      _pendingFittedZoneSignature = null;
      return;
    }
    if (points.isEmpty || _controller == null) return;
    final signature = '$zoneId:${points.length}';
    if (_lastFittedZoneSignature == signature ||
        _pendingFittedZoneSignature == signature) {
      return;
    }
    _pendingFittedZoneSignature = signature;
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted || vm.selectedZoneFilterId != zoneId) {
        if (_pendingFittedZoneSignature == signature) {
          _pendingFittedZoneSignature = null;
        }
        return;
      }
      final controller = _controller;
      if (controller == null) {
        _pendingFittedZoneSignature = null;
        return;
      }
      final viewport = calculateMapCameraViewport(
        points.map((point) => LatLng(point.latitude, point.longitude)),
      );
      try {
        await controller.animateCamera(
          viewport.bounds == null
              ? CameraUpdate.newLatLngZoom(viewport.target, 17)
              : CameraUpdate.newLatLngBounds(viewport.bounds!, 48),
        );
        if (mounted && vm.selectedZoneFilterId == zoneId) {
          _lastFittedZoneSignature = signature;
        }
      } catch (_) {
        // O mapa pode ser recriado enquanto o modal de filtro e fechado.
      } finally {
        if (_pendingFittedZoneSignature == signature) {
          _pendingFittedZoneSignature = null;
        }
      }
    });
  }
}

class _ActivityPrimaryActions extends StatelessWidget {
  const _ActivityPrimaryActions({
    required this.viewModel,
    required this.onDraw,
  });

  final ActivityViewModel viewModel;
  final VoidCallback onDraw;

  @override
  Widget build(BuildContext context) => SafeArea(
    top: false,
    child: Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 620),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Material(
            elevation: 3,
            borderRadius: BorderRadius.circular(22),
            color: Theme.of(context).colorScheme.surface,
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Row(
                children: [
                  Expanded(
                    child: OperationActionButton(
                      key: const ValueKey('activity-load-data'),
                      tooltip: 'Carregar plantas',
                      backgroundColor: const Color(0xFFE0F2FE),
                      borderColor: const Color(0xFFBAE6FD),
                      iconColor: const Color(0xFF0284C7),
                      icon: viewModel.status == ActivityLoadStatus.loading
                          ? const SizedBox(
                              width: 22,
                              height: 22,
                              child: CircularProgressIndicator(
                                strokeWidth: 2.5,
                                color: Color(0xFF0284C7),
                              ),
                            )
                          : const Icon(Icons.cloud_download_outlined, size: 24),
                      onPressed: viewModel.status == ActivityLoadStatus.loading
                          ? null
                          : () => viewModel.loadSnapshot(forceRemote: true),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: OperationActionButton(
                      key: const ValueKey('activity-filter-zone'),
                      tooltip: 'Filtrar por zona',
                      backgroundColor: const Color(0xFFFEF3C7),
                      borderColor: viewModel.isFiltered
                          ? const Color(0xFFD97706)
                          : const Color(0xFFFDE68A),
                      iconColor: const Color(0xFFD97706),
                      icon: Badge(
                        isLabelVisible: viewModel.isFiltered,
                        smallSize: 8,
                        backgroundColor: const Color(0xFFD97706),
                        child: const Icon(Icons.tune_rounded, size: 24),
                      ),
                      onPressed: () =>
                          ActivityZoneFilterModal.show(context, viewModel),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: OperationActionButton(
                      key: const ValueKey('activity-open-drawing'),
                      tooltip: 'Desenhar operação',
                      backgroundColor: const Color(0xFFDCFCE7),
                      borderColor: const Color(0xFFBBF7D0),
                      iconColor: const Color(0xFF15803D),
                      icon: const Icon(Icons.add_rounded, size: 24),
                      onPressed: onDraw,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: OperationActionButton(
                      key: const ValueKey('activity-saved-entries'),
                      tooltip: 'Marcações salvas',
                      backgroundColor: const Color(0xFFEDE9FE),
                      borderColor: const Color(0xFFDDD6FE),
                      iconColor: const Color(0xFF7C3AED),
                      icon: const Icon(Icons.folder_outlined, size: 24),
                      onPressed: () =>
                          ActivitySavedEntries.show(context, viewModel),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    ),
  );
}

class _ActivityDrawingModal extends StatelessWidget {
  const _ActivityDrawingModal({
    required this.map,
    required this.viewModel,
    required this.drawingEnabled,
    required this.onSelectType,
    required this.onToggleDrawing,
    required this.onContinue,
  });

  final Widget map;
  final ActivityViewModel viewModel;
  final bool drawingEnabled;
  final ValueChanged<ActivityGeometryType> onSelectType;
  final VoidCallback onToggleDrawing;
  final Future<void> Function() onContinue;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    return Material(
      key: const ValueKey('activity-drawing-modal'),
      color: colorScheme.surface,
      borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      clipBehavior: Clip.antiAlias,
      child: SafeArea(
        top: false,
        child: Stack(
          children: [
            Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 14, 12, 12),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: colorScheme.primaryContainer.withValues(
                            alpha: 0.5,
                          ),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Icon(
                          Icons.gesture_rounded,
                          color: colorScheme.primary,
                          size: 22,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Desenhar operação',
                              style: theme.textTheme.titleLarge?.copyWith(
                                fontWeight: FontWeight.bold,
                                fontSize: 20,
                              ),
                            ),
                            Text(
                              'Posicione o mapa e trace uma rota ou área',
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: colorScheme.outline,
                              ),
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        tooltip: 'Fechar',
                        onPressed: () => Navigator.of(context).pop(),
                        icon: const Icon(Icons.close),
                      ),
                    ],
                  ),
                ),
                const Divider(height: 1),
                Expanded(
                  child: Stack(
                    children: [
                      Positioned.fill(child: map),
                      Positioned(
                        top: 12,
                        left: 12,
                        right: 12,
                        child: Center(
                          child: SegmentedButton<ActivityGeometryType>(
                            key: const ValueKey('activity-geometry-selector'),
                            style: ButtonStyle(
                              backgroundColor: WidgetStateProperty.resolveWith(
                                (states) =>
                                    states.contains(WidgetState.selected)
                                    ? const Color(0xFF166534)
                                    : colorScheme.surface,
                              ),
                              foregroundColor: WidgetStateProperty.resolveWith(
                                (states) =>
                                    states.contains(WidgetState.selected)
                                    ? Colors.white
                                    : colorScheme.onSurface,
                              ),
                              side: WidgetStateProperty.resolveWith(
                                (states) => BorderSide(
                                  color: states.contains(WidgetState.selected)
                                      ? const Color(0xFF166534)
                                      : colorScheme.outline,
                                  width: states.contains(WidgetState.selected)
                                      ? 2
                                      : 1,
                                ),
                              ),
                            ),
                            segments: const [
                              ButtonSegment(
                                value: ActivityGeometryType.route,
                                icon: Icon(Icons.route_outlined),
                                label: Text('Rota'),
                              ),
                              ButtonSegment(
                                value: ActivityGeometryType.area,
                                icon: Icon(Icons.crop_square_rounded),
                                label: Text('Área'),
                              ),
                            ],
                            selected: {viewModel.geometryType},
                            onSelectionChanged: (value) =>
                                onSelectType(value.single),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const Divider(height: 1),
                Padding(
                  padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
                  child: Row(
                    key: const ValueKey('activity-drawing-actions-row'),
                    children: [
                      Expanded(
                        child: FilledButton.tonal(
                          key: const ValueKey('activity-drawing-mode'),
                          style: FilledButton.styleFrom(
                            minimumSize: const Size(0, 48),
                            padding: const EdgeInsets.symmetric(horizontal: 6),
                          ),
                          onPressed: onToggleDrawing,
                          child: FittedBox(
                            fit: BoxFit.scaleDown,
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  drawingEnabled
                                      ? Icons.pan_tool_alt
                                      : Icons.pan_tool,
                                ),
                                const SizedBox(width: 6),
                                Text(
                                  drawingEnabled ? 'Desenhando' : 'Mover mapa',
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 4),
                      IconButton.filledTonal(
                        key: const ValueKey('activity-drawing-undo'),
                        tooltip: 'Desfazer último ponto',
                        onPressed: viewModel.points.isEmpty
                            ? null
                            : viewModel.undoPoint,
                        icon: const Icon(Icons.undo),
                      ),
                      const SizedBox(width: 4),
                      IconButton.filledTonal(
                        key: const ValueKey('activity-drawing-clear'),
                        tooltip: 'Limpar desenho',
                        onPressed: viewModel.points.isEmpty
                            ? null
                            : viewModel.clearDrawing,
                        icon: const Icon(Icons.delete_outline),
                      ),
                      const SizedBox(width: 4),
                      Expanded(
                        child: FilledButton(
                          key: const ValueKey('activity-drawing-continue'),
                          style: FilledButton.styleFrom(
                            minimumSize: const Size(0, 48),
                            padding: const EdgeInsets.symmetric(horizontal: 6),
                          ),
                          onPressed: onContinue,
                          child: FittedBox(
                            fit: BoxFit.scaleDown,
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(Icons.edit_note_rounded),
                                const SizedBox(width: 6),
                                Text('Continuar (${viewModel.points.length})'),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
