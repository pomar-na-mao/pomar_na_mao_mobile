import 'package:flutter/material.dart';

import '../../domain/spraying_models.dart';
import '../spraying_view_model.dart';
import 'spraying_inputs_modal.dart';

class SprayingReviewModal extends StatefulWidget {
  const SprayingReviewModal({required this.viewModel, super.key});

  final SprayingViewModel viewModel;

  static Future<void> show(BuildContext context, SprayingViewModel vm) {
    final maxHeight = MediaQuery.sizeOf(context).height * 0.75;
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      constraints: BoxConstraints(maxHeight: maxHeight),
      builder: (_) => SprayingReviewModal(viewModel: vm),
    );
  }

  @override
  State<SprayingReviewModal> createState() => _SprayingReviewModalState();
}

class _SprayingReviewModalState extends State<SprayingReviewModal> {
  String _searchQuery = '';

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return ListenableBuilder(
      listenable: widget.viewModel,
      builder: (context, _) {
        final vm = widget.viewModel;
        final allPlants = vm.displayedPlants;
        final reviewedSet = vm.reviewedPlantIds;

        final filtered = allPlants.where((p) {
          if (_searchQuery.isEmpty) return true;
          return p.label.toLowerCase().contains(_searchQuery.toLowerCase()) ||
              p.id.toLowerCase().contains(_searchQuery.toLowerCase());
        }).toList();

        filtered.sort((a, b) {
          final aMarked = reviewedSet.contains(a.id);
          final bMarked = reviewedSet.contains(b.id);
          if (aMarked && !bMarked) return -1;
          if (!aMarked && bMarked) return 1;
          return a.label.compareTo(b.label);
        });

        final autoCount = vm.reviewedPlants
            .where((p) => p.matchSource == SprayingMatchSource.autoMatched)
            .length;
        final manualCount = vm.reviewedPlants
            .where((p) => p.matchSource == SprayingMatchSource.manualAdded)
            .length;

        return Material(
          color: colorScheme.surface,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          clipBehavior: Clip.antiAlias,
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxHeight: MediaQuery.sizeOf(context).height * 0.75,
            ),
            child: SafeArea(
              top: false,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Drag handle
                  Center(
                    child: Container(
                      margin: const EdgeInsets.only(top: 10, bottom: 4),
                      width: 36,
                      height: 4,
                      decoration: BoxDecoration(
                        color: colorScheme.outlineVariant.withValues(alpha: 0.6),
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),

                  // Header
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 8, 12, 12),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: colorScheme.primaryContainer
                                .withValues(alpha: 0.5),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Icon(
                            Icons.checklist_rounded,
                            color: colorScheme.primary,
                            size: 22,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Revisão de Plantas',
                                style: theme.textTheme.titleLarge?.copyWith(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 20,
                                ),
                              ),
                              Text(
                                '${vm.reviewedPlants.length} confirmadas ($autoCount auto, $manualCount manual)',
                                style: theme.textTheme.bodySmall?.copyWith(
                                  color: colorScheme.outline,
                                ),
                              ),
                            ],
                          ),
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

                  // Campo de Busca
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 12, 20, 8),
                    child: TextField(
                      decoration: InputDecoration(
                        hintText: 'Buscar planta por nome ou código...',
                        prefixIcon: const Icon(Icons.search),
                        isDense: true,
                        filled: true,
                        fillColor: colorScheme.surfaceContainerHighest
                            .withValues(alpha: 0.35),
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 10,
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
                      onChanged: (val) {
                        setState(() {
                          _searchQuery = val.trim();
                        });
                      },
                    ),
                  ),

                  // Lista de plantas
                  Expanded(
                    child: filtered.isEmpty
                        ? Center(
                            child: Text(
                              'Nenhuma planta encontrada',
                              style: theme.textTheme.bodyMedium?.copyWith(
                                color: colorScheme.outline,
                              ),
                            ),
                          )
                        : ListView.separated(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 20,
                              vertical: 8,
                            ),
                            itemCount: filtered.length,
                            separatorBuilder: (_, _) =>
                                const SizedBox(height: 8),
                            itemBuilder: (ctx, idx) {
                              final plant = filtered[idx];
                              final isMarked = reviewedSet.contains(plant.id);
                              final confirmed = isMarked
                                  ? vm.reviewedPlants.firstWhere(
                                      (p) => p.plantId == plant.id,
                                    )
                                  : null;
                              final isAuto = confirmed?.matchSource ==
                                  SprayingMatchSource.autoMatched;

                              return Material(
                                color: isMarked
                                    ? colorScheme.primaryContainer
                                        .withValues(alpha: 0.25)
                                    : colorScheme.surface,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(14),
                                  side: BorderSide(
                                    color: isMarked
                                        ? colorScheme.primary
                                            .withValues(alpha: 0.5)
                                        : colorScheme.outlineVariant
                                            .withValues(alpha: 0.6),
                                    width: isMarked ? 1.5 : 1,
                                  ),
                                ),
                                child: InkWell(
                                  borderRadius: BorderRadius.circular(14),
                                  onTap: () => vm.toggleAffectedPlant(plant),
                                  child: Padding(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 16,
                                      vertical: 12,
                                    ),
                                    child: Row(
                                      children: [
                                        Container(
                                          width: 26,
                                          height: 26,
                                          decoration: BoxDecoration(
                                            shape: BoxShape.circle,
                                            color: isMarked
                                                ? colorScheme.primary
                                                : Colors.transparent,
                                            border: Border.all(
                                              color: isMarked
                                                  ? colorScheme.primary
                                                  : colorScheme.outline,
                                              width: 2,
                                            ),
                                          ),
                                          child: isMarked
                                              ? Icon(
                                                  Icons.check_rounded,
                                                  size: 16,
                                                  color: colorScheme.onPrimary,
                                                )
                                              : null,
                                        ),
                                        const SizedBox(width: 14),
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                plant.label,
                                                style: theme.textTheme.bodyMedium
                                                    ?.copyWith(
                                                      fontWeight: isMarked
                                                          ? FontWeight.bold
                                                          : FontWeight.normal,
                                                    ),
                                              ),
                                              if (confirmed?.distanceMeters !=
                                                  null)
                                                Text(
                                                  'Distância da rota: ${confirmed!.distanceMeters!.toStringAsFixed(1)} m',
                                                  style: theme.textTheme.bodySmall
                                                      ?.copyWith(
                                                        color: colorScheme.outline,
                                                      ),
                                                ),
                                            ],
                                          ),
                                        ),
                                        if (isMarked)
                                          Container(
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 8,
                                              vertical: 3,
                                            ),
                                            decoration: BoxDecoration(
                                              color: isAuto
                                                  ? colorScheme.primaryContainer
                                                      .withValues(alpha: 0.6)
                                                  : colorScheme.secondaryContainer
                                                      .withValues(alpha: 0.6),
                                              borderRadius:
                                                  BorderRadius.circular(8),
                                            ),
                                            child: Text(
                                              isAuto ? 'AUTO' : 'MANUAL',
                                              style: TextStyle(
                                                fontSize: 10,
                                                fontWeight: FontWeight.bold,
                                                color: isAuto
                                                    ? colorScheme.primary
                                                    : colorScheme.secondary,
                                              ),
                                            ),
                                          ),
                                      ],
                                    ),
                                  ),
                                ),
                              );
                            },
                          ),
                  ),

                  // FOOTER
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
                    child: Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            style: OutlinedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(14),
                              ),
                            ),
                            onPressed: () => Navigator.of(context).pop(),
                            child: const Text('Ver no Mapa'),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          flex: 2,
                          child: FilledButton.icon(
                            style: FilledButton.styleFrom(
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(14),
                              ),
                            ),
                            icon: const Icon(Icons.arrow_forward_rounded, size: 18),
                            label: Text(
                              'Preencher Insumos (${vm.reviewedPlants.length})',
                              style: const TextStyle(fontWeight: FontWeight.bold),
                            ),
                            onPressed: () {
                              Navigator.of(context).pop();
                              SprayingInputsModal.show(context, vm);
                            },
                          ),
                        ),
                      ],
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
