import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pomar_na_mao_mobile/features/farm/domain/user_location.dart';
import 'package:pomar_na_mao_mobile/features/operations/data/mipd_photo_service.dart';
import 'package:pomar_na_mao_mobile/features/operations/data/mipd_repository.dart';
import 'package:pomar_na_mao_mobile/features/operations/domain/inspection_models.dart';
import 'package:pomar_na_mao_mobile/features/operations/domain/mipd_models.dart';
import 'package:pomar_na_mao_mobile/features/operations/presentation/mipd_view.dart';
import 'package:pomar_na_mao_mobile/features/operations/presentation/mipd_view_model.dart';

void main() {
  const pest = OccurrenceType(
    id: 'pest',
    name: 'Cochonilha',
    code: 'cochonilha',
    category: OccurrenceType.pestDiseaseCategory,
  );
  final plant = InspectionPlant(
    id: 'plant',
    latitude: -21,
    longitude: -47,
    description: 'Planta 1',
  );
  late _Repository repository;
  late MipdViewModel viewModel;

  setUp(() {
    repository = _Repository(
      MipdSnapshot(plants: [plant], types: const [pest]),
    );
    viewModel = MipdViewModel(
      repository: repository,
      locationService: _LocationService(),
      photoService: MipdPhotoService(picker: _NoPhotoPicker()),
    );
  });

  tearDown(() => viewModel.dispose());

  testWidgets('shows map and both required actions at 320 px', (tester) async {
    await tester.binding.setSurfaceSize(const Size(320, 640));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      MaterialApp(
        home: MipdView(
          viewModel: viewModel,
          mapBuilder: (_, config) => Text(
            '${config.plants.length} plantas',
            key: const ValueKey('fake-mipd-map'),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('fake-mipd-map')), findsOneWidget);
    expect(find.byKey(const ValueKey('mipd-load-plants')), findsOneWidget);
    expect(find.byKey(const ValueKey('mipd-saved-markings')), findsOneWidget);
    expect(find.text('Carregar Plantas'), findsNothing);
    expect(find.text('Marcações salvas'), findsNothing);
    expect(find.byTooltip('Carregar plantas'), findsOneWidget);
    expect(find.byTooltip('Marcações salvas'), findsOneWidget);
    expect(find.byIcon(Icons.cloud_download_outlined), findsOneWidget);
    expect(find.byIcon(Icons.folder_outlined), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('shows signal stabilization overlay before GPS is ready', (
    tester,
  ) async {
    final locationService = _ControlledLocationService();
    final localViewModel = MipdViewModel(
      repository: repository,
      locationService: locationService,
      photoService: MipdPhotoService(picker: _NoPhotoPicker()),
    );
    addTearDown(() {
      localViewModel.dispose();
      locationService.dispose();
    });

    await tester.pumpWidget(
      MaterialApp(
        home: MipdView(
          viewModel: localViewModel,
          mapBuilder: (_, _) => const SizedBox.expand(),
        ),
      ),
    );
    await tester.pump();

    expect(find.text('Aguardando sinal estabilizar'), findsOneWidget);
    expect(find.text('Cancelar'), findsOneWidget);
  });

  testWidgets(
    'modal requires pest type and supports multiple plant parts without photo',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(320, 700));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.pumpWidget(
        MaterialApp(
          home: MipdView(
            viewModel: viewModel,
            mapBuilder: (context, config) => FilledButton(
              onPressed: () => config.onSelectPlant(config.plants.single),
              child: const Text('Planta'),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Planta'));
      await tester.pumpAndSettle();
      expect(find.byTooltip('Fechar'), findsOneWidget);
      expect(find.byKey(const ValueKey('mipd-plant-form')), findsOneWidget);
      expect(
        tester
            .widget<FilledButton>(find.byKey(const ValueKey('mipd-save')))
            .onPressed,
        isNull,
      );
      expect(tester.takeException(), isNull);
      await tester.tap(find.byKey(const ValueKey('mipd-occurrence-selector')));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(find.text('Cochonilha'), findsOneWidget);
      await tester.tap(find.text('Cochonilha').last);
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      await tester.ensureVisible(find.text('Folha'));
      await tester.tap(find.text('Folha'));
      await tester.ensureVisible(find.text('Fruto'));
      await tester.tap(find.text('Fruto'));
      await tester.pump();
      await tester.tap(find.byKey(const ValueKey('mipd-save')));
      await tester.pumpAndSettle();
      expect(repository.saved.single.plantParts, {
        MipdPlantPart.leaf,
        MipdPlantPart.fruit,
      });
      expect(repository.saved.single.localPhotoPath, isNull);
    },
  );

  testWidgets(
    'saved markings matches inspection modal and keeps sync footer visible',
    (tester) async {
      repository.saved.add(
        MipdMarking(
          localId: 'pending-1',
          plantId: plant.id,
          occurrenceTypeId: pest.id,
          plantParts: const [MipdPlantPart.leaf],
          observedAt: DateTime.utc(2026, 10, 21, 12),
        ),
      );
      await tester.pumpWidget(
        MaterialApp(
          home: MipdView(
            viewModel: viewModel,
            mapBuilder: (_, _) => const SizedBox.expand(),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('mipd-saved-markings')));
      await tester.pumpAndSettle();

      expect(find.text('Marcações Salvas'), findsOneWidget);
      expect(find.byTooltip('Fechar'), findsOneWidget);
      expect(
        find.byKey(const ValueKey('mipd-saved-markings-list')),
        findsOneWidget,
      );
      expect(find.text('Planta 1'), findsOneWidget);
      expect(find.textContaining('Cochonilha'), findsOneWidget);
      expect(find.text('Pendente'), findsOneWidget);
      final syncButton = tester.widget<FilledButton>(
        find.byKey(const ValueKey('mipd-sync-all-pending-button')),
      );
      expect(syncButton.onPressed, isNotNull);
      expect(find.text('Sincronizar Pendentes'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('saved markings keeps disabled sync footer when empty', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: MipdView(
          viewModel: viewModel,
          mapBuilder: (_, _) => const SizedBox.expand(),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('mipd-saved-markings')));
    await tester.pumpAndSettle();

    expect(find.text('Nenhuma marcação foi salva.'), findsOneWidget);
    final syncButton = tester.widget<FilledButton>(
      find.byKey(const ValueKey('mipd-sync-all-pending-button')),
    );
    expect(syncButton.onPressed, isNull);
    expect(find.text('Sincronizar Pendentes'), findsOneWidget);
  });
}

class _Repository implements MipdRepository {
  _Repository(this.snapshot);
  final MipdSnapshot snapshot;
  final saved = <MipdMarking>[];
  @override
  String createLocalId() => 'local-1';
  @override
  Future<MipdSnapshot?> loadSnapshot({bool forceRemote = false}) async =>
      snapshot;
  @override
  Future<List<MipdMarking>> list() async => saved;
  @override
  Future<MipdMarking> save({
    required String localId,
    required String plantId,
    required OccurrenceType occurrenceType,
    required Iterable<MipdPlantPart> plantParts,
    String? localPhotoPath,
  }) async {
    final marking = MipdMarking(
      localId: localId,
      plantId: plantId,
      occurrenceTypeId: occurrenceType.id,
      plantParts: plantParts,
      observedAt: DateTime.utc(2026),
      localPhotoPath: localPhotoPath,
    );
    saved.add(marking);
    return marking;
  }

  @override
  Future<bool> syncAll() async => true;
  @override
  Future<bool> syncOne(String localId) async => true;
}

class _LocationService implements LocationService {
  @override
  Future<LocationResult> getCurrentLocation() async =>
      const LocationResult.permissionDenied();
  @override
  Stream<LocationResult> watchLocation() =>
      Stream.value(const LocationResult.permissionDenied());
}

class _ControlledLocationService implements LocationService {
  final _controller = StreamController<LocationResult>.broadcast();

  @override
  Future<LocationResult> getCurrentLocation() async =>
      const LocationResult.serviceDisabled();

  @override
  Stream<LocationResult> watchLocation() => _controller.stream;

  void dispose() => _controller.close();
}

class _NoPhotoPicker implements MipdPhotoPicker {
  @override
  Future<String?> capture() async => null;
}
