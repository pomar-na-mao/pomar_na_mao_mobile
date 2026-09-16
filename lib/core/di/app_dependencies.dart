import 'package:supabase_flutter/supabase_flutter.dart';

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
    InventoryViewModel? inventoryViewModel,
    FarmMapViewModel? farmMapViewModel,
  })  : _injectedInventoryViewModel = inventoryViewModel,
        _injectedFarmMapViewModel = farmMapViewModel;

  factory AppDependencies.fromSupabaseClient(
    SupabaseClient supabaseClient, {
    LocationService? locationService,
  }) {
    final farmRepo = SupabaseFarmRepository(supabaseClient);
    final plantsRepo = SupabasePlantsRepository(supabaseClient);
    final zonesRepo = SupabaseZonesRepository(supabaseClient);
    final inventoryRepo = SupabaseInventoryRepository(supabaseClient);
    final locService = locationService ?? GeolocatorLocationService();

    return AppDependencies(
      farmRepository: farmRepo,
      plantsRepository: plantsRepo,
      zonesRepository: zonesRepo,
      inventoryRepository: inventoryRepo,
      locationService: locService,
    );
  }

  final FarmRepository farmRepository;
  final PlantsRepository plantsRepository;
  final ZonesRepository zonesRepository;
  final InventoryRepository inventoryRepository;
  final LocationService locationService;

  final InventoryViewModel? _injectedInventoryViewModel;
  final FarmMapViewModel? _injectedFarmMapViewModel;

  late final InventoryViewModel inventoryViewModel =
      _injectedInventoryViewModel ??
      InventoryViewModel(
        inventoryRepository,
        farmRepository,
        zonesRepository,
      );

  late final FarmMapViewModel farmMapViewModel =
      _injectedFarmMapViewModel ??
      FarmMapViewModel(
        plantsRepository,
        zonesRepository,
        locationService,
        farmRepository,
      );

  /// Libera recursos e encerra listeners dos ViewModels criados.
  void dispose() {
    inventoryViewModel.dispose();
    farmMapViewModel.dispose();
  }
}
