import 'package:pomar_na_mao_mobile/features/operations/data/inspection_local_store.dart';
import 'package:pomar_na_mao_mobile/features/operations/domain/inspection_models.dart';

enum OrchardDistribution { dispersed, dense, coincident }

class OrchardFixture {
  OrchardFixture(
    int count, {
    OrchardDistribution distribution = OrchardDistribution.dispersed,
  }) {
    if (count < 0) throw ArgumentError.value(count, 'count');
    plants = List.generate(count, (index) {
      final invalid = index % 101 == 100;
      final nonExistent = index % 10 == 9;
      final spacing = switch (distribution) {
        OrchardDistribution.dispersed => 0.001,
        OrchardDistribution.dense => 0.000001,
        OrchardDistribution.coincident => 0.0,
      };
      return InspectionPlant(
        id: 'plant-${index.toString().padLeft(6, '0')}',
        latitude: invalid ? null : -23.0 + (index ~/ 250) * spacing,
        longitude: invalid ? 181 : -46.0 + (index % 250) * spacing,
        description: 'Synthetic plant $index',
        zoneId: 'zone-${index % zoneCount}',
        nonExistent: nonExistent,
        eligible: !nonExistent,
        openTypeIds: !nonExistent && index % 3 == 0 ? {'pest'} : {},
      );
    }, growable: false);
  }

  static const sizes = [0, 1000, 21000, 50000];
  static const zoneCount = 20;
  static final loadedAt = DateTime.utc(2026, 1, 1);
  static const types = [
    OccurrenceType(id: 'pest', name: 'Synthetic pest', code: 'pest'),
    OccurrenceType(id: 'drought', name: 'Synthetic drought', code: 'drought'),
  ];

  late final List<InspectionPlant> plants;

  List<Map<String, dynamic>> get zones => List.generate(
    zoneCount,
    (index) => {'id': 'zone-$index', 'name': 'Synthetic zone $index'},
  );

  Future<LocalInspection?> seed(InspectionLocalStore store) async {
    await store.saveCatalog(types);
    await store.replaceZoneRows(zones);
    await store.replaceSharedPlantRows(
      plants.map((plant) => plant.toJson()).toList(growable: false),
      {for (final plant in plants) plant.id: plant.openTypeIds},
      loadedAt: loadedAt,
    );
    if (plants.isEmpty) return null;
    await store.toggle(plants.first.id, 'drought');
    return store.finalize();
  }
}
