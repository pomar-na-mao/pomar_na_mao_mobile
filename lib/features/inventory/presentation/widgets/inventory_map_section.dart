import 'package:flutter/material.dart';

import '../../../farm/domain/farm_point.dart';
import '../../../farm/domain/region_point.dart';
import '../../../farm/presentation/farm_map_geometry.dart';
import '../inventory_map.dart';
import '../inventory_view_model.dart';
import 'inventory_dashboard_card.dart';
import 'inventory_status_banner.dart';

typedef InventoryMapBuilder = Widget Function(
  BuildContext context,
  List<FarmPoint> farmPoints,
  Map<String, List<RegionPoint>> zonePointsById,
);

class InventoryMapSection extends StatelessWidget {
  const InventoryMapSection({
    required this.viewModel,
    this.mapBuilder,
    super.key,
  });

  final InventoryViewModel viewModel;
  final InventoryMapBuilder? mapBuilder;

  @override
  Widget build(BuildContext context) {
    final loading =
        viewModel.mapStatus == InventoryLoadStatus.initial ||
        viewModel.mapStatus == InventoryLoadStatus.loading;
    final error = viewModel.mapStatus == InventoryLoadStatus.error;

    return InventoryDashboardCard(
      padding: const EdgeInsets.fromLTRB(18, 18, 18, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const InventorySectionTitle(
            title: 'Mapa da propriedade',
            subtitle: 'Fazenda e zonas de cultivo',
          ),
          const SizedBox(height: 12),
          const Wrap(
            spacing: 16,
            runSpacing: 8,
            children: [
              _MapLegend(color: farmBoundaryStrokeColor, label: 'Fazenda'),
              _MapLegend(
                color: zoneBoundaryStrokeColor,
                label: 'Zonas A–G',
                dotted: true,
              ),
            ],
          ),
          if (!error && viewModel.mapMessage != null) ...[
            const SizedBox(height: 12),
            InventoryMapNotice(
              message: viewModel.mapMessage!,
              onRetry: viewModel.loadMapData,
            ),
          ],
          const SizedBox(height: 12),
          SizedBox(
            height: 280,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: DecoratedBox(
                decoration: const BoxDecoration(color: Color(0xFFE7ECE6)),
                child: loading
                    ? Center(
                        child: Semantics(
                          label: 'Carregando mapa da propriedade',
                          child: const CircularProgressIndicator(),
                        ),
                      )
                    : error
                    ? InventoryMapError(onRetry: viewModel.loadMapData)
                    : _buildMap(context),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMap(BuildContext context) {
    final builder = mapBuilder;
    if (builder != null) {
      return builder(
        context,
        viewModel.farmBoundaryPoints,
        viewModel.zonePointsById,
      );
    }
    return InventoryMap(
      farmPoints: viewModel.farmBoundaryPoints,
      zonePointsById: viewModel.zonePointsById,
    );
  }
}

class _MapLegend extends StatelessWidget {
  const _MapLegend({
    required this.color,
    required this.label,
    this.dotted = false,
  });

  final Color color;
  final String label;
  final bool dotted;

  @override
  Widget build(BuildContext context) {
    final colorName = color == farmBoundaryStrokeColor ? 'azul' : 'verde';
    final lineStyle = dotted ? ' pontilhado' : '';
    return Semantics(
      label: '$label, limite$lineStyle $colorName',
      child: ExcludeSemantics(
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (dotted)
              SizedBox(
                width: 18,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: List.generate(
                    4,
                    (_) => DecoratedBox(
                      decoration: BoxDecoration(
                        color: color,
                        shape: BoxShape.circle,
                      ),
                      child: const SizedBox.square(dimension: 3),
                    ),
                  ),
                ),
              )
            else
              Container(
                width: 18,
                height: 8,
                decoration: BoxDecoration(
                  color: color,
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
            const SizedBox(width: 7),
            Text(label, style: Theme.of(context).textTheme.labelLarge),
          ],
        ),
      ),
    );
  }
}
