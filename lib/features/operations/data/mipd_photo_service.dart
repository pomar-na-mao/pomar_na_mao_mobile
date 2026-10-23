import 'dart:io';

import 'package:image_picker/image_picker.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

abstract interface class MipdPhotoPicker {
  Future<String?> capture();
}

class ImagePickerMipdPhotoPicker implements MipdPhotoPicker {
  ImagePickerMipdPhotoPicker({ImagePicker? picker})
    : _picker = picker ?? ImagePicker();

  final ImagePicker _picker;

  @override
  Future<String?> capture() async => (await _picker.pickImage(
    source: ImageSource.camera,
    imageQuality: 85,
    maxWidth: 1920,
  ))?.path;
}

abstract interface class MipdPhotoDirectoryProvider {
  Future<Directory> directory();
}

class AppSupportMipdPhotoDirectoryProvider
    implements MipdPhotoDirectoryProvider {
  const AppSupportMipdPhotoDirectoryProvider();

  @override
  Future<Directory> directory() async => Directory(
    p.join((await getApplicationSupportDirectory()).path, 'mipd_photos'),
  );
}

class MipdPhotoService {
  MipdPhotoService({
    required this.picker,
    this.directoryProvider = const AppSupportMipdPhotoDirectoryProvider(),
  });

  final MipdPhotoPicker picker;
  final MipdPhotoDirectoryProvider directoryProvider;

  Future<String?> captureAndPersist(String localId) async {
    final sourcePath = await picker.capture();
    if (sourcePath == null) return null;
    final source = File(sourcePath);
    if (!await source.exists()) {
      throw FileSystemException('Foto capturada não encontrada', sourcePath);
    }
    final directory = await directoryProvider.directory();
    await directory.create(recursive: true);
    final extension = _normalizedExtension(sourcePath);
    final destination = File(p.join(directory.path, '$localId$extension'));
    try {
      await source.copy(destination.path);
      return destination.path;
    } catch (_) {
      if (await destination.exists()) await destination.delete();
      rethrow;
    }
  }

  Future<void> remove(String? path) async {
    if (path == null || path.isEmpty) return;
    final file = File(path);
    if (await file.exists()) await file.delete();
  }

  static String _normalizedExtension(String path) =>
      switch (p.extension(path).toLowerCase()) {
        '.png' => '.png',
        '.heic' || '.heif' => '.heic',
        _ => '.jpg',
      };
}
