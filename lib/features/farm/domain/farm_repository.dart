import 'farm_point.dart';

abstract interface class FarmRepository {
  Future<List<FarmPoint>> fetchFarmBoundary();
}
