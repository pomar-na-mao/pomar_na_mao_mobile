import 'dart:async';

import 'package:flutter/material.dart';

import '../../../farm/domain/zone.dart';
import '../activity_view_model.dart';

class ActivityZoneFilterModal extends StatefulWidget {
  const ActivityZoneFilterModal({required this.viewModel, super.key});

  final ActivityViewModel viewModel;

  static Future<void> show(BuildContext context, ActivityViewModel viewModel) =>
      showModalBottomSheet<void>(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        builder: (_) => ActivityZoneFilterModal(viewModel: viewModel),
      );

  @override
  State<ActivityZoneFilterModal> createState() =>
      _ActivityZoneFilterModalState();
}

class _ActivityZoneFilterModalState extends State<ActivityZoneFilterModal> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (widget.viewModel.zones.isEmpty) {
        unawaited(widget.viewModel.loadZones());
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final screenHeight = MediaQuery.sizeOf(context).height;
    final sheetHeight = (screenHeight * 0.78).clamp(520.0, 780.0);

    return ListenableBuilder(
      listenable: widget.viewModel,
      builder: (context, _) {
        final vm = widget.viewModel;
        final selectedId =
            vm.zones.any((zone) => zone.id == vm.selectedZoneFilterId)
            ? vm.selectedZoneFilterId
            : null;

        return Material(
          color: colorScheme.surface,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          clipBehavior: Clip.antiAlias,
          child: SizedBox(
            height: sheetHeight,
            child: SafeArea(
              top: false,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 14, 12, 8),
                    child: Row(
                      children: [
                        Icon(
                          Icons.tune_rounded,
                          color: colorScheme.primary,
                          size: 24,
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Filtros de Plantas',
                                style: theme.textTheme.titleLarge?.copyWith(
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              Text(
                                '${vm.plants.length} de ${vm.allPlants.length} plantas visíveis',
                                style: theme.textTheme.bodySmall?.copyWith(
                                  color: colorScheme.outline,
                                ),
                              ),
                            ],
                          ),
                        ),
                        if (vm.isFiltered)
                          TextButton(
                            key: const ValueKey(
                              'activity-clear-zone-filter-button',
                            ),
                            onPressed: () => vm.setZoneFilter(null),
                            child: const Text('Limpar'),
                          ),
                        IconButton(
                          icon: const Icon(Icons.close),
                          tooltip: 'Fechar',
                          onPressed: () => Navigator.of(context).pop(),
                        ),
                      ],
                    ),
                  ),
                  const Divider(height: 1),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 14, 20, 4),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Text(
                          'Zona',
                          style: theme.textTheme.labelLarge?.copyWith(
                            fontWeight: FontWeight.bold,
                            color: colorScheme.onSurface,
                          ),
                        ),
                        const SizedBox(height: 6),
                        InputDecorator(
                          decoration: InputDecoration(
                            prefixIcon: const Icon(Icons.grid_view_rounded),
                            filled: true,
                            fillColor: colorScheme.surfaceContainerHighest
                                .withValues(alpha: 0.35),
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 14,
                              vertical: 4,
                            ),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(14),
                              borderSide: BorderSide(
                                color: colorScheme.outlineVariant,
                              ),
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(14),
                              borderSide: BorderSide(
                                color: colorScheme.outlineVariant,
                              ),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(14),
                              borderSide: BorderSide(
                                color: colorScheme.primary,
                                width: 2,
                              ),
                            ),
                          ),
                          child: DropdownButtonHideUnderline(
                            child: DropdownButton<String?>(
                              key: const ValueKey(
                                'activity-filter-zone-dropdown',
                              ),
                              value: selectedId,
                              isExpanded: true,
                              hint: Text(
                                vm.zones.isEmpty
                                    ? 'Todas as zonas'
                                    : 'Selecione a zona',
                              ),
                              items: [
                                const DropdownMenuItem<String?>(
                                  value: null,
                                  child: Text('Todas as zonas'),
                                ),
                                ...vm.zones.map(
                                  (Zone zone) => DropdownMenuItem<String?>(
                                    value: zone.id,
                                    child: Text(
                                      zone.name,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                ),
                              ],
                              onChanged: vm.setZoneFilter,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const Spacer(),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
                    child: FilledButton.icon(
                      key: const ValueKey('activity-apply-zone-filter-button'),
                      icon: const Icon(Icons.map_outlined),
                      label: Text('Ver no mapa (${vm.plants.length} plantas)'),
                      style: FilledButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
