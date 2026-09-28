import 'dart:async';
import 'dart:isolate';
import 'dart:math' as math;

import 'package:supercluster/supercluster.dart';

const _maxClusterZoom = 20;
const _maxProjectedNodes = 1000;
const _maxIndividualClusterMembers = 12;

class SpatialPlant {
  const SpatialPlant(this.id, this.latitude, this.longitude);
  final String id;
  final double latitude;
  final double longitude;
  bool get isValid =>
      latitude.isFinite &&
      longitude.isFinite &&
      latitude.abs() <= 90 &&
      longitude.abs() <= 180;
}

class SpatialBounds {
  const SpatialBounds({
    required this.south,
    required this.west,
    required this.north,
    required this.east,
  });

  final double south;
  final double west;
  final double north;
  final double east;

  double get centerLatitude => (south + north) / 2;
  double get centerLongitude => (west + east) / 2;
  bool get hasArea => south != north || west != east;
}

class PlantMapNode {
  const PlantMapNode({
    required this.id,
    required this.latitude,
    required this.longitude,
    required this.count,
    this.plantId,
    this.clusterId,
  });
  final String id;
  final double latitude;
  final double longitude;
  final int count;
  final String? plantId;
  final int? clusterId;
}

/// Owns the large index in a worker; only bounded map projections cross back.
class PlantSpatialIndex {
  Isolate? _isolate;
  Future<SendPort>? _starting;
  ReceivePort? _ready;
  final Set<ReceivePort> _replies = {};
  bool _disposed = false;

  Future<SendPort> _start() => _starting ??= () async {
    final ready = ReceivePort();
    _ready = ready;
    try {
      final isolate = await Isolate.spawn(_spatialWorker, ready.sendPort);
      if (_disposed) {
        isolate.kill(priority: Isolate.immediate);
        throw StateError('Spatial worker disposed');
      }
      _isolate = isolate;
      return await ready.first.timeout(const Duration(seconds: 30)) as SendPort;
    } finally {
      ready.close();
      _ready = null;
    }
  }();

  Future<T> _request<T>(String command, Object data) async {
    if (_disposed) throw StateError('Spatial worker disposed');
    final port = await _start();
    if (_disposed) throw StateError('Spatial worker disposed');
    final reply = ReceivePort();
    _replies.add(reply);
    try {
      port.send((command, data, reply.sendPort));
      final result = await reply.first.timeout(const Duration(seconds: 30));
      if (result is _WorkerFailure) {
        throw StateError('Spatial operation failed');
      }
      return result as T;
    } finally {
      reply.close();
      _replies.remove(reply);
    }
  }

  Future<SpatialBounds?> load(List<SpatialPlant> plants) =>
      _request('load', plants);

  Future<List<PlantMapNode>> query({
    double west = -180,
    double south = -90,
    double east = 180,
    double north = 90,
    int zoom = 0,
  }) => _request('query', (west, south, east, north, zoom));

  Future<List<String>> members(int clusterId, {int offset = 0}) =>
      _request('members', (clusterId, offset));

  void dispose() {
    _disposed = true;
    _ready?.close();
    _isolate?.kill(priority: Isolate.immediate);
    for (final reply in _replies) {
      reply.close();
    }
    _replies.clear();
  }
}

class _WorkerFailure {
  const _WorkerFailure();
}

void _spatialWorker(SendPort ready) {
  final requests = ReceivePort();
  ready.send(requests.sendPort);
  var index = _newIndex()..load(const []);
  SpatialBounds? bounds;
  requests.listen((message) {
    final (command, data, reply) = message as (String, Object, SendPort);
    try {
      switch (command) {
        case 'load':
          final plants = (data as List<SpatialPlant>)
              .where((p) => p.isValid)
              .toList(growable: false);
          index = _newIndex()..load(plants);
          bounds = _calculateBounds(plants);
          reply.send(bounds);
        case 'query':
          final (west, south, east, north, requestedZoom) =
              data as (double, double, double, double, int);
          var zoom = requestedZoom.clamp(0, _maxClusterZoom);
          late List<ImmutableLayerElement<SpatialPlant>> elements;
          do {
            // Margin grows with cluster radius so edge clusters remain reachable.
            final margin = 360 * 80 / (512 * math.pow(2, zoom));
            elements = index.search(
              (west - margin).clamp(-180, 180),
              (south - margin).clamp(-90, 90),
              (east + margin).clamp(-180, 180),
              (north + margin).clamp(-90, 90),
              zoom,
            );
          } while (elements.length > _maxProjectedNodes && zoom-- > 0);
          if (elements.length > _maxProjectedNodes) {
            throw StateError('Unbounded projection');
          }
          final nodes = _projectNodes(
            index: index,
            elements: elements,
            splitSmallClusters: requestedZoom >= _maxClusterZoom,
          );
          if (nodes.length > _maxProjectedNodes) {
            reply.send(_projectNodes(index: index, elements: elements));
          } else {
            reply.send(nodes);
          }
        case 'members':
          final (id, offset) = data as (int, int);
          reply.send(
            index
                .pointsWithin(id, limit: 50, offset: offset)
                .map((point) => point.originalPoint.id)
                .toList(growable: false),
          );
        default:
          reply.send(const _WorkerFailure());
      }
    } catch (_) {
      reply.send(const _WorkerFailure());
    }
  });
}

SuperclusterImmutable<SpatialPlant> _newIndex() => SuperclusterImmutable(
  getX: (point) => point.longitude,
  getY: (point) => point.latitude,
  maxZoom: _maxClusterZoom,
  radius: 80,
);

List<PlantMapNode> _projectNodes({
  required SuperclusterImmutable<SpatialPlant> index,
  required List<ImmutableLayerElement<SpatialPlant>> elements,
  bool splitSmallClusters = false,
}) {
  final nodes = <PlantMapNode>[];
  for (final element in elements) {
    element.handle(
      cluster: (cluster) {
        final typedCluster = cluster as ImmutableLayerCluster<SpatialPlant>;
        if (splitSmallClusters &&
            cluster.childPointCount <= _maxIndividualClusterMembers) {
          final points = index.pointsWithin(
            typedCluster.id,
            limit: _maxIndividualClusterMembers,
          );
          nodes.addAll(_projectSmallCluster(cluster, points));
          return;
        }
        nodes.add(
          PlantMapNode(
            id: 'cluster-${cluster.uuid}',
            latitude: cluster.latitude,
            longitude: cluster.longitude,
            count: cluster.childPointCount,
            clusterId: typedCluster.id,
          ),
        );
      },
      point: (point) {
        nodes.add(
          PlantMapNode(
            id: 'plant-${point.originalPoint.id}',
            latitude: point.originalPoint.latitude,
            longitude: point.originalPoint.longitude,
            count: 1,
            plantId: point.originalPoint.id,
          ),
        );
      },
    );
  }
  return nodes;
}

Iterable<PlantMapNode> _projectSmallCluster(
  ImmutableLayerCluster<SpatialPlant> cluster,
  List<ImmutableLayerPoint<SpatialPlant>> points,
) {
  if (!_hasCoincidentCoordinates(points)) {
    return points.map((point) => _nodeForPoint(point.originalPoint));
  }
  final step = 2 * math.pi / points.length;
  return points.indexed.map((entry) {
    final (index, point) = entry;
    final angle = index * step;
    const radius = 0.000012;
    return _nodeForPoint(
      point.originalPoint,
      latitude: (cluster.latitude + math.sin(angle) * radius).clamp(-90, 90),
      longitude: (cluster.longitude + math.cos(angle) * radius).clamp(
        -180,
        180,
      ),
    );
  });
}

bool _hasCoincidentCoordinates(List<ImmutableLayerPoint<SpatialPlant>> points) {
  if (points.length < 2) return false;
  final latitude = points.first.originalPoint.latitude;
  final longitude = points.first.originalPoint.longitude;
  return points
      .skip(1)
      .any(
        (point) =>
            point.originalPoint.latitude == latitude &&
            point.originalPoint.longitude == longitude,
      );
}

PlantMapNode _nodeForPoint(
  SpatialPlant point, {
  double? latitude,
  double? longitude,
}) => PlantMapNode(
  id: 'plant-${point.id}',
  latitude: latitude ?? point.latitude,
  longitude: longitude ?? point.longitude,
  count: 1,
  plantId: point.id,
);

SpatialBounds? _calculateBounds(List<SpatialPlant> plants) {
  if (plants.isEmpty) return null;
  var south = plants.first.latitude;
  var north = plants.first.latitude;
  var west = plants.first.longitude;
  var east = plants.first.longitude;
  for (final plant in plants.skip(1)) {
    south = math.min(south, plant.latitude);
    north = math.max(north, plant.latitude);
    west = math.min(west, plant.longitude);
    east = math.max(east, plant.longitude);
  }
  return SpatialBounds(south: south, west: west, north: north, east: east);
}
