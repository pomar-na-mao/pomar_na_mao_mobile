import 'dart:async';

import 'package:flutter/material.dart';

import '../../../../core/di/app_scope.dart';
import '../../../farm/domain/zone.dart';
import '../inspection_view_model.dart';

class InspectionFiltersModal extends StatefulWidget {
  const InspectionFiltersModal({required this.viewModel, super.key});

  final InspectionViewModel viewModel;

  static Future<void> show(
    BuildContext context,
    InspectionViewModel viewModel,
  ) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => InspectionFiltersModal(viewModel: viewModel),
    );
  }

  @override
  State<InspectionFiltersModal> createState() => _InspectionFiltersModalState();
}

class _InspectionFiltersModalState extends State<InspectionFiltersModal> {
  late bool _isOccurrencesExpanded;

  @override
  void initState() {
    super.initState();
    _isOccurrencesExpanded =
        widget.viewModel.selectedOccurrenceFilterId != null;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      final scope = AppScope.maybeOf(context);
      if (scope?.zonesRepository != null) {
        widget.viewModel.attachZonesRepository(scope!.zonesRepository);
      }
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
        final types = vm.catalog;
        final isFiltered = vm.isFiltered;
        final selectedZoneId = vm.selectedZoneFilterId;
        final selectedOccurrence = vm.selectedOccurrenceFilter;

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
                                '${vm.plants.length} de ${vm.allPlants.length} plantas visíveis',
                                style: theme.textTheme.bodySmall?.copyWith(
                                  color: colorScheme.outline,
                                ),
                              ),
                            ],
                          ),
                        ),
                        if (isFiltered)
                          TextButton(
                            key: const ValueKey('clear-all-filters-button'),
                            onPressed: () => vm.clearAllFilters(),
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

                  // SEÇÃO FIXA: Dropdown de Zonas e Botão de Ocorrências
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 14, 20, 4),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        // SECTION 1: Dropdown de Zonas
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
                              key: const ValueKey('filter-zone-dropdown'),
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
                                vm.filterByZone(newZoneId);
                              },
                            ),
                          ),
                        ),
                        const SizedBox(height: 14),

                        // SECTION 2: Botão de Ocorrências (Expande e mostra as opções)
                        Text(
                          'Ocorrência',
                          style: theme.textTheme.labelLarge?.copyWith(
                            fontWeight: FontWeight.bold,
                            color: colorScheme.onSurface,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Material(
                          color: _isOccurrencesExpanded
                              ? colorScheme.primaryContainer.withValues(
                                  alpha: 0.25,
                                )
                              : colorScheme.surfaceContainerHighest.withValues(
                                  alpha: 0.35,
                                ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                            side: BorderSide(
                              color: _isOccurrencesExpanded
                                  ? colorScheme.primary.withValues(alpha: 0.5)
                                  : colorScheme.outlineVariant,
                            ),
                          ),
                          clipBehavior: Clip.antiAlias,
                          child: InkWell(
                            key: const ValueKey(
                              'toggle-occurrences-filter-section',
                            ),
                            onTap: () {
                              setState(() {
                                _isOccurrencesExpanded =
                                    !_isOccurrencesExpanded;
                              });
                            },
                            child: Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 14,
                                vertical: 10,
                              ),
                              child: Row(
                                children: [
                                  Icon(
                                    Icons.pest_control_outlined,
                                    color: selectedOccurrence != null
                                        ? colorScheme.primary
                                        : colorScheme.onSurfaceVariant,
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          selectedOccurrence != null
                                              ? selectedOccurrence.name
                                              : 'Todas as ocorrências',
                                          style: theme.textTheme.bodyLarge
                                              ?.copyWith(
                                                fontWeight:
                                                    selectedOccurrence != null
                                                    ? FontWeight.bold
                                                    : FontWeight.w500,
                                                color:
                                                    selectedOccurrence != null
                                                    ? colorScheme.primary
                                                    : colorScheme.onSurface,
                                              ),
                                        ),
                                        Text(
                                          _isOccurrencesExpanded
                                              ? 'Toque para recolher'
                                              : 'Toque para escolher uma ocorrência',
                                          style: theme.textTheme.bodySmall
                                              ?.copyWith(
                                                color: colorScheme.outline,
                                              ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  Icon(
                                    _isOccurrencesExpanded
                                        ? Icons.expand_less_rounded
                                        : Icons.expand_more_rounded,
                                    color: colorScheme.onSurfaceVariant,
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                  // ÁREA SCROLLÁVEL: Apenas nos itens disponíveis de ocorrência
                  if (_isOccurrencesExpanded)
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(20, 8, 20, 8),
                        child: Material(
                          color: colorScheme.surface,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                            side: BorderSide(color: colorScheme.outlineVariant),
                          ),
                          clipBehavior: Clip.antiAlias,
                          child: types.isEmpty
                              ? Padding(
                                  padding: const EdgeInsets.all(20),
                                  child: Center(
                                    child: Text(
                                      'Nenhum tipo de ocorrência disponível.',
                                      style: theme.textTheme.bodySmall
                                          ?.copyWith(
                                            color: colorScheme.onSurfaceVariant,
                                          ),
                                    ),
                                  ),
                                )
                              : ListView.separated(
                                  key: const ValueKey(
                                    'catalog-occurrences-list',
                                  ),
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 4,
                                  ),
                                  itemCount: types.length + 1,
                                  separatorBuilder: (_, _) => const Divider(
                                    height: 1,
                                    indent: 16,
                                    endIndent: 16,
                                  ),
                                  itemBuilder: (context, index) {
                                    if (index == 0) {
                                      final isAllSelected =
                                          vm.selectedOccurrenceFilterId == null;
                                      return ListTile(
                                        key: const ValueKey('catalog-type-all'),
                                        dense: true,
                                        contentPadding:
                                            const EdgeInsets.symmetric(
                                              horizontal: 16,
                                              vertical: 2,
                                            ),
                                        leading: Icon(
                                          Icons.filter_list_off_rounded,
                                          color: isAllSelected
                                              ? colorScheme.primary
                                              : colorScheme.onSurfaceVariant,
                                        ),
                                        title: Text(
                                          'Mostrar todas',
                                          style: theme.textTheme.bodyMedium
                                              ?.copyWith(
                                                fontWeight: isAllSelected
                                                    ? FontWeight.bold
                                                    : FontWeight.w600,
                                                color: isAllSelected
                                                    ? colorScheme.primary
                                                    : null,
                                              ),
                                        ),
                                        trailing: isAllSelected
                                            ? Icon(
                                                Icons.check_circle_rounded,
                                                color: colorScheme.primary,
                                                size: 18,
                                              )
                                            : null,
                                        onTap: () {
                                          vm.clearOccurrenceFilter();
                                          Navigator.of(context).pop();
                                        },
                                      );
                                    }

                                    final type = types[index - 1];
                                    final isSelected =
                                        vm.selectedOccurrenceFilterId ==
                                        type.id;
                                    final occurrencesCount = vm.allPlants
                                        .where(
                                          (p) =>
                                              p.openTypeIds.contains(type.id),
                                        )
                                        .length;

                                    return ListTile(
                                      key: ValueKey(
                                        'catalog-type-${type.code}',
                                      ),
                                      dense: true,
                                      contentPadding:
                                          const EdgeInsets.symmetric(
                                            horizontal: 16,
                                            vertical: 2,
                                          ),
                                      leading: Icon(
                                        Icons.pest_control_outlined,
                                        color: isSelected
                                            ? colorScheme.primary
                                            : colorScheme.onSurfaceVariant,
                                      ),
                                      title: Text(
                                        type.name,
                                        style: theme.textTheme.bodyMedium
                                            ?.copyWith(
                                              fontWeight: isSelected
                                                  ? FontWeight.bold
                                                  : FontWeight.w500,
                                              color: isSelected
                                                  ? colorScheme.primary
                                                  : null,
                                            ),
                                      ),
                                      subtitle: Text(
                                        '$occurrencesCount ${occurrencesCount == 1 ? "planta" : "plantas"}',
                                        style: theme.textTheme.bodySmall
                                            ?.copyWith(
                                              color: colorScheme.outline,
                                            ),
                                      ),
                                      trailing: isSelected
                                          ? Icon(
                                              Icons.check_circle_rounded,
                                              color: colorScheme.primary,
                                              size: 18,
                                            )
                                          : null,
                                      onTap: () {
                                        vm.filterByOccurrence(type.id);
                                        Navigator.of(context).pop();
                                      },
                                    );
                                  },
                                ),
                        ),
                      ),
                    )
                  else
                    const Spacer(),

                  // FOOTER: Botão Ver no mapa (Fixo na parte inferior)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
                    child: FilledButton.icon(
                      key: const ValueKey('apply-filters-button'),
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
