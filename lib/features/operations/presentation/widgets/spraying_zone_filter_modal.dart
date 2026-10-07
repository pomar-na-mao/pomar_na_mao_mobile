import 'dart:async';

import 'package:flutter/material.dart';

import '../../../farm/domain/zone.dart';
import '../spraying_view_model.dart';

class SprayingZoneFilterModal extends StatefulWidget {
  const SprayingZoneFilterModal({required this.viewModel, super.key});

  final SprayingViewModel viewModel;

  static Future<void> show(
    BuildContext context,
    SprayingViewModel viewModel,
  ) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => SprayingZoneFilterModal(viewModel: viewModel),
    );
  }

  @override
  State<SprayingZoneFilterModal> createState() =>
      _SprayingZoneFilterModalState();
}

class _SprayingZoneFilterModalState extends State<SprayingZoneFilterModal> {
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
    final vm = widget.viewModel;
    final screenHeight = MediaQuery.sizeOf(context).height;
    final sheetHeight = (screenHeight * 0.78).clamp(520.0, 780.0);

    return ListenableBuilder(
      listenable: vm,
      builder: (context, _) {
        final zones = vm.zones;
        final isFiltered = vm.isFiltered;
        final selectedZoneId = vm.selectedZoneFilterId;

        final validSelectedZoneId = zones.any((z) => z.id == selectedZoneId)
            ? selectedZoneId
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
                  // HEADER (Fixo no topo)
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
                                '${vm.displayedPlants.length} de ${vm.allPlants.length} plantas visíveis',
                                style: theme.textTheme.bodySmall?.copyWith(
                                  color: colorScheme.outline,
                                ),
                              ),
                            ],
                          ),
                        ),
                        if (isFiltered)
                          TextButton(
                            key: const ValueKey('clear-zone-filter-button'),
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

                  // SEÇÃO: Dropdown de Zonas
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
                              key: const ValueKey('spraying-filter-zone-dropdown'),
                              value: validSelectedZoneId,
                              isExpanded: true,
                              hint: Text(
                                zones.isEmpty
                                    ? 'Todas as zonas'
                                    : 'Selecione a zona',
                              ),
                              items: [
                                const DropdownMenuItem<String?>(
                                  value: null,
                                  child: Text('Todas as zonas'),
                                ),
                                ...zones.map((Zone z) {
                                  return DropdownMenuItem<String?>(
                                    value: z.id,
                                    child: Text(
                                      z.name,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  );
                                }),
                              ],
                              onChanged: (newZoneId) {
                                vm.setZoneFilter(newZoneId);
                              },
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                  const Spacer(),

                  // FOOTER: Botão Ver no mapa
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
                    child: FilledButton.icon(
                      key: const ValueKey('apply-zone-filter-button'),
                      icon: const Icon(Icons.map_outlined),
                      label: Text(
                        'Ver no mapa (${vm.displayedPlants.length} plantas)',
                      ),
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
