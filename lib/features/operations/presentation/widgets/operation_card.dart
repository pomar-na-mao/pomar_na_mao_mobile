import 'package:flutter/material.dart';

import '../operation_definition.dart';

class OperationCard extends StatelessWidget {
  const OperationCard({
    required this.operation,
    required this.onTap,
    this.prominent = false,
    super.key,
  });

  final OperationDefinition operation;
  final VoidCallback? onTap;
  final bool prominent;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final isEnabled = operation.isEnabled;
    final foreground = isEnabled
        ? colorScheme.onSurface
        : colorScheme.onSurfaceVariant;
    final actionColor = isEnabled
        ? operation.accent
        : colorScheme.onSurfaceVariant;

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
          elevation: prominent ? 1 : 0,
          color: isEnabled
              ? colorScheme.surface
              : colorScheme.surfaceContainerLow,
          clipBehavior: Clip.antiAlias,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(prominent ? 22 : 18),
            side: BorderSide(
              color: isEnabled
                  ? operation.accent.withValues(alpha: 0.42)
                  : colorScheme.outlineVariant,
            ),
          ),
          child: InkWell(
            onTap: onTap,
            child: Padding(
              padding: EdgeInsets.all(prominent ? 20 : 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _OperationIcon(
                        operation: operation,
                        size: prominent ? 56 : 48,
                        iconSize: prominent ? 30 : 26,
                      ),
                      const Spacer(),
                      Flexible(
                        child: Align(
                          alignment: Alignment.topRight,
                          child: _StatusPill(
                            label: operation.statusLabel,
                            icon: isEnabled
                                ? Icons.check_circle_outline
                                : Icons.lock_outline,
                            color: actionColor,
                          ),
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: prominent ? 18 : 14),
                  Text(
                    operation.title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style:
                        (prominent
                                ? textTheme.headlineSmall
                                : textTheme.titleMedium)
                            ?.copyWith(
                              color: foreground,
                              fontWeight: FontWeight.w800,
                              height: 1.1,
                            ),
                  ),
                  const SizedBox(height: 8),
                  Flexible(
                    fit: FlexFit.loose,
                    child: Text(
                      operation.description,
                      maxLines: prominent ? 2 : 3,
                      overflow: TextOverflow.ellipsis,
                      style: textTheme.bodyMedium?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                        height: 1.28,
                      ),
                    ),
                  ),
                  SizedBox(height: prominent ? 14 : 12),
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          isEnabled ? 'Abrir rotina' : 'Planejada',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: textTheme.labelLarge?.copyWith(
                            color: actionColor,
                            fontWeight: FontWeight.w700,
                          ),
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

class _OperationIcon extends StatelessWidget {
  const _OperationIcon({
    required this.operation,
    required this.size,
    required this.iconSize,
  });

  final OperationDefinition operation;
  final double size;
  final double iconSize;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: operation.accent.withValues(
          alpha: operation.isEnabled ? 0.14 : 0.09,
        ),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Icon(
        operation.icon,
        size: iconSize,
        color: operation.accent.withValues(
          alpha: operation.isEnabled ? 1 : 0.72,
        ),
      ),
    );
  }
}

class _StatusPill extends StatelessWidget {
  const _StatusPill({
    required this.label,
    required this.icon,
    required this.color,
  });

  final String label;
  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(minHeight: 32),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withValues(alpha: 0.20)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: color),
          const SizedBox(width: 5),
          Flexible(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.labelMedium
                  ?.copyWith(color: color, fontWeight: FontWeight.w800),
            ),
          ),
        ],
      ),
    );
  }
}
