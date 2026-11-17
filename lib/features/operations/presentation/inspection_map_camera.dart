import '../../farm/presentation/user_map_navigation.dart';

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

typedef InspectionUserMarkerKind = UserMapMarkerKind;
typedef InspectionUserMarkerPresentation = UserMapMarkerPresentation;

const inspectionUserMarkerAnchor = userMapMarkerAnchor;

InspectionUserMarkerPresentation inspectionUserMarkerForCourse(double? course) {
  return userMapMarkerForCourse(course);
}
