import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pomar_na_mao_mobile/features/auth/domain/authentication_repository.dart';
import 'package:pomar_na_mao_mobile/features/auth/presentation/authentication_view_model.dart';
import 'package:pomar_na_mao_mobile/features/operations/presentation/inspection_view.dart';
import 'package:pomar_na_mao_mobile/features/operations/data/activity_repository.dart';
import 'package:pomar_na_mao_mobile/features/operations/domain/activity_models.dart';
import 'package:pomar_na_mao_mobile/features/operations/presentation/activity_view.dart';
import 'package:pomar_na_mao_mobile/features/operations/presentation/activity_view_model.dart';
import 'package:pomar_na_mao_mobile/features/operations/data/mipd_photo_service.dart';
import 'package:pomar_na_mao_mobile/features/operations/data/mipd_repository.dart';
import 'package:pomar_na_mao_mobile/features/operations/domain/inspection_models.dart';
import 'package:pomar_na_mao_mobile/features/operations/domain/mipd_models.dart';
import 'package:pomar_na_mao_mobile/features/operations/presentation/mipd_view.dart';
import 'package:pomar_na_mao_mobile/features/operations/presentation/mipd_view_model.dart';
import 'package:pomar_na_mao_mobile/features/farm/domain/user_location.dart';
import 'package:pomar_na_mao_mobile/features/operations/presentation/operations_view.dart';
import 'package:pomar_na_mao_mobile/features/operations/presentation/spraying_view.dart';
import 'package:pomar_na_mao_mobile/features/operations/data/stock_photo_picker.dart';
import 'package:pomar_na_mao_mobile/features/operations/data/stock_repository.dart';
import 'package:pomar_na_mao_mobile/features/operations/domain/stock_models.dart';
import 'package:pomar_na_mao_mobile/features/operations/presentation/stock_view.dart';
import 'package:pomar_na_mao_mobile/features/operations/presentation/stock_view_model.dart';

Widget buildSubject({
  InspectionMapBuilder? inspectionMapBuilder,
  SprayingMapBuilder? sprayingMapBuilder,
  MipdViewModel? mipdViewModel,
  ActivityViewModel? activityViewModel,
  StockViewModel? stockViewModel,
  AuthenticationViewModel? authenticationViewModel,
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
          activityViewModel: activityViewModel,
          stockViewModel: stockViewModel,
          authenticationViewModel: authenticationViewModel,
          activityMapBuilder: (_, _) =>
              const SizedBox(key: ValueKey('test-activity-map')),
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

class _EmptyActivityRepository implements ActivityRepository {
  @override
  String createLocalId() => 'local';

  @override
  Future<ActivitySnapshot> loadSnapshot({bool forceRemote = false}) async =>
      const ActivitySnapshot(plants: [], inputs: []);

  @override
  Future<List<ActivityEntry>> list() async => const [];

  @override
  Future<bool> deleteLocal(String localId) async => false;

  @override
  Future<ActivityEntry> save({
    required ActivityGeometry geometry,
    required String activity,
    required DateTime performedAt,
    required String responsible,
    List<ActivityInput> inputs = const [],
    MixtureCatalogItem? mixture,
    MachineCatalogItem? machine,
  }) => throw UnimplementedError();

  @override
  Future<bool> syncAll() async => true;

  @override
  Future<bool> syncOne(String localId) async => true;
}

class _EmptyStockRepository implements StockRepository {
  @override
  Future<StockItem> create(StockDraft draft, {StockPhoto? photo}) =>
      throw UnimplementedError();
  @override
  Future<String?> createSignedPhotoUrl(String? objectPath) async => null;
  @override
  Future<void> delete(StockItem item) async {}
  @override
  Future<List<StockItem>> fetchAll() async => const [];
  @override
  Future<List<String>> fetchTypes() async => defaultStockTypes;
  @override
  Future<StockItem> update(
    StockItem current,
    StockDraft draft, {
    StockPhoto? photo,
  }) => throw UnimplementedError();
}

class _NoStockPhotoPicker implements StockPhotoPicker {
  @override
  Future<StockPhoto?> pick(StockPhotoSource source) async => null;
}

class _FakeAuthenticationRepository implements AuthenticationRepository {
  _FakeAuthenticationRepository({this.authenticated = false});

  bool authenticated;
  String? receivedEmail;
  String? receivedPassword;

  @override
  bool get isAuthenticated => authenticated;

  @override
  Future<void> signIn({required String email, required String password}) async {
    receivedEmail = email;
    receivedPassword = password;
    if (email != 'operador@pomar.com' || password != 'segredo') {
      throw const AuthenticationFailure('E-mail ou senha inválidos.');
    }
    authenticated = true;
  }
}

Future<void> setSurfaceSize(WidgetTester tester, Size size) async {
  await tester.binding.setSurfaceSize(size);
  addTearDown(() => tester.binding.setSurfaceSize(null));
}

void main() {
  testWidgets('groups operations in horizontal module carousels', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();
    await setSurfaceSize(tester, const Size(768, 1024));
    await tester.pumpWidget(buildSubject());
    await tester.pumpAndSettle();

    expect(find.text('Trabalho no pomar'), findsOneWidget);
    expect(find.text('Rotina do pomar'), findsOneWidget);
    expect(
      find.text('Registros e controles para o trabalho diário no campo.'),
      findsOneWidget,
    );
    expect(find.text('Gestão da produção'), findsOneWidget);
    expect(
      find.text(
        'Acompanhe aplicações, recursos, colheita e planejamento técnico.',
      ),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('operations-module-orchard-routine-list')),
      findsOneWidget,
    );
    expect(
      find.byKey(
        const ValueKey('operations-module-production-management-list'),
      ),
      findsOneWidget,
    );
    expect(find.text('Inspeção'), findsOneWidget);
    expect(find.text('MIPD'), findsOneWidget);
    expect(find.text('Pulverização'), findsOneWidget);
    expect(find.text('Irrigação'), findsOneWidget);

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

    await tester.drag(
      find.byKey(const ValueKey('operations-module-orchard-routine-list')),
      const Offset(-1200, 0),
    );
    await tester.drag(
      find.byKey(
        const ValueKey('operations-module-production-management-list'),
      ),
      const Offset(-1200, 0),
    );
    await tester.pumpAndSettle();
    expect(find.text('Estoque'), findsOneWidget);
    expect(find.text('Coletas agronômicas'), findsOneWidget);
    expect(find.text('Planejamento de atividades'), findsOneWidget);

    final stockOpacity = tester.widget<AnimatedOpacity>(
      find.descendant(
        of: find.byKey(const ValueKey('operation-card-stock')),
        matching: find.byType(AnimatedOpacity),
      ),
    );
    expect(stockOpacity.opacity, 1);
    semantics.dispose();
  });

  testWidgets('new future operations are disabled and do not navigate', (
    tester,
  ) async {
    await setSurfaceSize(tester, const Size(768, 1024));
    await tester.pumpWidget(buildSubject());
    await tester.pumpAndSettle();

    await tester.drag(
      find.byKey(const ValueKey('operations-module-orchard-routine-list')),
      const Offset(-1200, 0),
    );
    await tester.drag(
      find.byKey(
        const ValueKey('operations-module-production-management-list'),
      ),
      const Offset(-1200, 0),
    );
    await tester.pumpAndSettle();

    for (final id in ['agronomic-sampling', 'activity-planning']) {
      final card = find.byKey(ValueKey('operation-card-$id'));
      expect(card, findsOneWidget);
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

    await tester.drag(
      find.byKey(const ValueKey('operations-scroll-view')),
      const Offset(0, -320),
    );
    await tester.pumpAndSettle();

    expect(
      find.byKey(const ValueKey('operations-module-production-management')),
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
    await tester.drag(
      find.byKey(const ValueKey('operations-module-orchard-routine-list')),
      const Offset(-300, 0),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('operation-card-mipd')));
    await tester.pumpAndSettle();
    expect(find.byType(MipdView), findsOneWidget);
    expect(find.byKey(const ValueKey('mipd-load-plants')), findsOneWidget);
    await tester.pageBack();
    await tester.pumpAndSettle();
    expect(find.byType(OperationsView), findsOneWidget);
  });

  testWidgets('activity follows MIPD in its module and opens its map', (
    tester,
  ) async {
    final viewModel = ActivityViewModel(
      repository: _EmptyActivityRepository(),
      locationService: _NoLocationService(),
    );
    addTearDown(viewModel.dispose);
    await setSurfaceSize(tester, const Size(420, 900));
    await tester.pumpWidget(buildSubject(activityViewModel: viewModel));
    await tester.pumpAndSettle();

    await tester.drag(
      find.byKey(const ValueKey('operations-module-orchard-routine-list')),
      const Offset(-650, 0),
    );
    await tester.pumpAndSettle();
    final notebook = find.byKey(const ValueKey('operation-card-activity'));
    expect(notebook, findsOneWidget);

    await tester.tap(notebook);
    await tester.pumpAndSettle();
    expect(find.byType(ActivityView), findsOneWidget);
    expect(find.byKey(const ValueKey('test-activity-map')), findsOneWidget);
    await tester.pageBack();
    await tester.pumpAndSettle();
    expect(find.byType(OperationsView), findsOneWidget);
  });

  testWidgets('stock card authenticates before opening the management screen', (
    tester,
  ) async {
    final viewModel = StockViewModel(
      repository: _EmptyStockRepository(),
      photoPicker: _NoStockPhotoPicker(),
    );
    addTearDown(viewModel.dispose);
    final authenticationRepository = _FakeAuthenticationRepository();
    final authenticationViewModel = AuthenticationViewModel(
      authenticationRepository,
    );
    addTearDown(authenticationViewModel.dispose);
    await setSurfaceSize(tester, const Size(420, 900));
    await tester.pumpWidget(
      buildSubject(
        stockViewModel: viewModel,
        authenticationViewModel: authenticationViewModel,
      ),
    );
    await tester.pumpAndSettle();
    await tester.drag(
      find.byKey(const ValueKey('operations-module-orchard-routine-list')),
      const Offset(-1000, 0),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('operation-card-stock')));
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('authentication-dialog')), findsOneWidget);
    expect(find.byType(StockView), findsNothing);
    final dialogRect = tester.getRect(
      find.byKey(const ValueKey('authentication-dialog')),
    );
    expect(dialogRect, const Rect.fromLTWH(0, 0, 420, 900));
    final dialog = tester.widget<Material>(
      find.byKey(const ValueKey('authentication-dialog')),
    );
    expect(
      dialog.borderRadius,
      const BorderRadius.vertical(top: Radius.circular(24)),
    );
    expect(
      find.byKey(const ValueKey('authentication-dialog-scroll')),
      findsOneWidget,
    );
    expect(find.text('E-mail'), findsOneWidget);
    expect(find.text('Senha'), findsOneWidget);
    for (final key in const [
      ValueKey('authentication-email'),
      ValueKey('authentication-password'),
    ]) {
      final fieldFinder = find.byKey(key);
      final decoration = tester.widget<TextField>(fieldFinder).decoration!;
      final colorScheme = Theme.of(tester.element(fieldFinder)).colorScheme;
      expect(decoration.filled, isTrue);
      expect(
        decoration.fillColor,
        colorScheme.surfaceContainerHighest.withValues(alpha: 0.35),
      );
      expect(
        decoration.contentPadding,
        const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      );
      expect(
        (decoration.border! as OutlineInputBorder).borderRadius,
        BorderRadius.circular(14),
      );
      expect(
        (decoration.focusedBorder! as OutlineInputBorder).borderSide,
        BorderSide(color: colorScheme.primary, width: 2),
      );
    }
    await tester.enterText(
      find.byKey(const ValueKey('authentication-email')),
      'operador@pomar.com',
    );
    await tester.enterText(
      find.byKey(const ValueKey('authentication-password')),
      'segredo',
    );
    await tester.tap(find.byKey(const ValueKey('authentication-submit')));
    await tester.pumpAndSettle();

    expect(find.byType(StockView), findsOneWidget);
    expect(find.byKey(const ValueKey('add-stock-item')), findsOneWidget);
    expect(authenticationRepository.receivedEmail, 'operador@pomar.com');
    expect(authenticationRepository.receivedPassword, 'segredo');
  });

  testWidgets('stock card reuses an existing authenticated session', (
    tester,
  ) async {
    final stockViewModel = StockViewModel(
      repository: _EmptyStockRepository(),
      photoPicker: _NoStockPhotoPicker(),
    );
    final authenticationViewModel = AuthenticationViewModel(
      _FakeAuthenticationRepository(authenticated: true),
    );
    addTearDown(stockViewModel.dispose);
    addTearDown(authenticationViewModel.dispose);
    await setSurfaceSize(tester, const Size(420, 900));
    await tester.pumpWidget(
      buildSubject(
        stockViewModel: stockViewModel,
        authenticationViewModel: authenticationViewModel,
      ),
    );
    await tester.pumpAndSettle();
    await tester.drag(
      find.byKey(const ValueKey('operations-module-orchard-routine-list')),
      const Offset(-1000, 0),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('operation-card-stock')));
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('authentication-dialog')), findsNothing);
    expect(find.byType(StockView), findsOneWidget);
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
      for (final id in ['inspection', 'spraying']) {
        final card = find.byKey(ValueKey('operation-card-$id'));
        final rect = tester.getRect(card);
        expect(rect.width, greaterThanOrEqualTo(48));
        expect(rect.height, greaterThanOrEqualTo(48));
        expect(rect.left, greaterThanOrEqualTo(0));
        expect(rect.right, lessThanOrEqualTo(screenWidth));
      }

      await tester.drag(
        find.byKey(const ValueKey('operations-module-orchard-routine-list')),
        const Offset(-1600, 0),
      );
      await tester.drag(
        find.byKey(
          const ValueKey('operations-module-production-management-list'),
        ),
        const Offset(-1600, 0),
      );
      await tester.pumpAndSettle();

      for (final id in ['agronomic-sampling', 'activity-planning']) {
        final rect = tester.getRect(find.byKey(ValueKey('operation-card-$id')));
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
