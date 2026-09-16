import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pomar_na_mao_mobile/core/di/app_dependencies.dart';
import 'package:pomar_na_mao_mobile/core/di/app_scope.dart';

import 'app_dependencies_test.dart';

void main() {
  group('AppScope', () {
    testWidgets('provides AppDependencies to descendant widgets in tree', (tester) async {
      final dependencies = AppDependencies(
        farmRepository: MockFarmRepository(),
        plantsRepository: MockPlantsRepository(),
        zonesRepository: MockZonesRepository(),
        inventoryRepository: MockInventoryRepository(),
        locationService: MockLocationService(),
      );

      AppDependencies? extractedDependencies;

      await tester.pumpWidget(
        AppScope(
          dependencies: dependencies,
          child: Builder(
            builder: (context) {
              extractedDependencies = AppScope.of(context);
              return const SizedBox();
            },
          ),
        ),
      );

      expect(extractedDependencies, same(dependencies));
    });
  });
}
