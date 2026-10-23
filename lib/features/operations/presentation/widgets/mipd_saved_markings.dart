import 'dart:io';

import 'package:flutter/material.dart';

import '../../domain/mipd_models.dart';
import '../mipd_view_model.dart';

class MipdSavedMarkings extends StatelessWidget {
  const MipdSavedMarkings({required this.viewModel, super.key});

  final MipdViewModel viewModel;

  static Future<void> show(
    BuildContext context,
    MipdViewModel viewModel,
  ) async {
    await viewModel.loadMarkings();
    if (context.mounted) {
      await showModalBottomSheet<void>(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        builder: (_) => MipdSavedMarkings(viewModel: viewModel),
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
        (item) => item.status != MipdSyncStatus.synced,
      );

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
                        key: const ValueKey('mipd-saved-close'),
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
                          key: const ValueKey('mipd-saved-markings-list'),
                          padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
                          itemCount: markings.length,
                          separatorBuilder: (_, _) =>
                              const SizedBox(height: 10),
                          itemBuilder: (context, index) => _MipdMarkingCard(
                            key: ValueKey(
                              'mipd-saved-marking-${markings[index].localId}',
                            ),
                            marking: markings[index],
                            plantLabel: _plantLabel(markings[index].plantId),
                            occurrenceName: _occurrenceName(
                              markings[index].occurrenceTypeId,
                            ),
                            syncing: viewModel.syncing,
                            onSync: () =>
                                viewModel.syncOne(markings[index].localId),
                          ),
                        ),
                ),
                const Divider(height: 1),
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                  child: FilledButton.icon(
                    key: const ValueKey('mipd-sync-all-pending-button'),
                    style: FilledButton.styleFrom(
                      minimumSize: const Size.fromHeight(48),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    onPressed: viewModel.syncing || !hasPending
                        ? null
                        : viewModel.syncAll,
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

  String _plantLabel(String plantId) {
    for (final plant in viewModel.plants) {
      if (plant.id == plantId) return plant.label;
    }
    return 'Planta';
  }

  String _occurrenceName(String occurrenceTypeId) {
    for (final type in viewModel.catalog) {
      if (type.id == occurrenceTypeId) return type.name;
    }
    return 'Praga ou doença';
  }
}

class _MipdMarkingCard extends StatelessWidget {
  const _MipdMarkingCard({
    required this.marking,
    required this.plantLabel,
    required this.occurrenceName,
    required this.syncing,
    required this.onSync,
    super.key,
  });

  final MipdMarking marking;
  final String plantLabel;
  final String occurrenceName;
  final bool syncing;
  final Future<bool> Function() onSync;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final statusColor = switch (marking.status) {
      MipdSyncStatus.synced => Colors.green.shade700,
      MipdSyncStatus.syncing => Colors.blue.shade700,
      MipdSyncStatus.error => colorScheme.error,
      MipdSyncStatus.pending => Colors.orange.shade800,
    };
    final statusIcon = switch (marking.status) {
      MipdSyncStatus.synced => Icons.cloud_done_outlined,
      MipdSyncStatus.syncing => Icons.cloud_sync_outlined,
      MipdSyncStatus.error => Icons.error_outline_rounded,
      MipdSyncStatus.pending => Icons.cloud_upload_outlined,
    };
    final date = marking.observedAt.toUtc().subtract(const Duration(hours: 3));
    final dateFormatted =
        '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')} '
        'às ${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';

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
                  backgroundColor: statusColor.withValues(alpha: 0.15),
                  child: Icon(statusIcon, color: statusColor, size: 20),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        plantLabel,
                        style: theme.textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '$occurrenceName • $dateFormatted',
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
                  child: Text(
                    _status(marking.status),
                    style: TextStyle(
                      color: statusColor,
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                    ),
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
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                if (marking.localPhotoPath case final path?) ...[
                  ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: Image.file(
                      File(path),
                      width: 56,
                      height: 56,
                      fit: BoxFit.cover,
                    ),
                  ),
                  const SizedBox(width: 10),
                ],
                Expanded(
                  child: Wrap(
                    spacing: 6,
                    runSpacing: 4,
                    children: [
                      for (final part in marking.plantParts)
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 7,
                            vertical: 3,
                          ),
                          decoration: BoxDecoration(
                            color: colorScheme.primaryContainer.withValues(
                              alpha: 0.45,
                            ),
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(
                              color: colorScheme.primary.withValues(
                                alpha: 0.25,
                              ),
                              width: 0.5,
                            ),
                          ),
                          child: Text(
                            part.label,
                            style: theme.textTheme.bodySmall?.copyWith(
                              fontSize: 11,
                              color: colorScheme.onPrimaryContainer,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
                if (marking.status != MipdSyncStatus.synced)
                  IconButton(
                    key: ValueKey('mipd-sync-${marking.localId}'),
                    tooltip: 'Sincronizar marcação',
                    onPressed: syncing ? null : onSync,
                    icon: Icon(Icons.sync_rounded, color: colorScheme.primary),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  String _status(MipdSyncStatus status) => switch (status) {
    MipdSyncStatus.pending => 'Pendente',
    MipdSyncStatus.syncing => 'Sincronizando',
    MipdSyncStatus.error => 'Erro',
    MipdSyncStatus.synced => 'Sincronizada',
  };
}
