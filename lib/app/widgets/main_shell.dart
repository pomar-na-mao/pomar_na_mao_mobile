import 'package:flutter/material.dart';

import '../../core/di/app_scope.dart';
import '../../features/about/presentation/about_view.dart';
import '../../features/farm/presentation/farm_map_view.dart';
import '../../features/farm/presentation/farm_map_view_model.dart';
import '../../features/inventory/presentation/inventory_view.dart';
import '../../features/inventory/presentation/inventory_view_model.dart';
import '../../features/operations/presentation/inspection_view.dart';
import '../../features/operations/presentation/inspection_view_model.dart';
import '../../features/operations/presentation/operations_view.dart';

import '../../core/ui/app_loading_controller.dart';
import '../../core/ui/map_activity.dart';

class MainShell extends StatefulWidget {
  const MainShell({
    this.farmMapViewModel,
    this.inventoryViewModel,
    this.inspectionViewModel,
    this.loadingController,
    this.inspectionMapBuilder,
    super.key,
  });

  final FarmMapViewModel? farmMapViewModel;
  final InventoryViewModel? inventoryViewModel;
  final InspectionViewModel? inspectionViewModel;
  final AppLoadingController? loadingController;
  final InspectionMapBuilder? inspectionMapBuilder;

  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  var _selectedIndex = 0;
  var _farmOpened = false;
  final _operationsNavigatorKey = GlobalKey<NavigatorState>();

  @override
  Widget build(BuildContext context) {
    final scopeDeps = AppScope.maybeOf(context);
    final effectiveInventoryVm =
        widget.inventoryViewModel ?? scopeDeps?.inventoryViewModel;
    final effectiveFarmVm =
        widget.farmMapViewModel ?? scopeDeps?.farmMapViewModel;
    final effectiveInspectionVm =
        widget.inspectionViewModel ?? scopeDeps?.inspectionViewModel;
    final effectiveLoadingController =
        widget.loadingController ?? scopeDeps?.loadingController;

    return PopScope(
      canPop:
          _selectedIndex != 2 ||
          !(_operationsNavigatorKey.currentState?.canPop() ?? false),
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) {
          _operationsNavigatorKey.currentState?.maybePop();
        }
      },
      child: Stack(
        children: [
          Scaffold(
            body: SafeArea(
              bottom: false,
              child: IndexedStack(
                index: _selectedIndex,
                children: [
                  if (effectiveInventoryVm != null)
                    MapActivity(
                      active: _selectedIndex == 0,
                      child: InventoryView(viewModel: effectiveInventoryVm),
                    )
                  else
                    const SizedBox.expand(),
                  if (_farmOpened && effectiveFarmVm != null)
                    MapActivity(
                      active: _selectedIndex == 1,
                      child: FarmMapView(viewModel: effectiveFarmVm),
                    )
                  else
                    const SizedBox.expand(),
                  MapActivity(
                    active: _selectedIndex == 2,
                    child: Navigator(
                      key: _operationsNavigatorKey,
                      onGenerateRoute: (settings) {
                        return MaterialPageRoute<void>(
                          builder: (_) => OperationsView(
                            inspectionViewModel: effectiveInspectionVm,
                            inspectionMapBuilder: widget.inspectionMapBuilder,
                          ),
                          settings: settings,
                        );
                      },
                    ),
                  ),
                  const AboutView(),
                ],
              ),
            ),
            bottomNavigationBar: NavigationBar(
              selectedIndex: _selectedIndex,
              onDestinationSelected: (index) {
                if (index != 2) {
                  effectiveInspectionVm?.pauseLocation();
                }
                setState(() {
                  _selectedIndex = index;
                  _farmOpened = _farmOpened || index == 1;
                });
              },
              destinations: const [
                NavigationDestination(
                  icon: Icon(Icons.inventory_2_outlined),
                  selectedIcon: Icon(Icons.inventory_2),
                  label: 'Inventário',
                ),
                NavigationDestination(
                  icon: Icon(Icons.eco_outlined),
                  selectedIcon: Icon(Icons.eco),
                  label: 'Fazenda',
                ),
                NavigationDestination(
                  icon: Icon(Icons.grid_view_outlined),
                  selectedIcon: Icon(Icons.grid_view),
                  label: 'Operações',
                ),
                NavigationDestination(
                  icon: Icon(Icons.info_outline),
                  selectedIcon: Icon(Icons.info),
                  label: 'Sobre',
                ),
              ],
            ),
          ),
          if (effectiveLoadingController != null)
            ListenableBuilder(
              listenable: effectiveLoadingController,
              builder: (context, _) {
                if (!effectiveLoadingController.isLoading) {
                  return const SizedBox.shrink();
                }

                return const Positioned(
                  top: 0,
                  left: 0,
                  right: 0,
                  child: IgnorePointer(child: LinearProgressIndicator()),
                );
              },
            ),
        ],
      ),
    );
  }
}
