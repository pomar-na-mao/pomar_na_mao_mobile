import 'package:flutter/material.dart';

import 'inspection_view.dart';
import 'inspection_view_model.dart';
import 'operation_definition.dart';
import 'spraying_view.dart';
import 'spraying_view_model.dart';
import 'widgets/operation_card.dart';

class OperationsView extends StatelessWidget {
  const OperationsView({
    this.inspectionViewModel,
    this.inspectionMapBuilder,
    this.sprayingViewModel,
    this.sprayingMapBuilder,
    super.key,
  });

  final InspectionViewModel? inspectionViewModel;
  final InspectionMapBuilder? inspectionMapBuilder;
  final SprayingViewModel? sprayingViewModel;
  final SprayingMapBuilder? sprayingMapBuilder;

  static const _backgroundColor = Color(0xFFF4F7F2);

  void _openOperation(BuildContext context, OperationDefinition operation) {
    if (!operation.isEnabled) return;

    if (operation.id == 'inspection') {
      Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (_) => InspectionView(
            viewModel: inspectionViewModel,
            mapBuilder: inspectionMapBuilder,
          ),
        ),
      );
    } else if (operation.id == 'spraying') {
      Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (_) => SprayingView(
            viewModel: sprayingViewModel,
            mapBuilder: sprayingMapBuilder,
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final available = operationDefinitions
        .where((item) => item.isEnabled)
        .toList();
    final future = operationDefinitions
        .where((item) => !item.isEnabled)
        .toList();

    return Scaffold(
      backgroundColor: _backgroundColor,
      appBar: AppBar(
        backgroundColor: _backgroundColor,
        surfaceTintColor: Colors.transparent,
        title: const Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.grid_view_outlined),
            SizedBox(width: 8),
            Flexible(child: Text('Operações', overflow: TextOverflow.ellipsis)),
          ],
        ),
      ),
      body: LayoutBuilder(
        builder: (context, constraints) {
          final horizontalPadding = constraints.maxWidth >= 720 ? 28.0 : 16.0;
          final contentWidth = constraints.maxWidth - horizontalPadding * 2;
          final primaryHeight = constraints.maxWidth >= 720 ? 238.0 : 228.0;
          final futureCardHeight = constraints.maxWidth >= 720 ? 202.0 : 196.0;
          final futureColumns = contentWidth >= 560 ? 2 : 1;

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
                      14,
                    ),
                    sliver: SliverToBoxAdapter(
                      child: _OperationsSummary(
                        availableCount: available.length,
                        futureCount: future.length,
                      ),
                    ),
                  ),
                  SliverPadding(
                    padding: EdgeInsets.fromLTRB(
                      horizontalPadding,
                      0,
                      horizontalPadding,
                      18,
                    ),
                    sliver: SliverToBoxAdapter(
                      child: KeyedSubtree(
                        key: const ValueKey('primary-operation-section'),
                        child: Column(
                          children: [
                            for (var i = 0; i < available.length; i++) ...[
                              if (i > 0) const SizedBox(height: 16),
                              SizedBox(
                                height: primaryHeight,
                                child: OperationCard(
                                  key: ValueKey(
                                    'operation-card-${available[i].id}',
                                  ),
                                  operation: available[i],
                                  prominent: true,
                                  onTap: () =>
                                      _openOperation(context, available[i]),
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ),
                  ),
                  SliverPadding(
                    padding: EdgeInsets.fromLTRB(
                      horizontalPadding,
                      0,
                      horizontalPadding,
                      10,
                    ),
                    sliver: const SliverToBoxAdapter(
                      child: _SectionHeader(
                        title: 'Próximas rotinas',
                        subtitle: 'Planejadas para evoluir o manejo do pomar.',
                      ),
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
                      key: const ValueKey('future-operations-grid'),
                      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: futureColumns,
                        mainAxisExtent: futureCardHeight,
                        crossAxisSpacing: 16,
                        mainAxisSpacing: 16,
                      ),
                      delegate: SliverChildBuilderDelegate((context, index) {
                        final operation = future[index];
                        return OperationCard(
                          key: ValueKey('operation-card-${operation.id}'),
                          operation: operation,
                          onTap: null,
                        );
                      }, childCount: future.length),
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

class _OperationsSummary extends StatelessWidget {
  const _OperationsSummary({
    required this.availableCount,
    required this.futureCount,
  });

  final int availableCount;
  final int futureCount;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return DecoratedBox(
      decoration: BoxDecoration(
        color: colorScheme.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: colorScheme.outlineVariant),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Rotinas de campo',
              style: textTheme.titleLarge?.copyWith(
                color: colorScheme.onSurface,
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'Acesse o manejo disponível e acompanhe as próximas rotinas do pomar.',
              style: textTheme.bodyMedium?.copyWith(
                color: colorScheme.onSurfaceVariant,
                height: 1.35,
              ),
            ),
            const SizedBox(height: 14),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _SummaryChip(
                  icon: Icons.check_circle_outline,
                  label: availableCount == 1
                      ? '1 disponível'
                      : '$availableCount disponíveis',
                ),
                _SummaryChip(
                  icon: Icons.schedule_outlined,
                  label: '$futureCount em breve',
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _SummaryChip extends StatelessWidget {
  const _SummaryChip({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Container(
      constraints: const BoxConstraints(minHeight: 34),
      padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 7),
      decoration: BoxDecoration(
        color: colorScheme.primaryContainer.withValues(alpha: 0.42),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: colorScheme.onPrimaryContainer),
          const SizedBox(width: 6),
          Text(
            label,
            style: Theme.of(context).textTheme.labelLarge?.copyWith(
              color: colorScheme.onPrimaryContainer,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.title, required this.subtitle});

  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: textTheme.titleMedium?.copyWith(
            color: colorScheme.onSurface,
            fontWeight: FontWeight.w900,
          ),
        ),
        const SizedBox(height: 3),
        Text(
          subtitle,
          style: textTheme.bodySmall?.copyWith(
            color: colorScheme.onSurfaceVariant,
            height: 1.25,
          ),
        ),
      ],
    );
  }
}
