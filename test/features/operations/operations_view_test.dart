import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pomar_na_mao_mobile/features/operations/presentation/inspection_view.dart';
import 'package:pomar_na_mao_mobile/features/operations/presentation/operations_view.dart';

Widget buildSubject({
  InspectionMapBuilder? inspectionMapBuilder,
  TextScaler textScaler = TextScaler.noScaling,
}) {
  return MaterialApp(
    theme: ThemeData(
      colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF3C6E47)),
      useMaterial3: true,
    ),
    home: Builder(
      builder: (context) => MediaQuery(
        data: MediaQuery.of(context).copyWith(textScaler: textScaler),
        child: OperationsView(
          inspectionMapBuilder:
              inspectionMapBuilder ??
              (_, _) => const SizedBox(key: ValueKey('test-inspection-map')),
        ),
      ),
    ),
  );
}

Future<void> setSurfaceSize(WidgetTester tester, Size size) async {
  await tester.binding.setSurfaceSize(size);
  addTearDown(() => tester.binding.setSurfaceSize(null));
}

void main() {
  testWidgets('shows operation hierarchy and availability', (tester) async {
    final semantics = tester.ensureSemantics();
    await setSurfaceSize(tester, const Size(768, 1024));
    await tester.pumpWidget(buildSubject());
    await tester.pumpAndSettle();

    expect(find.text('Rotinas de campo'), findsOneWidget);
    expect(find.text('1 disponível'), findsOneWidget);
    expect(find.text('4 em breve'), findsOneWidget);
    expect(
      find.byKey(const ValueKey('primary-operation-section')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('future-operations-grid')),
      findsOneWidget,
    );

    for (final title in [
      'Inspeção',
      'Pulverização',
      'Irrigação',
      'Colheita',
      'Análise de Solo',
    ]) {
      expect(find.text(title), findsOneWidget);
    }
    expect(find.text('Disponível agora'), findsOneWidget);
    expect(find.text('Em breve'), findsNWidgets(4));

    final primaryTop = tester.getTopLeft(
      find.byKey(const ValueKey('operation-card-inspection')),
    );
    final futureTop = tester.getTopLeft(
      find.byKey(const ValueKey('operation-card-spraying')),
    );
    expect(primaryTop.dy, lessThan(futureTop.dy));

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

  testWidgets('future operations do not navigate', (tester) async {
    await setSurfaceSize(tester, const Size(768, 1024));
    await tester.pumpWidget(buildSubject());
    await tester.pumpAndSettle();

    for (final id in ['spraying', 'irrigation', 'harvest', 'soil-analysis']) {
      final card = find.byKey(ValueKey('operation-card-$id'));
      await tester.ensureVisible(card);
      await tester.tap(card);
      await tester.pumpAndSettle();
      expect(find.byType(InspectionView), findsNothing);
      expect(find.byType(OperationsView), findsOneWidget);
    }
  });

  testWidgets('primary inspection action opens and returns to operations', (
    tester,
  ) async {
    await setSurfaceSize(tester, const Size(420, 900));
    await tester.pumpWidget(buildSubject());
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('operation-card-inspection')));
    await tester.pumpAndSettle();

    expect(find.byType(InspectionView), findsOneWidget);
    expect(find.byKey(const ValueKey('action-load-plants')), findsOneWidget);
    expect(find.byKey(const ValueKey('action-occurrences')), findsOneWidget);
    expect(
      find.byKey(const ValueKey('action-saved-inspections')),
      findsOneWidget,
    );

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
    testWidgets('keeps operations layout usable at ${size.width}px', (
      tester,
    ) async {
      await setSurfaceSize(tester, size);
      await tester.pumpWidget(buildSubject());
      await tester.pumpAndSettle();

      final screenWidth = size.width;
      for (final id in [
        'inspection',
        'spraying',
        'irrigation',
        'harvest',
        'soil-analysis',
      ]) {
        final card = find.byKey(ValueKey('operation-card-$id'));
        await tester.scrollUntilVisible(
          card,
          120,
          scrollable: find.byType(Scrollable),
        );
        await tester.pumpAndSettle();
        final rect = tester.getRect(card);
        expect(rect.width, greaterThanOrEqualTo(48));
        expect(rect.height, greaterThanOrEqualTo(48));
        expect(rect.left, greaterThanOrEqualTo(0));
        expect(rect.right, lessThanOrEqualTo(screenWidth));
      }
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('primary operation does not overflow with larger text', (
    tester,
  ) async {
    await setSurfaceSize(tester, const Size(360, 800));
    await tester.pumpWidget(
      buildSubject(textScaler: const TextScaler.linear(1.18)),
    );
    await tester.pumpAndSettle();

    final primary = find.byKey(const ValueKey('operation-card-inspection'));
    expect(primary, findsOneWidget);
    final rect = tester.getRect(primary);
    expect(rect.height, greaterThanOrEqualTo(48));
    expect(tester.takeException(), isNull);
  });
}
