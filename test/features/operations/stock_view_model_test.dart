import 'package:flutter_test/flutter_test.dart';
import 'package:pomar_na_mao_mobile/features/operations/data/stock_photo_picker.dart';
import 'package:pomar_na_mao_mobile/features/operations/data/stock_repository.dart';
import 'package:pomar_na_mao_mobile/features/operations/domain/stock_models.dart';
import 'package:pomar_na_mao_mobile/features/operations/presentation/stock_view_model.dart';

class _FakePicker implements StockPhotoPicker {
  @override
  Future<StockPhoto?> pick(StockPhotoSource source) async => null;
}

class _FakeRepository implements StockRepository {
  final items = <StockItem>[_item('1', 'Fungicida cobre', 'FUNGICIDE')];
  bool fail = false;

  @override
  Future<StockItem> create(StockDraft draft, {StockPhoto? photo}) async {
    if (fail) throw Exception('failed');
    final item = _item('2', draft.name, draft.type, quantity: draft.quantity);
    items.add(item);
    return item;
  }

  @override
  Future<String?> createSignedPhotoUrl(String? objectPath) async => null;

  @override
  Future<void> delete(StockItem item) async {
    if (fail) throw Exception('failed');
    items.removeWhere((candidate) => candidate.id == item.id);
  }

  @override
  Future<List<StockItem>> fetchAll() async {
    if (fail) throw Exception('failed');
    return List.of(items);
  }

  @override
  Future<List<String>> fetchTypes() async => defaultStockTypes;

  @override
  Future<StockItem> update(
    StockItem current,
    StockDraft draft, {
    StockPhoto? photo,
  }) async => _item(current.id, draft.name, draft.type);
}

StockItem _item(String id, String name, String type, {double? quantity}) =>
    StockItem(
      id: id,
      name: name,
      type: type,
      registeredForCrop: true,
      quantity: quantity,
      createdAt: DateTime.utc(2026),
      updatedAt: DateTime.utc(2026),
    );

void main() {
  late _FakeRepository repository;
  late StockViewModel viewModel;

  setUp(() {
    repository = _FakeRepository();
    viewModel = StockViewModel(
      repository: repository,
      photoPicker: _FakePicker(),
    );
  });

  tearDown(() => viewModel.dispose());

  test('loads and filters stock items', () async {
    await viewModel.load();
    expect(viewModel.items, hasLength(1));

    viewModel.search('cobre');
    expect(viewModel.filteredItems.single.name, 'Fungicida cobre');
    viewModel.search('inseticida');
    expect(viewModel.filteredItems, isEmpty);
  });

  test('creates and deletes items while keeping observable state', () async {
    await viewModel.load();
    const draft = StockDraft(
      name: 'Adjuvante',
      type: 'ADJUVANT',
      registeredForCrop: true,
      quantity: 2,
      unit: 'L',
    );

    expect(await viewModel.save(draft: draft), isTrue);
    expect(viewModel.items.first.name, 'Adjuvante');
    expect(await viewModel.delete(viewModel.items.first), isTrue);
    expect(viewModel.items, hasLength(1));
  });

  test('surfaces repository failures without dropping loaded data', () async {
    await viewModel.load();
    repository.fail = true;

    await viewModel.load();

    expect(viewModel.error, 'Não foi possível carregar o estoque.');
    expect(viewModel.items, hasLength(1));
  });
}
