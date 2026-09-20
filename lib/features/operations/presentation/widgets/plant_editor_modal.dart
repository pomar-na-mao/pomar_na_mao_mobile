import 'package:flutter/material.dart';

import '../inspection_view_model.dart';

class PlantEditorModal extends StatelessWidget {
  const PlantEditorModal({
    required this.viewModel,
    super.key,
  });

  final InspectionViewModel viewModel;

  static Future<void> show(BuildContext context, InspectionViewModel viewModel) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => PlantEditorModal(viewModel: viewModel),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: viewModel,
      builder: (context, _) {
        final plant = viewModel.selectedPlant;
        if (plant == null) return const SizedBox.shrink();

        final theme = Theme.of(context);
        final colorScheme = theme.colorScheme;
        final catalog = viewModel.catalog;
        final changedPlantsCount = viewModel.changedPlantsCountInCurrentDraft;
        final hasStagedChanges = viewModel.hasStagedChanges;
        final canFinalize = (hasStagedChanges || changedPlantsCount > 0) &&
            !viewModel.isSyncing &&
            !viewModel.isSavingLocal;
        final screenHeight = MediaQuery.sizeOf(context).height;
        final modalHeight = screenHeight * 0.80;

        return Material(
          color: colorScheme.surface,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
          clipBehavior: Clip.antiAlias,
          child: SizedBox(
            height: modalHeight,
            child: SafeArea(
              top: false,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Top Drag Handle
                  Center(
                    child: Container(
                      width: 36,
                      height: 4,
                      margin: const EdgeInsets.only(top: 12, bottom: 8),
                      decoration: BoxDecoration(
                        color: colorScheme.outlineVariant,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),

                  // Header
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 8, 12, 12),
                    child: Row(
                      children: [
                        Icon(
                          Icons.eco_rounded,
                          color: colorScheme.primary,
                          size: 26,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            plant.label,
                            style: theme.textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.bold,
                              fontSize: 18,
                            ),
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.close_rounded),
                          tooltip: 'Fechar',
                          onPressed: () {
                            viewModel.selectPlant(null);
                            Navigator.of(context).pop();
                          },
                        ),
                      ],
                    ),
                  ),
                  const Divider(height: 1),

                  // Feedback message banner if any
                  if (viewModel.feedbackMessage case final message?)
                    Container(
                      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                      decoration: BoxDecoration(
                        color: colorScheme.primaryContainer.withValues(alpha: 0.35),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: colorScheme.primary.withValues(alpha: 0.25),
                        ),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            Icons.check_circle_outline_rounded,
                            size: 18,
                            color: colorScheme.primary,
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              message,
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: colorScheme.onPrimaryContainer,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),

                  // Occurrence items list
                  Expanded(
                    child: catalog.isEmpty
                        ? Padding(
                            padding: const EdgeInsets.all(32),
                            child: Center(
                              child: Text(
                                'Nenhum tipo de ocorrência disponível.',
                                style: theme.textTheme.bodyMedium?.copyWith(
                                  color: colorScheme.onSurfaceVariant,
                                ),
                              ),
                            ),
                          )
                        : ListView.separated(
                            key: const ValueKey('plant-occurrences-list'),
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                            itemCount: catalog.length,
                            separatorBuilder: (_, _) => const SizedBox(height: 8),
                            itemBuilder: (context, index) {
                              final type = catalog[index];
                              final isChecked = viewModel.isOccurrenceChecked(type.id);

                              return Semantics(
                                label: type.name,
                                checked: isChecked,
                                button: true,
                                hint: isChecked
                                    ? 'Marcado. Toque para desmarcar'
                                    : 'Desmarcado. Toque para marcar',
                                child: Material(
                                  color: isChecked
                                      ? colorScheme.primaryContainer.withValues(alpha: 0.25)
                                      : colorScheme.surface,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(14),
                                    side: BorderSide(
                                      color: isChecked
                                          ? colorScheme.primary.withValues(alpha: 0.5)
                                          : colorScheme.outlineVariant.withValues(alpha: 0.6),
                                      width: isChecked ? 1.5 : 1,
                                    ),
                                  ),
                                  clipBehavior: Clip.antiAlias,
                                  child: InkWell(
                                    key: ValueKey('occurrence-toggle-${type.code}'),
                                    onTap: viewModel.isSavingLocal
                                        ? null
                                        : () => viewModel.toggleStagedOccurrence(type.id),
                                    child: Padding(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 16,
                                        vertical: 14,
                                      ),
                                      child: Row(
                                        children: [
                                          Container(
                                            width: 26,
                                            height: 26,
                                            decoration: BoxDecoration(
                                              shape: BoxShape.circle,
                                              color: isChecked
                                                  ? colorScheme.primary
                                                  : Colors.transparent,
                                              border: Border.all(
                                                color: isChecked
                                                    ? colorScheme.primary
                                                    : colorScheme.outline,
                                                width: 2,
                                              ),
                                            ),
                                            child: isChecked
                                                ? Icon(
                                                    Icons.check_rounded,
                                                    size: 16,
                                                    color: colorScheme.onPrimary,
                                                  )
                                                : null,
                                          ),
                                          const SizedBox(width: 14),
                                          Expanded(
                                            child: Text(
                                              type.name,
                                              style: theme.textTheme.bodyMedium?.copyWith(
                                                fontWeight: isChecked
                                                    ? FontWeight.w600
                                                    : FontWeight.normal,
                                                fontSize: 15,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ),
                              );
                            },
                          ),
                  ),

                  const Divider(height: 1),

                  // Fixed footer
                  Container(
                    color: colorScheme.surface,
                    padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
                    child: Row(
                      children: [
                        Expanded(
                          child: Row(
                            children: [
                              Icon(
                                Icons.edit_note_rounded,
                                size: 20,
                                color: colorScheme.onSurfaceVariant,
                              ),
                              const SizedBox(width: 6),
                              Flexible(
                                child: Text(
                                  hasStagedChanges
                                      ? 'Alterações pendentes'
                                      : (changedPlantsCount == 1
                                          ? '1 planta alterada'
                                          : '$changedPlantsCount plantas alteradas'),
                                  style: theme.textTheme.bodyMedium?.copyWith(
                                    color: colorScheme.onSurfaceVariant,
                                    fontWeight: FontWeight.w600,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 12),
                        FilledButton.icon(
                          key: const ValueKey('plant-editor-update-button'),
                          style: FilledButton.styleFrom(
                            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14),
                            ),
                          ),
                          onPressed: canFinalize
                              ? () async {
                                  await viewModel.savePlantChanges();
                                  if (context.mounted) {
                                    viewModel.selectPlant(null);
                                    Navigator.of(context).pop();
                                  }
                                }
                              : null,
                          icon: viewModel.isSavingLocal
                              ? const SizedBox(
                                  width: 16,
                                  height: 16,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Colors.white,
                                  ),
                                )
                              : const Icon(Icons.check_rounded, size: 18),
                          label: const Text('Atualizar'),
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
