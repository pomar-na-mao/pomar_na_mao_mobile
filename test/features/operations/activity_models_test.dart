import 'package:flutter_test/flutter_test.dart';
import 'package:pomar_na_mao_mobile/features/operations/domain/activity_models.dart';

void main() {
  group('ActivityGeometry', () {
    test('round-trips route GeoJSON in longitude latitude order', () {
      final geometry = ActivityGeometry(
        type: ActivityGeometryType.route,
        points: const [
          ActivityPoint(-21.1, -47.8),
          ActivityPoint(-21.2, -47.9),
        ],
      );

      expect(geometry.validate(), isNull);
      expect(
        ActivityGeometry.fromGeoJson(geometry.toGeoJson()).points,
        geometry.points,
      );
      expect(geometry.toGeoJson()['type'], 'LineString');
    });

    test('closes a valid polygon and rejects a bow-tie', () {
      final area = ActivityGeometry(
        type: ActivityGeometryType.area,
        points: const [
          ActivityPoint(-21, -47),
          ActivityPoint(-21, -47.01),
          ActivityPoint(-21.01, -47.01),
          ActivityPoint(-21.01, -47),
        ],
      );
      final coordinates = area.toGeoJson()['coordinates']! as List;
      final ring = coordinates.single as List;
      expect(area.validate(), isNull);
      expect(ring.first, ring.last);
      expect(ring, hasLength(5));

      final bowTie = ActivityGeometry(
        type: ActivityGeometryType.area,
        points: const [
          ActivityPoint(0, 0),
          ActivityPoint(1, 1),
          ActivityPoint(0, 1),
          ActivityPoint(1, 0),
        ],
      );
      expect(bowTie.validate(), contains('cruzamentos'));
    });

    test('builder samples, undoes, clears and enforces minimums', () {
      final builder = ActivityGeometryBuilder(minimumSampleDistanceMeters: 10);
      expect(builder.add(const ActivityPoint(-21, -47)), isTrue);
      expect(builder.add(const ActivityPoint(-21.000001, -47.000001)), isFalse);
      expect(builder.build().validate(), contains('dois pontos'));
      expect(builder.add(const ActivityPoint(-21.001, -47.001)), isTrue);
      expect(builder.build().validate(), isNull);
      builder.undo();
      expect(builder.points, hasLength(1));
      builder.changeType(ActivityGeometryType.area);
      expect(builder.points, isEmpty);
      expect(builder.type, ActivityGeometryType.area);
    });

    test('builder caps a drawing at two thousand vertices', () {
      final builder = ActivityGeometryBuilder(minimumSampleDistanceMeters: 0);
      for (var index = 0; index < ActivityGeometryBuilder.maxPoints; index++) {
        expect(builder.add(ActivityPoint(-21, -47 + index / 100000)), isTrue);
      }
      expect(builder.add(const ActivityPoint(-20, -46)), isFalse);
      expect(builder.points, hasLength(ActivityGeometryBuilder.maxPoints));
    });
  });

  test('catalog supports optional snapshots and textual label dose', () {
    final item = FieldInputCatalogItem.fromJson({
      'id': 'input-1',
      'name': 'Produto',
      'type': 'FUNGICIDE',
      'label_dose': '50 - 100',
      'dose_unit': 'mL/100L',
    });
    final input = ActivityInput.fromCatalog(item, localId: 'local-1');

    expect(item.activeIngredient, isNull);
    expect(input.appliedDose, '50 - 100 mL/100L');
    expect(FieldInputCatalogItem.fromJson(item.toJson()).name, 'Produto');
  });

  test('mixture parses its composition and payload sends only mixture id', () {
    final mixture = MixtureCatalogItem.fromJson({
      'id': 'mixture-1',
      'name': 'Calda cítrica',
      'is_active': true,
      'components': [
        {
          'input_id': 'input-1',
          'dose': '75',
          'dose_unit': 'mL/100L',
          'input': {
            'id': 'input-1',
            'name': 'Produto',
            'type': 'FUNGICIDE',
            'active_ingredient': 'Ingrediente',
          },
        },
      ],
    });
    final entry = ActivityEntry(
      localId: 'entry-mixture',
      geometry: ActivityGeometry(
        type: ActivityGeometryType.route,
        points: const [ActivityPoint(0, 0), ActivityPoint(0, 1)],
      ),
      activity: 'aplicação',
      performedAt: DateTime.utc(2026, 10, 30),
      responsible: 'João',
      mixtureId: mixture.id,
      mixtureNameSnapshot: mixture.name,
      inputs: [
        ActivityInput(
          localId: 'component-1',
          inputId: mixture.inputs.single.inputId,
          nameSnapshot: mixture.inputs.single.name,
          appliedDose: mixture.inputs.single.dose,
        ),
      ],
    );

    expect(mixture.inputs.single.formattedDose, '75 mL/100L');
    final payload = entry.toPayload();
    expect(payload['mixtureId'], 'mixture-1');
    expect(payload['inputs'], isEmpty);
    expect(payload, isNot(contains('mixtureName')));
    expect(payload, isNot(contains('mixtureObservations')));
  });

  test('machine catalog is immutable and payload sends only machine id', () {
    final machine = MachineCatalogItem.fromJson({
      'id': 'machine-1',
      'name': 'Trator Valtra A950',
      'brand': 'Valtra',
      'manufacturing_year': 2024,
      'quantity': 1,
    });
    final entry = ActivityEntry(
      localId: 'entry-machine',
      geometry: ActivityGeometry(
        type: ActivityGeometryType.route,
        points: const [ActivityPoint(0, 0), ActivityPoint(0, 1)],
      ),
      activity: 'roçagem',
      performedAt: DateTime.utc(2026, 10, 30),
      responsible: 'João',
      machineId: machine.id,
      machineNameSnapshot: machine.name,
      machineBrandSnapshot: machine.brand,
    );

    expect(MachineCatalogItem.fromJson(machine.toJson()).brand, 'Valtra');
    expect(entry.toPayload()['machineId'], 'machine-1');
    expect(entry.toPayload(), isNot(contains('machineName')));
    expect(entry.toPayload(), isNot(contains('machineBrand')));
  });

  test(
    'entry permits no inputs but rejects duplicate inputs and blank dose',
    () {
      final geometry = ActivityGeometry(
        type: ActivityGeometryType.route,
        points: const [ActivityPoint(0, 0), ActivityPoint(0, 1)],
      );
      final performedAt = composeActivityDateTime(
        DateTime(2026, 10, 30),
        12,
        30,
      );
      final empty = ActivityEntry(
        localId: 'entry-1',
        geometry: geometry,
        activity: '  roçagem ',
        performedAt: performedAt,
        responsible: ' João ',
      );
      expect(empty.activity, 'roçagem');
      expect(empty.responsible, 'João');
      expect(empty.inputs, isEmpty);
      expect(performedAt, DateTime(2026, 10, 30, 12, 30));

      const valid = ActivityInput(
        localId: 'a',
        inputId: 'input-1',
        nameSnapshot: 'Produto',
        appliedDose: '1 L/ha',
      );
      expect(
        () => ActivityEntry(
          localId: 'entry-2',
          geometry: geometry,
          activity: 'aplicação',
          performedAt: performedAt,
          responsible: 'João',
          inputs: const [valid, valid],
        ),
        throwsArgumentError,
      );
      expect(
        () => ActivityEntry(
          localId: 'entry-3',
          geometry: geometry,
          activity: 'aplicação',
          performedAt: performedAt,
          responsible: 'João',
          inputs: const [
            ActivityInput(
              localId: 'b',
              inputId: 'input-2',
              nameSnapshot: 'Outro',
              appliedDose: ' ',
            ),
          ],
        ),
        throwsArgumentError,
      );
    },
  );
}
