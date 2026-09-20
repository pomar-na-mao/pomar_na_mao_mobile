import 'package:flutter/material.dart';

import '../../domain/inspection_models.dart';
import '../inspection_view_model.dart';

class LocalInspectionsModal extends StatelessWidget {
  const LocalInspectionsModal({
    required this.viewModel,
    super.key,
  });

  final InspectionViewModel viewModel;

  static Future<void> show(BuildContext context, InspectionViewModel viewModel) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => LocalInspectionsModal(viewModel: viewModel),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: viewModel,
      builder: (context, _) {
        final theme = Theme.of(context);
        final colorScheme = theme.colorScheme;
        final inspections = viewModel.localInspections;
        final hasDraftChanges = inspections.any((i) => i.isDraft && i.changesCount > 0);
        final hasPending = inspections.any((i) =>
            !i.isDraft &&
            (i.status == InspectionSyncStatus.pending ||
                i.status == InspectionSyncStatus.error));
        final canSync = hasDraftChanges || hasPending;

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
                  // Drag handle indicator
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
                            color: colorScheme.primaryContainer.withValues(alpha: 0.5),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Icon(
                            Icons.inventory_2_outlined,
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
                                'Inspeções Salvas',
                                style: theme.textTheme.titleLarge?.copyWith(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 20,
                                ),
                              ),
                              if (inspections.isNotEmpty)
                                Text(
                                  '${inspections.length} ${inspections.length == 1 ? 'registro no dispositivo' : 'registros no dispositivo'}',
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

                  // Feedback message if any
                  if (viewModel.feedbackMessage case final message?)
                    Container(
                      color: colorScheme.primaryContainer.withValues(alpha: 0.3),
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                      child: Row(
                        children: [
                          Icon(
                            Icons.info_outline,
                            size: 16,
                            color: colorScheme.primary,
                          ),
                          const SizedBox(width: 8),
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

                  // List of inspections
                  Flexible(
                    child: inspections.isEmpty
                        ? Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 48),
                            child: Center(
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Container(
                                    padding: const EdgeInsets.all(16),
                                    decoration: BoxDecoration(
                                      color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.4),
                                      shape: BoxShape.circle,
                                    ),
                                    child: Icon(
                                      Icons.folder_open_outlined,
                                      size: 40,
                                      color: colorScheme.onSurfaceVariant,
                                    ),
                                  ),
                                  const SizedBox(height: 16),
                                  Text(
                                    'Nenhuma inspeção foi salva.',
                                    textAlign: TextAlign.center,
                                    style: theme.textTheme.bodyMedium?.copyWith(
                                      color: colorScheme.onSurfaceVariant,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          )
                        : ListView.separated(
                            key: const ValueKey('local-inspections-list'),
                            padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
                            itemCount: inspections.length,
                            separatorBuilder: (_, _) => const SizedBox(height: 10),
                            itemBuilder: (context, index) {
                              final inspection = inspections[index];
                              final alteredPlants = viewModel.getAlteredPlantsForInspection(inspection.id);
                              return _LocalInspectionCard(
                                key: ValueKey('local-inspection-${inspection.id}'),
                                inspection: inspection,
                                alteredPlants: alteredPlants,
                                onDeletePlant: (plantId) => viewModel.deletePlantFromInspection(
                                  inspectionId: inspection.id,
                                  plantId: plantId,
                                ),
                              );
                            },
                          ),
                  ),

                  // Sync button
                  if (canSync)
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                      child: FilledButton.icon(
                        key: const ValueKey('sync-all-pending-button'),
                        style: FilledButton.styleFrom(
                          minimumSize: const Size.fromHeight(48),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        onPressed: viewModel.isSyncing
                            ? null
                            : () => viewModel.syncPendingInspections(),
                        icon: viewModel.isSyncing
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                            : const Icon(Icons.sync_rounded, size: 20),
                        label: Text(
                          viewModel.isSyncing ? 'Sincronizando...' : 'Sincronizar Pendentes',
                          style: const TextStyle(fontWeight: FontWeight.w600),
                        ),
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

class _LocalInspectionCard extends StatefulWidget {
  const _LocalInspectionCard({
    required this.inspection,
    required this.alteredPlants,
    required this.onDeletePlant,
    super.key,
  });

  final LocalInspection inspection;
  final List<AlteredPlantItem> alteredPlants;
  final Future<void> Function(String plantId) onDeletePlant;

  @override
  State<_LocalInspectionCard> createState() => _LocalInspectionCardState();
}

class _LocalInspectionCardState extends State<_LocalInspectionCard> {
  bool _isExpanded = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final inspection = widget.inspection;
    final alteredPlants = widget.alteredPlants;

    final statusColor = switch (inspection.status) {
      InspectionSyncStatus.synced => Colors.green.shade700,
      InspectionSyncStatus.syncing => Colors.blue.shade700,
      InspectionSyncStatus.error => inspection.isNetworkError
          ? Colors.orange.shade800
          : colorScheme.error,
      InspectionSyncStatus.pending => Colors.orange.shade800,
    };

    final statusIcon = switch (inspection.status) {
      InspectionSyncStatus.synced => Icons.cloud_done_outlined,
      InspectionSyncStatus.syncing => Icons.cloud_sync_outlined,
      InspectionSyncStatus.error => inspection.isNetworkError
          ? Icons.wifi_off_rounded
          : Icons.error_outline_rounded,
      InspectionSyncStatus.pending => Icons.cloud_upload_outlined,
    };

    final utcDate = (inspection.finishedAt ?? inspection.startedAt).toUtc();
    // Horário no Brasil (UTC-3)
    final date = utcDate.subtract(const Duration(hours: 3));
    final dateFormatted =
        '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')} '
        'às ${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';

    return Container(
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: inspection.isDraft
              ? colorScheme.primary.withValues(alpha: 0.35)
              : colorScheme.outlineVariant.withValues(alpha: 0.5),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Top row: Leading Icon + Title + Status Chip
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                CircleAvatar(
                  radius: 18,
                  backgroundColor: inspection.isDraft
                      ? colorScheme.primary.withValues(alpha: 0.15)
                      : statusColor.withValues(alpha: 0.15),
                  child: Icon(
                    inspection.isDraft ? Icons.edit_note_rounded : statusIcon,
                    color: inspection.isDraft ? colorScheme.primary : statusColor,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        inspection.isDraft ? 'Rascunho atual' : 'Inspeção de $dateFormatted',
                        style: theme.textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '${inspection.plantsCount} ${inspection.plantsCount == 1 ? "planta alterada" : "plantas alteradas"} (${inspection.changesCount} ${inspection.changesCount == 1 ? "alteração" : "alterações"})',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: statusColor.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: statusColor.withValues(alpha: 0.25),
                      width: 0.5,
                    ),
                  ),
                  child: Text(
                    inspection.statusLabel,
                    style: TextStyle(
                      color: statusColor,
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),

            // Remote ID if present
            if (inspection.remoteId != null) ...[
              const SizedBox(height: 6),
              Padding(
                padding: const EdgeInsets.only(left: 48),
                child: Text(
                  'ID Remoto: ${inspection.remoteId}',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: colorScheme.outline,
                    fontSize: 11,
                  ),
                ),
              ),
            ],

            // Error banner if any
            if (inspection.error != null) ...[
              const SizedBox(height: 8),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: inspection.isNetworkError
                      ? Colors.orange.withValues(alpha: 0.12)
                      : colorScheme.errorContainer.withValues(alpha: 0.35),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: inspection.isNetworkError
                        ? Colors.orange.withValues(alpha: 0.3)
                        : colorScheme.error.withValues(alpha: 0.3),
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
                      inspection.isNetworkError
                          ? Icons.wifi_off_rounded
                          : Icons.error_outline_rounded,
                      size: 15,
                      color: inspection.isNetworkError
                          ? Colors.orange.shade800
                          : colorScheme.error,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        inspection.displayErrorMessage ?? inspection.error!,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: inspection.isNetworkError
                              ? Colors.orange.shade900
                              : colorScheme.onErrorContainer,
                          fontWeight: FontWeight.w600,
                          fontSize: 11,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],

            // Expandable section for altered plants
            if (alteredPlants.isNotEmpty) ...[
              const SizedBox(height: 8),
              InkWell(
                key: ValueKey('toggle-altered-plants-${inspection.id}'),
                borderRadius: BorderRadius.circular(8),
                onTap: () => setState(() => _isExpanded = !_isExpanded),
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 4),
                  child: Row(
                    children: [
                      Icon(
                        Icons.eco_rounded,
                        size: 16,
                        color: colorScheme.primary,
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          _isExpanded
                              ? 'Ocultar plantas alteradas'
                              : 'Ver plantas alteradas (${alteredPlants.length})',
                          style: theme.textTheme.labelMedium?.copyWith(
                            color: colorScheme.primary,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      Icon(
                        _isExpanded
                            ? Icons.keyboard_arrow_up_rounded
                            : Icons.keyboard_arrow_down_rounded,
                        size: 20,
                        color: colorScheme.primary,
                      ),
                    ],
                  ),
                ),
              ),
              AnimatedSize(
                duration: const Duration(milliseconds: 200),
                curve: Curves.easeInOut,
                alignment: Alignment.topCenter,
                child: _isExpanded
                    ? _buildAlteredPlantsList(context, colorScheme, theme, alteredPlants)
                    : const SizedBox.shrink(),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildAlteredPlantsList(
    BuildContext context,
    ColorScheme colorScheme,
    ThemeData theme,
    List<AlteredPlantItem> alteredPlants,
  ) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(top: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.35),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: colorScheme.outlineVariant.withValues(alpha: 0.4),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.format_list_bulleted_rounded,
                size: 14,
                color: colorScheme.primary,
              ),
              const SizedBox(width: 6),
              Text(
                'Plantas alteradas:',
                style: theme.textTheme.labelSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: colorScheme.primary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          for (int i = 0; i < alteredPlants.length; i++) ...[
            if (i > 0)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 6),
                child: Divider(
                  height: 1,
                  thickness: 0.5,
                  color: colorScheme.outlineVariant.withValues(alpha: 0.3),
                ),
              ),
            _buildPlantItem(context, colorScheme, theme, alteredPlants[i]),
          ],
        ],
      ),
    );
  }

  Widget _buildPlantItem(
    BuildContext context,
    ColorScheme colorScheme,
    ThemeData theme,
    AlteredPlantItem plant,
  ) {
    final isSynced = widget.inspection.status == InspectionSyncStatus.synced;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(
              Icons.eco_outlined,
              size: 14,
              color: colorScheme.primary.withValues(alpha: 0.8),
            ),
            const SizedBox(width: 6),
            Expanded(
              child: Text(
                plant.plantLabel,
                style: theme.textTheme.bodySmall?.copyWith(
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
                ),
              ),
            ),
            IconButton(
              key: ValueKey('delete-plant-${widget.inspection.id}-${plant.plantId}'),
              icon: Icon(
                Icons.delete_outline_rounded,
                size: 18,
                color: isSynced
                    ? colorScheme.outline.withValues(alpha: 0.4)
                    : colorScheme.error.withValues(alpha: 0.8),
              ),
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
              tooltip: isSynced
                  ? 'Inspeção já sincronizada'
                  : 'Excluir planta da inspeção',
              onPressed: isSynced
                  ? null
                  : () => _confirmDeletePlant(context, plant),
            ),
          ],
        ),
        if (plant.changesSummary.isNotEmpty) ...[
          const SizedBox(height: 4),
          Padding(
            padding: const EdgeInsets.only(left: 20),
            child: Wrap(
              spacing: 6,
              runSpacing: 4,
              children: plant.changesSummary.map((summary) {
                final isRemoved = summary.contains('(removida)');
                return Container(
                  padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                  decoration: BoxDecoration(
                    color: isRemoved
                        ? colorScheme.errorContainer.withValues(alpha: 0.25)
                        : colorScheme.primaryContainer.withValues(alpha: 0.45),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(
                      color: isRemoved
                          ? colorScheme.error.withValues(alpha: 0.25)
                          : colorScheme.primary.withValues(alpha: 0.25),
                      width: 0.5,
                    ),
                  ),
                  child: Text(
                    summary,
                    style: theme.textTheme.bodySmall?.copyWith(
                      fontSize: 11,
                      color: isRemoved
                          ? colorScheme.error
                          : colorScheme.onPrimaryContainer,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
        ],
      ],
    );
  }

  Future<void> _confirmDeletePlant(BuildContext context, AlteredPlantItem plant) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Excluir planta'),
        content: Text('Deseja remover as alterações da ${plant.plantLabel} desta inspeção?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            key: const ValueKey('confirm-delete-plant-button'),
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(ctx).colorScheme.error,
            ),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Excluir'),
          ),
        ],
      ),
    );
    if (confirm == true) {
      await widget.onDeletePlant(plant.plantId);
    }
  }
}
