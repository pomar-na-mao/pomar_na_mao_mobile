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
import '../../features/operations/data/inspection_local_store.dart';
import '../../features/operations/data/inspection_remote_data_source.dart';
import '../../features/operations/data/inspection_repository.dart';
import '../../features/operations/domain/inspection_models.dart';
import '../../features/operations/presentation/inspection_view_model.dart';
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
    this.sharedReadRepository,
    InventoryViewModel? inventoryViewModel,
    FarmMapViewModel? farmMapViewModel,
    InspectionViewModel? inspectionViewModel,
  }) : loadingController = loadingController ?? AppLoadingController(),
       _injectedInspectionRepository = inspectionRepository,
       _injectedInventoryViewModel = inventoryViewModel,
       _injectedFarmMapViewModel = farmMapViewModel,
       _injectedInspectionViewModel = inspectionViewModel;

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
    final sharedReadRepo = SharedReadRepository(
      localStore: inspStore,
      farmRemoteDataSource: farmRemote,
      inspectionRemoteDataSource: inspRemote,
      loadingController: loadingController,
    );
    final farmRepo = SupabaseFarmRepository.fromShared(sharedReadRepo);
    final plantsRepo = SupabasePlantsRepository.fromShared(sharedReadRepo);
    final zonesRepo = SupabaseZonesRepository.fromShared(sharedReadRepo);
    final inventoryRepo = SupabaseInventoryRepository(supabaseClient);
    final inventoryFarmRepo = SupabaseFarmRepository(supabaseClient);
    final inventoryZonesRepo = SupabaseZonesRepository(supabaseClient);
    final inspRepo = DefaultInspectionRepository(
      localStore: inspStore,
      remoteDataSource: inspRemote,
      sharedReadRepository: sharedReadRepo,
      loadingController: loadingController,
    );

    return AppDependencies(
      farmRepository: farmRepo,
      plantsRepository: plantsRepo,
      zonesRepository: zonesRepo,
      inventoryRepository: inventoryRepo,
      locationService: locService,
      loadingController: loadingController,
      inspectionDatabase: inspDb,
      sharedReadRepository: sharedReadRepo,
      inspectionRepository: inspRepo,
      inventoryViewModel: InventoryViewModel(
        inventoryRepo,
        inventoryFarmRepo,
        inventoryZonesRepo,
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
  final SharedReadRepository? sharedReadRepository;
  final InspectionRepository? _injectedInspectionRepository;

  InspectionRepository get inspectionRepository =>
      _injectedInspectionRepository ??
      DefaultInspectionRepository(
        localStore: InspectionLocalStore(
          inspectionDatabase ?? InspectionDatabase(projectUrl: ''),
        ),
        remoteDataSource: FakeEmptyRemoteDataSource(),
      );

  final InventoryViewModel? _injectedInventoryViewModel;
  final FarmMapViewModel? _injectedFarmMapViewModel;
  final InspectionViewModel? _injectedInspectionViewModel;

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
        locationService,
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

  /// Libera recursos e encerra listeners dos ViewModels criados.
  void dispose() {
    inventoryViewModel.dispose();
    farmMapViewModel.dispose();
    inspectionViewModel.dispose();
    unawaited(sharedReadRepository?.dispose());
    unawaited(inspectionDatabase?.close());
  }
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
}
