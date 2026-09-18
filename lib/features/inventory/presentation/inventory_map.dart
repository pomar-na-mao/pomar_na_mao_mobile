import 'dart:async';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

import '../../farm/domain/farm_point.dart';
import '../../farm/domain/region_point.dart';
import '../../farm/presentation/farm_map_geometry.dart';

class InventoryMap extends StatefulWidget {
  const InventoryMap({
    required this.farmPoints,
    required this.zonePointsById,
    super.key,
  });

  final List<FarmPoint> farmPoints;
  final Map<String, List<RegionPoint>> zonePointsById;

  @override
  State<InventoryMap> createState() => _InventoryMapState();
}

class _InventoryMapState extends State<InventoryMap> {
  GoogleMapController? _controller;
  Map<String, BitmapDescriptor> _zoneLabelIcons = const {};
  var _labelIconLoadVersion = 0;

  List<LatLng> get _coordinates => [
    ...widget.farmPoints.map(
      (point) => LatLng(point.latitude, point.longitude),
    ),
    ...widget.zonePointsById.values
        .expand((points) => points)
        .map((point) => LatLng(point.latitude, point.longitude)),
  ];

  @override
  void initState() {
    super.initState();
    unawaited(_loadZoneLabelIcons());
  }

  @override
  void didUpdateWidget(covariant InventoryMap oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.farmPoints != widget.farmPoints ||
        oldWidget.zonePointsById != widget.zonePointsById) {
      unawaited(_loadZoneLabelIcons());
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) unawaited(_fitCamera());
      });
    }
  }

  Future<void> _loadZoneLabelIcons() async {
    final version = ++_labelIconLoadVersion;
    final labels = zoneLabelsById(widget.zonePointsById).values.toSet();
    final entries = await Future.wait(
      labels.map((label) async {
        final icon = await createZoneLabelIcon(label);
        return MapEntry(label, icon);
      }),
    );
    if (!mounted || version != _labelIconLoadVersion) return;
    setState(() => _zoneLabelIcons = Map.fromEntries(entries));
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
      zonePointsById: widget.zonePointsById,
      zoneLabelIcons: _zoneLabelIcons,
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
  required Map<String, List<RegionPoint>> zonePointsById,
  Map<String, BitmapDescriptor> zoneLabelIcons = const {},
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
      zonePointsById: zonePointsById,
      showZoneStroke: false,
    ),
    polylines: buildDottedZoneBoundaries(zonePointsById),
    markers: buildZoneLabelMarkers(
      zonePointsById: zonePointsById,
      iconsByLabel: zoneLabelIcons,
    ),
    clusterManagers: const <ClusterManager>{},
    myLocationEnabled: false,
    myLocationButtonEnabled: false,
    mapToolbarEnabled: false,
    zoomControlsEnabled: false,
    onMapCreated: onMapCreated,
  );
}

Map<String, String> zoneLabelsById(
  Map<String, List<RegionPoint>> zonePointsById,
) {
  final labels = <String, String>{};
  for (final MapEntry(key: zoneId, value: points) in zonePointsById.entries) {
    for (final point in points) {
      final label = _normalizeZoneLabel(point.region);
      if (label != null) {
        labels[zoneId] = label;
        break;
      }
    }
  }
  return labels;
}

Set<Marker> buildZoneLabelMarkers({
  required Map<String, List<RegionPoint>> zonePointsById,
  required Map<String, BitmapDescriptor> iconsByLabel,
}) {
  final labels = zoneLabelsById(zonePointsById);
  final markers = <Marker>{};
  for (final MapEntry(key: zoneId, value: points) in zonePointsById.entries) {
    if (points.length < 3) continue;
    final label = labels[zoneId];
    if (label == null) continue;
    final icon = iconsByLabel[label];
    if (icon == null) continue;
    markers.add(
      Marker(
        markerId: MarkerId('zone_label_$zoneId'),
        position: _zoneCenter(points),
        anchor: const Offset(0.5, 0.5),
        icon: icon,
        zIndexInt: 2,
        infoWindow: InfoWindow(title: 'Zona $label'),
      ),
    );
  }
  return markers;
}

LatLng _zoneCenter(List<RegionPoint> points) {
  var latitude = 0.0;
  var longitude = 0.0;
  for (final point in points) {
    latitude += point.latitude;
    longitude += point.longitude;
  }
  return LatLng(latitude / points.length, longitude / points.length);
}

String? _normalizeZoneLabel(String? value) {
  final normalized = value?.trim();
  if (normalized == null || normalized.isEmpty) return null;
  final match = RegExp(
    r'^(?:zona\s*)?([a-z])$',
    caseSensitive: false,
  ).firstMatch(normalized);
  return match?.group(1)?.toUpperCase();
}

Future<BitmapDescriptor> createZoneLabelIcon(String label) async {
  const logicalSize = 40.0;
  const pixelRatio = 3.0;
  final recorder = ui.PictureRecorder();
  final canvas = Canvas(recorder)..scale(pixelRatio);
  const center = Offset(logicalSize / 2, logicalSize / 2);

  canvas.drawCircle(
    center + const Offset(0, 1.5),
    17,
    Paint()..color = const Color(0x33000000),
  );
  canvas.drawCircle(center, 17, Paint()..color = Colors.white);
  canvas.drawCircle(
    center,
    17,
    Paint()
      ..color = zoneBoundaryStrokeColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.5,
  );

  final textPainter = TextPainter(
    text: TextSpan(
      text: label,
      style: const TextStyle(
        color: Color(0xFF17351D),
        fontSize: 19,
        fontWeight: FontWeight.w700,
      ),
    ),
    textDirection: TextDirection.ltr,
  )..layout();
  textPainter.paint(
    canvas,
    center - Offset(textPainter.width / 2, textPainter.height / 2),
  );

  final picture = recorder.endRecording();
  final image = await picture.toImage(
    (logicalSize * pixelRatio).round(),
    (logicalSize * pixelRatio).round(),
  );
  picture.dispose();
  final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
  image.dispose();
  if (byteData == null) {
    throw StateError('Não foi possível criar o rótulo da zona.');
  }
  final bytes = byteData.buffer.asUint8List();
  return BitmapDescriptor.bytes(bytes, imagePixelRatio: pixelRatio);
}
