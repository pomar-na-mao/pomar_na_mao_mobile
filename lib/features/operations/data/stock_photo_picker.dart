import 'package:image_picker/image_picker.dart';

import '../domain/stock_models.dart';

enum StockPhotoSource { camera, gallery }

abstract interface class StockPhotoPicker {
  Future<StockPhoto?> pick(StockPhotoSource source);
}

class ImagePickerStockPhotoPicker implements StockPhotoPicker {
  ImagePickerStockPhotoPicker({ImagePicker? picker})
    : _picker = picker ?? ImagePicker();

  final ImagePicker _picker;

  @override
  Future<StockPhoto?> pick(StockPhotoSource source) async {
    final image = await _picker.pickImage(
      source: source == StockPhotoSource.camera
          ? ImageSource.camera
          : ImageSource.gallery,
      imageQuality: 85,
      maxWidth: 1920,
    );
    if (image == null) return null;
    final mime = image.mimeType ?? _mimeFromName(image.name);
    return StockPhoto(path: image.path, contentType: mime);
  }
}

String _mimeFromName(String name) => switch (name.toLowerCase()) {
  final value when value.endsWith('.png') => 'image/png',
  final value when value.endsWith('.webp') => 'image/webp',
  _ => 'image/jpeg',
};
