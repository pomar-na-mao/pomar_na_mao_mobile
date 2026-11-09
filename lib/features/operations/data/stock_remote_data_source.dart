import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';

import '../domain/stock_models.dart';

const stockPhotosBucket = 'stock-item-photos';
const stockPhotoMaxSizeBytes = 5 * 1024 * 1024;

abstract interface class StockRemoteDataSource {
  Future<List<StockItem>> fetchAll();
  Future<List<String>> fetchTypes();
  Future<StockItem> create(StockDraft draft);
  Future<StockItem> update(String id, StockDraft draft);
  Future<void> delete(String id);
  Future<String> uploadPhoto(String stockId, StockPhoto photo);
  Future<void> deletePhoto(String? objectPath);
  Future<String?> createSignedPhotoUrl(String? objectPath);
}

class SupabaseStockRemoteDataSource implements StockRemoteDataSource {
  SupabaseStockRemoteDataSource(this._client, {Uuid? uuid})
    : _uuid = uuid ?? const Uuid();

  final SupabaseClient _client;
  final Uuid _uuid;

  @override
  Future<List<StockItem>> fetchAll() async {
    final rows = await _client
        .from('stocks')
        .select()
        .order('type')
        .order('name');
    return (rows as List).cast<Map<String, dynamic>>().map(_fromJson).toList();
  }

  @override
  Future<List<String>> fetchTypes() async {
    try {
      final rows = await _client.rpc('get_stock_type_enum_values');
      final values = (rows as List)
          .map((row) => row is String ? row : (row as Map)['value'] as String)
          .toList();
      return {...defaultStockTypes, ...values}.toList();
    } catch (_) {
      return defaultStockTypes;
    }
  }

  @override
  Future<StockItem> create(StockDraft draft) async {
    final now = DateTime.now().toUtc().toIso8601String();
    final row = await _client
        .from('stocks')
        .insert({..._toJson(draft), 'created_at': now, 'updated_at': now})
        .select()
        .single();
    return _fromJson(row);
  }

  @override
  Future<StockItem> update(String id, StockDraft draft) async {
    final row = await _client
        .from('stocks')
        .update({
          ..._toJson(draft),
          'updated_at': DateTime.now().toUtc().toIso8601String(),
        })
        .eq('id', id)
        .select()
        .single();
    return _fromJson(row);
  }

  @override
  Future<void> delete(String id) async {
    await _client.from('stocks').delete().eq('id', id);
  }

  @override
  Future<String> uploadPhoto(String stockId, StockPhoto photo) async {
    final file = File(photo.path);
    final size = await file.length();
    if (size > stockPhotoMaxSizeBytes) {
      throw const FormatException('A imagem deve ter no máximo 5 MB.');
    }
    final extension = switch (p.extension(photo.path).toLowerCase()) {
      '.png' => 'png',
      '.webp' => 'webp',
      _ => 'jpg',
    };
    final objectPath = '$stockId/${_uuid.v4()}.$extension';
    await _client.storage
        .from(stockPhotosBucket)
        .upload(
          objectPath,
          file,
          fileOptions: FileOptions(
            contentType: photo.contentType,
            upsert: false,
          ),
        );
    return objectPath;
  }

  @override
  Future<void> deletePhoto(String? objectPath) async {
    if (objectPath == null || objectPath.isEmpty) return;
    await _client.storage.from(stockPhotosBucket).remove([objectPath]);
  }

  @override
  Future<String?> createSignedPhotoUrl(String? objectPath) async {
    if (objectPath == null || objectPath.isEmpty) return null;
    return _client.storage
        .from(stockPhotosBucket)
        .createSignedUrl(objectPath, 300);
  }

  Map<String, dynamic> _toJson(StockDraft draft) => {
    'name': draft.name.trim(),
    'type': draft.type.trim(),
    'active_ingredient': _emptyToNull(draft.activeIngredient),
    'formulation': _emptyToNull(draft.formulation),
    'concentration': _emptyToNull(draft.concentration),
    'chemical_group': _emptyToNull(draft.chemicalGroup),
    'manufacturer': _emptyToNull(draft.manufacturer),
    'mapa_registration': _emptyToNull(draft.mapaRegistration),
    'expiration_date': formatStockDateForDatabase(draft.expirationDate),
    'registered_for_crop': draft.registeredForCrop,
    'target_1': _emptyToNull(draft.target1),
    'target_2': _emptyToNull(draft.target2),
    'safety_interval_days': draft.safetyIntervalDays,
    'label_dose': _emptyToNull(draft.labelDose),
    'dose_unit': _emptyToNull(draft.doseUnit),
    'quantity': draft.quantity,
    'unit': draft.unit,
    'photo_object_path': draft.photoObjectPath,
    'observations': _emptyToNull(draft.observations),
  };

  StockItem _fromJson(Map<String, dynamic> json) => StockItem(
    id: json['id'] as String,
    name: json['name'] as String,
    type: json['type'] as String,
    activeIngredient: json['active_ingredient'] as String?,
    formulation: json['formulation'] as String?,
    concentration: json['concentration'] as String?,
    chemicalGroup: json['chemical_group'] as String?,
    manufacturer: json['manufacturer'] as String?,
    mapaRegistration: json['mapa_registration'] as String?,
    expirationDate: DateTime.tryParse(json['expiration_date'] as String? ?? ''),
    registeredForCrop: json['registered_for_crop'] as bool? ?? true,
    target1: json['target_1'] as String?,
    target2: json['target_2'] as String?,
    safetyIntervalDays: (json['safety_interval_days'] as num?)?.toInt(),
    labelDose: json['label_dose'] as String?,
    doseUnit: json['dose_unit'] as String?,
    quantity: (json['quantity'] as num?)?.toDouble(),
    unit: json['unit'] as String?,
    photoObjectPath: json['photo_object_path'] as String?,
    observations: json['observations'] as String?,
    createdAt: DateTime.parse(json['created_at'] as String),
    updatedAt: DateTime.parse(json['updated_at'] as String),
  );
}

String? formatStockDateForDatabase(DateTime? date) {
  if (date == null) return null;
  final year = date.year.toString().padLeft(4, '0');
  final month = date.month.toString().padLeft(2, '0');
  final day = date.day.toString().padLeft(2, '0');
  return '$year-$month-$day';
}

String? _emptyToNull(String? value) {
  final trimmed = value?.trim();
  return trimmed == null || trimmed.isEmpty ? null : trimmed;
}
