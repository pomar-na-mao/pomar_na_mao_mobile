import '../../farm/presentation/user_map_navigation.dart';
import '../domain/spraying_geometry_service.dart';

class SprayingCourseTracker extends UserCourseTracker {
  SprayingCourseTracker({
    SprayingGeometryService geometry = const SprayingGeometryService(),
  }) : super(distance: geometry.haversineDistanceMeters);
}

double? nextSprayingMapBearing(double current, double? course) =>
    nextUserMapBearing(current, course);
