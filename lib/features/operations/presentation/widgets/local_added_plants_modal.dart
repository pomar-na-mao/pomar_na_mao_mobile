import 'package:flutter/material.dart';

import '../../domain/inspection_models.dart';
import '../inspection_view_model.dart';

class LocalAddedPlantsModal extends StatelessWidget {
  const LocalAddedPlantsModal({
    required this.viewModel,
    super.key,
  });

  final InspectionViewModel viewModel;

  static Future<void> show(BuildContext context, InspectionViewModel viewModel) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => LocalAddedPlantsModal(viewModel: viewModel),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: viewModel,
      builder: (context, _) {
        final theme = Theme.of(context);
        final colorScheme = theme.colorScheme;
        final plants = viewModel.addedPlants;
        final canSync = plants.any(
          (p) =>
              p.status == InspectionSyncStatus.pending ||
              p.status == InspectionSyncStatus.error,
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
                            color: colorScheme.secondaryContainer.withValues(alpha: 0.55),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Icon(
                            Icons.add_location_alt_outlined,
                            color: colorScheme.secondary,
                            size: 22,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Plantas adicionadas',
                                style: theme.textTheme.titleLarge?.copyWith(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 20,
                                ),
                              ),
                              if (plants.isNotEmpty)
                                Text(
                                  '${plants.length} ${plants.length == 1 ? 'ponto no dispositivo' : 'pontos no dispositivo'}',
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
                  Flexible(
                    child: plants.isEmpty
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
                                      Icons.add_location_alt_outlined,
                                      size: 40,
                                      color: colorScheme.onSurfaceVariant,
                                    ),
                                  ),
                                  const SizedBox(height: 16),
                                  Text(
                                    'Nenhuma planta foi marcada.',
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
                            key: const ValueKey('local-added-plants-list'),
                            padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
                            itemCount: plants.length,
                            separatorBuilder: (_, _) => const SizedBox(height: 10),
                            itemBuilder: (context, index) {
                              final plant = plants[index];
                              final zoneName = plant.zoneId != null
                                  ? viewModel.zones
                                      .where((z) => z.id == plant.zoneId)
                                      .firstOrNull
                                      ?.name
                                  : null;
                              return _AddedPlantCard(
                                key: ValueKey('local-added-plant-${plant.localId}'),
                                plant: plant,
                                zoneName: zoneName,
                                onDoubleTap: () => viewModel.removeAddedPlant(
                                  plant.localId,
                                ),
                              );
                            },
                          ),
                  ),
                  if (canSync)
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                      child: FilledButton.icon(
                        key: const ValueKey('sync-added-plants-button'),
                        style: FilledButton.styleFrom(
                          minimumSize: const Size.fromHeight(48),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        onPressed: viewModel.isSyncingAddedPlants
                            ? null
                            : () => viewModel.syncPendingAddedPlants(),
                        icon: viewModel.isSyncingAddedPlants
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
                          viewModel.isSyncingAddedPlants
                              ? 'Sincronizando...'
                              : 'Sincronizar plantas',
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

class _AddedPlantCard extends StatelessWidget {
  const _AddedPlantCard({
    required this.plant,
    required this.onDoubleTap,
    this.zoneName,
    super.key,
  });

  final AddedInspectionPlant plant;
  final VoidCallback onDoubleTap;
  final String? zoneName;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final statusColor = switch (plant.status) {
      InspectionSyncStatus.synced => const Color(0xFF2E7D32),
      InspectionSyncStatus.syncing => colorScheme.primary,
      InspectionSyncStatus.error => colorScheme.error,
      InspectionSyncStatus.pending => colorScheme.outline,
    };

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onDoubleTap: onDoubleTap,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: colorScheme.surfaceContainerLowest,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: colorScheme.outlineVariant),
        ),
        child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.place_outlined, color: colorScheme.secondary, size: 22),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    '${plant.latitude.toStringAsFixed(6)}, ${plant.longitude.toStringAsFixed(6)}',
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _StatusChip(
                  icon: Icons.sync_rounded,
                  label: plant.statusLabel,
                  color: statusColor,
                ),
                _StatusChip(
                  icon: plant.nonExistent
                      ? Icons.hide_source_outlined
                      : Icons.spa_outlined,
                  label: plant.nonExistent ? 'Inexistente' : 'Existente',
                  color: plant.nonExistent
                      ? const Color(0xFFF9A825)
                      : const Color(0xFF2E7D32),
                ),
                if (zoneName != null || plant.zoneId != null)
                  _StatusChip(
                    icon: Icons.grid_view_rounded,
                    label: zoneName ?? 'Zona: ${plant.zoneId}',
                    color: colorScheme.secondary,
                  ),
              ],
            ),
            if (plant.error case final error?) ...[
              const SizedBox(height: 10),
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
      ),
    );
  }
}

class _StatusChip extends StatelessWidget {
  const _StatusChip({
    required this.icon,
    required this.label,
    required this.color,
  });

  final IconData icon;
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 14, color: color),
            const SizedBox(width: 5),
            Text(
              label,
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                color: color,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
