import 'package:flutter/material.dart';

import '../spraying_view_model.dart';
import 'spraying_inputs_modal.dart';
import 'spraying_review_modal.dart';

class SprayingReviewActionBar extends StatelessWidget {
  const SprayingReviewActionBar({required this.viewModel, super.key});

  final SprayingViewModel viewModel;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final vm = viewModel;
    final operation = vm.reviewingOperation;

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
                  color: const Color(0xFF2563EB).withValues(alpha: 0.5),
                  width: 1.5,
                ),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF2563EB).withValues(alpha: 0.08),
                    blurRadius: 14,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 14),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Top header row
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(7),
                          decoration: BoxDecoration(
                            color: const Color(0xFFDBEAFE),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: const Icon(
                            Icons.rate_review_rounded,
                            color: Color(0xFF1D4ED8),
                            size: 20,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                operation?.title?.isNotEmpty == true
                                    ? operation!.title!
                                    : 'Revisão de Pulverização',
                                style: theme.textTheme.titleSmall?.copyWith(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 15,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                              Text(
                                'Toque no mapa para marcar/desmarcar plantas',
                                style: theme.textTheme.bodySmall?.copyWith(
                                  color: colorScheme.outline,
                                  fontSize: 11,
                                ),
                              ),
                            ],
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.close, size: 20),
                          tooltip: 'Sair da revisão',
                          onPressed: () => vm.cancelReviewing(),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),

                    Row(
                      key: const ValueKey('review-plants-count'),
                      children: [
                        Text(
                          '${vm.reviewedPlants.length}',
                          style: theme.textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.bold,
                            color: const Color(0xFF1D4ED8),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Flexible(
                          child: Text(
                            'Plantas atingidas',
                            style: theme.textTheme.bodyMedium?.copyWith(
                              color: colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton.icon(
                            key: const ValueKey('btn-review-plants-list'),
                            style: OutlinedButton.styleFrom(
                              minimumSize: const Size.fromHeight(44),
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                              ),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                            icon: const Icon(Icons.checklist_rounded, size: 16),
                            label: const Text('Lista'),
                            onPressed: () =>
                                SprayingReviewModal.show(context, vm),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: FilledButton.icon(
                            key: const ValueKey('btn-review-proceed-inputs'),
                            style: FilledButton.styleFrom(
                              backgroundColor: const Color(0xFF1D4ED8),
                              foregroundColor: Colors.white,
                              minimumSize: const Size.fromHeight(44),
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                              ),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                            icon: const Icon(Icons.science_outlined, size: 16),
                            label: const Text(
                              'Insumos',
                              style: TextStyle(fontWeight: FontWeight.bold),
                            ),
                            onPressed: () =>
                                SprayingInputsModal.show(context, vm),
                          ),
                        ),
                      ],
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
