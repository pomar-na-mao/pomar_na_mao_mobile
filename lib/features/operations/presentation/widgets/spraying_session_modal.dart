import 'package:flutter/material.dart';

import '../../domain/spraying_models.dart';
import '../spraying_view_model.dart';

class SprayingSessionModal extends StatelessWidget {
  const SprayingSessionModal({required this.viewModel, super.key});

  final SprayingViewModel viewModel;

  static Future<void> show(BuildContext context, SprayingViewModel vm) {
    final maxHeight = MediaQuery.sizeOf(context).height * 0.75;
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      constraints: BoxConstraints(maxHeight: maxHeight),
      builder: (_) => SprayingSessionModal(viewModel: vm),
    );
  }

  Future<void> _onFinish(BuildContext context, SprayingViewModel vm) async {
    final nav = Navigator.of(context);
    final messenger = ScaffoldMessenger.of(context);

    if (vm.activeTrackPoints.length < 2) {
      messenger.showSnackBar(
        const SnackBar(
          content: Text(
            'A rota precisa de pelo menos 2 pontos GPS registrados para ser finalizada.',
          ),
        ),
      );
      return;
    }

    await vm.finishSession();
    nav.pop();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final vm = viewModel;

    return ListenableBuilder(
      listenable: vm,
      builder: (context, _) {
        final isIdle = vm.sessionState == SprayingSessionState.idle;
        final isRecording = vm.sessionState == SprayingSessionState.recording;

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
                            Icons.agriculture_rounded,
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
                                'Controle de Pulverização',
                                style: theme.textTheme.titleLarge?.copyWith(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 20,
                                ),
                              ),
                              Text(
                                isIdle
                                    ? 'Pronto para iniciar gravação'
                                    : isRecording
                                    ? 'Gravando rota em tempo real'
                                    : 'Gravação de rota pausada',
                                style: theme.textTheme.bodySmall?.copyWith(
                                  color: isRecording
                                      ? colorScheme.primary
                                      : colorScheme.outline,
                                  fontWeight: isRecording
                                      ? FontWeight.bold
                                      : FontWeight.normal,
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

                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        if (isIdle) ...[
                          // Card informativo inicial
                          Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: colorScheme.surfaceContainerHighest
                                  .withValues(alpha: 0.35),
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(
                                color: colorScheme.outlineVariant,
                              ),
                            ),
                            child: Row(
                              children: [
                                Icon(
                                  Icons.gps_fixed_rounded,
                                  color: colorScheme.primary,
                                  size: 24,
                                ),
                                const SizedBox(width: 14),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        'Rastreamento de Rota GPS',
                                        style: theme.textTheme.bodyMedium
                                            ?.copyWith(
                                              fontWeight: FontWeight.bold,
                                            ),
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        'Toque em Iniciar para gravar o trajeto no pomar. Os dados de produtos e operador serão preenchidos ao finalizar.',
                                        style: theme.textTheme.bodySmall
                                            ?.copyWith(
                                              color: colorScheme.outline,
                                            ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 20),
                          FilledButton.icon(
                            key: const ValueKey('btn-start-spraying'),
                            style: FilledButton.styleFrom(
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(14),
                              ),
                            ),
                            icon: const Icon(
                              Icons.play_arrow_rounded,
                              size: 22,
                            ),
                            label: const Text(
                              'Iniciar Pulverização',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            onPressed: () {
                              vm.startSession();
                              Navigator.of(context).pop();
                            },
                          ),
                        ] else ...[
                          // Métricas da sessão em andamento
                          Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: colorScheme.surfaceContainerHighest
                                  .withValues(alpha: 0.35),
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(
                                color: colorScheme.outlineVariant,
                              ),
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceAround,
                              children: [
                                Column(
                                  children: [
                                    Text(
                                      '${vm.activeTrackPoints.length}',
                                      style: theme.textTheme.headlineSmall
                                          ?.copyWith(
                                            fontWeight: FontWeight.bold,
                                            color: colorScheme.primary,
                                          ),
                                    ),
                                    Text(
                                      'Pontos GPS',
                                      style:
                                          theme.textTheme.bodySmall?.copyWith(
                                            color: colorScheme.outline,
                                          ),
                                    ),
                                  ],
                                ),
                                Container(
                                  width: 1,
                                  height: 36,
                                  color: colorScheme.outlineVariant,
                                ),
                                Column(
                                  children: [
                                    Text(
                                      '${vm.totalDistanceMeters.toStringAsFixed(0)} m',
                                      style: theme.textTheme.headlineSmall
                                          ?.copyWith(
                                            fontWeight: FontWeight.bold,
                                            color: colorScheme.primary,
                                          ),
                                    ),
                                    Text(
                                      'Distância',
                                      style:
                                          theme.textTheme.bodySmall?.copyWith(
                                            color: colorScheme.outline,
                                          ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 20),

                          Row(
                            children: [
                              Expanded(
                                child: isRecording
                                    ? OutlinedButton.icon(
                                        key: const ValueKey(
                                          'btn-pause-spraying',
                                        ),
                                        style: OutlinedButton.styleFrom(
                                          padding: const EdgeInsets.symmetric(
                                            vertical: 14,
                                          ),
                                          shape: RoundedRectangleBorder(
                                            borderRadius:
                                                BorderRadius.circular(14),
                                          ),
                                        ),
                                        icon: const Icon(Icons.pause_rounded),
                                        label: const Text('Parar / Pausar'),
                                        onPressed: () => vm.pauseSession(),
                                      )
                                    : OutlinedButton.icon(
                                        key: const ValueKey(
                                          'btn-resume-spraying',
                                        ),
                                        style: OutlinedButton.styleFrom(
                                          padding: const EdgeInsets.symmetric(
                                            vertical: 14,
                                          ),
                                          shape: RoundedRectangleBorder(
                                            borderRadius:
                                                BorderRadius.circular(14),
                                          ),
                                        ),
                                        icon: const Icon(
                                          Icons.play_arrow_rounded,
                                        ),
                                        label: const Text('Retomar'),
                                        onPressed: () => vm.resumeSession(),
                                      ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: FilledButton.icon(
                                  key: const ValueKey('btn-finish-spraying'),
                                  style: FilledButton.styleFrom(
                                    padding: const EdgeInsets.symmetric(
                                      vertical: 14,
                                    ),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(14),
                                    ),
                                  ),
                                  icon: const Icon(Icons.check_rounded),
                                  label: const Text('Finalizar'),
                                  onPressed: () => _onFinish(context, vm),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          TextButton(
                            key: const ValueKey('btn-cancel-spraying'),
                            style: TextButton.styleFrom(
                              foregroundColor: colorScheme.error,
                            ),
                            onPressed: () async {
                              final confirm = await showDialog<bool>(
                                context: context,
                                builder: (ctx) => AlertDialog(
                                  title: const Text('Descartar sessão?'),
                                  content: const Text(
                                    'Os pontos gravados serão perdidos e a rota não será salva.',
                                  ),
                                  actions: [
                                    TextButton(
                                      onPressed: () => Navigator.pop(ctx, false),
                                      child: const Text('Voltar'),
                                    ),
                                    FilledButton(
                                      style: FilledButton.styleFrom(
                                        backgroundColor: colorScheme.error,
                                      ),
                                      onPressed: () => Navigator.pop(ctx, true),
                                      child: const Text('Descartar'),
                                    ),
                                  ],
                                ),
                              );
                              if (confirm == true) {
                                await vm.cancelSession();
                                if (context.mounted) Navigator.pop(context);
                              }
                            },
                            child: const Text('Cancelar e Descartar Rota'),
                          ),
                        ],
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
