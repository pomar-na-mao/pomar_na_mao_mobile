import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:pomar_na_mao_mobile/features/operations/data/inspection_database.dart';
import 'package:pomar_na_mao_mobile/features/operations/data/inspection_local_store.dart';
import 'package:pomar_na_mao_mobile/features/operations/data/mipd_database.dart';
import 'package:pomar_na_mao_mobile/features/operations/data/mipd_local_store.dart';
import 'package:pomar_na_mao_mobile/features/operations/data/mipd_remote_data_source.dart';
import 'package:pomar_na_mao_mobile/features/operations/data/mipd_repository.dart';
import 'package:pomar_na_mao_mobile/features/operations/domain/inspection_models.dart';
import 'package:pomar_na_mao_mobile/features/operations/domain/mipd_models.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  sqfliteFfiInit();
  late Directory directory;
  late MipdDatabase mipdDb;
  late InspectionDatabase inspectionDb;
  late MipdLocalStore localStore;
  late _Remote remote;
  late DefaultMipdRepository repository;

  setUp(() async {
    directory = await Directory.systemTemp.createTemp('mipd_repo_');
    mipdDb = MipdDatabase(
      projectUrl: 'https://test.supabase.co',
      factory: databaseFactoryFfi,
      directory: directory.path,
    );
    inspectionDb = InspectionDatabase(
      projectUrl: 'https://test.supabase.co',
      factory: databaseFactoryFfi,
      directory: directory.path,
    );
    localStore = MipdLocalStore(mipdDb, newId: () => 'local-1');
    remote = _Remote();
    repository = DefaultMipdRepository(
      localStore: localStore,
      remoteDataSource: remote,
      inspectionLocalStore: InspectionLocalStore(inspectionDb),
      refreshSharedCache: () async {},
    );
  });

  tearDown(() async {
    await mipdDb.close();
    await inspectionDb.close();
    await directory.delete(recursive: true);
  });

  test('persists photo path before RPC and reconciles the response', () async {
    await repository.save(
      localId: 'local-1',
      plantId: 'plant-1',
      occurrenceType: const OccurrenceType(
        id: 'pest-1',
        name: 'Ácaro',
        code: 'acaro',
        category: OccurrenceType.pestDiseaseCategory,
      ),
      plantParts: const {MipdPlantPart.leaf},
      localPhotoPath: 'photo.jpg',
    );
    expect(await repository.syncAll(), isTrue);
    expect(remote.uploads, 1);
    expect(
      remote.payload!['markings'][0]['photoObjectPath'],
      contains('/local-1.jpg'),
    );
    expect((await repository.list()).single.status, MipdSyncStatus.synced);
    expect(await repository.syncAll(), isTrue);
    expect(remote.uploads, 1);
  });

  test('upload failure leaves marking recoverable', () async {
    remote.failUpload = true;
    await localStore.create(
      plantId: 'plant-1',
      occurrenceTypeId: 'pest-1',
      plantParts: const {MipdPlantPart.root},
      localPhotoPath: 'photo.jpg',
    );
    expect(await repository.syncAll(), isFalse);
    expect((await repository.list()).single.status, MipdSyncStatus.error);
  });
}

class _Remote implements MipdRemoteDataSource {
  int uploads = 0;
  bool failUpload = false;
  Map<String, dynamic>? payload;
  @override
  Future<String> uploadPhoto({
    required String deviceId,
    required String localId,
    required String localPath,
  }) async {
    uploads++;
    if (failUpload) throw StateError('offline');
    return 'user/$deviceId/$localId.jpg';
  }

  @override
  Future<List<MipdSyncResult>> syncMarkings(
    Map<String, dynamic> payload,
  ) async {
    this.payload = payload;
    return [
      MipdSyncResult(
        localMarkingId: 'local-1',
        operationId: 'op',
        occurrenceId: 'occ',
        markingId: 'mark',
        syncedAt: DateTime.utc(2026),
      ),
    ];
  }
}
