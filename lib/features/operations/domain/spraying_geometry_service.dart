import 'dart:math' as math;
import 'package:uuid/uuid.dart';

import 'inspection_models.dart';
import 'spraying_models.dart';

class SprayingGeometryService {
  const SprayingGeometryService({this.earthRadiusMeters = 6371000.0});

  final double earthRadiusMeters;

  /// Converte graus para radianos.
  double _toRadians(double deg) => deg * (math.pi / 180.0);

  /// Calcula a distância euclidiana/haversine em metros entre dois pontos geográficos.
  double haversineDistanceMeters(
    double lat1,
    double lon1,
    double lat2,
    double lon2,
  ) {
    final dLat = _toRadians(lat2 - lat1);
    final dLon = _toRadians(lon2 - lon1);
    final a =
        math.sin(dLat / 2) * math.sin(dLat / 2) +
        math.cos(_toRadians(lat1)) *
            math.cos(_toRadians(lat2)) *
            math.sin(dLon / 2) *
            math.sin(dLon / 2);
    final c = 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));
    return earthRadiusMeters * c;
  }

  /// Calcula a distância total percorrida somando os segmentos consecutivos dos pontos GPS.
  double calculateTotalDistanceMeters(List<SprayingTrackPoint> points) {
    if (points.length < 2) return 0.0;
    var total = 0.0;
    for (var i = 0; i < points.length - 1; i++) {
      total += haversineDistanceMeters(
        points[i].latitude,
        points[i].longitude,
        points[i + 1].latitude,
        points[i + 1].longitude,
      );
    }
    return total;
  }

  /// Gera a geometria GeoJSON padrão LineString a partir dos pontos da rota.
  Map<String, dynamic> buildLineStringGeoJson(List<SprayingTrackPoint> points) {
    return {
      'type': 'LineString',
      'coordinates': points.map((p) => [p.longitude, p.latitude]).toList(),
    };
  }

  /// Calcula a distância perpendicular mínima em metros de um ponto a um segmento de reta (A -> B).
  double pointToSegmentDistanceMeters({
    required double pLat,
    required double pLon,
    required double aLat,
    required double aLon,
    required double bLat,
    required double bLon,
  }) {
    // Projeção equirretangular local centrada em P
    final cosLat = math.cos(_toRadians(pLat));
    final ax = _toRadians(aLon - pLon) * earthRadiusMeters * cosLat;
    final ay = _toRadians(aLat - pLat) * earthRadiusMeters;
    final bx = _toRadians(bLon - pLon) * earthRadiusMeters * cosLat;
    final by = _toRadians(bLat - pLat) * earthRadiusMeters;

    final dx = bx - ax;
    final dy = by - ay;
    final segmentLengthSquared = dx * dx + dy * dy;

    if (segmentLengthSquared <= 1e-6) {
      // Segmento degenerado (A e B praticamente no mesmo local)
      return math.sqrt(ax * ax + ay * ay);
    }

    // Vetor AP em coordenadas locais é (-ax, -ay)
    // Projeção t do ponto P no segmento AB: t = ((P - A) . (B - A)) / |B - A|^2
    final t = ((-ax * dx) + (-ay * dy)) / segmentLengthSquared;

    if (t <= 0.0) {
      // Ponto mais próximo é A
      return math.sqrt(ax * ax + ay * ay);
    } else if (t >= 1.0) {
      // Ponto mais próximo é B
      return math.sqrt(bx * bx + by * by);
    } else {
      // Ponto mais próximo é a projeção no segmento
      final projX = ax + t * dx;
      final projY = ay + t * dy;
      return math.sqrt(projX * projX + projY * projY);
    }
  }

  /// Identifica quais plantas foram atingidas pela rota (distância <= maxDistanceMeters).
  ///
  /// Executa poda espacial prévia por Bounding Box para manter performance fluida
  /// mesmo em pomares com milhares de plantas.
  List<SprayingConfirmedPlant> calculateAffectedPlants({
    required List<InspectionPlant> candidatePlants,
    required List<SprayingTrackPoint> trackPoints,
    double maxDistanceMeters = 9.0,
    String Function()? idGenerator,
  }) {
    if (trackPoints.isEmpty || candidatePlants.isEmpty) {
      return const [];
    }

    final genId = idGenerator ?? const Uuid().v4;

    // 1. Poda espacial: Bounding Box dos trackPoints
    var minLat = double.infinity;
    var maxLat = -double.infinity;
    var minLon = double.infinity;
    var maxLon = -double.infinity;

    for (final tp in trackPoints) {
      if (tp.latitude < minLat) minLat = tp.latitude;
      if (tp.latitude > maxLat) maxLat = tp.latitude;
      if (tp.longitude < minLon) minLon = tp.longitude;
      if (tp.longitude > maxLon) maxLon = tp.longitude;
    }

    // Margem em graus correspondente ao raio + margem de segurança (15 metros)
    const safetyBufferMeters = 15.0;
    final bufferDegreesLat = safetyBufferMeters / 111139.0;
    final midLatRad = _toRadians((minLat + maxLat) / 2);
    final cosMidLat = math.cos(midLatRad).abs();
    final bufferDegreesLon =
        safetyBufferMeters / (111139.0 * (cosMidLat > 0.01 ? cosMidLat : 1.0));

    final bboxMinLat = minLat - bufferDegreesLat;
    final bboxMaxLat = maxLat + bufferDegreesLat;
    final bboxMinLon = minLon - bufferDegreesLon;
    final bboxMaxLon = maxLon + bufferDegreesLon;

    final affected = <SprayingConfirmedPlant>[];

    for (final plant in candidatePlants) {
      if (!plant.hasValidCoordinates || plant.nonExistent) continue;
      final pLat = plant.latitude!;
      final pLon = plant.longitude!;

      // Poda rápida
      if (pLat < bboxMinLat ||
          pLat > bboxMaxLat ||
          pLon < bboxMinLon ||
          pLon > bboxMaxLon) {
        continue;
      }

      // Encontra distância mínima à polyline e o trackPoint mais próximo
      var minDistance = double.infinity;
      SprayingTrackPoint? nearestPoint;

      // Se temos apenas 1 ponto GPS
      if (trackPoints.length == 1) {
        final tp = trackPoints.first;
        final d = haversineDistanceMeters(pLat, pLon, tp.latitude, tp.longitude);
        if (d <= maxDistanceMeters) {
          affected.add(
            SprayingConfirmedPlant(
              localId: genId(),
              plantId: plant.id,
              matchSource: SprayingMatchSource.autoMatched,
              matchedAt: tp.recordedAt,
              nearestTrackPointLocalId: tp.localId,
              distanceMeters: double.parse(d.toStringAsFixed(2)),
            ),
          );
        }
        continue;
      }

      // Se temos múltiplos pontos, calcula distância a cada segmento
      for (var i = 0; i < trackPoints.length - 1; i++) {
        final a = trackPoints[i];
        final b = trackPoints[i + 1];

        final segDist = pointToSegmentDistanceMeters(
          pLat: pLat,
          pLon: pLon,
          aLat: a.latitude,
          aLon: a.longitude,
          bLat: b.latitude,
          bLon: b.longitude,
        );

        if (segDist < minDistance) {
          minDistance = segDist;
          // Ponto mais próximo entre os extremos do segmento
          final distA = haversineDistanceMeters(pLat, pLon, a.latitude, a.longitude);
          final distB = haversineDistanceMeters(pLat, pLon, b.latitude, b.longitude);
          nearestPoint = distA <= distB ? a : b;
        }
      }

      if (minDistance <= maxDistanceMeters) {
        affected.add(
          SprayingConfirmedPlant(
            localId: genId(),
            plantId: plant.id,
            matchSource: SprayingMatchSource.autoMatched,
            matchedAt: nearestPoint?.recordedAt ?? trackPoints.first.recordedAt,
            nearestTrackPointLocalId: nearestPoint?.localId,
            distanceMeters: double.parse(minDistance.toStringAsFixed(2)),
          ),
        );
      }
    }

    return affected;
  }
}
