import 'package:flutter/material.dart';

import 'inventory_dashboard_card.dart';

class InventoryMetricCard extends StatelessWidget {
  const InventoryMetricCard({
    required this.label,
    required this.value,
    required this.isLoading,
    required this.icon,
    required this.accent,
    required this.tint,
    super.key,
  });

  final String label;
  final int? value;
  final bool isLoading;
  final IconData icon;
  final Color accent;
  final Color tint;

  @override
  Widget build(BuildContext context) {
    final valueLabel =
        isLoading ? 'Carregando' : formatInventoryCount(value ?? 0);
    return Semantics(
      container: true,
      label: '$label: $valueLabel',
      child: InventoryDashboardCard(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: tint,
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(icon, color: accent, size: 26),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: ExcludeSemantics(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (isLoading)
                      const Padding(
                        padding: EdgeInsets.symmetric(vertical: 5),
                        child: SizedBox(
                          width: 24,
                          height: 24,
                          child: CircularProgressIndicator(strokeWidth: 2.5),
                        ),
                      )
                    else
                      Text(
                        valueLabel,
                        style: Theme.of(context)
                            .textTheme
                            .headlineMedium
                            ?.copyWith(
                              color: const Color(0xFF173326),
                              fontWeight: FontWeight.w900,
                            ),
                      ),
                    const SizedBox(height: 3),
                    Text(
                      label,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: const Color(0xFF5F6F64),
                            fontWeight: FontWeight.w600,
                            height: 1.25,
                          ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
