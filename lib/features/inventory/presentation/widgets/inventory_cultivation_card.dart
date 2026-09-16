import 'package:flutter/material.dart';

import '../../domain/inventory_property_profile.dart';
import 'inventory_dashboard_card.dart';

class InventoryCultivationCard extends StatelessWidget {
  const InventoryCultivationCard({required this.profile, super.key});

  final InventoryPropertyProfile profile;

  @override
  Widget build(BuildContext context) {
    final items = [
      _DetailData(Icons.straighten_outlined, 'Espaçamento', profile.spacing),
      _DetailData(
        Icons.grid_view_outlined,
        'Classificação',
        profile.classification,
      ),
      _DetailData(Icons.scatter_plot_outlined, 'Adensamento', profile.density),
      _DetailData(Icons.spa_outlined, 'Variedade', profile.variety),
    ];

    return InventoryDashboardCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const InventorySectionTitle(
            title: 'Configuração do cultivo',
            subtitle: 'Parâmetros agronômicos da propriedade',
          ),
          const SizedBox(height: 14),
          LayoutBuilder(
            builder: (context, constraints) {
              final wide = constraints.maxWidth >= 600;
              final itemWidth = wide
                  ? (constraints.maxWidth - 12) / 2
                  : constraints.maxWidth;
              return Wrap(
                spacing: 12,
                runSpacing: 12,
                children: [
                  for (final item in items)
                    SizedBox(
                      width: itemWidth,
                      child: _DetailItem(data: item),
                    ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}

class _DetailData {
  const _DetailData(this.icon, this.label, this.value);

  final IconData icon;
  final String label;
  final String value;
}

class _DetailItem extends StatelessWidget {
  const _DetailItem({required this.data});

  final _DetailData data;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAF7),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE1E9DF)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(data.icon, color: const Color(0xFF3C6E47), size: 23),
            const SizedBox(width: 11),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    data.label,
                    style: Theme.of(context).textTheme.labelMedium?.copyWith(
                          color: const Color(0xFF5F6F64),
                          fontWeight: FontWeight.w700,
                        ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    data.value,
                    style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                          color: const Color(0xFF173326),
                          fontWeight: FontWeight.w800,
                          height: 1.25,
                        ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
