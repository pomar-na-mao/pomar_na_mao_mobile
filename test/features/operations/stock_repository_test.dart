import 'package:flutter_test/flutter_test.dart';
import 'package:pomar_na_mao_mobile/features/operations/data/stock_remote_data_source.dart';
import 'package:pomar_na_mao_mobile/features/operations/data/stock_repository.dart';
import 'package:pomar_na_mao_mobile/features/operations/domain/stock_models.dart';

class _FakeRemote implements StockRemoteDataSource {
  final deletedIds = <String>[];
  final deletedPhotos = <String>[];
  bool failUpdate = false;

  @override
  Future<StockItem> create(StockDraft draft) async => _item('created');
  @override
  Future<String?> createSignedPhotoUrl(String? objectPath) async => null;
  @override
  Future<void> delete(String id) async => deletedIds.add(id);
  @override
  Future<void> deletePhoto(String? objectPath) async {
    if (objectPath != null) deletedPhotos.add(objectPath);
  }

  @override
  Future<List<StockItem>> fetchAll() async => const [];
  @override
  Future<List<String>> fetchTypes() async => defaultStockTypes;
  @override
  Future<String> uploadPhoto(String stockId, StockPhoto photo) async =>
      '$stockId/new.jpg';
  @override
  Future<StockItem> update(String id, StockDraft draft) async {
    if (failUpdate) throw Exception('update failed');
    return _item(id, photo: draft.photoObjectPath);
  }
}

StockItem _item(String id, {String? photo}) => StockItem(
  id: id,
  name: 'Produto',
  type: 'FUNGICIDE',
  registeredForCrop: true,
  photoObjectPath: photo,
  createdAt: DateTime.utc(2026),
  updatedAt: DateTime.utc(2026),
);

const _draft = StockDraft(
  name: 'Produto',
  type: 'FUNGICIDE',
  registeredForCrop: true,
  quantity: 1,
  unit: 'Kg',
);
const _photo = StockPhoto(path: 'photo.jpg', contentType: 'image/jpeg');

void main() {
  test('replaces the old photo only after a successful update', () async {
    final remote = _FakeRemote();
    final repository = DefaultStockRepository(remote);

    final updated = await repository.update(
      _item('stock-1', photo: 'stock-1/old.jpg'),
      _draft,
      photo: _photo,
    );

    expect(updated.photoObjectPath, 'stock-1/new.jpg');
    expect(remote.deletedPhotos, ['stock-1/old.jpg']);
  });

  test('removes uploaded photo and row when create completion fails', () async {
    final remote = _FakeRemote()..failUpdate = true;
    final repository = DefaultStockRepository(remote);

    await expectLater(
      repository.create(_draft, photo: _photo),
      throwsException,
    );

    expect(remote.deletedPhotos, ['created/new.jpg']);
    expect(remote.deletedIds, ['created']);
  });
}
