import 'package:flutter/material.dart';

import '../core/di/app_dependencies.dart';
import '../core/di/app_scope.dart';
import '../features/farm/presentation/farm_map_view_model.dart';
import '../features/inventory/presentation/inventory_view_model.dart';
import 'widgets/main_shell.dart';
import 'widgets/splash_screen.dart';

class PomarNaMaoApp extends StatefulWidget {
  const PomarNaMaoApp({
    this.dependencies,
    this.farmMapViewModel,
    this.inventoryViewModel,
    super.key,
  });

  final AppDependencies? dependencies;
  final FarmMapViewModel? farmMapViewModel;
  final InventoryViewModel? inventoryViewModel;

  @override
  State<PomarNaMaoApp> createState() => _PomarNaMaoAppState();
}

class _PomarNaMaoAppState extends State<PomarNaMaoApp> {
  var _showSplash = true;

  void _hideSplash() {
    if (!mounted || !_showSplash) return;
    setState(() => _showSplash = false);
  }

  @override
  Widget build(BuildContext context) {
    final farmVm = widget.farmMapViewModel ?? widget.dependencies?.farmMapViewModel;
    final inventoryVm = widget.inventoryViewModel ?? widget.dependencies?.inventoryViewModel;

    Widget app = MaterialApp(
      title: 'Pomar na mão',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF3C6E47)),
        useMaterial3: true,
      ),
      home: AnimatedSwitcher(
        duration: const Duration(milliseconds: 350),
        child: _showSplash
            ? SplashScreen(
                key: const ValueKey('splash'),
                onFinished: _hideSplash,
              )
            : MainShell(
                key: const ValueKey('main-shell'),
                farmMapViewModel: farmVm,
                inventoryViewModel: inventoryVm,
              ),
      ),
    );

    if (widget.dependencies case final deps?) {
      return AppScope(
        dependencies: deps,
        child: app,
      );
    }
    return app;
  }
}
