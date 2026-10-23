import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:pomar_na_mao_mobile/features/farm/domain/user_location.dart';
import 'package:pomar_na_mao_mobile/features/operations/data/mipd_photo_service.dart';
import 'package:pomar_na_mao_mobile/features/operations/data/mipd_repository.dart';
import 'package:pomar_na_mao_mobile/features/operations/domain/inspection_models.dart';
import 'package:pomar_na_mao_mobile/features/operations/domain/mipd_models.dart';
import 'package:pomar_na_mao_mobile/features/operations/presentation/mipd_view_model.dart';

void main() {
  test('aguarda três amostras GPS antes de publicar a posição', () async {
    final locationService = _LocationService();
    final viewModel = MipdViewModel(
      repository: _Repository(),
      locationService: locationService,
      photoService: MipdPhotoService(picker: _PhotoPicker()),
    );
    addTearDown(() {
      viewModel.dispose();
      locationService.dispose();
    });

    viewModel.resumeLocation();
    expect(viewModel.isWaitingForStableLocation, isTrue);

    final now = DateTime.now().toUtc();
    for (var secondsAgo = 2; secondsAgo >= 0; secondsAgo--) {
      locationService.emit(
        LocationResult.available(
          UserLocation(
            latitude: -21.177,
            longitude: -47.81,
            accuracy: 3,
            timestamp: now.subtract(Duration(seconds: secondsAgo)),
          ),
        ),
      );
      await Future<void>.delayed(Duration.zero);
      if (secondsAgo > 0) {
        expect(viewModel.userLocation, isNull);
        expect(viewModel.isWaitingForStableLocation, isTrue);
      }
    }

    expect(viewModel.userLocation, isNotNull);
    expect(viewModel.isWaitingForStableLocation, isFalse);
  });
}

class _LocationService implements LocationService {
  final _controller = StreamController<LocationResult>.broadcast();

  @override
  Future<LocationResult> getCurrentLocation() async =>
      const LocationResult.serviceDisabled();

  @override
  Stream<LocationResult> watchLocation() => _controller.stream;

  void emit(LocationResult result) => _controller.add(result);
  void dispose() => _controller.close();
}

class _Repository implements MipdRepository {
  @override
  String createLocalId() => 'local-id';

  @override
  Future<MipdSnapshot?> loadSnapshot({bool forceRemote = false}) async => null;

  @override
  Future<List<MipdMarking>> list() async => const [];

  @override
  Future<MipdMarking> save({
    required String localId,
    required String plantId,
    required OccurrenceType occurrenceType,
    required Iterable<MipdPlantPart> plantParts,
    String? localPhotoPath,
  }) => throw UnimplementedError();

  @override
  Future<bool> syncAll() async => true;

  @override
  Future<bool> syncOne(String localId) async => true;
}

class _PhotoPicker implements MipdPhotoPicker {
  @override
  Future<String?> capture() async => null;
}
