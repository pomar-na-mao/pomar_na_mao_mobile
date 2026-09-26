import 'dart:async';

import 'package:flutter/material.dart';

import '../../../core/config/app_config.dart';
import 'inventory_view_model.dart';
import 'widgets/inventory_cultivation_card.dart';
import 'widgets/inventory_map_section.dart';
import 'widgets/inventory_metrics_grid.dart';
import 'widgets/inventory_summary_header.dart';

export 'widgets/inventory_dashboard_card.dart' show formatInventoryCount;
export 'widgets/inventory_map_section.dart' show InventoryMapBuilder;

class InventoryView extends StatefulWidget {
  InventoryView({
    required this.viewModel,
    this.mapBuilder,
    String? fruitAssetPath,
    super.key,
  }) : fruitAssetPath =
           fruitAssetPath ?? AppConfig.activeTenant.fruitAssetPath;

  final InventoryViewModel viewModel;
  final InventoryMapBuilder? mapBuilder;
  final String fruitAssetPath;

  @override
  State<InventoryView> createState() => _InventoryViewState();
}

class _InventoryViewState extends State<InventoryView> {
  static const _backgroundColor = Color(0xFFF4F7F2);

  @override
  void initState() {
    super.initState();
    unawaited(widget.viewModel.initialize());
  }

  @override
  void didUpdateWidget(covariant InventoryView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.viewModel != widget.viewModel) {
      unawaited(widget.viewModel.initialize());
    }
  }

  Future<void> _refresh() => Future.wait([
    widget.viewModel.loadSummary(),
    widget.viewModel.loadMapData(),
  ]);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _backgroundColor,
      appBar: AppBar(
        backgroundColor: _backgroundColor,
        surfaceTintColor: Colors.transparent,
        leading: const Icon(Icons.inventory_2_outlined),
        title: const Text('Inventário'),
      ),
      body: RefreshIndicator(
        onRefresh: _refresh,
        child: LayoutBuilder(
          builder: (context, constraints) {
            final horizontalPadding = constraints.maxWidth >= 720 ? 28.0 : 16.0;
            return SingleChildScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: EdgeInsets.fromLTRB(
                horizontalPadding,
                8,
                horizontalPadding,
                32,
              ),
              child: Align(
                alignment: Alignment.topCenter,
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 960),
                  child: ListenableBuilder(
                    listenable: widget.viewModel,
                    builder: (context, _) {
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          InventorySummaryHeader(
                            key: const ValueKey('inventory-property-hero'),
                            profile: widget.viewModel.profile,
                            fruitAssetPath: widget.fruitAssetPath,
                          ),
                          const SizedBox(height: 18),
                          InventoryMetricsGrid(viewModel: widget.viewModel),
                          const SizedBox(height: 18),
                          InventoryCultivationCard(
                            key: const ValueKey('inventory-cultivation-card'),
                            profile: widget.viewModel.profile,
                          ),
                          const SizedBox(height: 18),
                          InventoryMapSection(
                            key: const ValueKey('inventory-map-card'),
                            viewModel: widget.viewModel,
                            mapBuilder: widget.mapBuilder,
                          ),
                        ],
                      );
                    },
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}
