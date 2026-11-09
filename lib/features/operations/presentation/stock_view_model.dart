import 'dart:collection';

import 'package:flutter/foundation.dart';

import '../data/stock_photo_picker.dart';
import '../data/stock_repository.dart';
import '../domain/stock_models.dart';

class StockViewModel extends ChangeNotifier {
  StockViewModel({required this.repository, required this.photoPicker});

  final StockRepository repository;
  final StockPhotoPicker photoPicker;
  final List<StockItem> _items = [];
  List<String> _types = defaultStockTypes;
  String _query = '';
  bool _loading = false;
  bool _saving = false;
  String? _error;

  UnmodifiableListView<StockItem> get items => UnmodifiableListView(_items);
  UnmodifiableListView<String> get types => UnmodifiableListView(_types);
  bool get loading => _loading;
  bool get saving => _saving;
  String? get error => _error;

  List<StockItem> get filteredItems {
    final normalized = _query.trim().toLowerCase();
    if (normalized.isEmpty) return List.unmodifiable(_items);
    return List.unmodifiable(
      _items.where(
        (item) =>
            item.name.toLowerCase().contains(normalized) ||
            stockTypeLabel(item.type).toLowerCase().contains(normalized) ||
            (item.activeIngredient?.toLowerCase().contains(normalized) ??
                false),
      ),
    );
  }

  Future<void> load() async {
    if (_loading) return;
    _loading = true;
    _error = null;
    notifyListeners();
    try {
      final results = await Future.wait([
        repository.fetchAll(),
        repository.fetchTypes(),
      ]);
      _items
        ..clear()
        ..addAll(results[0] as List<StockItem>);
      _types = results[1] as List<String>;
    } catch (_) {
      _error = 'Não foi possível carregar o estoque.';
    } finally {
      _loading = false;
      notifyListeners();
    }
  }

  void search(String value) {
    if (_query == value) return;
    _query = value;
    notifyListeners();
  }

  Future<StockPhoto?> pickPhoto(StockPhotoSource source) async {
    try {
      return await photoPicker.pick(source);
    } catch (_) {
      _error = 'Não foi possível selecionar a foto.';
      notifyListeners();
      return null;
    }
  }

  Future<String?> photoUrl(StockItem item) =>
      repository.createSignedPhotoUrl(item.photoObjectPath);

  Future<bool> save({
    required StockDraft draft,
    StockItem? current,
    StockPhoto? photo,
  }) async {
    final validationError = draft.validate();
    if (validationError != null) {
      _error = validationError;
      notifyListeners();
      return false;
    }
    _saving = true;
    _error = null;
    notifyListeners();
    try {
      final saved = current == null
          ? await repository.create(draft, photo: photo)
          : await repository.update(current, draft, photo: photo);
      _items.removeWhere((item) => item.id == saved.id);
      _items.insert(0, saved);
      return true;
    } catch (_) {
      _error = current == null
          ? 'Não foi possível cadastrar o item.'
          : 'Não foi possível atualizar o item.';
      return false;
    } finally {
      _saving = false;
      notifyListeners();
    }
  }

  Future<bool> delete(StockItem item) async {
    _saving = true;
    _error = null;
    notifyListeners();
    try {
      await repository.delete(item);
      _items.removeWhere((candidate) => candidate.id == item.id);
      return true;
    } catch (_) {
      _error = 'Não foi possível excluir o item.';
      return false;
    } finally {
      _saving = false;
      notifyListeners();
    }
  }
}
