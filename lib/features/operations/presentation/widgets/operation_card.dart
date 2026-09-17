import 'package:flutter/material.dart';

import '../operation_definition.dart';

class OperationCard extends StatelessWidget {
  const OperationCard({
    required this.operation,
    required this.onTap,
    super.key,
  });

  final OperationDefinition operation;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final isEnabled = operation.isEnabled;

    return Semantics(
      container: true,
      button: true,
      enabled: isEnabled,
      label: operation.title,
      hint: isEnabled
          ? 'Disponível. Toque duas vezes para abrir'
          : 'Indisponível. Em breve',
      child: ExcludeSemantics(
        child: Card(
          margin: EdgeInsets.zero,
          elevation: 0,
          color: isEnabled
              ? colorScheme.surface
              : colorScheme.surfaceContainerLow,
          clipBehavior: Clip.antiAlias,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
            side: BorderSide(
              color: isEnabled
                  ? operation.accent.withValues(alpha: 0.42)
                  : colorScheme.outlineVariant,
            ),
          ),
          child: InkWell(
            onTap: onTap,
            child: Padding(
              padding: const EdgeInsets.all(18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        width: 52,
                        height: 52,
                        decoration: BoxDecoration(
                          color: operation.accent.withValues(
                            alpha: isEnabled ? 0.14 : 0.09,
                          ),
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Icon(
                          operation.icon,
                          size: 28,
                          color: operation.accent.withValues(
                            alpha: isEnabled ? 1 : 0.72,
                          ),
                        ),
                      ),
                      const Spacer(),
                      if (!isEnabled)
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            color: colorScheme.surfaceContainerHighest,
                            borderRadius: BorderRadius.circular(999),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.lock_outline,
                                size: 16,
                                color: colorScheme.onSurfaceVariant,
                              ),
                              const SizedBox(width: 5),
                              Text(
                                'Em breve',
                                style: Theme.of(context).textTheme.labelMedium
                                    ?.copyWith(
                                      color: colorScheme.onSurfaceVariant,
                                      fontWeight: FontWeight.w700,
                                    ),
                              ),
                            ],
                          ),
                        ),
                    ],
                  ),
                  const Spacer(),
                  Text(
                    operation.title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      color: isEnabled
                          ? colorScheme.onSurface
                          : colorScheme.onSurfaceVariant,
                      fontWeight: FontWeight.w800,
                      height: 1.1,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Text(
                        isEnabled ? 'Acessar operação' : 'Indisponível',
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: isEnabled
                              ? operation.accent
                              : colorScheme.onSurfaceVariant,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      if (isEnabled) ...[
                        const SizedBox(width: 6),
                        Icon(
                          Icons.arrow_forward_rounded,
                          size: 18,
                          color: operation.accent,
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
