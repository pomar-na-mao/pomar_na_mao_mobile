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
    final textTheme = Theme.of(context).textTheme;
    final isEnabled = operation.isEnabled;
    final cardColor = Color.alphaBlend(
      operation.accent.withValues(alpha: 0.10),
      colorScheme.surface,
    );

    return Semantics(
      container: true,
      button: true,
      enabled: isEnabled,
      label: operation.title,
      hint: isEnabled ? 'Toque duas vezes para abrir' : 'Operação indisponível',
      child: ExcludeSemantics(
        child: AnimatedOpacity(
          duration: const Duration(milliseconds: 180),
          opacity: isEnabled ? 1 : 0.52,
          child: Card(
            margin: EdgeInsets.zero,
            elevation: isEnabled ? 1.5 : 0,
            color: cardColor,
            shadowColor: operation.accent.withValues(alpha: 0.20),
            clipBehavior: Clip.antiAlias,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
              side: BorderSide(
                color: operation.accent.withValues(
                  alpha: isEnabled ? 0.34 : 0.20,
                ),
              ),
            ),
            child: InkWell(
              onTap: isEnabled ? onTap : null,
              splashColor: operation.accent.withValues(alpha: 0.12),
              highlightColor: operation.accent.withValues(alpha: 0.06),
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Row(
                  children: [
                    _OperationIcon(operation: operation),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            operation.title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: textTheme.titleMedium?.copyWith(
                              color: colorScheme.onSurface,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            operation.description,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: textTheme.bodySmall?.copyWith(
                              color: colorScheme.onSurfaceVariant,
                              height: 1.28,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 10),
                    _CardAction(operation: operation),
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

class _OperationIcon extends StatelessWidget {
  const _OperationIcon({required this.operation});

  final OperationDefinition operation;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 54,
      height: 54,
      decoration: BoxDecoration(
        color: operation.accent.withValues(alpha: 0.16),
        borderRadius: BorderRadius.circular(17),
        border: Border.all(color: operation.accent.withValues(alpha: 0.22)),
      ),
      child: Icon(operation.icon, size: 29, color: operation.accent),
    );
  }
}

class _CardAction extends StatelessWidget {
  const _CardAction({required this.operation});

  final OperationDefinition operation;

  @override
  Widget build(BuildContext context) {
    final isEnabled = operation.isEnabled;

    return Container(
      width: 34,
      height: 34,
      decoration: BoxDecoration(
        color: isEnabled
            ? operation.accent
            : operation.accent.withValues(alpha: 0.14),
        shape: BoxShape.circle,
      ),
      child: Icon(
        isEnabled ? Icons.arrow_forward_rounded : Icons.lock_outline_rounded,
        size: 18,
        color: isEnabled ? Colors.white : operation.accent,
      ),
    );
  }
}
