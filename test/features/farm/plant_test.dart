import 'package:flutter_test/flutter_test.dart';
import 'package:pomar_na_mao_mobile/features/farm/domain/plant.dart';

void main() {
  group('Plant.fromJson', () {
    test('instantiates with complete fields', () {
      final json = {
        'id': 'plant-1',
        'latitude': -21.234,
        'longitude': -47.790,
        'location': null,
        'gps_timestamp': 123456789,
        'variety_id': 1,
        'zone_id': 'zone-1',
        'mass': '10kg',
        'harvest': '2026',
        'description': 'Laranjeira',
        'planting_date': '2024-01-01',
        'life_of_the_tree': 'healthy',
        'is_dead': false,
        'is_new': false,
        'non_existent': false,
        'local_id': 'loc-1',
        'device_id': 'dev-1',
        'sync_status': 'synced',
        'synced_at': '2024-01-01T00:00:00Z',
        'created_at': '2024-01-01T00:00:00Z',
        'updated_at': '2024-01-02T00:00:00Z',
      };

      final plant = Plant.fromJson(json);

      expect(plant.id, 'plant-1');
      expect(plant.latitude, -21.234);
      expect(plant.longitude, -47.790);
      expect(plant.zoneId, 'zone-1');
      expect(plant.nonExistent, false);
      expect(plant.createdAt, DateTime.parse('2024-01-01T00:00:00Z'));
    });

    test('instantiates with selective projection fields only', () {
      final json = {
        'id': 'plant-selective',
        'latitude': -21.234,
        'longitude': -47.790,
        'zone_id': 'zone-1',
        'non_existent': true,
      };

      final plant = Plant.fromJson(json);

      expect(plant.id, 'plant-selective');
      expect(plant.latitude, -21.234);
      expect(plant.longitude, -47.790);
      expect(plant.zoneId, 'zone-1');
      expect(plant.nonExistent, true);
      expect(plant.isDead, false);
      expect(plant.isNew, false);
      expect(plant.syncStatus, 'synced');
      expect(plant.createdAt, DateTime.fromMillisecondsSinceEpoch(0));
    });
  });
}
