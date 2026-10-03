import 'package:flutter/material.dart';

import '../../domain/spraying_models.dart';
import '../inspection_view_model.dart';
import '../spraying_view_model.dart';
import 'local_sprayings_modal.dart';
import 'spraying_session_modal.dart';
import 'spraying_zone_filter_modal.dart';

class SprayingActionCard extends StatelessWidget {
  const SprayingActionCard({
    required this.viewModel,
    super.key,
  });

  final SprayingViewModel viewModel;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isRecording = viewModel.sessionState == SprayingSessionState.recording;
    final isPaused = viewModel.sessionState == SprayingSessionState.paused;
    final unsyncedCount = viewModel.localOperations
        .where((op) => op.syncStatus == SprayingSyncStatus.reviewed)
        .length;

    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 480),
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: colorScheme.surface,
                borderRadius: BorderRadius.circular(24),
                border: Border.all(
                  color: colorScheme.outlineVariant.withValues(alpha: 0.6),
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.06),
                    blurRadius: 14,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                child: Row(
                  children: [
                    // Botão 1: Carregar plantas (Blue / Ocean tone)
                    Expanded(
                      child: _ActionButton(
                        key: const ValueKey('action-spraying-load-plants'),
                        tooltip: 'Carregar plantas',
                        backgroundColor: const Color(0xFFE0F2FE),
                        borderColor: const Color(0xFFBAE6FD),
                        iconColor: const Color(0xFF0284C7),
                        icon: viewModel.loadStatus == InspectionLoadStatus.loading
                            ? const SizedBox(
                                width: 22,
                                height: 22,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2.5,
                                  color: Color(0xFF0284C7),
                                ),
                              )
                            : const Icon(Icons.cloud_download_outlined, size: 24),
                        onPressed: viewModel.loadStatus == InspectionLoadStatus.loading
                            ? null
                            : () => viewModel.loadPlants(),
                      ),
                    ),
                    const SizedBox(width: 10),

                    // Botão 2: Filtro por Zona (Amber / Orange tone)
                    Expanded(
                      child: _ActionButton(
                        key: const ValueKey('action-spraying-filter-zone'),
                        tooltip: 'Filtrar por zona',
                        backgroundColor: const Color(0xFFFEF3C7),
                        borderColor: viewModel.isFiltered
                            ? const Color(0xFFD97706)
                            : const Color(0xFFFDE68A),
                        iconColor: const Color(0xFFD97706),
                        icon: Badge(
                          isLabelVisible: viewModel.isFiltered,
                          smallSize: 8,
                          backgroundColor: const Color(0xFFD97706),
                          child: const Icon(Icons.tune_rounded, size: 24),
                        ),
                        onPressed: () => SprayingZoneFilterModal.show(context, viewModel),
                      ),
                    ),
                    const SizedBox(width: 10),

                    // Botão 3: Controle de Sessão (Emerald / Green tone)
                    Expanded(
                      child: _ActionButton(
                        key: const ValueKey('action-spraying-session'),
                        tooltip: isRecording
                            ? 'Rota gravando (Pausar/Finalizar)'
                            : isPaused
                            ? 'Rota pausada'
                            : 'Iniciar pulverização',
                        backgroundColor: isRecording
                            ? const Color(0xFFDCFCE7)
                            : isPaused
                            ? const Color(0xFFFEF3C7)
                            : const Color(0xFFF0FDF4),
                        borderColor: isRecording
                            ? const Color(0xFF15803D)
                            : isPaused
                            ? const Color(0xFFD97706)
                            : const Color(0xFFBBF7D0),
                        iconColor: isRecording
                            ? const Color(0xFF15803D)
                            : isPaused
                            ? const Color(0xFFD97706)
                            : const Color(0xFF166534),
                        icon: Badge(
                          isLabelVisible: isRecording || isPaused,
                          backgroundColor: isRecording
                              ? const Color(0xFF15803D)
                              : const Color(0xFFD97706),
                          label: isRecording
                              ? const Text('REC', style: TextStyle(fontSize: 9, color: Colors.white, fontWeight: FontWeight.bold))
                              : const Text('PAUSA', style: TextStyle(fontSize: 8, color: Colors.white)),
                          child: Icon(
                            isRecording
                                ? Icons.pause_circle_outline
                                : Icons.play_circle_outline,
                            size: 24,
                          ),
                        ),
                        onPressed: () => SprayingSessionModal.show(context, viewModel),
                      ),
                    ),
                    const SizedBox(width: 10),

                    // Botão 4: Pulverizações salvas (Purple / Violet tone)
                    Expanded(
                      child: _ActionButton(
                        key: const ValueKey('action-spraying-saved-history'),
                        tooltip: 'Pulverizações salvas',
                        backgroundColor: const Color(0xFFEDE9FE),
                        borderColor: const Color(0xFFDDD6FE),
                        iconColor: const Color(0xFF7C3AED),
                        icon: Badge(
                          isLabelVisible: unsyncedCount > 0,
                          backgroundColor: const Color(0xFFD97706),
                          label: Text(
                            '$unsyncedCount',
                            style: const TextStyle(fontSize: 10, color: Colors.white, fontWeight: FontWeight.bold),
                          ),
                          child: const Icon(Icons.folder_outlined, size: 24),
                        ),
                        onPressed: () => LocalSprayingsModal.show(context, viewModel),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _ActionButton extends StatelessWidget {
  const _ActionButton({
    required this.icon,
    required this.tooltip,
    required this.backgroundColor,
    required this.borderColor,
    required this.iconColor,
    required this.onPressed,
    super.key,
  });

  final Widget icon;
  final String tooltip;
  final Color backgroundColor;
  final Color borderColor;
  final Color iconColor;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final isEnabled = onPressed != null;

    return Tooltip(
      message: tooltip,
      child: Material(
        color: isEnabled ? backgroundColor : backgroundColor.withValues(alpha: 0.4),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(
            color: isEnabled ? borderColor : borderColor.withValues(alpha: 0.4),
            width: 1.5,
          ),
        ),
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: onPressed,
          child: SizedBox(
            height: 52,
            child: Center(
              child: IconTheme(
                data: IconThemeData(
                  color: isEnabled ? iconColor : iconColor.withValues(alpha: 0.4),
                ),
                child: icon,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
