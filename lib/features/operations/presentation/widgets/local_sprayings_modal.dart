import 'package:flutter/material.dart';

import '../../domain/spraying_models.dart';
import '../spraying_view_model.dart';

class LocalSprayingsModal extends StatelessWidget {
  const LocalSprayingsModal({required this.viewModel, super.key});

  final SprayingViewModel viewModel;

  static Future<void> show(BuildContext context, SprayingViewModel vm) {
    final maxHeight = MediaQuery.sizeOf(context).height * 0.75;
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      constraints: BoxConstraints(maxHeight: maxHeight),
      builder: (_) => LocalSprayingsModal(viewModel: vm),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: viewModel,
      builder: (context, _) {
        final theme = Theme.of(context);
        final colorScheme = theme.colorScheme;
        final operations = viewModel.localOperations;
        final canSyncAny = operations.any((op) => op.isEligibleForSync);

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
                        color: colorScheme.outlineVariant.withValues(
                          alpha: 0.6,
                        ),
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
                                'Pulverizações Salvas',
                                style: theme.textTheme.titleLarge?.copyWith(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 20,
                                ),
                              ),
                              if (operations.isNotEmpty)
                                Text(
                                  '${operations.length} ${operations.length == 1 ? "registro no dispositivo" : "registros no dispositivo"}',
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
                      color: colorScheme.primaryContainer.withValues(
                        alpha: 0.3,
                      ),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 20,
                        vertical: 10,
                      ),
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
                  if (viewModel.errorMessage case final message?)
                    Container(
                      color: colorScheme.errorContainer,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 20,
                        vertical: 10,
                      ),
                      child: Row(
                        children: [
                          Icon(
                            Icons.warning_amber_rounded,
                            size: 18,
                            color: colorScheme.onErrorContainer,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              message,
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: colorScheme.onErrorContainer,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),

                  // Lista de pulverizações
                  Expanded(
                    child: operations.isEmpty
                        ? Center(
                            child: Padding(
                              padding: const EdgeInsets.all(32),
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    Icons.inventory_2_outlined,
                                    size: 48,
                                    color: colorScheme.outline,
                                  ),
                                  const SizedBox(height: 12),
                                  Text(
                                    'Nenhum registro local',
                                    style: theme.textTheme.titleMedium
                                        ?.copyWith(
                                          fontWeight: FontWeight.bold,
                                          color: colorScheme.onSurface,
                                        ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    'As pulverizações salvas neste dispositivo aparecerão aqui.',
                                    textAlign: TextAlign.center,
                                    style: theme.textTheme.bodySmall?.copyWith(
                                      color: colorScheme.outline,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          )
                        : ListView.separated(
                            padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
                            itemCount: operations.length,
                            separatorBuilder: (_, _) =>
                                const SizedBox(height: 10),
                            itemBuilder: (ctx, idx) {
                              final op = operations[idx];
                              return _SprayingOperationCard(
                                key: ValueKey(
                                  'local-spraying-card-${op.localId}',
                                ),
                                operation: op,
                                viewModel: viewModel,
                              );
                            },
                          ),
                  ),

                  // Botão de sincronização em lote
                  if (canSyncAny)
                    Padding(
                      padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
                      child: FilledButton.icon(
                        key: const ValueKey('sync-all-sprayings-button'),
                        icon: const Icon(Icons.sync_rounded),
                        label: const Text('Sincronizar Todas'),
                        style: FilledButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                        ),
                        onPressed: viewModel.isSyncing
                            ? null
                            : () => viewModel.syncAllReviewedOperations(),
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

class _SprayingOperationCard extends StatelessWidget {
  const _SprayingOperationCard({
    required this.operation,
    required this.viewModel,
    super.key,
  });

  final SprayingOperation operation;
  final SprayingViewModel viewModel;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isSyncing = viewModel.isSyncing;
    final hasReviewedPlants = operation.hasReviewedPlants;
    final responsible = operation.responsible.trim();
    final displayedResponsible =
        responsible.isEmpty || responsible == 'Operador'
        ? 'A definir'
        : responsible;
    final status = _statusVisual(operation.syncStatus);
    final performedAt = operation.performedAt.toLocal();
    final date =
        '${performedAt.day.toString().padLeft(2, '0')}/'
        '${performedAt.month.toString().padLeft(2, '0')}/'
        '${performedAt.year} às '
        '${performedAt.hour.toString().padLeft(2, '0')}:'
        '${performedAt.minute.toString().padLeft(2, '0')}';
    final title = operation.title?.trim();
    final machine = operation.machineNameSnapshot ?? operation.machineName;
    final machineDescription = machine == null
        ? 'Não informada'
        : '$machine'
              '${operation.machineBrandSnapshot == null ? '' : ' • ${operation.machineBrandSnapshot}'}';

    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: Color.alphaBlend(
          status.color.withValues(alpha: 0.055),
          colorScheme.surface,
        ),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: status.color.withValues(alpha: 0.28)),
        boxShadow: [
          BoxShadow(
            color: status.color.withValues(alpha: 0.08),
            blurRadius: 16,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Stack(
        children: [
          Positioned(
            left: 0,
            top: 0,
            bottom: 0,
            child: ColoredBox(
              color: status.color,
              child: const SizedBox(width: 5),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(18, 16, 16, 14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _OperationIdentity(
                  key: ValueKey('spraying-identity-${operation.localId}'),
                  title: title?.isNotEmpty == true ? title! : 'Pulverização',
                  date: date,
                  color: status.color,
                ),
                if (operation.syncStatus != SprayingSyncStatus.synced) ...[
                  const SizedBox(height: 10),
                  _StatusBadge(
                    key: ValueKey('spraying-status-${operation.localId}'),
                    status: status,
                  ),
                  const SizedBox(height: 14),
                ] else
                  const SizedBox(height: 14),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: colorScheme.surface.withValues(alpha: 0.82),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: colorScheme.outlineVariant.withValues(alpha: 0.7),
                    ),
                  ),
                  child: Column(
                    children: [
                      _OperationDetail(
                        icon: Icons.person_outline_rounded,
                        label: 'Responsável',
                        value: displayedResponsible,
                        color: const Color(0xFF2563EB),
                      ),
                      const SizedBox(height: 9),
                      _OperationDetail(
                        icon: Icons.agriculture_outlined,
                        label: 'Máquina',
                        value: machineDescription,
                        color: const Color(0xFFEA580C),
                      ),
                      const SizedBox(height: 9),
                      _OperationDetail(
                        icon: Icons.science_outlined,
                        label: 'Calda',
                        value: operation.mixtureNameSnapshot ?? 'Não informada',
                        color: const Color(0xFF7C3AED),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: _MetricTile(
                        key: const ValueKey('spraying-distance-metric'),
                        icon: Icons.route_rounded,
                        label: 'Percurso',
                        value:
                            '${operation.route?.distanceMeters.toStringAsFixed(0) ?? 0} m',
                        color: const Color(0xFF0284C7),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _MetricTile(
                        key: const ValueKey('spraying-plants-metric'),
                        icon: Icons.eco_outlined,
                        label: 'Plantas',
                        value: '${operation.confirmedPlants.length}',
                        color: const Color(0xFF15803D),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                Divider(
                  height: 1,
                  color: colorScheme.outlineVariant.withValues(alpha: 0.65),
                ),
                const SizedBox(height: 10),
                if (operation.syncStatus == SprayingSyncStatus.draft)
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      _DeleteOperationButton(
                        key: ValueKey('delete-spraying-${operation.localId}'),
                        onPressed: () => _deleteOperation(context),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: FilledButton.icon(
                          key: ValueKey('review-spraying-${operation.localId}'),
                          style: FilledButton.styleFrom(
                            backgroundColor: const Color(0xFF0369A1),
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 10,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          icon: const Icon(Icons.checklist_rounded, size: 18),
                          label: const Text(
                            'Revisar',
                            maxLines: 2,
                            textAlign: TextAlign.center,
                          ),
                          onPressed: () async {
                            Navigator.of(context).pop();
                            await viewModel.startReviewingOperation(operation);
                          },
                        ),
                      ),
                    ],
                  )
                else if (operation.syncStatus == SprayingSyncStatus.synced)
                  Row(
                    children: [
                      _DeleteOperationButton(
                        key: ValueKey('delete-spraying-${operation.localId}'),
                        onPressed: () => _deleteOperation(context),
                      ),
                      const Spacer(),
                      _StatusBadge(
                        key: ValueKey('spraying-status-${operation.localId}'),
                        status: status,
                      ),
                    ],
                  )
                else
                  Wrap(
                    alignment: WrapAlignment.end,
                    runAlignment: WrapAlignment.center,
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      _DeleteOperationButton(
                        key: ValueKey('delete-spraying-${operation.localId}'),
                        onPressed: () => _deleteOperation(context),
                      ),
                      if (operation.syncStatus == SprayingSyncStatus.reviewed ||
                          operation.syncStatus == SprayingSyncStatus.error) ...[
                        OutlinedButton.icon(
                          style: OutlinedButton.styleFrom(
                            foregroundColor: const Color(0xFF2563EB),
                            side: const BorderSide(color: Color(0xFF93C5FD)),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 10,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          icon: const Icon(Icons.edit_note_rounded, size: 18),
                          label: const Text('Revisar'),
                          onPressed: () async {
                            Navigator.of(context).pop();
                            await viewModel.startReviewingOperation(operation);
                          },
                        ),
                        Tooltip(
                          message: hasReviewedPlants
                              ? 'Sincronizar pulverização'
                              : 'Revise e associe ao menos uma planta para sincronizar',
                          child: FilledButton.icon(
                            key: ValueKey('sync-spraying-${operation.localId}'),
                            style: FilledButton.styleFrom(
                              backgroundColor: const Color(0xFF15803D),
                              foregroundColor: Colors.white,
                              disabledBackgroundColor:
                                  colorScheme.surfaceContainerHighest,
                              disabledForegroundColor: colorScheme.outline,
                              padding: const EdgeInsets.symmetric(
                                horizontal: 14,
                                vertical: 10,
                              ),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                            icon: isSyncing
                                ? const SizedBox(
                                    width: 14,
                                    height: 14,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: Colors.white,
                                    ),
                                  )
                                : const Icon(
                                    Icons.cloud_upload_outlined,
                                    size: 18,
                                  ),
                            label: const Text('Sincronizar'),
                            onPressed: isSyncing || !hasReviewedPlants
                                ? null
                                : () => viewModel.syncOperation(
                                    operation.localId,
                                  ),
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
    );
  }

  Future<void> _deleteOperation(BuildContext context) async {
    final colorScheme = Theme.of(context).colorScheme;
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Excluir pulverização?'),
        content: const Text(
          'Esta ação removerá a pulverização gravada no dispositivo.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: colorScheme.error),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Excluir'),
          ),
        ],
      ),
    );
    if (confirm == true) {
      await viewModel.sprayingRepository.deleteOperation(operation.localId);
      await viewModel.loadLocalOperations();
    }
  }

  _SprayingStatusVisual _statusVisual(SprayingSyncStatus status) =>
      switch (status) {
        SprayingSyncStatus.synced => const _SprayingStatusVisual(
          color: Color(0xFF15803D),
          icon: Icons.cloud_done_outlined,
          label: 'Sincronizada',
        ),
        SprayingSyncStatus.syncing => const _SprayingStatusVisual(
          color: Color(0xFF0284C7),
          icon: Icons.cloud_sync_outlined,
          label: 'Sincronizando',
        ),
        SprayingSyncStatus.reviewed => const _SprayingStatusVisual(
          color: Color(0xFF2563EB),
          icon: Icons.cloud_upload_outlined,
          label: 'Pronta para envio',
        ),
        SprayingSyncStatus.error => const _SprayingStatusVisual(
          color: Color(0xFFC62828),
          icon: Icons.error_outline_rounded,
          label: 'Erro no envio',
        ),
        SprayingSyncStatus.draft => const _SprayingStatusVisual(
          color: Color(0xFFD97706),
          icon: Icons.edit_note_rounded,
          label: 'Aguardando revisão',
        ),
      };
}

class _SprayingStatusVisual {
  const _SprayingStatusVisual({
    required this.color,
    required this.icon,
    required this.label,
  });

  final Color color;
  final IconData icon;
  final String label;
}

class _OperationIdentity extends StatelessWidget {
  const _OperationIdentity({
    required this.title,
    required this.date,
    required this.color,
    super.key,
  });

  final String title;
  final String date;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.14),
            borderRadius: BorderRadius.circular(14),
          ),
          child: Icon(Icons.water_drop_outlined, color: color, size: 24),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.titleMedium?.copyWith(
                  color: colorScheme.onSurface,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 3),
              Row(
                children: [
                  Icon(
                    Icons.calendar_today_outlined,
                    size: 13,
                    color: colorScheme.onSurfaceVariant,
                  ),
                  const SizedBox(width: 5),
                  Expanded(
                    child: Text(
                      date,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _StatusBadge extends StatelessWidget {
  const _StatusBadge({required this.status, super.key});

  final _SprayingStatusVisual status;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
    decoration: BoxDecoration(
      color: status.color.withValues(alpha: 0.12),
      borderRadius: BorderRadius.circular(20),
      border: Border.all(color: status.color.withValues(alpha: 0.28)),
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(status.icon, size: 14, color: status.color),
        const SizedBox(width: 5),
        Text(
          status.label,
          style: Theme.of(context).textTheme.labelSmall
              ?.copyWith(color: status.color, fontWeight: FontWeight.w800),
        ),
      ],
    ),
  );
}

class _DeleteOperationButton extends StatelessWidget {
  const _DeleteOperationButton({required this.onPressed, super.key});

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return IconButton.filledTonal(
      style: IconButton.styleFrom(
        backgroundColor: colorScheme.errorContainer.withValues(alpha: 0.7),
        foregroundColor: colorScheme.error,
      ),
      icon: const Icon(Icons.delete_outline, size: 20),
      tooltip: 'Excluir registro',
      onPressed: onPressed,
    );
  }
}

class _OperationDetail extends StatelessWidget {
  const _OperationDetail({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
  });

  final IconData icon;
  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      children: [
        Container(
          width: 30,
          height: 30,
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.11),
            borderRadius: BorderRadius.circular(9),
          ),
          child: Icon(icon, size: 17, color: color),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            '$label: $value',
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    );
  }
}

class _MetricTile extends StatelessWidget {
  const _MetricTile({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
    super.key,
  });

  final IconData icon;
  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 10),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.18)),
      ),
      child: Row(
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(width: 9),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  value,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.titleSmall?.copyWith(
                    color: color,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                Text(
                  label,
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
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
