import 'package:flutter/material.dart';

import '../../domain/activity_models.dart';
import '../activity_view_model.dart';

class ActivitySavedEntries extends StatelessWidget {
  const ActivitySavedEntries({required this.viewModel, super.key});

  final ActivityViewModel viewModel;

  static Future<void> show(
    BuildContext context,
    ActivityViewModel viewModel,
  ) async {
    await viewModel.loadEntries();
    if (!context.mounted) return;
    final maxHeight = MediaQuery.sizeOf(context).height * 0.75;
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      constraints: BoxConstraints(maxHeight: maxHeight),
      builder: (_) => ActivitySavedEntries(viewModel: viewModel),
    );
  }

  Future<void> _confirmDelete(BuildContext context, ActivityEntry entry) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Excluir operação?'),
        content: const Text(
          'Esta ação remove somente a cópia salva neste dispositivo. '
          'Dados já sincronizados permanecem no servidor.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(dialogContext).colorScheme.error,
            ),
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Excluir'),
          ),
        ],
      ),
    );
    if (confirmed != true || !context.mounted) return;
    final deleted = await viewModel.deleteLocal(entry.localId);
    if (!deleted && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Não foi possível excluir a operação.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: viewModel,
    builder: (context, _) {
      final theme = Theme.of(context);
      final colorScheme = theme.colorScheme;
      final entries = viewModel.entries;
      final hasPending = entries.any(
        (entry) => entry.syncStatus != ActivitySyncStatus.synced,
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
                              'Operações salvas',
                              style: theme.textTheme.titleLarge?.copyWith(
                                fontWeight: FontWeight.bold,
                                fontSize: 20,
                              ),
                            ),
                            if (entries.isNotEmpty)
                              Text(
                                '${entries.length} ${entries.length == 1 ? "registro no dispositivo" : "registros no dispositivo"}',
                                style: theme.textTheme.bodySmall?.copyWith(
                                  color: colorScheme.outline,
                                ),
                              ),
                          ],
                        ),
                      ),
                      IconButton(
                        tooltip: 'Fechar',
                        onPressed: () => Navigator.of(context).pop(),
                        icon: const Icon(Icons.close),
                      ),
                    ],
                  ),
                ),
                const Divider(height: 1),
                Expanded(
                  child: entries.isEmpty
                      ? const Center(
                          child: Text('Nenhuma operação salva no dispositivo.'),
                        )
                      : ListView.separated(
                          padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
                          itemCount: entries.length,
                          separatorBuilder: (_, _) =>
                              const SizedBox(height: 10),
                          itemBuilder: (context, index) => _EntryCard(
                            entry: entries[index],
                            busy: viewModel.syncing || viewModel.deleting,
                            onSync: () =>
                                viewModel.syncOne(entries[index].localId),
                            onDelete: () =>
                                _confirmDelete(context, entries[index]),
                          ),
                        ),
                ),
                const Divider(height: 1),
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 10, 16, 16),
                  child: FilledButton.icon(
                    key: const ValueKey('activity-sync-all'),
                    style: FilledButton.styleFrom(
                      minimumSize: const Size.fromHeight(50),
                    ),
                    onPressed: viewModel.syncing || !hasPending
                        ? null
                        : viewModel.syncAll,
                    icon: viewModel.syncing
                        ? const SizedBox.square(
                            dimension: 18,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Icon(Icons.sync),
                    label: Text(
                      viewModel.syncing
                          ? 'Sincronizando...'
                          : 'Sincronizar pendentes',
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

class _EntryCard extends StatelessWidget {
  const _EntryCard({
    required this.entry,
    required this.busy,
    required this.onSync,
    required this.onDelete,
  });

  final ActivityEntry entry;
  final bool busy;
  final Future<bool> Function() onSync;
  final Future<void> Function() onDelete;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;
    final statusColor = switch (entry.syncStatus) {
      ActivitySyncStatus.pending =>
        isDark ? Colors.orange.shade300 : Colors.orange.shade800,
      ActivitySyncStatus.syncing =>
        isDark ? Colors.blue.shade300 : Colors.blue.shade700,
      ActivitySyncStatus.error =>
        isDark ? colorScheme.errorContainer : colorScheme.error,
      ActivitySyncStatus.synced =>
        isDark ? Colors.green.shade300 : Colors.green.shade700,
    };
    final cardAccent = isDark ? Colors.orange.shade300 : Colors.orange.shade800;
    final cardBackground = Color.alphaBlend(
      cardAccent.withValues(alpha: isDark ? 0.16 : 0.1),
      colorScheme.surface,
    );
    final local = entry.performedAt.toLocal();
    final date =
        '${local.day.toString().padLeft(2, '0')}/'
        '${local.month.toString().padLeft(2, '0')}/${local.year} '
        '${local.hour.toString().padLeft(2, '0')}:'
        '${local.minute.toString().padLeft(2, '0')}';
    return Card(
      margin: EdgeInsets.zero,
      elevation: 0,
      color: cardBackground,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
        side: BorderSide(color: cardAccent.withValues(alpha: 0.5)),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 14, 10, 10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: statusColor.withValues(alpha: 0.16),
                    borderRadius: BorderRadius.circular(13),
                  ),
                  child: Icon(
                    entry.geometry.type == ActivityGeometryType.route
                        ? Icons.route_outlined
                        : Icons.crop_square_rounded,
                    color: statusColor,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        entry.activity,
                        style: theme.textTheme.titleMedium?.copyWith(
                          color: colorScheme.onSurface,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        entry.geometry.type.label,
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
                    horizontal: 9,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: statusColor.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        _statusIcon(entry.syncStatus),
                        size: 14,
                        color: statusColor,
                      ),
                      const SizedBox(width: 5),
                      Text(
                        _status(entry.syncStatus),
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: statusColor,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            Wrap(
              spacing: 7,
              runSpacing: 7,
              children: [
                _EntryInfoChip(
                  icon: Icons.calendar_today_outlined,
                  label: date,
                  accent: statusColor,
                ),
                _EntryInfoChip(
                  icon: Icons.person_outline,
                  label: entry.responsible,
                  accent: statusColor,
                ),
                _EntryInfoChip(
                  icon: Icons.location_on_outlined,
                  label:
                      '${entry.geometry.type.label}: ${entry.geometry.points.length} pontos',
                  accent: statusColor,
                ),
                _EntryInfoChip(
                  icon: Icons.inventory_2_outlined,
                  label:
                      '${entry.inputs.length} ${entry.inputs.length == 1 ? 'insumo' : 'insumos'}',
                  accent: statusColor,
                ),
              ],
            ),
            if (entry.machineNameSnapshot != null) ...[
              const SizedBox(height: 10),
              _EntryDetail(
                icon: Icons.agriculture_outlined,
                label: 'Máquina/Trator',
                value: entry.machineNameSnapshot!,
                accent: isDark
                    ? Colors.purple.shade300
                    : Colors.purple.shade700,
              ),
            ],
            if (entry.mixtureNameSnapshot != null) ...[
              const SizedBox(height: 7),
              _EntryDetail(
                icon: Icons.science_outlined,
                label: 'Calda utilizada',
                value: entry.mixtureNameSnapshot!,
                accent: isDark ? Colors.green.shade300 : Colors.green.shade800,
              ),
            ],
            if (entry.error case final error?) ...[
              const SizedBox(height: 10),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: colorScheme.errorContainer.withValues(alpha: 0.62),
                  borderRadius: BorderRadius.circular(11),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(
                      Icons.error_outline,
                      size: 18,
                      color: colorScheme.error,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        error,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: colorScheme.onErrorContainer,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
            const SizedBox(height: 6),
            Align(
              alignment: Alignment.centerRight,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (entry.syncStatus != ActivitySyncStatus.synced)
                    TextButton.icon(
                      style: TextButton.styleFrom(
                        foregroundColor: colorScheme.onPrimary,
                        backgroundColor: colorScheme.primary,
                        disabledForegroundColor: colorScheme.onSurface
                            .withValues(alpha: 0.38),
                        disabledBackgroundColor: colorScheme.onSurface
                            .withValues(alpha: 0.12),
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                      ),
                      onPressed: busy ? null : onSync,
                      icon: const Icon(Icons.sync),
                      label: const Text('Sincronizar'),
                    ),
                  const SizedBox(width: 4),
                  IconButton.filledTonal(
                    key: ValueKey('activity-delete-${entry.localId}'),
                    tooltip: 'Excluir operação',
                    style: IconButton.styleFrom(
                      foregroundColor: colorScheme.error,
                      backgroundColor: colorScheme.errorContainer.withValues(
                        alpha: 0.65,
                      ),
                      disabledForegroundColor: colorScheme.onSurface.withValues(
                        alpha: 0.3,
                      ),
                    ),
                    onPressed:
                        busy || entry.syncStatus == ActivitySyncStatus.synced
                        ? null
                        : onDelete,
                    icon: const Icon(Icons.delete_outline),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _status(ActivitySyncStatus status) => switch (status) {
    ActivitySyncStatus.pending => 'Pendente',
    ActivitySyncStatus.syncing => 'Sincronizando',
    ActivitySyncStatus.error => 'Erro',
    ActivitySyncStatus.synced => 'Sincronizada',
  };

  IconData _statusIcon(ActivitySyncStatus status) => switch (status) {
    ActivitySyncStatus.pending => Icons.schedule_outlined,
    ActivitySyncStatus.syncing => Icons.sync,
    ActivitySyncStatus.error => Icons.error_outline,
    ActivitySyncStatus.synced => Icons.check_circle_outline,
  };
}

class _EntryInfoChip extends StatelessWidget {
  const _EntryInfoChip({
    required this.icon,
    required this.label,
    required this.accent,
  });

  final IconData icon;
  final String label;
  final Color accent;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
    decoration: BoxDecoration(
      color: Theme.of(context).colorScheme.surface.withValues(alpha: 0.72),
      borderRadius: BorderRadius.circular(999),
      border: Border.all(color: accent.withValues(alpha: 0.18)),
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 14, color: accent),
        const SizedBox(width: 5),
        Text(
          label,
          style: Theme.of(context).textTheme.labelSmall?.copyWith(
            color: Theme.of(context).colorScheme.onSurfaceVariant,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    ),
  );
}

class _EntryDetail extends StatelessWidget {
  const _EntryDetail({
    required this.icon,
    required this.label,
    required this.value,
    required this.accent,
  });

  final IconData icon;
  final String label;
  final String value;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 9),
      decoration: BoxDecoration(
        color: Color.alphaBlend(
          accent.withValues(alpha: 0.09),
          theme.colorScheme.surface,
        ),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: accent.withValues(alpha: 0.22)),
      ),
      child: Row(
        children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: accent.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(9),
            ),
            child: Icon(icon, size: 19, color: accent),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: accent,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 1),
                Text(
                  value,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
