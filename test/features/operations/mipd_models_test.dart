import 'package:flutter_test/flutter_test.dart';
import 'package:pomar_na_mao_mobile/features/operations/domain/inspection_models.dart';
import 'package:pomar_na_mao_mobile/features/operations/domain/mipd_models.dart';

void main() {
  test('serializes a marking with canonical parts and UTC time', () {
    final marking = MipdMarking(
      localId: 'local-1',
      plantId: 'plant-1',
      occurrenceTypeId: 'pest-1',
      plantParts: const {MipdPlantPart.fruit, MipdPlantPart.leaf},
      observedAt: DateTime.parse('2026-10-21T09:00:00-03:00'),
      remotePhotoPath: 'user/device/local-1.jpg',
    );

    expect(marking.toPayload(), {
      'localMarkingId': 'local-1',
      'plantId': 'plant-1',
      'occurrenceTypeId': 'pest-1',
      'plantParts': ['FRUIT', 'LEAF'],
      'observedAt': '2026-10-21T12:00:00.000Z',
      'photoObjectPath': 'user/device/local-1.jpg',
    });
    expect(MipdMarking.fromRow(marking.toRow()).plantParts, marking.plantParts);
  });

  test('rejects an empty plant part selection', () {
    expect(
      () => MipdMarking(
        localId: 'local-1',
        plantId: 'plant-1',
        occurrenceTypeId: 'pest-1',
        plantParts: const [],
        observedAt: DateTime.now(),
      ),
      throwsArgumentError,
    );
  });

  test('validates occurrence category for MIPD', () {
    const pest = OccurrenceType(
      id: 'pest',
      name: 'Pulgão',
      code: 'aphid',
      category: OccurrenceType.pestDiseaseCategory,
    );
    const structural = OccurrenceType(
      id: 'structural',
      name: 'Quebra',
      code: 'break',
    );

    expect(() => validatePestDiseaseType(pest), returnsNormally);
    expect(() => validatePestDiseaseType(structural), throwsArgumentError);
  });

  test('parses a canonical RPC result list', () {
    final results = MipdSyncResult.listFromRpc({
      'markings': [
        {
          'localMarkingId': 'local-1',
          'operationId': 'operation-1',
          'occurrenceId': 'occurrence-1',
          'markingId': 'marking-1',
          'syncedAt': '2026-10-21T12:00:00Z',
        },
      ],
    });

    expect(results.single.localMarkingId, 'local-1');
    expect(results.single.markingId, 'marking-1');
  });
}
