import 'package:flutter/material.dart';

import '../../domain/harvest_forecast_models.dart';
import '../harvest_forecast_view_model.dart';
import 'harvest_forecast_saved_markings.dart';

class HarvestForecastMarkingModal extends StatelessWidget {
  const HarvestForecastMarkingModal({
    required this.markingLocalId,
    required this.viewModel,
    super.key,
  });

  final String markingLocalId;
  final HarvestForecastViewModel viewModel;

  static Future<void> show(
    BuildContext context,
    HarvestForecastMarking marking,
    HarvestForecastViewModel viewModel,
  ) {
    final maxHeight = MediaQuery.sizeOf(context).height * 0.75;
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      constraints: BoxConstraints(maxHeight: maxHeight),
      builder: (_) => HarvestForecastMarkingModal(
        markingLocalId: marking.localId,
        viewModel: viewModel,
      ),
    );
  }

  HarvestForecastMarking? _findMarking() {
    for (final item in viewModel.markings) {
      if (item.localId == markingLocalId) return item;
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return ListenableBuilder(
      listenable: viewModel,
      builder: (context, _) {
        final marking = _findMarking();
        if (marking == null) {
          return const SizedBox.shrink();
        }
        final busy = viewModel.syncing || viewModel.deleting;
        final badgeColor = harvestForecastClassificationColor(
          marking.classification,
        );
        final statusColor = switch (marking.status) {
          HarvestForecastSyncStatus.synced => const Color(0xFF15803D),
          HarvestForecastSyncStatus.syncing => const Color(0xFF0284C7),
          HarvestForecastSyncStatus.error => colorScheme.error,
          HarvestForecastSyncStatus.pending => const Color(0xFFD97706),
        };
        final statusIcon = switch (marking.status) {
          HarvestForecastSyncStatus.synced => Icons.cloud_done_outlined,
          HarvestForecastSyncStatus.syncing => Icons.cloud_sync_outlined,
          HarvestForecastSyncStatus.error => Icons.error_outline_rounded,
          HarvestForecastSyncStatus.pending => Icons.cloud_upload_outlined,
        };
        final statusText = switch (marking.status) {
          HarvestForecastSyncStatus.pending => 'Pendente',
          HarvestForecastSyncStatus.syncing => 'Sincronizando',
          HarvestForecastSyncStatus.error => 'Erro',
          HarvestForecastSyncStatus.synced => 'Sincronizada',
        };
        final date = marking.createdAt.toUtc().subtract(
          const Duration(hours: 3),
        );
        final dateFormatted =
            '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year} '
            'às ${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';

        return Material(
          key: const ValueKey('harvest-forecast-point-modal'),
          color: colorScheme.surface,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          clipBehavior: Clip.antiAlias,
          child: SafeArea(
            top: false,
            child: SingleChildScrollView(
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
                        color: colorScheme.outlineVariant.withValues(
                          alpha: 0.6,
                        ),
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 8, 12, 12),
                    child: Row(
                      children: [
                        Container(
                          width: 40,
                          height: 40,
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            color: badgeColor.withValues(alpha: 0.16),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(
                              color: badgeColor.withValues(alpha: 0.4),
                            ),
                          ),
                          child: Text(
                            marking.classification.code,
                            style: TextStyle(
                              color: badgeColor,
                              fontWeight: FontWeight.w800,
                              fontSize: 15,
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Ponto Marcado',
                                style: theme.textTheme.titleLarge?.copyWith(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 20,
                                ),
                              ),
                              Text(
                                'Previsão ${marking.classification.code} (${marking.classification.label})',
                                style: theme.textTheme.bodySmall?.copyWith(
                                  color: colorScheme.outline,
                                ),
                              ),
                            ],
                          ),
                        ),
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
                                statusText,
                                style: TextStyle(
                                  color: statusColor,
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 4),
                        IconButton(
                          key: const ValueKey(
                            'harvest-forecast-point-modal-close',
                          ),
                          icon: const Icon(Icons.close),
                          tooltip: 'Fechar',
                          onPressed: () => Navigator.of(context).pop(),
                        ),
                      ],
                    ),
                  ),
                  const Divider(height: 1),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 14, 20, 16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: colorScheme.surfaceContainerLow,
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(
                              color: colorScheme.outlineVariant.withValues(
                                alpha: 0.5,
                              ),
                            ),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Icon(
                                    Icons.access_time_rounded,
                                    size: 16,
                                    color: colorScheme.onSurfaceVariant,
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      dateFormatted,
                                      style: theme.textTheme.bodyMedium
                                          ?.copyWith(
                                            fontWeight: FontWeight.w600,
                                          ),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 8),
                              Row(
                                children: [
                                  Icon(
                                    Icons.my_location_rounded,
                                    size: 16,
                                    color: colorScheme.onSurfaceVariant,
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      '${marking.latitude.toStringAsFixed(6)}, ${marking.longitude.toStringAsFixed(6)}',
                                      style: theme.textTheme.bodySmall
                                          ?.copyWith(
                                            color: colorScheme.onSurfaceVariant,
                                          ),
                                    ),
                                  ),
                                ],
                              ),
                              if (marking.error case final error?) ...[
                                const SizedBox(height: 8),
                                Text(
                                  error,
                                  style: theme.textTheme.bodySmall?.copyWith(
                                    color: colorScheme.error,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                        const SizedBox(height: 14),
                        Text(
                          'Classificação',
                          style: theme.textTheme.labelLarge?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            for (final option
                                in HarvestForecastClassification.values)
                              _ModalClassificationOption(
                                key: ValueKey(
                                  'harvest-forecast-point-modal-edit-${option.code}',
                                ),
                                classification: option,
                                selected: marking.classification == option,
                                enabled: !busy,
                                onTap: () {
                                  if (marking.classification != option) {
                                    viewModel.updateClassification(
                                      marking.localId,
                                      option,
                                    );
                                  }
                                },
                              ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        Row(
                          children: [
                            Expanded(
                              child: OutlinedButton.icon(
                                key: const ValueKey(
                                  'harvest-forecast-point-modal-delete',
                                ),
                                style: OutlinedButton.styleFrom(
                                  foregroundColor: colorScheme.error,
                                  side: BorderSide(
                                    color: colorScheme.error.withValues(
                                      alpha: 0.5,
                                    ),
                                  ),
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 12,
                                  ),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(14),
                                  ),
                                ),
                                onPressed: busy
                                    ? null
                                    : () async {
                                        final navigator = Navigator.of(context);
                                        final deleted = await viewModel
                                            .deleteMarking(marking.localId);
                                        if (deleted && navigator.mounted) {
                                          navigator.pop();
                                        }
                                      },
                                icon: const Icon(
                                  Icons.delete_outline_rounded,
                                  size: 18,
                                ),
                                label: const Text('Excluir'),
                              ),
                            ),
                            if (marking.status !=
                                HarvestForecastSyncStatus.synced) ...[
                              const SizedBox(width: 12),
                              Expanded(
                                child: FilledButton.icon(
                                  key: const ValueKey(
                                    'harvest-forecast-point-modal-sync',
                                  ),
                                  style: FilledButton.styleFrom(
                                    padding: const EdgeInsets.symmetric(
                                      vertical: 12,
                                    ),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(14),
                                    ),
                                  ),
                                  onPressed: busy
                                      ? null
                                      : () =>
                                            viewModel.syncOne(marking.localId),
                                  icon: viewModel.syncing
                                      ? const SizedBox(
                                          width: 16,
                                          height: 16,
                                          child: CircularProgressIndicator(
                                            strokeWidth: 2,
                                            color: Colors.white,
                                          ),
                                        )
                                      : const Icon(
                                          Icons.sync_rounded,
                                          size: 18,
                                        ),
                                  label: const Text('Sincronizar'),
                                ),
                              ),
                            ],
                          ],
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

class _ModalClassificationOption extends StatelessWidget {
  const _ModalClassificationOption({
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
        customBorder: const CircleBorder(),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          width: 44,
          height: 44,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: selected ? color : color.withValues(alpha: 0.12),
            border: Border.all(
              color: selected ? color : color.withValues(alpha: 0.45),
              width: selected ? 2.2 : 1.2,
            ),
            boxShadow: selected
                ? [
                    BoxShadow(
                      color: color.withValues(alpha: 0.35),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ]
                : null,
          ),
          child: Text(
            classification.code,
            style: TextStyle(
              color: selected ? Colors.white : color,
              fontWeight: FontWeight.w800,
              fontSize: 13,
            ),
          ),
        ),
      ),
    );
  }
}
