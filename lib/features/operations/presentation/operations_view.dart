import 'package:flutter/material.dart';

import 'inspection_view.dart';
import 'operation_definition.dart';
import 'widgets/operation_card.dart';

class OperationsView extends StatelessWidget {
  const OperationsView({super.key});

  static const _backgroundColor = Color(0xFFF4F7F2);

  void _openOperation(BuildContext context, OperationDefinition operation) {
    if (!operation.isEnabled || operation.id != 'inspection') return;

    Navigator.of(context)
        .push(MaterialPageRoute<void>(builder: (_) => const InspectionView()));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _backgroundColor,
      appBar: AppBar(
        backgroundColor: _backgroundColor,
        surfaceTintColor: Colors.transparent,
        leading: const Icon(Icons.grid_view_outlined),
        title: const Text('Operações'),
      ),
      body: LayoutBuilder(
        builder: (context, constraints) {
          final horizontalPadding = constraints.maxWidth >= 720 ? 28.0 : 16.0;

          return Align(
            alignment: Alignment.topCenter,
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 1080),
              child: CustomScrollView(
                key: const ValueKey('operations-scroll-view'),
                slivers: [
                  SliverPadding(
                    padding: EdgeInsets.fromLTRB(
                      horizontalPadding,
                      8,
                      horizontalPadding,
                      20,
                    ),
                    sliver: const SliverToBoxAdapter(
                      child: _OperationsHeader(),
                    ),
                  ),
                  SliverPadding(
                    padding: EdgeInsets.fromLTRB(
                      horizontalPadding,
                      0,
                      horizontalPadding,
                      32,
                    ),
                    sliver: SliverGrid(
                      key: const ValueKey('operations-grid'),
                      gridDelegate:
                          const SliverGridDelegateWithMaxCrossAxisExtent(
                            maxCrossAxisExtent: 420,
                            mainAxisExtent: 190,
                            crossAxisSpacing: 16,
                            mainAxisSpacing: 16,
                          ),
                      delegate: SliverChildBuilderDelegate((context, index) {
                        final operation = operationDefinitions[index];
                        return OperationCard(
                          key: ValueKey('operation-card-${operation.id}'),
                          operation: operation,
                          onTap: operation.isEnabled
                              ? () => _openOperation(context, operation)
                              : null,
                        );
                      }, childCount: operationDefinitions.length),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

class _OperationsHeader extends StatelessWidget {
  const _OperationsHeader();

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            colorScheme.primaryContainer,
            colorScheme.primaryContainer.withValues(alpha: 0.58),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(24),
      ),
      child: Padding(
        padding: const EdgeInsets.all(22),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Cuidado em cada etapa',
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      color: colorScheme.onPrimaryContainer,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Acesse as rotinas de manejo e acompanhe as atividades do pomar.',
                    style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                      color: colorScheme.onPrimaryContainer,
                      height: 1.4,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 16),
            Icon(
              Icons.eco_outlined,
              size: 44,
              color: colorScheme.onPrimaryContainer.withValues(alpha: 0.82),
            ),
          ],
        ),
      ),
    );
  }
}
