import 'plant.dart';

abstract interface class PlantsRepository {
  Future<List<Plant>> fetchPlants();
}
