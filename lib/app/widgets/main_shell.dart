import 'package:flutter/material.dart';

import '../../core/di/app_scope.dart';
import '../../features/about/presentation/about_view.dart';
import '../../features/farm/presentation/farm_map_view.dart';
import '../../features/farm/presentation/farm_map_view_model.dart';
import '../../features/inventory/presentation/inventory_view.dart';
import '../../features/inventory/presentation/inventory_view_model.dart';

class MainShell extends StatefulWidget {
  const MainShell({
    this.farmMapViewModel,
    this.inventoryViewModel,
    super.key,
  });

  final FarmMapViewModel? farmMapViewModel;
  final InventoryViewModel? inventoryViewModel;

  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  var _selectedIndex = 0;
  var _farmOpened = false;

  @override
  Widget build(BuildContext context) {
    final scopeDeps = AppScope.maybeOf(context);
    final effectiveInventoryVm = widget.inventoryViewModel ?? scopeDeps?.inventoryViewModel;
    final effectiveFarmVm = widget.farmMapViewModel ?? scopeDeps?.farmMapViewModel;

    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: IndexedStack(
          index: _selectedIndex,
          children: [
            if (effectiveInventoryVm != null)
              InventoryView(viewModel: effectiveInventoryVm)
            else
              const SizedBox.expand(),
            if (_farmOpened && effectiveFarmVm != null)
              FarmMapView(viewModel: effectiveFarmVm)
            else
              const SizedBox.expand(),
            const AboutView(),
          ],
        ),
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _selectedIndex,
        onDestinationSelected: (index) {
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
            icon: Icon(Icons.info_outline),
            selectedIcon: Icon(Icons.info),
            label: 'Sobre',
          ),
        ],
      ),
    );
  }
}
