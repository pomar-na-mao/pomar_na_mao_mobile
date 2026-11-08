import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pomar_na_mao_mobile/features/operations/data/stock_photo_picker.dart';
import 'package:pomar_na_mao_mobile/features/operations/data/stock_repository.dart';
import 'package:pomar_na_mao_mobile/features/operations/domain/stock_models.dart';
import 'package:pomar_na_mao_mobile/features/operations/presentation/stock_type_presentation.dart';
import 'package:pomar_na_mao_mobile/features/operations/presentation/stock_view.dart';
import 'package:pomar_na_mao_mobile/features/operations/presentation/stock_view_model.dart';

class _NoPhotoPicker implements StockPhotoPicker {
  @override
  Future<StockPhoto?> pick(StockPhotoSource source) async => null;
}

class _MemoryStockRepository implements StockRepository {
  int signedUrlRequests = 0;

  final items = <StockItem>[
    StockItem(
      id: 'stock-1',
      name: 'Calda bordalesa',
      type: 'FUNGICIDE',
      activeIngredient: 'Cobre',
      registeredForCrop: true,
      quantity: 12.5,
      unit: 'Kg',
      photoObjectPath: 'stock-1/current.jpg',
      createdAt: DateTime.utc(2026),
      updatedAt: DateTime.utc(2026),
    ),
    StockItem(
      id: 'stock-2',
      name: 'Bacillus subtilis',
      type: 'BIOLOGICAL',
      registeredForCrop: true,
      quantity: 4,
      unit: 'L',
      createdAt: DateTime.utc(2026),
      updatedAt: DateTime.utc(2026),
    ),
  ];

  @override
  Future<StockItem> create(StockDraft draft, {StockPhoto? photo}) async =>
      throw UnimplementedError();
  @override
  Future<String?> createSignedPhotoUrl(String? objectPath) async {
    signedUrlRequests += 1;
    return 'https://example.test/current.jpg';
  }

  @override
  Future<void> delete(StockItem item) async => items.remove(item);
  @override
  Future<List<StockItem>> fetchAll() async => List.of(items);
  @override
  Future<List<String>> fetchTypes() async => defaultStockTypes;
  @override
  Future<StockItem> update(
    StockItem current,
    StockDraft draft, {
    StockPhoto? photo,
  }) async => current;
}

void main() {
  test('groups stock items by type and assigns a unique enum color', () {
    final repository = _MemoryStockRepository();
    final groups = groupStockItemsByType(repository.items);

    expect(groups.map((group) => group.type), ['BIOLOGICAL', 'FUNGICIDE']);
    expect(groups.first.items.single.name, 'Bacillus subtilis');
    expect(
      defaultStockTypes.map(stockTypeColor).toSet(),
      hasLength(defaultStockTypes.length),
    );
  });

  testWidgets('renders, searches and opens the responsive stock form', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(320, 800));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final repository = _MemoryStockRepository();
    final viewModel = StockViewModel(
      repository: repository,
      photoPicker: _NoPhotoPicker(),
    );
    addTearDown(viewModel.dispose);
    await tester.pumpWidget(MaterialApp(home: StockView(viewModel: viewModel)));
    await tester.pumpAndSettle();

    expect(find.text('Calda bordalesa'), findsOneWidget);
    expect(find.text('12.50 Kg'), findsNothing);
    expect(
      find.byKey(const ValueKey('stock-type-group-BIOLOGICAL')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('stock-type-group-FUNGICIDE')),
      findsOneWidget,
    );
    final editRect = tester.getRect(
      find.byKey(const ValueKey('edit-stock-stock-2')),
    );
    final deleteRect = tester.getRect(
      find.byKey(const ValueKey('delete-stock-stock-2')),
    );
    final itemNameRect = tester.getRect(find.text('Bacillus subtilis'));
    expect(editRect.left, lessThan(deleteRect.left));
    expect(editRect.top, closeTo(deleteRect.top, 0.1));
    expect(editRect.top, greaterThan(itemNameRect.bottom));
    expect(tester.takeException(), isNull);

    await tester.enterText(find.byKey(const ValueKey('stock-search')), 'nada');
    await tester.pump();
    expect(find.text('Nenhum item encontrado'), findsOneWidget);

    await tester.enterText(find.byKey(const ValueKey('stock-search')), 'cobre');
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('edit-stock-stock-1')));
    await tester.pumpAndSettle();

    expect(find.text('Editar item'), findsOneWidget);
    expect(find.byKey(const ValueKey('save-stock-item')), findsOneWidget);
    final sheetRect = tester.getRect(
      find.byKey(const ValueKey('stock-form-sheet')),
    );
    expect(sheetRect.top, 0);
    expect(sheetRect.bottom, 800);
    final previewRect = tester.getRect(
      find.byKey(const ValueKey('stock-photo-preview')),
    );
    final cameraRect = tester.getRect(
      find.byKey(const ValueKey('stock-photo-camera')),
    );
    final galleryRect = tester.getRect(
      find.byKey(const ValueKey('stock-photo-gallery')),
    );
    expect(cameraRect.left, lessThan(galleryRect.left));
    expect(cameraRect.top, closeTo(galleryRect.top, 0.1));
    expect(cameraRect.center.dy, closeTo(previewRect.center.dy, 0.1));
    expect(galleryRect.center.dy, closeTo(previewRect.center.dy, 0.1));
    expect(find.text('Foto atual mantida'), findsNothing);
    expect(repository.signedUrlRequests, 1);
    expect(find.byKey(const ValueKey('stock-existing-photo')), findsOneWidget);
    final nameField = find.byKey(const ValueKey('stock-name-field'));
    final typeField = find.byKey(const ValueKey('stock-type-field'));
    expect(
      tester.getTopLeft(typeField).dy - tester.getBottomLeft(nameField).dy,
      greaterThanOrEqualTo(20),
    );
    final formScrollable = find
        .descendant(
          of: find.byKey(const ValueKey('stock-form-scroll')),
          matching: find.byType(Scrollable),
        )
        .first;
    final technicalDetails = find.text('Detalhes técnicos');
    await tester.scrollUntilVisible(
      technicalDetails,
      300,
      scrollable: formScrollable,
    );
    await tester.tap(technicalDetails);
    await tester.pumpAndSettle();
    final formulationField = find.byKey(
      const ValueKey('stock-formulation-field'),
    );
    final technicalTopSpacing = find.byKey(
      const ValueKey('stock-technical-details-top-spacing'),
    );
    expect(tester.getSize(technicalTopSpacing).height, 18);
    expect(
      tester.getBottomLeft(technicalTopSpacing).dy,
      tester.getTopLeft(formulationField).dy,
    );
    final doseUnitField = find.byKey(const ValueKey('stock-doseUnit-field'));
    await tester.scrollUntilVisible(
      doseUnitField,
      400,
      scrollable: formScrollable,
    );
    final technicalSpacing = find.byKey(
      const ValueKey('stock-technical-details-bottom-spacing'),
    );
    expect(tester.getSize(technicalSpacing).height, 18);
    expect(
      tester.getTopLeft(technicalSpacing).dy,
      tester.getBottomLeft(doseUnitField).dy,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('asks for confirmation before deleting an item', (tester) async {
    final repository = _MemoryStockRepository();
    final viewModel = StockViewModel(
      repository: repository,
      photoPicker: _NoPhotoPicker(),
    );
    addTearDown(viewModel.dispose);
    await tester.pumpWidget(MaterialApp(home: StockView(viewModel: viewModel)));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('delete-stock-stock-1')));
    await tester.pumpAndSettle();
    expect(find.text('Excluir item?'), findsOneWidget);
    await tester.tap(find.widgetWithText(FilledButton, 'Excluir'));
    await tester.pumpAndSettle();
    expect(repository.items.map((item) => item.id), isNot(contains('stock-1')));
    expect(repository.items.map((item) => item.id), contains('stock-2'));
  });

  testWidgets('requires quantity and unit in the stock form', (tester) async {
    final viewModel = StockViewModel(
      repository: _MemoryStockRepository(),
      photoPicker: _NoPhotoPicker(),
    );
    addTearDown(viewModel.dispose);
    await tester.pumpWidget(MaterialApp(home: StockView(viewModel: viewModel)));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('add-stock-item')));
    await tester.pumpAndSettle();
    final form = tester.state<FormState>(find.byType(Form));
    expect(form.validate(), isFalse);
    await tester.pump();

    final quantityState = tester.state<FormFieldState<String>>(
      find.byKey(const ValueKey('stock-quantity-field')),
    );
    final unitState = tester.state<FormFieldState<String>>(
      find.byKey(const ValueKey('stock-unit-field')),
    );
    expect(quantityState.errorText, 'Informe a quantidade.');
    expect(unitState.errorText, 'Selecione a unidade.');
  });
}
