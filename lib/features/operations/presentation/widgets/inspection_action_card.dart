import 'package:flutter/material.dart';

import '../inspection_view_model.dart';
import 'inspection_filters_modal.dart';
import 'local_inspections_modal.dart';

class InspectionActionCard extends StatelessWidget {
  const InspectionActionCard({
    required this.viewModel,
    super.key,
  });

  final InspectionViewModel viewModel;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

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
                    // Button 1: Carregar plantas (Blue / Ocean tone)
                    Expanded(
                      child: _ActionButton(
                        key: const ValueKey('action-load-plants'),
                        tooltip: 'Carregar plantas',
                        backgroundColor: const Color(0xFFE0F2FE),
                        borderColor: const Color(0xFFBAE6FD),
                        iconColor: const Color(0xFF0284C7),
                        icon: viewModel.loadStatus == InspectionLoadStatus.loading
                            ? const SizedBox(
                                width: 22,
                                height: 22,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2.5,
                                  color: Color(0xFF0284C7),
                                ),
                              )
                            : const Icon(Icons.cloud_download_outlined, size: 24),
                        onPressed: viewModel.loadStatus == InspectionLoadStatus.loading
                            ? null
                            : () => viewModel.loadPlants(),
                      ),
                    ),
                    const SizedBox(width: 10),

                    // Button 2: Filtros (Amber / Orange tone)
                    Expanded(
                      child: KeyedSubtree(
                        key: const ValueKey('action-occurrences'),
                        child: _ActionButton(
                          key: const ValueKey('action-filters'),
                          tooltip: 'Filtros',
                          backgroundColor: const Color(0xFFFEF3C7),
                          borderColor: viewModel.isFiltered
                              ? const Color(0xFFD97706)
                              : const Color(0xFFFDE68A),
                          iconColor: const Color(0xFFD97706),
                          icon: Badge(
                            isLabelVisible: viewModel.isFiltered,
                            smallSize: 8,
                            backgroundColor: const Color(0xFFD97706),
                            child: const Icon(Icons.tune_rounded, size: 24),
                          ),
                          onPressed: () => InspectionFiltersModal.show(context, viewModel),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),

                    // Button 3: Inspeções salvas (Purple / Violet tone)
                    Expanded(
                      child: _ActionButton(
                        key: const ValueKey('action-saved-inspections'),
                        tooltip: 'Inspeções salvas',
                        backgroundColor: const Color(0xFFEDE9FE),
                        borderColor: const Color(0xFFDDD6FE),
                        iconColor: const Color(0xFF7C3AED),
                        icon: const Icon(Icons.folder_outlined, size: 24),
                        onPressed: () => LocalInspectionsModal.show(context, viewModel),
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
    required this.onPressed,
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
    final isEnabled = onPressed != null;

    return Tooltip(
      message: tooltip,
      child: Material(
        color: isEnabled ? backgroundColor : backgroundColor.withValues(alpha: 0.4),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(
            color: isEnabled ? borderColor : borderColor.withValues(alpha: 0.4),
            width: 1.5,
          ),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onPressed,
          splashColor: iconColor.withValues(alpha: 0.15),
          highlightColor: iconColor.withValues(alpha: 0.08),
          child: Semantics(
            button: true,
            label: tooltip,
            enabled: isEnabled,
            child: ConstrainedBox(
              constraints: const BoxConstraints(minHeight: 52, minWidth: 48),
              child: Center(
                child: IconTheme(
                  data: IconThemeData(color: iconColor, size: 24),
                  child: icon,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
