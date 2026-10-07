import '../../farm/domain/user_position_tracker.dart';
import 'spraying_geometry_service.dart';

class SprayingLocationFilter extends UserLocationFilter {
  SprayingLocationFilter({
    SprayingGeometryService geometry = const SprayingGeometryService(),
  }) : super(distance: geometry.haversineDistanceMeters);
}
