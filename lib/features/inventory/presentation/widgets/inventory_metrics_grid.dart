import 'package:flutter/material.dart';

import '../inventory_view_model.dart';
import 'inventory_dashboard_card.dart';
import 'inventory_metric_card.dart';
import 'inventory_status_banner.dart';

class InventoryMetricsGrid extends StatelessWidget {
  const InventoryMetricsGrid({required this.viewModel, super.key});

  final InventoryViewModel viewModel;

  @override
  Widget build(BuildContext context) {
    return Column(
      key: const ValueKey('inventory-summary-section'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const InventorySectionTitle(
          title: 'Visão geral',
          subtitle: 'Situação atual do pomar',
        ),
        const SizedBox(height: 10),
        if (viewModel.summaryStatus == InventoryLoadStatus.error)
          InventoryInlineError(
            message: 'Não foi possível carregar os totais de plantas.',
            onRetry: viewModel.loadSummary,
          )
        else
          LayoutBuilder(
            builder: (context, constraints) {
              final isLoading =
                  viewModel.summaryStatus == InventoryLoadStatus.initial ||
                  viewModel.summaryStatus == InventoryLoadStatus.loading;
              final cards = [
                InventoryMetricCard(
                  label: 'Plantas existentes',
                  value: viewModel.summary?.existingPlants,
                  isLoading: isLoading,
                  icon: Icons.park_outlined,
                  accent: const Color(0xFF3C6E47),
                  tint: const Color(0xFFE2F0E2),
                ),
                InventoryMetricCard(
                  label: 'Disponíveis para plantio',
                  value: viewModel.summary?.availablePlantingSpots,
                  isLoading: isLoading,
                  icon: Icons.add_location_alt_outlined,
                  accent: const Color(0xFF9A6111),
                  tint: const Color(0xFFFFF0D5),
                ),
                InventoryMetricCard(
                  label: 'Zonas mapeadas',
                  value: viewModel.summary?.zones,
                  isLoading: isLoading,
                  icon: Icons.grid_4x4_outlined,
                  accent: const Color(0xFF245D6B),
                  tint: const Color(0xFFDFF2F4),
                ),
                InventoryMetricCard(
                  label: 'Pontos de limites',
                  value: viewModel.summary != null
                      ? viewModel.summary!.regionPoints +
                          viewModel.summary!.farmBoundaryPoints
                      : null,
                  isLoading: isLoading,
                  icon: Icons.place_outlined,
                  accent: const Color(0xFF6B245D),
                  tint: const Color(0xFFF4DFEF),
                ),
              ];

              if (constraints.maxWidth >= 760) {
                return Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    for (var index = 0; index < cards.length; index++) ...[
                      if (index > 0) const SizedBox(width: 12),
                      Expanded(child: cards[index]),
                    ],
                  ],
                );
              }
              if (constraints.maxWidth >= 540) {
                return Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  children: [
                    for (final card in cards)
                      SizedBox(
                        width: (constraints.maxWidth - 12) / 2,
                        child: card,
                      ),
                  ],
                );
              }
              return Column(
                children: [
                  for (var index = 0; index < cards.length; index++) ...[
                    if (index > 0) const SizedBox(height: 12),
                    cards[index],
                  ],
                ],
              );
            },
          ),
      ],
    );
  }
}
