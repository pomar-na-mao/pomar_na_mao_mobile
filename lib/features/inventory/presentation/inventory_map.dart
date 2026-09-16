import 'dart:async';

import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

import '../../farm/domain/farm_point.dart';
import '../../farm/domain/region_point.dart';
import '../../farm/presentation/farm_map_geometry.dart';

class InventoryMap extends StatefulWidget {
  const InventoryMap({
    required this.farmPoints,
    required this.zonePoints,
    required this.zoneId,
    super.key,
  });

  final List<FarmPoint> farmPoints;
  final List<RegionPoint> zonePoints;
  final String? zoneId;

  @override
  State<InventoryMap> createState() => _InventoryMapState();
}

class _InventoryMapState extends State<InventoryMap> {
  GoogleMapController? _controller;

  List<LatLng> get _coordinates => [
    ...widget.farmPoints.map(
      (point) => LatLng(point.latitude, point.longitude),
    ),
    ...widget.zonePoints.map(
      (point) => LatLng(point.latitude, point.longitude),
    ),
  ];

  @override
  void didUpdateWidget(covariant InventoryMap oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.farmPoints != widget.farmPoints ||
        oldWidget.zonePoints != widget.zonePoints ||
        oldWidget.zoneId != widget.zoneId) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) unawaited(_fitCamera());
      });
    }
  }

  Future<void> _fitCamera() async {
    final controller = _controller;
    if (controller == null) return;
    final viewport = calculateMapCameraViewport(_coordinates);
    final bounds = viewport.bounds;
    await controller.animateCamera(
      bounds == null
          ? CameraUpdate.newLatLngZoom(viewport.target, 16)
          : CameraUpdate.newLatLngBounds(bounds, 44),
    );
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final viewport = calculateMapCameraViewport(_coordinates);

    return createInventoryGoogleMap(
      farmPoints: widget.farmPoints,
      zonePoints: widget.zonePoints,
      zoneId: widget.zoneId,
      viewport: viewport,
      onMapCreated: (controller) {
        _controller = controller;
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) unawaited(_fitCamera());
        });
      },
    );
  }
}

GoogleMap createInventoryGoogleMap({
  required List<FarmPoint> farmPoints,
  required List<RegionPoint> zonePoints,
  required String? zoneId,
  required MapCameraViewport viewport,
  required void Function(GoogleMapController controller) onMapCreated,
}) {
  return GoogleMap(
    key: const ValueKey('inventory-google-map'),
    initialCameraPosition: CameraPosition(
      target: viewport.target,
      zoom: viewport.bounds == null ? 16 : 14,
    ),
    polygons: buildFarmPolygons(
      farmPoints: farmPoints,
      zonePoints: zonePoints,
      zoneId: zoneId,
    ),
    markers: const <Marker>{},
    clusterManagers: const <ClusterManager>{},
    myLocationEnabled: false,
    myLocationButtonEnabled: false,
    mapToolbarEnabled: false,
    zoomControlsEnabled: false,
    onMapCreated: onMapCreated,
  );
}
