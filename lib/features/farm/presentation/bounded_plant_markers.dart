import 'dart:async';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

import '../../../core/diagnostics/runtime_diagnostics.dart';
import 'plant_spatial_index.dart';

class BoundedPlantMarkers extends ChangeNotifier {
  final PlantSpatialIndex _index = PlantSpatialIndex();
  final _icons = <int, BitmapDescriptor>{};
  Object? _revision;
  var _generation = 0;
  var _request = 0;
  var _indexedGeneration = -1;
  final _nodeGenerations = Expando<int>();
  bool _disposed = false;
  Future<void> _loading = Future.value();
  Timer? _debounce;
  GoogleMapController? _controller;
  GoogleMapController? get controller => _controller;
  set controller(GoogleMapController? value) {
    if (identical(value, _controller)) return;
    ++_request;
    _debounce?.cancel();
    _controller = value;
  }

  Set<Marker> markers = const {};
  bool failed = false;
  SpatialBounds? bounds;

  void update({
    required Object revision,
    required List<SpatialPlant> Function() plants,
    required Marker Function(PlantMapNode) markerFor,
    required void Function(PlantMapNode) onClusterTap,
  }) {
    if (_disposed || _revision == revision) return;
    _revision = revision;
    final generation = ++_generation;
    _markerFor = markerFor;
    _onClusterTap = onClusterTap;
    _loading = _loading
        .then((_) async {
          if (_disposed || generation != _generation) return;
          bounds = await _index.load(plants());
          _indexedGeneration = generation;
        })
        .catchError((Object error) {
          if (!_disposed && generation == _generation) {
            failed = true;
            RuntimeDiagnostics.instance.record(
              RuntimeStage.projection,
              outcome: RuntimeOutcome.failure,
            );
          }
        });
    unawaited(refresh());
  }

  Marker Function(PlantMapNode)? _markerFor;
  void Function(PlantMapNode)? _onClusterTap;

  void cameraIdle() {
    _debounce?.cancel();
    _debounce = Timer(
      const Duration(milliseconds: 150),
      () => unawaited(refresh()),
    );
  }

  Future<void> refresh() async {
    final request = ++_request;
    final generation = _generation;
    try {
      await _loading;
      if (_disposed || request != _request || generation != _generation) return;
      if (_indexedGeneration != generation) {
        failed = true;
        notifyListeners();
        return;
      }
      final map = controller;
      final bounds = await map?.getVisibleRegion();
      final zoom = await map?.getZoomLevel() ?? 0;
      if (_disposed || request != _request || !identical(map, controller)) {
        return;
      }
      final nodes = await _index.query(
        west: bounds?.southwest.longitude ?? -180,
        south: bounds?.southwest.latitude ?? -90,
        east: bounds?.northeast.longitude ?? 180,
        north: bounds?.northeast.latitude ?? 90,
        zoom: zoom.floor(),
      );
      final next = <Marker>{};
      for (final node in nodes) {
        _nodeGenerations[node] = generation;
        if (_disposed || request != _request || generation != _generation) {
          return;
        }
        if (node.plantId != null) {
          final build = _markerFor;
          if (build != null) next.add(build(node));
        } else {
          final icon = await _clusterIcon(node.count);
          next.add(
            Marker(
              markerId: MarkerId(node.id),
              position: LatLng(node.latitude, node.longitude),
              icon: icon,
              anchor: const Offset(0.5, 0.5),
              infoWindow: InfoWindow(title: '${node.count} plantas'),
              onTap: () {
                if (!_disposed && generation == _generation) {
                  _onClusterTap?.call(node);
                }
              },
            ),
          );
        }
      }
      if (_disposed || request != _request || generation != _generation) return;
      markers = next;
      failed = false;
      RuntimeDiagnostics.instance.record(
        RuntimeStage.markers,
        count: markers.length,
      );
      notifyListeners();
    } catch (_) {
      if (_disposed || request != _request) return;
      failed = true;
      RuntimeDiagnostics.instance.record(
        RuntimeStage.projection,
        outcome: RuntimeOutcome.failure,
      );
      notifyListeners();
    }
  }

  Future<List<String>> members(PlantMapNode node, int offset) async {
    final generation = _generation;
    if (_nodeGenerations[node] != generation ||
        _indexedGeneration != generation) {
      throw StateError('Map revision changed');
    }
    final result = await _index.members(node.clusterId!, offset: offset);
    if (_disposed || generation != _generation) {
      throw StateError('Map revision changed');
    }
    return result;
  }

  Future<BitmapDescriptor> _clusterIcon(int count) async {
    final cached = _icons[count];
    if (cached != null) return cached;
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    canvas.drawCircle(const Offset(36, 36), 34, Paint()..color = Colors.white);
    canvas.drawCircle(
      const Offset(36, 36),
      30,
      Paint()..color = const Color(0xFF2E7D32),
    );
    final text = TextPainter(
      text: TextSpan(
        text: '$count',
        style: const TextStyle(
          color: Colors.white,
          fontSize: 18,
          fontWeight: FontWeight.bold,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    text.paint(canvas, Offset(36 - text.width / 2, 36 - text.height / 2));
    text.dispose();
    final picture = recorder.endRecording();
    final image = await picture.toImage(72, 72);
    picture.dispose();
    final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
    image.dispose();
    final icon = BitmapDescriptor.bytes(
      bytes!.buffer.asUint8List(),
      width: 40,
      height: 40,
    );
    if (!_disposed) {
      if (_icons.length >= 64) _icons.remove(_icons.keys.first);
      _icons[count] = icon;
    }
    return icon;
  }

  @override
  void dispose() {
    _disposed = true;
    ++_request;
    _debounce?.cancel();
    controller = null;
    _index.dispose();
    _icons.clear();
    super.dispose();
  }
}

Future<void> showPlantClusterMembers(
  BuildContext context, {
  required BoundedPlantMarkers layer,
  required PlantMapNode node,
  required String Function(String) labelFor,
  required ValueChanged<String> onSelect,
}) => showModalBottomSheet<void>(
  context: context,
  builder: (_) => _Members(
    layer: layer,
    node: node,
    labelFor: labelFor,
    onSelect: onSelect,
  ),
);

class _Members extends StatefulWidget {
  const _Members({
    required this.layer,
    required this.node,
    required this.labelFor,
    required this.onSelect,
  });
  final BoundedPlantMarkers layer;
  final PlantMapNode node;
  final String Function(String) labelFor;
  final ValueChanged<String> onSelect;
  @override
  State<_Members> createState() => _MembersState();
}

class _MembersState extends State<_Members> {
  int _offset = 0;
  late Future<List<String>> _page = widget.layer.members(widget.node, _offset);
  void _move(int delta) => setState(() {
    _offset += delta;
    _page = widget.layer.members(widget.node, _offset);
  });
  @override
  Widget build(BuildContext context) => SafeArea(
    child: SizedBox(
      height: 440,
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(12),
            child: Text('${widget.node.count} plantas'),
          ),
          Expanded(
            child: FutureBuilder<List<String>>(
              future: _page,
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return const Center(
                    child: Text('Mapa atualizado. Abra o grupo novamente.'),
                  );
                }
                if (!snapshot.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }
                return ListView.builder(
                  itemCount: snapshot.data!.length,
                  itemBuilder: (context, index) {
                    final id = snapshot.data![index];
                    return ListTile(
                      title: Text(widget.labelFor(id)),
                      onTap: () {
                        Navigator.of(context).pop();
                        widget.onSelect(id);
                      },
                    );
                  },
                );
              },
            ),
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              IconButton(
                tooltip: 'Anterior',
                icon: const Icon(Icons.chevron_left),
                onPressed: _offset > 0 ? () => _move(-50) : null,
              ),
              Text('${_offset ~/ 50 + 1} / ${(widget.node.count / 50).ceil()}'),
              IconButton(
                tooltip: 'Próxima',
                icon: const Icon(Icons.chevron_right),
                onPressed: _offset + 50 < widget.node.count
                    ? () => _move(50)
                    : null,
              ),
            ],
          ),
        ],
      ),
    ),
  );
}
