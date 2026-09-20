import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pomar_na_mao_mobile/features/operations/presentation/inspection_view.dart';
import 'package:pomar_na_mao_mobile/features/operations/presentation/operations_view.dart';

Widget buildSubject({InspectionMapBuilder? inspectionMapBuilder}) {
  return MaterialApp(
    theme: ThemeData(
      colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF3C6E47)),
      useMaterial3: true,
    ),
    home: OperationsView(
      inspectionMapBuilder: inspectionMapBuilder ??
          (_, _) => const SizedBox(key: ValueKey('test-inspection-map')),
    ),
  );
}

Future<void> setSurfaceSize(WidgetTester tester, Size size) async {
  await tester.binding.setSurfaceSize(size);
  addTearDown(() => tester.binding.setSurfaceSize(null));
}

void main() {
  testWidgets('shows all operations and exposes their availability', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();
    await setSurfaceSize(tester, const Size(768, 1024));
    await tester.pumpWidget(buildSubject());
    await tester.pumpAndSettle();

    for (final title in [
      'Inspeção',
      'Pulverização',
      'Irrigação',
      'Colheita',
      'Análise de Solo',
    ]) {
      expect(find.text(title), findsOneWidget);
    }
    for (final id in [
      'inspection',
      'spraying',
      'irrigation',
      'harvest',
      'soil-analysis',
    ]) {
      final size = tester.getSize(find.byKey(ValueKey('operation-card-$id')));
      expect(size.width, greaterThanOrEqualTo(48));
      expect(size.height, greaterThanOrEqualTo(48));
    }
    expect(find.text('Em breve'), findsNWidgets(4));
    expect(
      tester.getSemantics(
        find.byKey(const ValueKey('operation-card-inspection')),
      ),
      matchesSemantics(
        label: 'Inspeção',
        hint: 'Disponível. Toque duas vezes para abrir',
        isButton: true,
        hasEnabledState: true,
        isEnabled: true,
      ),
    );
    expect(
      tester.getSemantics(
        find.byKey(const ValueKey('operation-card-spraying')),
      ),
      matchesSemantics(
        label: 'Pulverização',
        hint: 'Indisponível. Em breve',
        isButton: true,
        hasEnabledState: true,
        isEnabled: false,
      ),
    );

    semantics.dispose();
  });

  testWidgets('blocked operations do not navigate', (tester) async {
    await setSurfaceSize(tester, const Size(768, 1024));
    await tester.pumpWidget(buildSubject());
    await tester.pumpAndSettle();

    for (final id in ['spraying', 'irrigation', 'harvest', 'soil-analysis']) {
      await tester.tap(find.byKey(ValueKey('operation-card-$id')));
      await tester.pumpAndSettle();
      expect(find.byType(InspectionView), findsNothing);
      expect(find.text('Operações'), findsOneWidget);
    }
  });

  testWidgets('inspection opens and returns to operations', (tester) async {
    await setSurfaceSize(tester, const Size(420, 900));
    await tester.pumpWidget(buildSubject());
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('operation-card-inspection')));
    await tester.pumpAndSettle();

    expect(find.byType(InspectionView), findsOneWidget);
    expect(find.byKey(const ValueKey('action-load-plants')), findsOneWidget);
    expect(find.byKey(const ValueKey('action-occurrences')), findsOneWidget);
    expect(find.byKey(const ValueKey('action-saved-inspections')), findsOneWidget);

    await tester.pageBack();
    await tester.pumpAndSettle();

    expect(find.byType(OperationsView), findsOneWidget);
    expect(find.text('Operações'), findsOneWidget);
  });

  for (final size in [
    const Size(320, 800),
    const Size(768, 1024),
    const Size(1024, 1000),
  ]) {
    testWidgets('adapts the operations grid at ${size.width}px', (
      tester,
    ) async {
      await setSurfaceSize(tester, size);
      await tester.pumpWidget(buildSubject());
      await tester.pumpAndSettle();

      final first = tester.getTopLeft(
        find.byKey(const ValueKey('operation-card-inspection')),
      );
      final second = tester.getTopLeft(
        find.byKey(const ValueKey('operation-card-spraying')),
      );

      if (size.width < 600) {
        expect(second.dy, greaterThan(first.dy));
      } else {
        expect(second.dy, first.dy);
        expect(second.dx, greaterThan(first.dx));
      }
      expect(tester.takeException(), isNull);
    });
  }
}
