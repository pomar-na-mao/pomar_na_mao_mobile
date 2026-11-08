import 'package:flutter/material.dart';

import '../domain/stock_models.dart';
import 'stock_type_presentation.dart';
import 'stock_view_model.dart';
import 'widgets/stock_form_sheet.dart';
import 'widgets/stock_item_card.dart';

class StockView extends StatefulWidget {
  const StockView({required this.viewModel, super.key});

  final StockViewModel viewModel;

  @override
  State<StockView> createState() => _StockViewState();
}

class _StockViewState extends State<StockView> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback(
      (_) => widget.viewModel.load(),
    );
  }

  @override
  Widget build(BuildContext context) {
    const background = Color(0xFFF2F6EF);
    return Scaffold(
      backgroundColor: background,
      appBar: AppBar(
        backgroundColor: background,
        surfaceTintColor: Colors.transparent,
        title: const Text('Estoque'),
        actions: [
          IconButton(
            key: const ValueKey('refresh-stock'),
            tooltip: 'Atualizar estoque',
            onPressed: widget.viewModel.load,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        key: const ValueKey('add-stock-item'),
        onPressed: () => _openForm(),
        icon: const Icon(Icons.add),
        label: const Text('Adicionar'),
      ),
      body: SafeArea(
        top: false,
        child: Align(
          alignment: Alignment.topCenter,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 760),
            child: ListenableBuilder(
              listenable: widget.viewModel,
              builder: (context, _) => Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
                    child: TextField(
                      key: const ValueKey('stock-search'),
                      onChanged: widget.viewModel.search,
                      decoration: InputDecoration(
                        hintText: 'Buscar por nome, tipo ou ingrediente ativo',
                        prefixIcon: const Icon(Icons.search),
                        filled: true,
                        fillColor: Theme.of(context).colorScheme.surface,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(16),
                          borderSide: BorderSide.none,
                        ),
                      ),
                    ),
                  ),
                  Expanded(child: _content()),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _content() {
    if (widget.viewModel.loading && widget.viewModel.items.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }
    if (widget.viewModel.error != null && widget.viewModel.items.isEmpty) {
      return _MessageState(
        icon: Icons.cloud_off_outlined,
        title: 'Não foi possível carregar o estoque',
        actionLabel: 'Tentar novamente',
        onAction: widget.viewModel.load,
      );
    }
    final items = widget.viewModel.filteredItems;
    if (items.isEmpty) {
      return const _MessageState(
        icon: Icons.inventory_2_outlined,
        title: 'Nenhum item encontrado',
      );
    }
    final groups = groupStockItemsByType(items);
    final entries = <Object>[
      for (final group in groups) ...[group, ...group.items],
    ];
    return RefreshIndicator(
      onRefresh: widget.viewModel.load,
      child: ListView.builder(
        key: const ValueKey('stock-items-list'),
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 96),
        itemCount: entries.length,
        itemBuilder: (context, index) {
          final entry = entries[index];
          return switch (entry) {
            StockTypeGroup group => _StockTypeHeader(group: group),
            StockItem item => Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: StockItemCard(
                item: item,
                onEdit: () => _openForm(item),
                onDelete: () => _confirmDelete(item),
              ),
            ),
            _ => const SizedBox.shrink(),
          };
        },
      ),
    );
  }

  Future<void> _openForm([StockItem? item]) async {
    final saved = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (_) => SizedBox.expand(
        child: StockFormSheet(viewModel: widget.viewModel, item: item),
      ),
    );
    if (!mounted || saved != true) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          item == null
              ? 'Item adicionado ao estoque.'
              : 'Item do estoque atualizado.',
        ),
      ),
    );
  }

  Future<void> _confirmDelete(StockItem item) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Excluir item?'),
        content: Text('O item “${item.name}” será removido do estoque.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.error,
            ),
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Excluir'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    final deleted = await widget.viewModel.delete(item);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          deleted
              ? 'Item removido do estoque.'
              : widget.viewModel.error ?? 'Erro ao excluir.',
        ),
      ),
    );
  }
}

class _StockTypeHeader extends StatelessWidget {
  const _StockTypeHeader({required this.group});

  final StockTypeGroup group;

  @override
  Widget build(BuildContext context) => Padding(
    key: ValueKey('stock-type-group-${group.type}'),
    padding: const EdgeInsets.fromLTRB(4, 14, 4, 8),
    child: Row(
      children: [
        Container(
          key: ValueKey('stock-type-color-${group.type}'),
          width: 12,
          height: 12,
          decoration: BoxDecoration(color: group.color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            group.label,
            style: Theme.of(context).textTheme.titleSmall
                ?.copyWith(color: group.color, fontWeight: FontWeight.w800),
          ),
        ),
        Text(
          '${group.items.length} ${group.items.length == 1 ? 'item' : 'itens'}',
          style: Theme.of(context).textTheme.labelMedium
              ?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant),
        ),
      ],
    ),
  );
}

class _MessageState extends StatelessWidget {
  const _MessageState({
    required this.icon,
    required this.title,
    this.actionLabel,
    this.onAction,
  });

  final IconData icon;
  final String title;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 52, color: Theme.of(context).colorScheme.outline),
          const SizedBox(height: 12),
          Text(title, textAlign: TextAlign.center),
          if (actionLabel != null) ...[
            const SizedBox(height: 12),
            OutlinedButton(onPressed: onAction, child: Text(actionLabel!)),
          ],
        ],
      ),
    ),
  );
}
