import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:supabase_flutter/supabase_flutter.dart';

import '../domain/mipd_models.dart';

abstract interface class MipdRemoteDataSource {
  Future<String> uploadPhoto({
    required String deviceId,
    required String localId,
    required String localPath,
  });

  Future<List<MipdSyncResult>> syncMarkings(Map<String, dynamic> payload);
}

class SupabaseMipdRemoteDataSource implements MipdRemoteDataSource {
  static const anonymousOwner = 'anonymous';

  const SupabaseMipdRemoteDataSource(
    this._client, {
    this.bucket = 'mipd-plant-photos',
    this.rpcName = 'sync_mipd_markings',
  });

  final SupabaseClient _client;
  final String bucket;
  final String rpcName;

  static String ownerSegment(String? userId) => userId ?? anonymousOwner;

  static String objectPath({
    required String ownerId,
    required String deviceId,
    required String localId,
    required String localPath,
  }) {
    final extension = switch (p.extension(localPath).toLowerCase()) {
      '.png' => '.png',
      '.heic' || '.heif' => '.heic',
      _ => '.jpg',
    };
    return '$ownerId/$deviceId/$localId$extension';
  }

  @override
  Future<String> uploadPhoto({
    required String deviceId,
    required String localId,
    required String localPath,
  }) async {
    final userId = _client.auth.currentUser?.id;
    final isAnonymous = userId == null;
    final path = objectPath(
      ownerId: ownerSegment(userId),
      deviceId: deviceId,
      localId: localId,
      localPath: localPath,
    );
    final mime = switch (p.extension(path)) {
      '.png' => 'image/png',
      '.heic' => 'image/heic',
      _ => 'image/jpeg',
    };
    try {
      await _client.storage
          .from(bucket)
          .upload(
            path,
            File(localPath),
            fileOptions: FileOptions(upsert: !isAnonymous, contentType: mime),
          );
    } on StorageException catch (error) {
      if (!isAnonymous || !_isExistingObject(error)) rethrow;
    }
    return path;
  }

  static bool _isExistingObject(StorageException error) {
    final details = '${error.message} ${error.error}'.toLowerCase();
    return error.statusCode == '409' ||
        (error.statusCode == '400' &&
            (details.contains('already exists') ||
                details.contains('duplicate')));
  }

  @override
  Future<List<MipdSyncResult>> syncMarkings(
    Map<String, dynamic> payload,
  ) async => MipdSyncResult.listFromRpc(
    await _client.rpc(rpcName, params: {'p_payload': payload}),
  );
}
