import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:pomar_na_mao_mobile/features/operations/data/mipd_photo_service.dart';

class _FakePicker implements MipdPhotoPicker {
  _FakePicker(this.path);
  final String? path;

  @override
  Future<String?> capture() async => path;
}

class _FakeDirectoryProvider implements MipdPhotoDirectoryProvider {
  _FakeDirectoryProvider(this.value);
  final Directory value;

  @override
  Future<Directory> directory() async => value;
}

class _ThrowingPicker implements MipdPhotoPicker {
  @override
  Future<String?> capture() => Future.error(Exception('permission denied'));
}

void main() {
  late Directory tempDir;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('mipd_photo_test_');
  });

  tearDown(() async {
    if (await tempDir.exists()) await tempDir.delete(recursive: true);
  });

  test('copies captured photo into a durable managed directory', () async {
    final source = File(p.join(tempDir.path, 'camera.png'));
    await source.writeAsBytes([1, 2, 3]);
    final managed = Directory(p.join(tempDir.path, 'managed'));
    final service = MipdPhotoService(
      picker: _FakePicker(source.path),
      directoryProvider: _FakeDirectoryProvider(managed),
    );

    final saved = await service.captureAndPersist('local-1');

    expect(saved, p.join(managed.path, 'local-1.png'));
    expect(await File(saved!).readAsBytes(), [1, 2, 3]);
    await service.remove(saved);
    expect(await File(saved).exists(), isFalse);
  });

  test('camera cancellation keeps photo optional', () async {
    final service = MipdPhotoService(
      picker: _FakePicker(null),
      directoryProvider: _FakeDirectoryProvider(tempDir),
    );

    expect(await service.captureAndPersist('local-1'), isNull);
  });

  test('camera permission error does not create a managed file', () async {
    final managed = Directory(p.join(tempDir.path, 'managed'));
    final service = MipdPhotoService(
      picker: _ThrowingPicker(),
      directoryProvider: _FakeDirectoryProvider(managed),
    );

    await expectLater(
      service.captureAndPersist('local-1'),
      throwsA(isA<Exception>()),
    );
    expect(await managed.exists(), isFalse);
  });

  test('missing captured file reports a recoverable file error', () async {
    final service = MipdPhotoService(
      picker: _FakePicker(p.join(tempDir.path, 'missing.jpg')),
      directoryProvider: _FakeDirectoryProvider(tempDir),
    );

    await expectLater(
      service.captureAndPersist('local-1'),
      throwsA(isA<FileSystemException>()),
    );
  });
}
