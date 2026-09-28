import 'package:flutter_test/flutter_test.dart';
import 'package:pomar_na_mao_mobile/features/farm/presentation/plant_spatial_index.dart';

import '../../support/orchard_fixture.dart';

void main() {
  test('disposing during startup settles pending requests', () async {
    final index = PlantSpatialIndex();
    final pending = index.load([const SpatialPlant('one', 0, 0)]);
    final expectation = expectLater(pending, throwsStateError);
    index.dispose();
    await expectation.timeout(const Duration(seconds: 3));
    await expectLater(index.query(), throwsStateError);
  });

  test('viewport projection follows the requested location', () async {
    final index = PlantSpatialIndex();
    addTearDown(index.dispose);
    await index.load([
      const SpatialPlant('west', 0, -100),
      const SpatialPlant('east', 0, 100),
    ]);
    final west = await index.query(
      west: -101,
      east: -99,
      south: -1,
      north: 1,
      zoom: 15,
    );
    final east = await index.query(
      west: 99,
      east: 101,
      south: -1,
      north: 1,
      zoom: 15,
    );
    expect(west.single.plantId, 'west');
    expect(east.single.plantId, 'east');
  });
  for (final size in [21000, 50000]) {
    test(
      'worker preserves $size plants within bounded world projection',
      () async {
        final fixture = OrchardFixture(size);
        final index = PlantSpatialIndex();
        addTearDown(index.dispose);
        final watch = Stopwatch()..start();
        await index.load(
          fixture.plants
              .where((p) => p.hasValidCoordinates)
              .map((p) => SpatialPlant(p.id, p.latitude!, p.longitude!))
              .toList(),
        );
        for (final zoom in [0, 10, 20]) {
          final nodes = await index.query(zoom: zoom);
          expect(nodes.length, lessThanOrEqualTo(1000));
          expect(
            nodes.fold(0, (sum, node) => sum + node.count),
            size - size ~/ 101,
          );
        }
        // Host timing is a regression aid, not an Android performance claim.
        // ignore: avoid_print
        print('Spatial worker $size: ${watch.elapsedMilliseconds} ms');
      },
    );
  }
  test('coincident cluster exposes every member in bounded pages', () async {
    final index = PlantSpatialIndex();
    addTearDown(index.dispose);
    await index.load(List.generate(2100, (i) => SpatialPlant('$i', -23, -46)));
    final cluster = (await index.query(zoom: 20)).single;
    expect(cluster.count, 2100);
    final members = <String>{};
    for (var offset = 0; offset < 2100; offset += 50) {
      final page = await index.members(cluster.clusterId!, offset: offset);
      expect(page.length, lessThanOrEqualTo(50));
      members.addAll(page);
    }
    expect(members, hasLength(2100));
  });
  test(
    'small dense clusters split into individual plants at maximum zoom',
    () async {
      final index = PlantSpatialIndex();
      addTearDown(index.dispose);
      await index.load([
        const SpatialPlant('one', -23, -46),
        const SpatialPlant('two', -23.000001, -46.000001),
        const SpatialPlant('three', -23.000002, -46.000002),
      ]);

      final nodes = await index.query(
        west: -46.001,
        east: -45.999,
        south: -23.001,
        north: -22.999,
        zoom: 20,
      );

      expect(
        nodes.map((node) => node.plantId),
        containsAll(['one', 'two', 'three']),
      );
      expect(nodes.every((node) => node.count == 1), isTrue);
      expect(nodes.every((node) => node.clusterId == null), isTrue);
    },
  );
  test(
    'coincident small clusters receive separate marker positions at max zoom',
    () async {
      final index = PlantSpatialIndex();
      addTearDown(index.dispose);
      await index.load([
        const SpatialPlant('one', -23, -46),
        const SpatialPlant('two', -23, -46),
        const SpatialPlant('three', -23, -46),
      ]);

      final nodes = await index.query(
        west: -46.001,
        east: -45.999,
        south: -23.001,
        north: -22.999,
        zoom: 20,
      );

      expect(nodes, hasLength(3));
      expect(
        nodes.map((node) => node.plantId),
        containsAll(['one', 'two', 'three']),
      );
      expect(
        nodes.map((node) => '${node.latitude},${node.longitude}').toSet(),
        hasLength(3),
      );
    },
  );
  test('replacement reflects changed coordinates with same count', () async {
    final index = PlantSpatialIndex();
    addTearDown(index.dispose);
    await index.load([const SpatialPlant('one', 0, 0)]);
    expect((await index.query()).single.latitude, 0);
    await index.load([
      const SpatialPlant('one', 10, 10),
      const SpatialPlant('invalid', 100, 0),
    ]);
    expect((await index.query()).single.latitude, 10);
  });
}
