import 'package:flutter/material.dart';

import '../farm_map_view_model.dart';
import 'farm_zone_filter_modal.dart';

class FarmActionCard extends StatelessWidget {
  const FarmActionCard({
    required this.viewModel,
    super.key,
  });

  final FarmMapViewModel viewModel;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isFiltered = viewModel.selectedZoneId != null;
    final isLoading = viewModel.plantsStatus == PlantsLoadStatus.loading;

    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 480),
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: colorScheme.surface,
                borderRadius: BorderRadius.circular(24),
                border: Border.all(
                  color: colorScheme.outlineVariant.withValues(alpha: 0.6),
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.06),
                    blurRadius: 14,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                child: Row(
                  children: [
                    // Botão 1: Carregar plantas (Blue / Ocean tone)
                    Expanded(
                      child: _ActionButton(
                        key: const ValueKey('action-farm-load-plants'),
                        tooltip: 'Carregar plantas',
                        backgroundColor: const Color(0xFFE0F2FE),
                        borderColor: const Color(0xFFBAE6FD),
                        iconColor: const Color(0xFF0284C7),
                        icon: isLoading
                            ? const SizedBox(
                                width: 22,
                                height: 22,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2.5,
                                  color: Color(0xFF0284C7),
                                ),
                              )
                            : const Icon(Icons.cloud_download_outlined, size: 24),
                        onPressed: isLoading
                            ? null
                            : () => viewModel.loadFarmData(),
                      ),
                    ),
                    const SizedBox(width: 10),

                    // Botão 2: Filtro por Zona (Amber / Orange tone)
                    Expanded(
                      child: _ActionButton(
                        key: const ValueKey('action-farm-filter-zone'),
                        tooltip: 'Filtrar por zona',
                        backgroundColor: const Color(0xFFFEF3C7),
                        borderColor: isFiltered
                            ? const Color(0xFFD97706)
                            : const Color(0xFFFDE68A),
                        iconColor: const Color(0xFFD97706),
                        icon: Badge(
                          isLabelVisible: isFiltered,
                          smallSize: 8,
                          backgroundColor: const Color(0xFFD97706),
                          child: const Icon(Icons.tune_rounded, size: 24),
                        ),
                        onPressed: () => FarmZoneFilterModal.show(context, viewModel),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _ActionButton extends StatelessWidget {
  const _ActionButton({
    required this.icon,
    required this.tooltip,
    required this.backgroundColor,
    required this.borderColor,
    required this.iconColor,
    this.onPressed,
    super.key,
  });

  final Widget icon;
  final String tooltip;
  final Color backgroundColor;
  final Color borderColor;
  final Color iconColor;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: Material(
        color: backgroundColor,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: borderColor, width: 1.5),
        ),
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: onPressed,
          child: SizedBox(
            height: 52,
            child: Center(
              child: IconTheme(
                data: IconThemeData(color: iconColor),
                child: icon,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
