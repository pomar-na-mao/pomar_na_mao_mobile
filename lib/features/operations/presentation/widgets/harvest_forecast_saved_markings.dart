import 'package:flutter/material.dart';

import '../../domain/harvest_forecast_models.dart';
import '../harvest_forecast_view_model.dart';

Color harvestForecastClassificationColor(
  HarvestForecastClassification classification,
) => switch (classification) {
  HarvestForecastClassification.n => const Color(0xFF64748B),
  HarvestForecastClassification.p => const Color(0xFF0284C7),
  HarvestForecastClassification.m => const Color(0xFFEAB308),
  HarvestForecastClassification.g => const Color(0xFFEA580C),
  HarvestForecastClassification.gg => const Color(0xFFDC2626),
};

class HarvestForecastSavedMarkings extends StatelessWidget {
  const HarvestForecastSavedMarkings({required this.viewModel, super.key});

  final HarvestForecastViewModel viewModel;

  static Future<void> show(
    BuildContext context,
    HarvestForecastViewModel viewModel,
  ) async {
    await viewModel.loadMarkings();
    if (context.mounted) {
      await showModalBottomSheet<void>(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        builder: (_) => HarvestForecastSavedMarkings(viewModel: viewModel),
      );
    }
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: viewModel,
    builder: (context, _) {
      final theme = Theme.of(context);
      final colorScheme = theme.colorScheme;
      final markings = viewModel.markings;
      final hasPending = markings.any(
        (item) => item.status != HarvestForecastSyncStatus.synced,
      );
      final busy = viewModel.syncing || viewModel.deleting;

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
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 8, 12, 12),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: colorScheme.primaryContainer.withValues(
                            alpha: 0.5,
                          ),
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
                              'Marcações Salvas',
                              style: theme.textTheme.titleLarge?.copyWith(
                                fontWeight: FontWeight.bold,
                                fontSize: 20,
                              ),
                            ),
                            if (markings.isNotEmpty)
                              Text(
                                '${markings.length} ${markings.length == 1 ? 'registro no dispositivo' : 'registros no dispositivo'}',
                                style: theme.textTheme.bodySmall?.copyWith(
                                  color: colorScheme.outline,
                                ),
                              ),
                          ],
                        ),
                      ),
                      IconButton(
                        key: const ValueKey('harvest-forecast-saved-close'),
                        icon: const Icon(Icons.close),
                        tooltip: 'Fechar',
                        onPressed: () => Navigator.of(context).pop(),
                      ),
                    ],
                  ),
                ),
                const Divider(height: 1),
                Flexible(
                  child: markings.isEmpty
                      ? Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 32,
                            vertical: 48,
                          ),
                          child: Center(
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(16),
                                  decoration: BoxDecoration(
                                    color: colorScheme.surfaceContainerHighest
                                        .withValues(alpha: 0.4),
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
                                  'Nenhuma marcação foi salva.',
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
                          key: const ValueKey(
                            'harvest-forecast-saved-markings-list',
                          ),
                          padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
                          itemCount: markings.length,
                          separatorBuilder: (_, _) =>
                              const SizedBox(height: 10),
                          itemBuilder: (context, index) {
                            final item = markings[index];
                            return _HarvestForecastMarkingCard(
                              key: ValueKey(
                                'harvest-forecast-saved-marking-${item.localId}',
                              ),
                              marking: item,
                              busy: busy,
                              onChangeClassification: (classification) =>
                                  viewModel.updateClassification(
                                    item.localId,
                                    classification,
                                  ),
                              onDelete: () =>
                                  viewModel.deleteMarking(item.localId),
                              onSync: () => viewModel.syncOne(item.localId),
                            );
                          },
                        ),
                ),
                const Divider(height: 1),
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                  child: FilledButton.icon(
                    key: const ValueKey(
                      'harvest-forecast-sync-all-pending-button',
                    ),
                    style: FilledButton.styleFrom(
                      minimumSize: const Size.fromHeight(48),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    onPressed: busy || !hasPending ? null : viewModel.syncAll,
                    icon: viewModel.syncing
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
                      viewModel.syncing
                          ? 'Sincronizando...'
                          : 'Sincronizar Pendentes',
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

class _HarvestForecastMarkingCard extends StatelessWidget {
  const _HarvestForecastMarkingCard({
    required this.marking,
    required this.busy,
    required this.onChangeClassification,
    required this.onDelete,
    required this.onSync,
    super.key,
  });

  final HarvestForecastMarking marking;
  final bool busy;
  final Future<bool> Function(HarvestForecastClassification)
  onChangeClassification;
  final Future<bool> Function() onDelete;
  final Future<bool> Function() onSync;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final statusColor = switch (marking.status) {
      HarvestForecastSyncStatus.synced => Colors.green.shade700,
      HarvestForecastSyncStatus.syncing => Colors.blue.shade700,
      HarvestForecastSyncStatus.error => colorScheme.error,
      HarvestForecastSyncStatus.pending => Colors.orange.shade800,
    };
    final statusIcon = switch (marking.status) {
      HarvestForecastSyncStatus.synced => Icons.cloud_done_outlined,
      HarvestForecastSyncStatus.syncing => Icons.cloud_sync_outlined,
      HarvestForecastSyncStatus.error => Icons.error_outline_rounded,
      HarvestForecastSyncStatus.pending => Icons.cloud_upload_outlined,
    };
    final date = marking.createdAt.toUtc().subtract(const Duration(hours: 3));
    final dateFormatted =
        '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')} '
        'às ${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
    final badgeColor = harvestForecastClassificationColor(
      marking.classification,
    );

    return Container(
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: colorScheme.outlineVariant.withValues(alpha: 0.5),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                CircleAvatar(
                  radius: 18,
                  backgroundColor: badgeColor.withValues(alpha: 0.16),
                  child: Text(
                    marking.classification.code,
                    style: TextStyle(
                      color: badgeColor,
                      fontWeight: FontWeight.w800,
                      fontSize: 13,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Previsão ${marking.classification.code} (${marking.classification.label})',
                        style: theme.textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '$dateFormatted • ${marking.latitude.toStringAsFixed(5)}, ${marking.longitude.toStringAsFixed(5)}',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: statusColor.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: statusColor.withValues(alpha: 0.25),
                      width: 0.5,
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(statusIcon, size: 13, color: statusColor),
                      const SizedBox(width: 4),
                      Text(
                        _status(marking.status),
                        style: TextStyle(
                          color: statusColor,
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            if (marking.error case final error?) ...[
              const SizedBox(height: 8),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: colorScheme.errorContainer.withValues(alpha: 0.35),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: colorScheme.error.withValues(alpha: 0.3),
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.error_outline_rounded,
                      size: 15,
                      color: colorScheme.error,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        error,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: colorScheme.onErrorContainer,
                          fontWeight: FontWeight.w600,
                          fontSize: 11,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: [
                      for (final option
                          in HarvestForecastClassification.values)
                        _ClassificationChoiceChip(
                          key: ValueKey(
                            'harvest-forecast-edit-${marking.localId}-${option.code}',
                          ),
                          classification: option,
                          selected: marking.classification == option,
                          enabled: !busy,
                          onTap: () {
                            if (marking.classification != option) {
                              onChangeClassification(option);
                            }
                          },
                        ),
                    ],
                  ),
                ),
                IconButton(
                  key: ValueKey('harvest-forecast-delete-${marking.localId}'),
                  tooltip: 'Excluir marcação',
                  onPressed: busy ? null : onDelete,
                  icon: Icon(
                    Icons.delete_outline_rounded,
                    color: colorScheme.error,
                  ),
                ),
                if (marking.status != HarvestForecastSyncStatus.synced)
                  IconButton(
                    key: ValueKey('harvest-forecast-sync-${marking.localId}'),
                    tooltip: 'Sincronizar marcação',
                    onPressed: busy ? null : onSync,
                    icon: Icon(Icons.sync_rounded, color: colorScheme.primary),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  String _status(HarvestForecastSyncStatus status) => switch (status) {
    HarvestForecastSyncStatus.pending => 'Pendente',
    HarvestForecastSyncStatus.syncing => 'Sincronizando',
    HarvestForecastSyncStatus.error => 'Erro',
    HarvestForecastSyncStatus.synced => 'Sincronizada',
  };
}

class _ClassificationChoiceChip extends StatelessWidget {
  const _ClassificationChoiceChip({
    required this.classification,
    required this.selected,
    required this.enabled,
    required this.onTap,
    super.key,
  });

  final HarvestForecastClassification classification;
  final bool selected;
  final bool enabled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = harvestForecastClassificationColor(classification);
    return Semantics(
      button: true,
      selected: selected,
      label: 'Classificação ${classification.code} (${classification.label})',
      child: InkWell(
        onTap: enabled ? onTap : null,
        borderRadius: BorderRadius.circular(18),
        child: Container(
          width: 34,
          height: 34,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: selected ? color : color.withValues(alpha: 0.1),
            border: Border.all(
              color: selected ? color : color.withValues(alpha: 0.4),
              width: selected ? 2 : 1,
            ),
          ),
          child: Text(
            classification.code,
            style: TextStyle(
              color: selected ? Colors.white : color,
              fontWeight: FontWeight.w800,
              fontSize: 12,
            ),
          ),
        ),
      ),
    );
  }
}
