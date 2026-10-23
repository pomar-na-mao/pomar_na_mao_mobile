import 'package:flutter_test/flutter_test.dart';
import 'package:pomar_na_mao_mobile/features/operations/data/mipd_remote_data_source.dart';

void main() {
  test('uses the anonymous storage segment without a user session', () {
    expect(
      SupabaseMipdRemoteDataSource.ownerSegment(null),
      SupabaseMipdRemoteDataSource.anonymousOwner,
    );
    expect(SupabaseMipdRemoteDataSource.ownerSegment('user-1'), 'user-1');
  });

  test('builds deterministic authenticated and anonymous photo paths', () {
    expect(
      SupabaseMipdRemoteDataSource.objectPath(
        ownerId: 'user-1',
        deviceId: 'device-1',
        localId: 'local-1',
        localPath: r'C:\camera\photo.PNG',
      ),
      'user-1/device-1/local-1.png',
    );
    expect(
      SupabaseMipdRemoteDataSource.objectPath(
        ownerId: SupabaseMipdRemoteDataSource.anonymousOwner,
        deviceId: 'd',
        localId: 'l',
        localPath: 'photo.webp',
      ),
      'anonymous/d/l.jpg',
    );
  });
}
