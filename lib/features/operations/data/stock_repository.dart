import '../domain/stock_models.dart';
import 'stock_remote_data_source.dart';

abstract interface class StockRepository {
  Future<List<StockItem>> fetchAll();
  Future<List<String>> fetchTypes();
  Future<StockItem> create(StockDraft draft, {StockPhoto? photo});
  Future<StockItem> update(
    StockItem current,
    StockDraft draft, {
    StockPhoto? photo,
  });
  Future<void> delete(StockItem item);
  Future<String?> createSignedPhotoUrl(String? objectPath);
}

class DefaultStockRepository implements StockRepository {
  const DefaultStockRepository(this._remote);

  final StockRemoteDataSource _remote;

  @override
  Future<List<StockItem>> fetchAll() => _remote.fetchAll();

  @override
  Future<List<String>> fetchTypes() => _remote.fetchTypes();

  @override
  Future<StockItem> create(StockDraft draft, {StockPhoto? photo}) async {
    var created = await _remote.create(draft);
    if (photo == null) return created;
    String? uploadedPath;
    try {
      uploadedPath = await _remote.uploadPhoto(created.id, photo);
      created = await _remote.update(
        created.id,
        _copyDraft(draft, photoObjectPath: uploadedPath),
      );
      return created;
    } catch (_) {
      await _remote.deletePhoto(uploadedPath);
      await _remote.delete(created.id);
      rethrow;
    }
  }

  @override
  Future<StockItem> update(
    StockItem current,
    StockDraft draft, {
    StockPhoto? photo,
  }) async {
    String? uploadedPath;
    if (photo != null) {
      uploadedPath = await _remote.uploadPhoto(current.id, photo);
    }
    late final StockItem updated;
    try {
      updated = await _remote.update(
        current.id,
        _copyDraft(
          draft,
          photoObjectPath: uploadedPath ?? current.photoObjectPath,
        ),
      );
    } catch (_) {
      await _remote.deletePhoto(uploadedPath);
      rethrow;
    }
    if (uploadedPath != null && current.photoObjectPath != uploadedPath) {
      try {
        await _remote.deletePhoto(current.photoObjectPath);
      } catch (_) {
        // A linha já aponta para a foto nova; a limpeza antiga pode ser repetida.
      }
    }
    return updated;
  }

  @override
  Future<void> delete(StockItem item) async {
    await _remote.delete(item.id);
    try {
      await _remote.deletePhoto(item.photoObjectPath);
    } catch (_) {
      // O registro principal foi removido; a limpeza do objeto é best effort.
    }
  }

  @override
  Future<String?> createSignedPhotoUrl(String? objectPath) =>
      _remote.createSignedPhotoUrl(objectPath);
}

StockDraft _copyDraft(StockDraft source, {String? photoObjectPath}) =>
    StockDraft(
      name: source.name,
      type: source.type,
      registeredForCrop: source.registeredForCrop,
      activeIngredient: source.activeIngredient,
      formulation: source.formulation,
      concentration: source.concentration,
      chemicalGroup: source.chemicalGroup,
      manufacturer: source.manufacturer,
      mapaRegistration: source.mapaRegistration,
      expirationDate: source.expirationDate,
      target1: source.target1,
      target2: source.target2,
      safetyIntervalDays: source.safetyIntervalDays,
      labelDose: source.labelDose,
      doseUnit: source.doseUnit,
      quantity: source.quantity,
      unit: source.unit,
      photoObjectPath: photoObjectPath,
      observations: source.observations,
    );
