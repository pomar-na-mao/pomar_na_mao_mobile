import 'package:flutter/widgets.dart';

class InspectionCameraFollowState {
  bool _isFollowing = true;
  bool _pointerDown = false;

  bool get isFollowing => _isFollowing;

  void pointerDown() => _pointerDown = true;

  void pointerUp() => _pointerDown = false;

  bool cameraMoveStarted() {
    if (!_pointerDown) return false;
    return suspend();
  }

  bool suspend() {
    if (!_isFollowing) return false;
    _isFollowing = false;
    return true;
  }

  bool resume() {
    if (_isFollowing) return false;
    _isFollowing = true;
    return true;
  }
}

enum InspectionUserMarkerKind { neutral, directional }

class InspectionUserMarkerPresentation {
  const InspectionUserMarkerPresentation({
    required this.kind,
    required this.rotation,
    required this.flat,
    required this.anchor,
  });

  final InspectionUserMarkerKind kind;
  final double rotation;
  final bool flat;
  final Offset anchor;
}

const inspectionUserMarkerAnchor = Offset(0.5, 0.5);

InspectionUserMarkerPresentation inspectionUserMarkerForCourse(double? course) {
  final isDirectional =
      course != null && course.isFinite && course >= 0 && course < 360;
  return InspectionUserMarkerPresentation(
    kind: isDirectional
        ? InspectionUserMarkerKind.directional
        : InspectionUserMarkerKind.neutral,
    rotation: isDirectional ? course : 0,
    flat: isDirectional,
    anchor: inspectionUserMarkerAnchor,
  );
}
