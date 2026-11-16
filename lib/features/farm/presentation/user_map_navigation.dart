import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

import '../domain/user_location.dart';
import '../domain/user_position_tracker.dart';

const userFollowZoom = 20.5;
const directionalUserMarkerCanvasSize = 72;
const directionalUserMarkerDisplaySize = 32.0;

Future<BitmapDescriptor> createUserLocationMarkerIcon() async {
  const size = 64;
  const center = Offset(size / 2, size / 2);
  final recorder = ui.PictureRecorder();
  final canvas = Canvas(recorder);
  canvas.drawCircle(center, 27, Paint()..color = Colors.white);
  canvas.drawCircle(center, 22, Paint()..color = const Color(0xFF1976D2));
  canvas.drawCircle(
    center.translate(-7, -7),
    6,
    Paint()..color = const Color(0xFF90CAF9),
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

@visibleForTesting
Future<Uint8List> createDirectionalUserLocationMarkerBytes() async {
  const size = directionalUserMarkerCanvasSize;
  const center = Offset(size / 2, size / 2);
  final recorder = ui.PictureRecorder();
  final canvas = Canvas(recorder);
  canvas.drawCircle(center, 33, Paint()..color = Colors.white);

  final arrow = Path()
    ..moveTo(center.dx, 7)
    ..lineTo(61, 61)
    ..lineTo(center.dx, 50)
    ..lineTo(11, 61)
    ..close();
  canvas.drawPath(
    arrow,
    Paint()
      ..color = const Color(0xFF1976D2)
      ..style = PaintingStyle.fill,
  );
  canvas.drawPath(
    arrow,
    Paint()
      ..color = Colors.white
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3
      ..strokeJoin = StrokeJoin.round,
  );

  final picture = recorder.endRecording();
  final image = await picture.toImage(size, size);
  picture.dispose();
  final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
  image.dispose();
  return bytes!.buffer.asUint8List();
}

Future<BitmapDescriptor> createDirectionalUserLocationMarkerIcon() async {
  final bytes = await createDirectionalUserLocationMarkerBytes();
  return BitmapDescriptor.bytes(
    bytes,
    width: directionalUserMarkerDisplaySize,
    height: directionalUserMarkerDisplaySize,
  );
}

class UserCourseTracker {
  UserCourseTracker({this.distance = userDistanceMeters});

  final UserDistance distance;
  UserLocation? _lastObserved;
  UserLocation? _bearingOrigin;
  double? _course;

  double? get course => _course;

  void reset() {
    _lastObserved = null;
    _bearingOrigin = null;
    _course = null;
  }

  void add(UserLocation location) {
    if (identical(_lastObserved, location)) return;
    _lastObserved = location;

    final heading = location.heading;
    final speed = location.speed;
    if (heading != null &&
        heading.isFinite &&
        heading >= 0 &&
        heading < 360 &&
        speed != null &&
        speed.isFinite &&
        speed >= 0.7) {
      _course = heading;
      _bearingOrigin = location;
      return;
    }

    final origin = _bearingOrigin;
    if (origin == null) {
      _bearingOrigin = location;
      return;
    }
    if (speed != null && speed.isFinite && speed < 0.35) return;
    final meters = distance(
      origin.latitude,
      origin.longitude,
      location.latitude,
      location.longitude,
    );
    if (meters < math.max(4, (location.accuracy ?? 4) * 0.75)) return;

    final latitudeA = origin.latitude * math.pi / 180;
    final latitudeB = location.latitude * math.pi / 180;
    final longitudeDelta =
        (location.longitude - origin.longitude) * math.pi / 180;
    final east = math.sin(longitudeDelta) * math.cos(latitudeB);
    final north =
        math.cos(latitudeA) * math.sin(latitudeB) -
        math.sin(latitudeA) * math.cos(latitudeB) * math.cos(longitudeDelta);
    _course = (math.atan2(east, north) * 180 / math.pi + 360) % 360;
    _bearingOrigin = location;
  }
}

double? nextUserMapBearing(double current, double? course) {
  if (course == null || !course.isFinite) return null;
  if (!current.isFinite) return course;
  final delta = (course - current + 540) % 360 - 180;
  if (delta.abs() < 7) return null;
  return (current + delta.clamp(-60.0, 60.0) + 360) % 360;
}

bool isInsideUserFocusArea(
  LatLngBounds bounds,
  LatLng position, {
  double edgeMargin = 0.12,
}) {
  final south = bounds.southwest.latitude;
  final north = bounds.northeast.latitude;
  final latitudeMargin = (north - south) * edgeMargin;
  if (position.latitude < south + latitudeMargin ||
      position.latitude > north - latitudeMargin) {
    return false;
  }

  final west = bounds.southwest.longitude;
  final east = bounds.northeast.longitude;
  final longitudeSpan = east >= west ? east - west : east + 360 - west;
  final longitudeOffset = (position.longitude - west + 360) % 360;
  final longitudeMargin = longitudeSpan * edgeMargin;
  return longitudeOffset >= longitudeMargin &&
      longitudeOffset <= longitudeSpan - longitudeMargin;
}

CameraPosition? userFollowCameraPosition({
  required CameraPosition current,
  required LatLng user,
  required bool outsideFocusArea,
  double? bearing,
}) {
  if (!outsideFocusArea && bearing == null) return null;
  return CameraPosition(
    target: outsideFocusArea ? user : current.target,
    zoom: current.zoom,
    tilt: current.tilt,
    bearing: bearing ?? current.bearing,
  );
}

class UserMapNavigator {
  final UserCourseTracker _courseTracker = UserCourseTracker();
  UserLocation? _lastCheckedLocation;
  UserLocation? _queuedLocation;
  bool _checkingVisibleRegion = false;

  double? get course => _courseTracker.course;

  void reset() {
    _courseTracker.reset();
    _lastCheckedLocation = null;
    _queuedLocation = null;
  }

  void observe(UserLocation location) => _courseTracker.add(location);

  void invalidate() => _lastCheckedLocation = null;

  Future<void> focus(
    GoogleMapController controller,
    UserLocation location, {
    double zoom = userFollowZoom,
    double tilt = 0,
    double bearing = 0,
  }) async {
    _lastCheckedLocation = location;
    try {
      await controller.animateCamera(
        CameraUpdate.newCameraPosition(
          CameraPosition(
            target: LatLng(location.latitude, location.longitude),
            zoom: zoom,
            tilt: tilt,
            bearing: _courseTracker.course ?? bearing,
          ),
        ),
      );
    } catch (error) {
      debugPrint('Erro ao centralizar localizacao no mapa: $error');
    }
  }

  Future<void> follow({
    required UserLocation location,
    required GoogleMapController? controller,
    required CameraPosition? Function() camera,
    required bool Function() isActive,
  }) async {
    if (controller == null) return;
    await followWithCallbacks(
      location: location,
      getVisibleRegion: controller.getVisibleRegion,
      animateCamera: (position) =>
          controller.animateCamera(CameraUpdate.newCameraPosition(position)),
      camera: camera,
      isActive: isActive,
    );
  }

  @visibleForTesting
  Future<void> followWithCallbacks({
    required UserLocation location,
    required Future<LatLngBounds> Function() getVisibleRegion,
    required Future<void> Function(CameraPosition position) animateCamera,
    required CameraPosition? Function() camera,
    required bool Function() isActive,
  }) async {
    if (!isActive() || identical(_lastCheckedLocation, location)) return;
    if (_checkingVisibleRegion) {
      _queuedLocation = location;
      return;
    }
    _checkingVisibleRegion = true;
    try {
      final bounds = await getVisibleRegion();
      if (!isActive()) return;
      _lastCheckedLocation = location;
      final user = LatLng(location.latitude, location.longitude);
      final currentCamera = camera();
      final bearing = nextUserMapBearing(
        currentCamera?.bearing ?? 0,
        _courseTracker.course,
      );
      final next = userFollowCameraPosition(
        current:
            currentCamera ?? CameraPosition(target: user, zoom: userFollowZoom),
        user: user,
        outsideFocusArea: !isInsideUserFocusArea(bounds, user),
        bearing: bearing,
      );
      if (next != null && isActive()) {
        await animateCamera(next);
      }
    } catch (error) {
      debugPrint('Erro ao acompanhar localizacao no mapa: $error');
    } finally {
      _checkingVisibleRegion = false;
      final queued = _queuedLocation;
      _queuedLocation = null;
      if (queued != null && isActive()) {
        _lastCheckedLocation = null;
        await followWithCallbacks(
          location: queued,
          getVisibleRegion: getVisibleRegion,
          animateCamera: animateCamera,
          camera: camera,
          isActive: isActive,
        );
      }
    }
  }
}
