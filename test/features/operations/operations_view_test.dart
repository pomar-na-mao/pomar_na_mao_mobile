import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pomar_na_mao_mobile/features/operations/presentation/inspection_view.dart';
import 'package:pomar_na_mao_mobile/features/operations/data/mipd_photo_service.dart';
import 'package:pomar_na_mao_mobile/features/operations/data/mipd_repository.dart';
import 'package:pomar_na_mao_mobile/features/operations/domain/inspection_models.dart';
import 'package:pomar_na_mao_mobile/features/operations/domain/mipd_models.dart';
import 'package:pomar_na_mao_mobile/features/operations/presentation/mipd_view.dart';
import 'package:pomar_na_mao_mobile/features/operations/presentation/mipd_view_model.dart';
import 'package:pomar_na_mao_mobile/features/farm/domain/user_location.dart';
import 'package:pomar_na_mao_mobile/features/operations/presentation/operations_view.dart';
import 'package:pomar_na_mao_mobile/features/operations/presentation/spraying_view.dart';

Widget buildSubject({
  InspectionMapBuilder? inspectionMapBuilder,
  SprayingMapBuilder? sprayingMapBuilder,
  MipdViewModel? mipdViewModel,
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
          sprayingMapBuilder:
              sprayingMapBuilder ??
              (_, _) => const SizedBox(key: ValueKey('test-spraying-map')),
          mipdViewModel: mipdViewModel,
          mipdMapBuilder: (_, _) =>
              const SizedBox(key: ValueKey('test-mipd-map')),
        ),
      ),
    ),
  );
}

class _EmptyMipdRepository implements MipdRepository {
  @override
  String createLocalId() => 'local';
  @override
  Future<MipdSnapshot?> loadSnapshot({bool forceRemote = false}) async =>
      const MipdSnapshot(plants: [], types: []);
  @override
  Future<List<MipdMarking>> list() async => const [];
  @override
  Future<MipdMarking> save({
    required String localId,
    required String plantId,
    required OccurrenceType occurrenceType,
    required Iterable<MipdPlantPart> plantParts,
    String? localPhotoPath,
  }) => throw UnimplementedError();
  @override
  Future<bool> syncAll() async => true;
  @override
  Future<bool> syncOne(String localId) async => true;
}

class _NoLocationService implements LocationService {
  @override
  Future<LocationResult> getCurrentLocation() async =>
      const LocationResult.permissionDenied();
  @override
  Stream<LocationResult> watchLocation() => const Stream.empty();
}

class _NoPhotoPicker implements MipdPhotoPicker {
  @override
  Future<String?> capture() async => null;
}

Future<void> setSurfaceSize(WidgetTester tester, Size size) async {
  await tester.binding.setSurfaceSize(size);
  addTearDown(() => tester.binding.setSurfaceSize(null));
}

void main() {
  testWidgets('shows a compact unified operations grid', (tester) async {
    final semantics = tester.ensureSemantics();
    await setSurfaceSize(tester, const Size(768, 1024));
    await tester.pumpWidget(buildSubject());
    await tester.pumpAndSettle();

    expect(find.text('Trabalho no pomar'), findsOneWidget);
    expect(find.byKey(const ValueKey('operations-grid')), findsOneWidget);
    expect(find.textContaining('disponível'), findsNothing);
    expect(find.textContaining('em breve'), findsNothing);

    for (final title in [
      'Inspeção',
      'Pulverização',
      'MIPD',
      'Irrigação',
      'Colheita',
      'Análise de Solo',
    ]) {
      expect(find.text(title), findsOneWidget);
    }
    expect(find.byIcon(Icons.lock_outline_rounded), findsNWidgets(3));

    final enabledOpacity = tester.widget<AnimatedOpacity>(
      find.descendant(
        of: find.byKey(const ValueKey('operation-card-inspection')),
        matching: find.byType(AnimatedOpacity),
      ),
    );
    final disabledOpacity = tester.widget<AnimatedOpacity>(
      find.descendant(
        of: find.byKey(const ValueKey('operation-card-irrigation')),
        matching: find.byType(AnimatedOpacity),
      ),
    );
    expect(enabledOpacity.opacity, 1);
    expect(disabledOpacity.opacity, lessThan(1));

    expect(
      tester.getSemantics(
        find.byKey(const ValueKey('operation-card-inspection')),
      ),
      matchesSemantics(
        label: 'Inspeção',
        hint: 'Toque duas vezes para abrir',
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
        hint: 'Toque duas vezes para abrir',
        isButton: true,
        hasEnabledState: true,
        isEnabled: true,
      ),
    );
    expect(
      tester.getSemantics(
        find.byKey(const ValueKey('operation-card-irrigation')),
      ),
      matchesSemantics(
        label: 'Irrigação',
        hint: 'Operação indisponível',
        isButton: true,
        hasEnabledState: true,
      ),
    );
    semantics.dispose();
  });

  testWidgets('future operations do not navigate', (tester) async {
    await setSurfaceSize(tester, const Size(768, 1024));
    await tester.pumpWidget(buildSubject());
    await tester.pumpAndSettle();

    for (final id in ['irrigation', 'harvest', 'soil-analysis']) {
      final card = find.byKey(ValueKey('operation-card-$id'));
      await tester.ensureVisible(card);
      await tester.tap(card);
      await tester.pumpAndSettle();
      expect(find.byType(InspectionView), findsNothing);
      expect(find.byType(SprayingView), findsNothing);
      expect(find.byType(OperationsView), findsOneWidget);
    }
  });

  testWidgets('keeps the green header fixed while activities scroll', (
    tester,
  ) async {
    await setSurfaceSize(tester, const Size(320, 520));
    await tester.pumpWidget(buildSubject());
    await tester.pumpAndSettle();

    final header = find.byKey(const ValueKey('operations-header'));
    final initialTop = tester.getTopLeft(header).dy;

    await tester.scrollUntilVisible(
      find.byKey(const ValueKey('operation-card-harvest')),
      180,
      scrollable: find.byType(Scrollable),
    );
    await tester.pumpAndSettle();

    expect(
      find.byKey(const ValueKey('operation-card-harvest')),
      findsOneWidget,
    );
    expect(tester.getTopLeft(header).dy, initialTop);
  });

  testWidgets('spraying action opens and returns to operations', (
    tester,
  ) async {
    await setSurfaceSize(tester, const Size(420, 900));
    await tester.pumpWidget(buildSubject());
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('operation-card-spraying')));
    await tester.pumpAndSettle();

    expect(find.byType(SprayingView), findsOneWidget);
    expect(
      find.byKey(const ValueKey('action-spraying-load-plants')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('action-spraying-filter-zone')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('action-spraying-session')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('action-spraying-saved-history')),
      findsOneWidget,
    );

    await tester.pageBack();
    await tester.pumpAndSettle();

    expect(find.byType(OperationsView), findsOneWidget);
    expect(find.text('Operações'), findsOneWidget);
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

  testWidgets('MIPD action opens and returns to operations', (tester) async {
    final viewModel = MipdViewModel(
      repository: _EmptyMipdRepository(),
      locationService: _NoLocationService(),
      photoService: MipdPhotoService(picker: _NoPhotoPicker()),
    );
    addTearDown(viewModel.dispose);
    await setSurfaceSize(tester, const Size(420, 900));
    await tester.pumpWidget(buildSubject(mipdViewModel: viewModel));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('operation-card-mipd')));
    await tester.pumpAndSettle();
    expect(find.byType(MipdView), findsOneWidget);
    expect(find.byKey(const ValueKey('mipd-load-plants')), findsOneWidget);
    await tester.pageBack();
    await tester.pumpAndSettle();
    expect(find.byType(OperationsView), findsOneWidget);
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
        'mipd',
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
