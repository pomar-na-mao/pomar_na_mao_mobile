import 'package:flutter_test/flutter_test.dart';
import 'package:pomar_na_mao_mobile/features/farm/domain/zone.dart';
import 'package:pomar_na_mao_mobile/features/farm/presentation/farm_map_view.dart';

void main() {
  test('sorts zones alphabetically by code without changing the source', () {
    const zones = [
      Zone(id: 'zone-c', name: 'Terceira', code: 'C'),
      Zone(id: 'zone-no-code', name: 'Sem código'),
      Zone(id: 'zone-b', name: 'Segunda', code: ' b '),
      Zone(id: 'zone-a', name: 'Primeira', code: 'A'),
    ];

    final sortedZones = sortZonesByCode(zones);

    expect(sortedZones.map((zone) => zone.id), [
      'zone-a',
      'zone-b',
      'zone-c',
      'zone-no-code',
    ]);
    expect(zones.first.id, 'zone-c');
  });
}
