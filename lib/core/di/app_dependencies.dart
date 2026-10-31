import 'dart:async';

import 'package:supabase_flutter/supabase_flutter.dart';

import '../../features/farm/data/datasources/farm_remote_data_source.dart';
import '../../features/farm/data/geolocator_location_service.dart';
import '../../features/farm/data/supabase_farm_repository.dart';
import '../../features/farm/data/supabase_plants_repository.dart';
import '../../features/farm/data/supabase_zones_repository.dart';
import '../../features/farm/domain/farm_repository.dart';
import '../../features/farm/domain/plants_repository.dart';
import '../../features/farm/domain/user_location.dart';
import '../../features/farm/domain/zones_repository.dart';
import '../../features/farm/presentation/farm_map_view_model.dart';
import '../../features/inventory/data/supabase_inventory_repository.dart';
import '../../features/inventory/domain/inventory_repository.dart';
import '../../features/inventory/presentation/inventory_view_model.dart';
import '../../features/operations/data/inspection_database.dart';
import '../../features/operations/data/activity_database.dart';
import '../../features/operations/data/activity_local_store.dart';
import '../../features/operations/data/activity_remote_data_source.dart';
import '../../features/operations/data/activity_repository.dart';
import '../../features/operations/data/inspection_local_store.dart';
import '../../features/operations/data/inspection_remote_data_source.dart';
import '../../features/operations/data/inspection_repository.dart';
import '../../features/operations/data/mipd_database.dart';
import '../../features/operations/data/mipd_local_store.dart';
import '../../features/operations/data/mipd_photo_service.dart';
import '../../features/operations/data/mipd_remote_data_source.dart';
import '../../features/operations/data/mipd_repository.dart';
import '../../features/operations/data/spraying_database.dart';
import '../../features/operations/data/spraying_local_store.dart';
import '../../features/operations/data/spraying_remote_data_source.dart';
import '../../features/operations/data/spraying_repository.dart';
import '../../features/operations/domain/inspection_models.dart';
import '../../features/operations/domain/mipd_models.dart';
import '../../features/operations/domain/spraying_models.dart';
import '../../features/operations/presentation/inspection_view_model.dart';
import '../../features/operations/presentation/activity_view_model.dart';
import '../../features/operations/presentation/mipd_view_model.dart';
import '../../features/operations/presentation/spraying_view_model.dart';
import '../config/app_config.dart';
import '../data/shared_read_repository.dart';
import '../ui/app_loading_controller.dart';

/// Container central de injeção de dependências do aplicativo.
///
/// Gerencia a instanciação e o ciclo de vida dos serviços, repositórios
/// e ViewModels sem dependência de bibliotecas externas.
class AppDependencies {
  AppDependencies({
    required this.farmRepository,
    required this.plantsRepository,
    required this.zonesRepository,
    required this.inventoryRepository,
    required this.locationService,
    AppLoadingController? loadingController,
    InspectionRepository? inspectionRepository,
    this.inspectionDatabase,
    SprayingRepository? sprayingRepository,
    this.sprayingDatabase,
    MipdRepository? mipdRepository,
    this.mipdDatabase,
    ActivityRepository? activityRepository,
    this.activityDatabase,
    this.sharedReadRepository,
    InventoryViewModel? inventoryViewModel,
    FarmMapViewModel? farmMapViewModel,
    InspectionViewModel? inspectionViewModel,
    SprayingViewModel? sprayingViewModel,
    MipdViewModel? mipdViewModel,
    ActivityViewModel? activityViewModel,
  }) : loadingController = loadingController ?? AppLoadingController(),
       _injectedInspectionRepository = inspectionRepository,
       _injectedSprayingRepository = sprayingRepository,
       _injectedMipdRepository = mipdRepository,
       _injectedActivityRepository = activityRepository,
       _injectedInventoryViewModel = inventoryViewModel,
       _injectedFarmMapViewModel = farmMapViewModel,
       _injectedInspectionViewModel = inspectionViewModel,
       _injectedSprayingViewModel = sprayingViewModel,
       _injectedMipdViewModel = mipdViewModel,
       _injectedActivityViewModel = activityViewModel;

  factory AppDependencies.fromSupabaseClient(
    SupabaseClient supabaseClient, {
    LocationService? locationService,
    InspectionDatabase? inspectionDatabase,
  }) {
    final locService = locationService ?? GeolocatorLocationService();

    final inspDb =
        inspectionDatabase ??
        InspectionDatabase(projectUrl: supabaseClient.rest.url.toString());
    final inspStore = InspectionLocalStore(inspDb);
    final loadingController = AppLoadingController();
    final farmRemote = SupabaseFarmRemoteDataSource(supabaseClient);
    final inspRemote = SupabaseInspectionRemoteDataSource(supabaseClient);
    final activityRemote = SupabaseActivityRemoteDataSource(supabaseClient);
    final sharedReadRepo = SharedReadRepository(
      localStore: inspStore,
      farmRemoteDataSource: farmRemote,
      inspectionRemoteDataSource: inspRemote,
      activityRemoteDataSource: activityRemote,
      loadingController: loadingController,
    );
    final farmRepo = SupabaseFarmRepository.fromShared(sharedReadRepo);
    final plantsRepo = SupabasePlantsRepository.fromShared(sharedReadRepo);
    final zonesRepo = SupabaseZonesRepository.fromShared(sharedReadRepo);
    final inventoryRepo = SupabaseInventoryRepository.fromShared(
      sharedReadRepo,
    );
    final inspRepo = DefaultInspectionRepository(
      localStore: inspStore,
      remoteDataSource: inspRemote,
      sharedReadRepository: sharedReadRepo,
      loadingController: loadingController,
    );

    final sprayDb = SprayingDatabase(
      projectUrl: supabaseClient.rest.url.toString(),
    );
    final sprayStore = SprayingLocalStore(sprayDb);
    final sprayRemote = SupabaseSprayingRemoteDataSource(supabaseClient);
    final sprayRepo = DefaultSprayingRepository(
      localStore: sprayStore,
      remoteDataSource: sprayRemote,
    );
    final mipdDb = MipdDatabase(projectUrl: supabaseClient.rest.url.toString());
    final mipdRepo = DefaultMipdRepository(
      localStore: MipdLocalStore(mipdDb),
      remoteDataSource: SupabaseMipdRemoteDataSource(supabaseClient),
      inspectionLocalStore: inspStore,
      refreshSharedCache: sharedReadRepo.refreshCache,
    );
    final activityDb = ActivityDatabase(
      projectUrl: supabaseClient.rest.url.toString(),
    );
    final activityRepo = DefaultActivityRepository(
      localStore: ActivityLocalStore(activityDb),
      remoteDataSource: activityRemote,
      sharedReadRepository: sharedReadRepo,
    );

    return AppDependencies(
      farmRepository: farmRepo,
      plantsRepository: plantsRepo,
      zonesRepository: zonesRepo,
      inventoryRepository: inventoryRepo,
      locationService: locService,
      loadingController: loadingController,
      inspectionDatabase: inspDb,
      sprayingDatabase: sprayDb,
      mipdDatabase: mipdDb,
      activityDatabase: activityDb,
      sharedReadRepository: sharedReadRepo,
      inspectionRepository: inspRepo,
      sprayingRepository: sprayRepo,
      mipdRepository: mipdRepo,
      activityRepository: activityRepo,
      inventoryViewModel: InventoryViewModel(
        inventoryRepo,
        farmRepo,
        zonesRepo,
        profile: AppConfig.activeTenant.propertyProfile,
        plantChanges: sharedReadRepo.plantChanges,
      ),
    );
  }

  final FarmRepository farmRepository;
  final PlantsRepository plantsRepository;
  final ZonesRepository zonesRepository;
  final InventoryRepository inventoryRepository;
  final LocationService locationService;
  final AppLoadingController loadingController;
  final InspectionDatabase? inspectionDatabase;
  final SprayingDatabase? sprayingDatabase;
  final MipdDatabase? mipdDatabase;
  final ActivityDatabase? activityDatabase;
  final SharedReadRepository? sharedReadRepository;
  final InspectionRepository? _injectedInspectionRepository;
  final SprayingRepository? _injectedSprayingRepository;
  final MipdRepository? _injectedMipdRepository;
  final ActivityRepository? _injectedActivityRepository;

  InspectionRepository get inspectionRepository =>
      _injectedInspectionRepository ??
      DefaultInspectionRepository(
        localStore: InspectionLocalStore(
          inspectionDatabase ?? InspectionDatabase(projectUrl: ''),
        ),
        remoteDataSource: FakeEmptyRemoteDataSource(),
      );

  SprayingRepository get sprayingRepository =>
      _injectedSprayingRepository ??
      DefaultSprayingRepository(
        localStore: SprayingLocalStore(
          sprayingDatabase ?? SprayingDatabase(projectUrl: ''),
        ),
        remoteDataSource: const _FakeEmptySprayingRemoteDataSource(),
      );

  late final MipdRepository mipdRepository =
      _injectedMipdRepository ??
      DefaultMipdRepository(
        localStore: MipdLocalStore(
          mipdDatabase ?? MipdDatabase(projectUrl: ''),
        ),
        remoteDataSource: const _FakeEmptyMipdRemoteDataSource(),
        inspectionLocalStore: InspectionLocalStore(
          inspectionDatabase ?? InspectionDatabase(projectUrl: ''),
        ),
        refreshSharedCache: () async {},
      );

  final InventoryViewModel? _injectedInventoryViewModel;
  final FarmMapViewModel? _injectedFarmMapViewModel;
  final InspectionViewModel? _injectedInspectionViewModel;
  final SprayingViewModel? _injectedSprayingViewModel;
  final MipdViewModel? _injectedMipdViewModel;
  final ActivityViewModel? _injectedActivityViewModel;

  late final InventoryViewModel inventoryViewModel =
      _injectedInventoryViewModel ??
      InventoryViewModel(
        inventoryRepository,
        farmRepository,
        zonesRepository,
        profile: AppConfig.activeTenant.propertyProfile,
        plantChanges: sharedReadRepository?.plantChanges,
      );

  late final FarmMapViewModel farmMapViewModel =
      _injectedFarmMapViewModel ??
      FarmMapViewModel(
        plantsRepository,
        zonesRepository,
        farmRepository,
        plantChanges: sharedReadRepository?.plantChanges,
      );

  late final InspectionViewModel inspectionViewModel =
      _injectedInspectionViewModel ??
      InspectionViewModel(
        repository: inspectionRepository,
        zonesRepository: zonesRepository,
        locationService: locationService,
        plantChanges: sharedReadRepository?.plantChanges,
      );

  late final SprayingViewModel sprayingViewModel =
      _injectedSprayingViewModel ??
      SprayingViewModel(
        sprayingRepository: sprayingRepository,
        inspectionRepository: inspectionRepository,
        locationService: locationService,
        zonesRepository: zonesRepository,
      );

  MipdViewModel? _createdMipdViewModel;
  MipdViewModel get mipdViewModel =>
      _injectedMipdViewModel ??
      (_createdMipdViewModel ??= MipdViewModel(
        repository: mipdRepository,
        locationService: locationService,
        photoService: MipdPhotoService(picker: ImagePickerMipdPhotoPicker()),
      ));

  ActivityViewModel? _createdActivityViewModel;
  ActivityViewModel? get activityViewModel {
    if (_injectedActivityViewModel case final injected?) return injected;
    final repository = _injectedActivityRepository;
    if (repository == null) return null;
    return _createdActivityViewModel ??= ActivityViewModel(
      repository: repository,
      locationService: locationService,
      zonesRepository: zonesRepository,
    );
  }

  /// Libera recursos e encerra listeners dos ViewModels criados.
  void dispose() {
    inventoryViewModel.dispose();
    farmMapViewModel.dispose();
    inspectionViewModel.dispose();
    _injectedSprayingViewModel?.dispose();
    (_injectedMipdViewModel ?? _createdMipdViewModel)?.dispose();
    (_injectedActivityViewModel ?? _createdActivityViewModel)?.dispose();
    unawaited(sharedReadRepository?.dispose());
    unawaited(inspectionDatabase?.close());
    unawaited(sprayingDatabase?.close());
    unawaited(mipdDatabase?.close());
    unawaited(activityDatabase?.close());
  }
}

class _FakeEmptyMipdRemoteDataSource implements MipdRemoteDataSource {
  const _FakeEmptyMipdRemoteDataSource();

  @override
  Future<List<MipdSyncResult>> syncMarkings(
    Map<String, dynamic> payload,
  ) async => const [];

  @override
  Future<String> uploadPhoto({
    required String deviceId,
    required String localId,
    required String localPath,
  }) async => '';
}

class _FakeEmptySprayingRemoteDataSource implements SprayingRemoteDataSource {
  const _FakeEmptySprayingRemoteDataSource();

  @override
  Future<SprayingSyncResult> syncSprayingOperation(
    Map<String, dynamic> payload,
  ) async {
    return SprayingSyncResult(
      fieldOperationId: '',
      routeId: '',
      trackPointsCount: 0,
      inputsCount: 0,
      confirmedPlantsCount: 0,
      syncedAt: DateTime.now().toUtc(),
    );
  }

  @override
  Future<List<Map<String, dynamic>>> recalculateAffectedPlants({
    required Map<String, dynamic> geojson,
    String? zoneId,
    double maxDistanceMeters = 9.0,
  }) async => const [];
}

class FakeEmptyRemoteDataSource implements InspectionRemoteDataSource {
  @override
  Future<List<OccurrenceType>> fetchOccurrenceTypes() async => const [];

  @override
  Future<List<InspectionPlant>> fetchPlants({int pageSize = 1000}) async =>
      const [];

  @override
  Future<Map<String, Set<String>>> fetchOpenOccurrences(
    List<String> plantIds, {
    int batchSize = 500,
  }) async => const {};

  @override
  Future<InspectionSnapshot> fetchSnapshot({int pageSize = 1000}) async =>
      InspectionSnapshot(
        plants: const [],
        types: const [],
        loadedAt: DateTime.now(),
      );

  @override
  Future<InspectionSyncResult> syncInspection(
    Map<String, dynamic> payload,
  ) async => const InspectionSyncResult(
    operationId: '',
    created: 0,
    updated: 0,
    resolved: 0,
  );

  @override
  Future<List<AddedPlantSyncResult>> syncAddedPlants(
    Map<String, dynamic> payload,
  ) async => const [];
}
