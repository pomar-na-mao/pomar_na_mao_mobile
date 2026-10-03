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
        final canSyncAny = operations.any(
          (op) =>
              op.syncStatus == SprayingSyncStatus.reviewed ||
              op.syncStatus == SprayingSyncStatus.error,
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
                            color: colorScheme.primaryContainer
                                .withValues(alpha: 0.5),
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
                      color: colorScheme.primaryContainer.withValues(alpha: 0.3),
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
                                    style: theme.textTheme.titleMedium?.copyWith(
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
  });

  final SprayingOperation operation;
  final SprayingViewModel viewModel;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isSyncing = viewModel.isSyncing;

    return Material(
      color: colorScheme.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(color: colorScheme.outlineVariant),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    operation.title?.isNotEmpty == true
                        ? operation.title!
                        : 'Pulverização',
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                ),
                _buildStatusBadge(context, operation.syncStatus),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              'Operador: ${operation.operatorName}',
              style: theme.textTheme.bodySmall?.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
            ),
            if (operation.machineName != null &&
                operation.machineName!.isNotEmpty)
              Text(
                'Equipamento: ${operation.machineName}',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
            const SizedBox(height: 8),
            Row(
              children: [
                Icon(
                  Icons.route_outlined,
                  size: 14,
                  color: colorScheme.outline,
                ),
                const SizedBox(width: 4),
                Text(
                  '${operation.route?.distanceMeters.toStringAsFixed(0) ?? 0}m',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: colorScheme.outline,
                  ),
                ),
                const SizedBox(width: 14),
                Icon(
                  Icons.eco_outlined,
                  size: 14,
                  color: colorScheme.outline,
                ),
                const SizedBox(width: 4),
                Text(
                  '${operation.confirmedPlants.length} plantas',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: colorScheme.outline,
                  ),
                ),
                const SizedBox(width: 14),
                Icon(
                  Icons.science_outlined,
                  size: 14,
                  color: colorScheme.outline,
                ),
                const SizedBox(width: 4),
                Text(
                  '${operation.inputs.length} insumos',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: colorScheme.outline,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                IconButton(
                  icon: Icon(
                    Icons.delete_outline,
                    color: colorScheme.error,
                    size: 20,
                  ),
                  tooltip: 'Excluir registro',
                  onPressed: () async {
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
                            style: FilledButton.styleFrom(
                              backgroundColor: colorScheme.error,
                            ),
                            onPressed: () => Navigator.pop(ctx, true),
                            child: const Text('Excluir'),
                          ),
                        ],
                      ),
                    );
                    if (confirm == true) {
                      await viewModel.sprayingRepository.deleteOperation(
                        operation.localId,
                      );
                      await viewModel.loadLocalOperations();
                    }
                  },
                ),
                if (operation.syncStatus == SprayingSyncStatus.draft) ...[
                  const SizedBox(width: 8),
                  FilledButton.icon(
                    style: FilledButton.styleFrom(
                      backgroundColor: const Color(0xFF0284C7),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 8,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    icon: const Icon(Icons.checklist_rounded, size: 16),
                    label: const Text('Revisar e Determinar Plantas'),
                    onPressed: () async {
                      Navigator.of(context).pop();
                      await viewModel.startReviewingOperation(operation);
                    },
                  ),
                ] else if (operation.syncStatus == SprayingSyncStatus.reviewed ||
                    operation.syncStatus == SprayingSyncStatus.error) ...[
                  const SizedBox(width: 8),
                  OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 8,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    icon: const Icon(Icons.edit_note_rounded, size: 16),
                    label: const Text('Revisar'),
                    onPressed: () async {
                      Navigator.of(context).pop();
                      await viewModel.startReviewingOperation(operation);
                    },
                  ),
                  const SizedBox(width: 8),
                  FilledButton.icon(
                    style: FilledButton.styleFrom(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 8,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
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
                        : const Icon(Icons.sync_rounded, size: 16),
                    label: const Text('Sincronizar'),
                    onPressed: isSyncing
                        ? null
                        : () => viewModel.syncOperation(operation.localId),
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusBadge(BuildContext context, SprayingSyncStatus status) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final Color bg;
    final Color fg;
    final String label;

    switch (status) {
      case SprayingSyncStatus.synced:
        bg = colorScheme.primaryContainer.withValues(alpha: 0.5);
        fg = colorScheme.primary;
        label = 'Sincronizado';
      case SprayingSyncStatus.syncing:
        bg = colorScheme.surfaceContainerHighest;
        fg = colorScheme.outline;
        label = 'Sincronizando...';
      case SprayingSyncStatus.reviewed:
        bg = colorScheme.secondaryContainer.withValues(alpha: 0.6);
        fg = colorScheme.secondary;
        label = 'Pendente de envio';
      case SprayingSyncStatus.error:
        bg = colorScheme.errorContainer.withValues(alpha: 0.6);
        fg = colorScheme.error;
        label = 'Erro no envio';
      case SprayingSyncStatus.draft:
        bg = const Color(0xFFFEF3C7);
        fg = const Color(0xFFB45309);
        label = 'Aguardando Revisão';
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        label,
        style: theme.textTheme.labelSmall?.copyWith(
          color: fg,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }
}
