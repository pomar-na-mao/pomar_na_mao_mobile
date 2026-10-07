import 'dart:async';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

import '../domain/zone.dart';
import '../domain/user_location.dart';
import 'farm_map_geometry.dart';
import 'farm_map_view_model.dart';
import 'bounded_plant_markers.dart';
import 'plant_spatial_index.dart';
import 'user_map_navigation.dart';
import 'widgets/farm_action_card.dart';
import '../../../core/ui/map_activity.dart';
import '../../../core/ui/map_camera.dart';

List<Zone> sortZonesByCode(Iterable<Zone> zones) {
  final sortedZones = zones.toList();
  sortedZones.sort((first, second) {
    final firstCode = _normalizedZoneCode(first);
    final secondCode = _normalizedZoneCode(second);
    if (firstCode == null && secondCode == null) {
      return first.name.toLowerCase().compareTo(second.name.toLowerCase());
    }
    if (firstCode == null) return 1;
    if (secondCode == null) return -1;

    final codeComparison = firstCode.compareTo(secondCode);
    if (codeComparison != 0) return codeComparison;
    return first.name.toLowerCase().compareTo(second.name.toLowerCase());
  });
  return sortedZones;
}

String? _normalizedZoneCode(Zone zone) {
  final code = zone.code?.trim().toUpperCase();
  return code == null || code.isEmpty ? null : code;
}

class FarmMapView extends StatefulWidget {
  const FarmMapView({required this.viewModel, super.key});

  final FarmMapViewModel viewModel;

  @override
  State<FarmMapView> createState() => _FarmMapViewState();
}

class _FarmMapViewState extends State<FarmMapView> {
  static const _fallbackPosition = defaultFarmMapPosition;
  static const _allZonesValue = '';

  GoogleMapController? _mapController;
  CameraPosition? _savedCamera;
  String? _lastCameraSignature;
  String? _lastCameraZoneId;
  var _hasSetInitialCamera = false;
  BitmapDescriptor? _plantMarkerIcon;
  BitmapDescriptor? _nonExistentPlantMarkerIcon;
  BitmapDescriptor? _userMarkerIcon;
  final UserMapNavigator _userMapNavigator = UserMapNavigator();
  UserLocation? _lastUserLocation;
  bool _hasFocusedOnUser = false;

  Set<Marker> _cachedMarkers = const {};
  final _plantLayer = BoundedPlantMarkers();

  void _markersChanged() {
    if (mounted) setState(() => _cachedMarkers = _plantLayer.markers);
  }

  @override
  void initState() {
    super.initState();
    _plantLayer.addListener(_markersChanged);
    unawaited(_loadPlantMarkerIcon());
    unawaited(_loadUserMarkerIcon());
    unawaited(widget.viewModel.initialize());
  }

  @override
  void didUpdateWidget(covariant FarmMapView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.viewModel != widget.viewModel) {
      unawaited(widget.viewModel.initialize());
    }
  }

  @override
  void dispose() {
    _plantLayer.dispose();
    _mapController = null;
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

  void _updateMarkersIfNeeded() {
    final vm = widget.viewModel;
    final regularIcon =
        _plantMarkerIcon ??
        BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueGreen);
    final nonExistentIcon =
        _nonExistentPlantMarkerIcon ??
        BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueYellow);
    _plantLayer.update(
      revision: (
        vm.allPlants,
        vm.selectedZoneId,
        _plantMarkerIcon,
        _nonExistentPlantMarkerIcon,
      ),
      plants: () => vm.plants
          .map((p) => SpatialPlant(p.id, p.latitude, p.longitude))
          .toList(growable: false),
      markerFor: (node) {
        final plant = vm.plantById(node.plantId!)!;
        return Marker(
          markerId: MarkerId(plant.id),
          position: LatLng(node.latitude, node.longitude),
          infoWindow: InfoWindow(title: 'Planta ${plant.id}'),
          icon: plant.nonExistent ? nonExistentIcon : regularIcon,
          anchor: const Offset(0.5, 0.5),
        );
      },
      onClusterTap: (node) => showPlantClusterMembers(
        context,
        layer: _plantLayer,
        node: node,
        labelFor: (id) => 'Planta $id',
        onSelect: (id) {
          final plant = vm.plantById(id);
          if (plant == null) return;
          final controller = _mapController;
          if (controller != null) {
            unawaited(
              animateMapCamera(
                controller,
                CameraUpdate.newLatLngZoom(
                  LatLng(plant.latitude, plant.longitude),
                  21,
                ),
              ),
            );
          }
          if (mounted) {
            ScaffoldMessenger.of(context)
                .showSnackBar(SnackBar(content: Text('Planta $id')));
          }
        },
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
    ]);
    if (!mounted) return;
    _plantMarkerIcon = icons[0];
    _nonExistentPlantMarkerIcon = icons[1];
    _updateMarkersIfNeeded();
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

  Set<Polygon> get _polygons {
    return buildFarmPolygons(
      farmPoints: widget.viewModel.farmBoundaryPoints,
      zonePoints: widget.viewModel.selectedZonePoints,
      zoneId: widget.viewModel.selectedZoneId,
    );
  }

  Future<void> _fitCameraToAvailableCoordinates() async {
    final controller = _mapController;
    if (controller == null) return;
    if (_hasFocusedOnUser &&
        _lastCameraZoneId == widget.viewModel.selectedZoneId) {
      return;
    }
    final dataSignature = (
      widget.viewModel.allPlants,
      widget.viewModel.selectedZoneId,
      widget.viewModel.selectedZonePoints,
      widget.viewModel.farmBoundaryPoints,
      _plantLayer.bounds,
    );
    if (_cameraDataSignature == dataSignature) return;
    _cameraDataSignature = dataSignature;
    final zoneCoordinates = widget.viewModel.selectedZonePoints
        .map((point) => LatLng(point.latitude, point.longitude))
        .toList(growable: false);
    final farmBoundaryCoordinates = widget.viewModel.farmBoundaryPoints
        .map((point) => LatLng(point.latitude, point.longitude))
        .toList(growable: false);
    final userLocation = widget.viewModel.userLocation;
    final userPosition = userLocation == null
        ? null
        : LatLng(userLocation.latitude, userLocation.longitude);

    if (!_hasSetInitialCamera) {
      final farmDataFinished =
          widget.viewModel.plantsStatus != PlantsLoadStatus.initial &&
          widget.viewModel.plantsStatus != PlantsLoadStatus.loading;
      if (!farmDataFinished && widget.viewModel.locationResult == null) return;

      _hasSetInitialCamera = true;
      _lastCameraZoneId = widget.viewModel.selectedZoneId;
    }

    final zoneChanged = _lastCameraZoneId != widget.viewModel.selectedZoneId;
    if (zoneChanged) {
      _lastCameraZoneId = widget.viewModel.selectedZoneId;
    }

    final signature = [
      widget.viewModel.selectedZoneId ?? _allZonesValue,
      zoneCoordinates.length.toString(),
      widget.viewModel.plants.length.toString(),
      _plantLayer.bounds?.south.toStringAsFixed(5) ?? '',
      _plantLayer.bounds?.west.toStringAsFixed(5) ?? '',
      _plantLayer.bounds?.north.toStringAsFixed(5) ?? '',
      _plantLayer.bounds?.east.toStringAsFixed(5) ?? '',
      farmBoundaryCoordinates.length.toString(),
      zoneCoordinates.firstOrNull?.latitude.toStringAsFixed(5) ?? '',
      zoneCoordinates.lastOrNull?.longitude.toStringAsFixed(5) ?? '',
      farmBoundaryCoordinates.firstOrNull?.latitude.toStringAsFixed(5) ?? '',
      farmBoundaryCoordinates.lastOrNull?.longitude.toStringAsFixed(5) ?? '',
    ].join('_');
    if (_lastCameraSignature == signature) return;
    _lastCameraSignature = signature;

    final List<LatLng> cameraCoordinates;
    final double padding;
    final plantBounds = _plantLayer.bounds;
    if (zoneCoordinates.length > 1) {
      cameraCoordinates = zoneCoordinates;
      padding = 64;
    } else if (plantBounds != null) {
      await animateMapCamera(
        controller,
        _cameraUpdateForSpatialBounds(plantBounds, 72),
      );
      return;
    } else if (farmBoundaryCoordinates.length > 1) {
      cameraCoordinates = farmBoundaryCoordinates;
      padding = 64;
    } else {
      cameraCoordinates = [...zoneCoordinates, ...farmBoundaryCoordinates];
      padding = 64;
    }

    final viewport = calculateMapCameraViewport(
      cameraCoordinates,
      fallback: userPosition ?? _fallbackPosition,
    );
    final bounds = viewport.bounds;
    await animateMapCamera(
      controller,
      bounds == null
          ? CameraUpdate.newLatLngZoom(viewport.target, 17)
          : CameraUpdate.newLatLngBounds(bounds, padding),
    );
  }

  Object? _cameraDataSignature;

  CameraUpdate _cameraUpdateForSpatialBounds(
    SpatialBounds bounds,
    double padding,
  ) {
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
      padding,
    );
  }

  void _recenterOnUser() {
    final loc = widget.viewModel.userLocation;
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

  String _selectedZoneName(FarmMapViewModel vm) {
    final zoneId = vm.selectedZoneId;
    if (zoneId == null) return '';
    final zone = vm.zones.where((z) => z.id == zoneId).firstOrNull;
    return zone?.displayName ?? 'Zona filtrada';
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: widget.viewModel,
      builder: (context, _) {
        _updateMarkersIfNeeded();
        final location = widget.viewModel.userLocation;
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
          if (mounted) unawaited(_fitCameraToAvailableCoordinates());
        });

        return Scaffold(
          backgroundColor: const Color(0xFFF4F7F2),
          appBar: AppBar(
            backgroundColor: const Color(0xFFF4F7F2),
            surfaceTintColor: Colors.transparent,
            title: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.eco),
                SizedBox(width: 8),
                Flexible(
                  child: Text('Fazenda', overflow: TextOverflow.ellipsis),
                ),
              ],
            ),
            actions: [
              if (widget.viewModel.userLocation != null)
                IconButton(
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
                    ActiveMapSurface(
                      onActivityChanged: (active) {
                        if (active) {
                          unawaited(widget.viewModel.loadUserLocation());
                        } else {
                          widget.viewModel.pauseLocation();
                          _mapController = null;
                          _plantLayer.controller = null;
                        }
                      },
                      builder: (_) => GoogleMap(
                        mapType: MapType.satellite,
                        initialCameraPosition:
                            _savedCamera ??
                            const CameraPosition(
                              target: _fallbackPosition,
                              zoom: 17,
                            ),
                        onCameraIdle: () {
                          _plantLayer.cameraIdle();
                          if (widget.viewModel.userLocation
                              case final location?) {
                            _userMapNavigator.invalidate();
                            _followUser(location);
                          }
                        },
                        onCameraMove: (position) => _savedCamera = position,
                        markers: {
                          ..._cachedMarkers,
                          if (widget.viewModel.userLocation
                              case final location?)
                            Marker(
                              markerId: const MarkerId('farm_user'),
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
                        polygons: _polygons,
                        myLocationEnabled: false,
                        myLocationButtonEnabled: false,
                        onMapCreated: (controller) {
                          _mapController = controller;
                          _plantLayer.controller = controller;
                          _plantLayer.cameraIdle();
                          unawaited(_fitCameraToAvailableCoordinates());
                          if (widget.viewModel.userLocation
                              case final location?) {
                            _followUser(location);
                          }
                        },
                      ),
                    ),
                    if (widget.viewModel.plantsStatus ==
                        PlantsLoadStatus.loading)
                      const Positioned(
                        top: 0,
                        left: 0,
                        right: 0,
                        child: LinearProgressIndicator(),
                      ),
                    if (widget.viewModel.selectedZoneId != null)
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
                                  Text(
                                    _selectedZoneName(widget.viewModel),
                                    style: TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.bold,
                                      color: Theme.of(context)
                                          .colorScheme
                                          .primary,
                                    ),
                                  ),
                                  const SizedBox(width: 6),
                                  GestureDetector(
                                    key: const ValueKey(
                                      'clear-farm-zone-badge-button',
                                    ),
                                    onTap: () =>
                                        widget.viewModel.selectZone(null),
                                    child: Icon(
                                      Icons.close,
                                      size: 16,
                                      color: Theme.of(context)
                                          .colorScheme
                                          .primary,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                    if (widget.viewModel.plantsStatus == PlantsLoadStatus.empty)
                      _StatusCard(
                        message: widget.viewModel.selectedZoneId == null
                            ? 'Nenhuma planta foi encontrada.'
                            : 'Nenhuma planta foi encontrada nesta zona.',
                        topPadding: widget.viewModel.selectedZoneId != null
                            ? 64
                            : 24,
                      ),
                    if (widget.viewModel.plantsStatus == PlantsLoadStatus.error)
                      _StatusCard(
                        message: widget.viewModel.errorMessage!,
                        actionLabel: 'Tentar novamente',
                        onAction: widget.viewModel.loadFarmData,
                        topPadding: widget.viewModel.selectedZoneId != null
                            ? 64
                            : 24,
                      ),
                    if (widget.viewModel.locationMessage case final message?)
                      _StatusCard(message: message, alignBottom: true),
                  ],
                ),
              ),
              FarmActionCard(viewModel: widget.viewModel),
            ],
          ),
        );
      },
    );
  }
}

class _StatusCard extends StatelessWidget {
  const _StatusCard({
    required this.message,
    this.actionLabel,
    this.onAction,
    this.alignBottom = false,
    this.topPadding = 16,
  });

  final String message;
  final String? actionLabel;
  final VoidCallback? onAction;
  final bool alignBottom;
  final double topPadding;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: alignBottom ? Alignment.bottomCenter : Alignment.topCenter,
      child: SafeArea(
        minimum: EdgeInsets.fromLTRB(16, topPadding, 16, 16),
        child: Card(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Flexible(child: Text(message)),
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
