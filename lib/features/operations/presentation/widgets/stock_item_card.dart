import 'package:flutter/material.dart';

import '../../domain/stock_models.dart';
import '../stock_type_presentation.dart';

class StockItemCard extends StatelessWidget {
  const StockItemCard({
    required this.item,
    required this.onEdit,
    required this.onDelete,
    super.key,
  });

  final StockItem item;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final accent = stockTypeColor(item.type);
    final quantity = item.quantity == null
        ? 'Sem quantidade'
        : '${_formatQuantity(item.quantity!)} ${item.unit ?? ''}';
    return Card(
      key: ValueKey('stock-item-${item.id}'),
      margin: EdgeInsets.zero,
      clipBehavior: Clip.antiAlias,
      color: Color.alphaBlend(
        accent.withValues(alpha: 0.055),
        theme.colorScheme.surface,
      ),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
        side: BorderSide(color: accent.withValues(alpha: 0.28)),
      ),
      child: InkWell(
        onTap: onEdit,
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color: accent.withValues(alpha: 0.14),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Icon(
                      item.photoObjectPath == null
                          ? Icons.inventory_2_outlined
                          : Icons.image_outlined,
                      color: accent,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          item.name,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: 5),
                        Wrap(
                          spacing: 6,
                          runSpacing: 6,
                          children: [
                            _Badge(
                              icon: Icons.category_outlined,
                              label: stockTypeLabel(item.type),
                              color: accent,
                            ),
                            _Badge(
                              icon: Icons.scale_outlined,
                              label: quantity,
                              color: const Color(0xFF15803D),
                            ),
                          ],
                        ),
                        if (item.activeIngredient case final ingredient?) ...[
                          const SizedBox(height: 8),
                          Text(
                            'Ingrediente ativo: $ingredient',
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Divider(height: 1, color: accent.withValues(alpha: 0.2)),
              const SizedBox(height: 6),
              LayoutBuilder(
                builder: (context, constraints) {
                  final compact = constraints.maxWidth < 300;
                  return Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: compact
                        ? [
                            IconButton.filledTonal(
                              key: ValueKey('edit-stock-${item.id}'),
                              tooltip: 'Editar item',
                              onPressed: onEdit,
                              icon: const Icon(Icons.edit_outlined),
                            ),
                            const SizedBox(width: 8),
                            IconButton.filledTonal(
                              key: ValueKey('delete-stock-${item.id}'),
                              tooltip: 'Excluir item',
                              style: IconButton.styleFrom(
                                foregroundColor: theme.colorScheme.error,
                              ),
                              onPressed: onDelete,
                              icon: const Icon(Icons.delete_outline),
                            ),
                          ]
                        : [
                            TextButton.icon(
                              key: ValueKey('edit-stock-${item.id}'),
                              onPressed: onEdit,
                              icon: const Icon(Icons.edit_outlined, size: 19),
                              label: const Text('Editar'),
                            ),
                            const SizedBox(width: 4),
                            TextButton.icon(
                              key: ValueKey('delete-stock-${item.id}'),
                              style: TextButton.styleFrom(
                                foregroundColor: theme.colorScheme.error,
                              ),
                              onPressed: onDelete,
                              icon: const Icon(Icons.delete_outline, size: 19),
                              label: const Text('Excluir'),
                            ),
                          ],
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Badge extends StatelessWidget {
  const _Badge({required this.icon, required this.label, required this.color});

  final IconData icon;
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
    decoration: BoxDecoration(
      color: color.withValues(alpha: 0.1),
      borderRadius: BorderRadius.circular(20),
      border: Border.all(color: color.withValues(alpha: 0.22)),
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 14, color: color),
        const SizedBox(width: 5),
        Text(
          label,
          style: Theme.of(context).textTheme.labelSmall
              ?.copyWith(color: color, fontWeight: FontWeight.w700),
        ),
      ],
    ),
  );
}

String _formatQuantity(double value) => value == value.roundToDouble()
    ? value.toInt().toString()
    : value.toStringAsFixed(2).replaceFirst(RegExp(r'0+$'), '');
