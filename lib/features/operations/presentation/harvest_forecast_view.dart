import 'dart:async';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

import '../../../core/ui/map_activity.dart';
import '../../farm/domain/user_location.dart';
import '../../farm/presentation/bounded_plant_markers.dart';
import '../../farm/presentation/map_initial_camera.dart';
import '../../farm/presentation/map_initial_placeholder.dart';
import '../../farm/presentation/plant_spatial_index.dart';
import '../../farm/presentation/user_map_navigation.dart';
import '../domain/harvest_forecast_models.dart';
import '../domain/inspection_models.dart';
import 'harvest_forecast_view_model.dart';
import 'inspection_map_camera.dart';
import 'operation_map_style.dart';
import 'widgets/harvest_forecast_marking_modal.dart';
import 'widgets/harvest_forecast_saved_markings.dart';
import 'widgets/operation_action_button.dart';

Future<BitmapDescriptor> createHarvestForecastPointMarkerIcon(
  HarvestForecastClassification classification,
) async {
  const size = 64;
  const center = Offset(size / 2, size / 2);
  const radius = 18.0;
  final color = harvestForecastClassificationColor(classification);
  final highlightColor = Color.lerp(color, Colors.white, 0.45) ?? Colors.white;

  final recorder = ui.PictureRecorder();
  final canvas = Canvas(recorder);

  canvas.drawCircle(center, radius + 4, Paint()..color = Colors.white);
  canvas.drawCircle(center, radius, Paint()..color = color);
  canvas.drawCircle(
    center.translate(-5.5, -5.5),
    4.5,
    Paint()..color = highlightColor,
  );

  final picture = recorder.endRecording();
  final image = await picture.toImage(size, size);
  picture.dispose();
  final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
  image.dispose();
  return BitmapDescriptor.bytes(
    bytes!.buffer.asUint8List(),
    width: 22,
    height: 22,
  );
}

class HarvestForecastMapConfig {
  const HarvestForecastMapConfig({
    required this.plants,
    required this.polylines,
    required this.onMapGestureStarted,
    this.markings = const [],
    this.onSelectMarking,
    this.onMapDoubleTap,
    this.userLocation,
    this.userCourse,
    this.isFollowingUser = true,
    this.initialCameraPosition,
  });

  final List<InspectionPlant> plants;
  final Set<Polyline> polylines;
  final VoidCallback onMapGestureStarted;
  final List<HarvestForecastMarking> markings;
  final ValueChanged<HarvestForecastMarking>? onSelectMarking;
  final ValueChanged<LatLng>? onMapDoubleTap;
  final UserLocation? userLocation;
  final double? userCourse;
  final bool isFollowingUser;
  final CameraPosition? initialCameraPosition;
}

typedef HarvestForecastMapBuilder =
    Widget Function(BuildContext context, HarvestForecastMapConfig config);

class HarvestForecastView extends StatefulWidget {
  const HarvestForecastView({
    required this.viewModel,
    this.mapBuilder,
    super.key,
  });

  final HarvestForecastViewModel viewModel;
  final HarvestForecastMapBuilder? mapBuilder;

  @override
  State<HarvestForecastView> createState() => _HarvestForecastViewState();
}

class _HarvestForecastViewState extends State<HarvestForecastView> {
  final _plantLayer = BoundedPlantMarkers();
  Set<Marker> _markers = const {};
  BitmapDescriptor? _plantIcon;
  BitmapDescriptor? _userIcon;
  BitmapDescriptor? _directionalUserIcon;
  Map<HarvestForecastClassification, BitmapDescriptor> _markingIcons = const {};
  GoogleMapController? _controller;
  CameraPosition? _cameraPosition;
  final UserMapNavigator _userMapNavigator = UserMapNavigator();
  final InspectionCameraFollowState _cameraFollowState =
      InspectionCameraFollowState();
  bool _hasFocusedOnUser = false;
  UserLocation? _lastUserLocation;
  HarvestForecastClassification? _lastTriggeredClassification;

  int _activePointers = 0;
  bool _multiTouchInGesture = false;
  DateTime? _pointerDownAt;
  Offset? _pointerDownPosition;
  DateTime? _lastTapUpAt;
  Offset? _lastTapUpPosition;
  DateTime? _lastMapOnTapAt;
  LatLng? _lastMapOnTapPosition;
  DateTime? _lastDoubleTapRecordedAt;

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
    final baseIcons = await Future.wait([
      OperationMapStyle.createPlantMarkerIcon(
        color: OperationMapStyle.plantColor,
        highlightColor: OperationMapStyle.plantHighlightColor,
      ),
      createUserLocationMarkerIcon(),
      createDirectionalUserLocationMarkerIcon(),
    ]);
    final markingEntries = await Future.wait([
      for (final classification in HarvestForecastClassification.values)
        createHarvestForecastPointMarkerIcon(
          classification,
        ).then((icon) => MapEntry(classification, icon)),
    ]);
    if (mounted) {
      setState(() {
        _plantIcon = baseIcons[0];
        _userIcon = baseIcons[1];
        _directionalUserIcon = baseIcons[2];
        _markingIcons =
            Map<HarvestForecastClassification, BitmapDescriptor>.fromEntries(
              markingEntries,
            );
      });
    }
  }

  void _markersChanged() {
    if (mounted) setState(() => _markers = _plantLayer.markers);
  }

  void _updateMarkers() {
    final vm = widget.viewModel;
    final plantsById = {for (final plant in vm.plants) plant.id: plant};
    _plantLayer.update(
      revision: (vm.plants, _plantIcon),
      plants: () => [
        for (final plant in vm.plants)
          SpatialPlant(plant.id, plant.latitude!, plant.longitude!),
      ],
      markerFor: (node) {
        final plant = plantsById[node.plantId]!;
        return Marker(
          markerId: MarkerId('harvest_forecast_${plant.id}'),
          position: LatLng(plant.latitude!, plant.longitude!),
          icon:
              _plantIcon ??
              BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueGreen),
          infoWindow: InfoWindow(title: plant.label),
          anchor: OperationMapStyle.markerAnchor,
          onTap: () =>
              _handleGoogleMapTap(vm, LatLng(plant.latitude!, plant.longitude!)),
        );
      },
      onClusterTap: (node) => showPlantClusterMembers(
        context,
        layer: _plantLayer,
        node: node,
        labelFor: (id) => plantsById[id]!.label,
        onSelect: (_) {},
      ),
    );
  }

  Set<Marker> _buildMarkingMarkers(HarvestForecastViewModel vm) {
    return {
      for (final marking in vm.markings)
        Marker(
          markerId: MarkerId('harvest_forecast_marking_${marking.localId}'),
          position: LatLng(marking.latitude, marking.longitude),
          icon:
              _markingIcons[marking.classification] ??
              BitmapDescriptor.defaultMarkerWithHue(
                BitmapDescriptor.hueViolet,
              ),
          anchor: OperationMapStyle.markerAnchor,
          zIndexInt: OperationMapStyle.userMarkerZIndex - 10,
          onTap: () {
            _lastTapUpAt = null;
            _lastTapUpPosition = null;
            _lastMapOnTapAt = null;
            _lastMapOnTapPosition = null;
            HarvestForecastMarkingModal.show(context, marking, vm);
          },
        ),
    };
  }

  void _followUser(UserLocation location) {
    final controller = _controller;
    if (controller == null || !_cameraFollowState.isFollowing) return;
    if (!_hasFocusedOnUser) {
      _hasFocusedOnUser = true;
      unawaited(
        _userMapNavigator.focus(
          controller,
          location,
          zoom: 19,
          tilt: _cameraPosition?.tilt ?? 0,
          bearing: _cameraPosition?.bearing ?? 0,
        ),
      );
      return;
    }
    unawaited(
      _userMapNavigator.follow(
        location: location,
        controller: controller,
        camera: () => _cameraPosition,
        isActive: () =>
            mounted &&
            _controller == controller &&
            _cameraFollowState.isFollowing,
      ),
    );
  }

  void _handleManualMapGestureStarted() {
    final changed = _cameraFollowState.suspend();
    if (changed && mounted) setState(() {});
  }

  void _handleCameraMoveStarted() {
    if (!_cameraFollowState.cameraMoveStarted()) return;
    if (mounted) setState(() {});
  }

  void _recenterOnUser() {
    final vm = widget.viewModel;
    final location = vm.mapLocation.location ?? vm.userLocation;
    if (location == null) return;
    _cameraFollowState.resume();
    final controller = _controller;
    if (controller != null) {
      _hasFocusedOnUser = true;
      unawaited(
        _userMapNavigator.focus(
          controller,
          location,
          zoom: _cameraPosition?.zoom ?? 19,
          tilt: _cameraPosition?.tilt ?? 0,
          bearing: _cameraPosition?.bearing ?? 0,
        ),
      );
    }
    if (mounted) setState(() {});
  }

  Future<void> _handleClassificationPressed(
    HarvestForecastViewModel vm,
    HarvestForecastClassification classification,
  ) async {
    setState(() => _lastTriggeredClassification = classification);
    await vm.recordClassification(classification);
  }

  void _handlePointerDown(PointerDownEvent event) {
    _cameraFollowState.pointerDown();
    _activePointers++;
    if (_activePointers > 1) {
      _multiTouchInGesture = true;
      _lastTapUpAt = null;
      _lastTapUpPosition = null;
      return;
    }
    _multiTouchInGesture = false;
    _pointerDownAt = DateTime.now();
    _pointerDownPosition = event.localPosition;
  }

  void _handlePointerUp(PointerUpEvent event, HarvestForecastViewModel vm) {
    _cameraFollowState.pointerUp();
    if (_activePointers > 0) _activePointers--;
    if (_multiTouchInGesture || _activePointers > 0) {
      if (_activePointers == 0) _multiTouchInGesture = false;
      _pointerDownAt = null;
      _pointerDownPosition = null;
      return;
    }

    final downAt = _pointerDownAt;
    final downPos = _pointerDownPosition;
    _pointerDownAt = null;
    _pointerDownPosition = null;
    if (downAt == null || downPos == null) return;

    final now = DateTime.now();
    final pressDuration = now.difference(downAt);
    final moveDistance = (event.localPosition - downPos).distance;
    if (pressDuration > const Duration(milliseconds: 280) ||
        moveDistance > 18) {
      _lastTapUpAt = null;
      _lastTapUpPosition = null;
      return;
    }

    final prevUpAt = _lastTapUpAt;
    final prevUpPos = _lastTapUpPosition;
    if (prevUpAt != null &&
        prevUpPos != null &&
        now.difference(prevUpAt) <= const Duration(milliseconds: 450) &&
        (event.localPosition - prevUpPos).distance <= 42) {
      _lastTapUpAt = null;
      _lastTapUpPosition = null;
      unawaited(_resolveAndRecordDoubleTapAtOffset(vm, event.localPosition));
      return;
    }

    _lastTapUpAt = now;
    _lastTapUpPosition = event.localPosition;
  }

  void _handlePointerCancel(PointerCancelEvent _) {
    _cameraFollowState.pointerUp();
    if (_activePointers > 0) _activePointers--;
    if (_activePointers == 0) _multiTouchInGesture = false;
    _pointerDownAt = null;
    _pointerDownPosition = null;
  }

  Future<void> _resolveAndRecordDoubleTapAtOffset(
    HarvestForecastViewModel vm,
    Offset localPosition,
  ) async {
    final controller = _controller;
    if (controller == null || !mounted) return;
    final pixelRatio = MediaQuery.devicePixelRatioOf(context);
    try {
      final latLng = await controller.getLatLng(
        ScreenCoordinate(
          x: (localPosition.dx * pixelRatio).round(),
          y: (localPosition.dy * pixelRatio).round(),
        ),
      );
      if (!mounted) return;
      await _recordPointFromMapDoubleTap(vm, latLng);
    } catch (_) {
      // Fallback caso o controller nativo não resolva a coordenada de tela.
    }
  }

  void _handleGoogleMapTap(HarvestForecastViewModel vm, LatLng position) {
    final now = DateTime.now();
    final prevAt = _lastMapOnTapAt;
    final prevPos = _lastMapOnTapPosition;
    if (prevAt != null &&
        prevPos != null &&
        now.difference(prevAt) <= const Duration(milliseconds: 650)) {
      final distanceMeters = vm.geometryService.haversineDistanceMeters(
        prevPos.latitude,
        prevPos.longitude,
        position.latitude,
        position.longitude,
      );
      if (distanceMeters <= 35) {
        _lastMapOnTapAt = null;
        _lastMapOnTapPosition = null;
        unawaited(_recordPointFromMapDoubleTap(vm, position));
        return;
      }
    }
    _lastMapOnTapAt = now;
    _lastMapOnTapPosition = position;
  }

  Future<void> _recordPointFromMapDoubleTap(
    HarvestForecastViewModel vm,
    LatLng position,
  ) async {
    final now = DateTime.now();
    if (_lastDoubleTapRecordedAt != null &&
        now.difference(_lastDoubleTapRecordedAt!) <
            const Duration(milliseconds: 700)) {
      return;
    }
    _lastDoubleTapRecordedAt = now;
    unawaited(HapticFeedback.mediumImpact());
    if (mounted) {
      setState(
        () => _lastTriggeredClassification = HarvestForecastClassification.n,
      );
    }
    await vm.recordClassificationAt(
      latitude: position.latitude,
      longitude: position.longitude,
      classification: HarvestForecastClassification.n,
    );
  }

  @override
  void dispose() {
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
      if (_cameraPosition == null && vm.initialMapPosition != null) {
        _cameraPosition = mapInitialCamera(vm.initialMapPosition!);
      }
      final colorScheme = Theme.of(context).colorScheme;
      if (widget.mapBuilder == null) _updateMarkers();

      if (vm.errorMessage != null &&
          vm.status != HarvestForecastLoadStatus.error) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!mounted || vm.errorMessage == null) return;
          ScaffoldMessenger.of(context)
            ..hideCurrentSnackBar()
            ..showSnackBar(
              SnackBar(
                content: Text(vm.errorMessage!),
                backgroundColor: colorScheme.error,
              ),
            );
          vm.clearMessages();
        });
      }

      return Scaffold(
        backgroundColor: const Color(0xFFF4F7F2),
        appBar: AppBar(
          title: const Text('Previsão de Safra'),
          backgroundColor: const Color(0xFFF4F7F2),
          surfaceTintColor: Colors.transparent,
          actions: [
            if (vm.mapLocation.location != null || vm.userLocation != null)
              IconButton(
                key: const ValueKey('harvest-forecast-my-location'),
                icon: const Icon(Icons.my_location),
                tooltip: 'Minha localização',
                onPressed: _recenterOnUser,
              ),
          ],
        ),
        body: Column(
          children: [
            Expanded(
              child: Stack(
                children: [
                  Positioned.fill(
                    child: Listener(
                      onPointerDown: _handlePointerDown,
                      onPointerUp: (event) => _handlePointerUp(event, vm),
                      onPointerCancel: _handlePointerCancel,
                      child: ActiveMapSurface(
                        onActivityChanged: (active) => active
                            ? widget.viewModel.resumeLocation()
                            : widget.viewModel.pauseLocation(),
                        builder: (_) => ListenableBuilder(
                          listenable: vm.mapLocation,
                          builder: (context, _) {
                            final location =
                                vm.mapLocation.location ?? vm.userLocation;
                            if (location == null) {
                              if (_lastUserLocation != null) {
                                _userMapNavigator.reset();
                              }
                              _lastUserLocation = null;
                              _hasFocusedOnUser = false;
                            } else {
                              _userMapNavigator.observe(location);
                              if (!identical(_lastUserLocation, location)) {
                                _lastUserLocation = location;
                                WidgetsBinding.instance.addPostFrameCallback((
                                  _,
                                ) {
                                  if (mounted) _followUser(location);
                                });
                              }
                            }
                            final userMarker = userMapMarkerForCourse(
                              vm.mapLocation.course,
                            );
                            if (widget.mapBuilder != null) {
                              return widget.mapBuilder!(
                                context,
                                HarvestForecastMapConfig(
                                  plants: vm.plants,
                                  polylines: vm.polylines,
                                  onMapGestureStarted:
                                      _handleManualMapGestureStarted,
                                  markings: vm.markings,
                                  onSelectMarking: (marking) =>
                                      HarvestForecastMarkingModal.show(
                                        context,
                                        marking,
                                        vm,
                                      ),
                                  onMapDoubleTap: (position) =>
                                      _recordPointFromMapDoubleTap(
                                        vm,
                                        position,
                                      ),
                                  userLocation: location,
                                  userCourse: vm.mapLocation.course,
                                  isFollowingUser:
                                      _cameraFollowState.isFollowing,
                                  initialCameraPosition: _cameraPosition,
                                ),
                              );
                            }
                            if (_cameraPosition == null) {
                              return MapInitialPlaceholder(
                                resolved: vm.initialMapPositionResolved,
                              );
                            }
                            return GoogleMap(
                              key: const ValueKey(
                                'harvest-forecast-google-map',
                              ),
                              mapType: OperationMapStyle.mapType,
                              initialCameraPosition: _cameraPosition!,
                              onCameraMoveStarted: _handleCameraMoveStarted,
                              onCameraMove: (position) =>
                                  _cameraPosition = position,
                              onTap: (position) =>
                                  _handleGoogleMapTap(vm, position),
                              markers: {
                                ..._markers,
                                ..._buildMarkingMarkers(vm),
                                if (location != null)
                                  Marker(
                                    markerId: const MarkerId(
                                      'harvest_forecast_user',
                                    ),
                                    position: LatLng(
                                      location.latitude,
                                      location.longitude,
                                    ),
                                    icon:
                                        (userMarker.kind ==
                                                UserMapMarkerKind.directional
                                            ? _directionalUserIcon
                                            : _userIcon) ??
                                        BitmapDescriptor.defaultMarkerWithHue(
                                          BitmapDescriptor.hueAzure,
                                        ),
                                    anchor: userMarker.anchor,
                                    rotation: userMarker.rotation,
                                    flat: userMarker.flat,
                                    zIndexInt:
                                        OperationMapStyle.userMarkerZIndex,
                                  ),
                              },
                              polylines: vm.polylines,
                              myLocationEnabled: false,
                              myLocationButtonEnabled: false,
                              onCameraIdle: _plantLayer.cameraIdle,
                              onMapCreated: (controller) {
                                _controller = controller;
                                _plantLayer.controller = controller;
                                _plantLayer.cameraIdle();
                                if (location != null) {
                                  _followUser(location);
                                }
                              },
                            );
                          },
                        ),
                      ),
                    ),
                  ),
                  if (vm.status == HarvestForecastLoadStatus.loading)
                    const Positioned(
                      top: 0,
                      left: 0,
                      right: 0,
                      child: LinearProgressIndicator(),
                    ),
                  if (vm.status == HarvestForecastLoadStatus.error)
                    Positioned(
                      top: 12,
                      left: 12,
                      right: 12,
                      child: Material(
                        color: Colors.red.shade50,
                        borderRadius: BorderRadius.circular(12),
                        child: ListTile(
                          title: Text(
                            vm.errorMessage ?? 'Erro ao carregar dados',
                          ),
                          trailing: IconButton(
                            icon: const Icon(Icons.refresh),
                            onPressed: vm.loadPlants,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 10, 16, 4),
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 480),
                  child: Row(
                    key: const ValueKey('harvest-forecast-classification-row'),
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      for (final classification
                          in HarvestForecastClassification.values)
                        _CircularClassificationButton(
                          key: ValueKey(
                            'harvest-forecast-button-${classification.code}',
                          ),
                          classification: classification,
                          enabled: !vm.saving,
                          isLastTriggered:
                              _lastTriggeredClassification == classification,
                          onPressed: () =>
                              _handleClassificationPressed(vm, classification),
                        ),
                    ],
                  ),
                ),
              ),
            ),
            SafeArea(
              top: false,
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 8,
                ),
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 480),
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        color: colorScheme.surface,
                        borderRadius: BorderRadius.circular(24),
                        border: Border.all(
                          color: colorScheme.outlineVariant.withValues(
                            alpha: 0.6,
                          ),
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.06),
                            blurRadius: 14,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 10,
                        ),
                        child: Row(
                          children: [
                            Expanded(
                              child: OperationActionButton(
                                key: const ValueKey(
                                  'harvest-forecast-load-plants',
                                ),
                                tooltip: 'Carregar plantas',
                                backgroundColor: const Color(0xFFE0F2FE),
                                borderColor: const Color(0xFFBAE6FD),
                                iconColor: const Color(0xFF0284C7),
                                icon:
                                    vm.status ==
                                        HarvestForecastLoadStatus.loading
                                    ? const SizedBox(
                                        width: 22,
                                        height: 22,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2.5,
                                          color: Color(0xFF0284C7),
                                        ),
                                      )
                                    : const Icon(
                                        Icons.cloud_download_outlined,
                                        size: 24,
                                      ),
                                onPressed:
                                    vm.status ==
                                        HarvestForecastLoadStatus.loading
                                    ? null
                                    : vm.loadPlants,
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: OperationActionButton(
                                key: const ValueKey(
                                  'harvest-forecast-saved-markings',
                                ),
                                tooltip: 'Marcações salvas',
                                backgroundColor: const Color(0xFFEDE9FE),
                                borderColor: const Color(0xFFDDD6FE),
                                iconColor: const Color(0xFF7C3AED),
                                icon: const Icon(
                                  Icons.folder_outlined,
                                  size: 24,
                                ),
                                onPressed: () =>
                                    HarvestForecastSavedMarkings.show(
                                      context,
                                      vm,
                                    ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      );
    },
  );
}

class _CircularClassificationButton extends StatefulWidget {
  const _CircularClassificationButton({
    required this.classification,
    required this.enabled,
    required this.isLastTriggered,
    required this.onPressed,
    super.key,
  });

  final HarvestForecastClassification classification;
  final bool enabled;
  final bool isLastTriggered;
  final VoidCallback onPressed;

  @override
  State<_CircularClassificationButton> createState() =>
      _CircularClassificationButtonState();
}

class _CircularClassificationButtonState
    extends State<_CircularClassificationButton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulseController;
  late final Animation<double> _scaleAnimation;
  bool _isPressed = false;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 360),
    );
    _scaleAnimation = TweenSequence<double>([
      TweenSequenceItem(
        tween: Tween<double>(
          begin: 1.0,
          end: 0.82,
        ).chain(CurveTween(curve: Curves.easeOut)),
        weight: 28,
      ),
      TweenSequenceItem(
        tween: Tween<double>(
          begin: 0.82,
          end: 1.18,
        ).chain(CurveTween(curve: Curves.easeOutBack)),
        weight: 42,
      ),
      TweenSequenceItem(
        tween: Tween<double>(
          begin: 1.18,
          end: 1.0,
        ).chain(CurveTween(curve: Curves.easeInOut)),
        weight: 30,
      ),
    ]).animate(_pulseController);
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  void _triggerClick() {
    if (!widget.enabled) return;
    unawaited(HapticFeedback.mediumImpact());
    _pulseController.forward(from: 0);
    widget.onPressed();
  }

  @override
  Widget build(BuildContext context) {
    final classification = widget.classification;
    final color = harvestForecastClassificationColor(classification);

    return AnimatedBuilder(
      animation: _pulseController,
      builder: (context, _) {
        final isAnimating = _pulseController.isAnimating;
        final isHighlighted =
            _isPressed || isAnimating || widget.isLastTriggered;
        final scale = _isPressed ? 0.86 : _scaleAnimation.value;

        return Semantics(
          button: true,
          enabled: widget.enabled,
          selected: widget.isLastTriggered,
          label: 'Previsão ${classification.code} (${classification.label})',
          child: Tooltip(
            message: '${classification.code} - ${classification.label}',
            child: Transform.scale(
              scale: scale,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 140),
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: isHighlighted ? color : color.withValues(alpha: 0.16),
                  border: Border.all(
                    color: isHighlighted
                        ? Colors.white
                        : color.withValues(alpha: 0.65),
                    width: isHighlighted ? 2.6 : 1.8,
                  ),
                  boxShadow: isHighlighted
                      ? [
                          BoxShadow(
                            color: color.withValues(
                              alpha: isAnimating ? 0.65 : 0.42,
                            ),
                            blurRadius: isAnimating ? 16 : 10,
                            spreadRadius: isAnimating ? 3 : 1,
                            offset: const Offset(0, 3),
                          ),
                        ]
                      : [
                          BoxShadow(
                            color: color.withValues(alpha: 0.12),
                            blurRadius: 6,
                            offset: const Offset(0, 2),
                          ),
                        ],
                ),
                child: Material(
                  color: Colors.transparent,
                  shape: const CircleBorder(),
                  child: InkWell(
                    customBorder: const CircleBorder(),
                    splashColor: Colors.white.withValues(alpha: 0.35),
                    highlightColor: Colors.white.withValues(alpha: 0.2),
                    onHighlightChanged: (value) {
                      if (_isPressed != value) {
                        setState(() => _isPressed = value);
                      }
                    },
                    onTap: widget.enabled ? _triggerClick : null,
                    child: Center(
                      child: Text(
                        classification.code,
                        style: TextStyle(
                          color: isHighlighted ? Colors.white : color,
                          fontWeight: FontWeight.w900,
                          fontSize: 16,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
