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

  static const _backgroundColor = Color(0xFFF2F6EF);

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
    return Scaffold(
      backgroundColor: _backgroundColor,
      appBar: AppBar(
        backgroundColor: _backgroundColor,
        surfaceTintColor: Colors.transparent,
        title: const Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.agriculture_rounded),
            SizedBox(width: 8),
            Flexible(child: Text('Operações', overflow: TextOverflow.ellipsis)),
          ],
        ),
      ),
      body: LayoutBuilder(
        builder: (context, constraints) {
          final horizontalPadding = constraints.maxWidth >= 720 ? 28.0 : 14.0;
          final contentWidth = constraints.maxWidth - horizontalPadding * 2;
          final columns = contentWidth >= 900
              ? 3
              : contentWidth >= 560
              ? 2
              : 1;

          return Align(
            alignment: Alignment.topCenter,
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 1080),
              child: Column(
                children: [
                  Padding(
                    padding: EdgeInsets.fromLTRB(
                      horizontalPadding,
                      6,
                      horizontalPadding,
                      12,
                    ),
                    child: const _OperationsHeader(
                      key: ValueKey('operations-header'),
                    ),
                  ),
                  Expanded(
                    child: CustomScrollView(
                      key: const ValueKey('operations-scroll-view'),
                      slivers: [
                        SliverPadding(
                          padding: EdgeInsets.fromLTRB(
                            horizontalPadding,
                            0,
                            horizontalPadding,
                            20,
                          ),
                          sliver: SliverGrid(
                            key: const ValueKey('operations-grid'),
                            gridDelegate:
                                SliverGridDelegateWithFixedCrossAxisCount(
                                  crossAxisCount: columns,
                                  mainAxisExtent: 142,
                                  crossAxisSpacing: 12,
                                  mainAxisSpacing: 12,
                                ),
                            delegate: SliverChildBuilderDelegate((
                              context,
                              index,
                            ) {
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
  const _OperationsHeader({super.key});

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return Container(
      height: 112,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF245C3E), Color(0xFF4E914D)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(22),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF245C3E).withValues(alpha: 0.18),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Stack(
        children: [
          const Positioned(
            right: -14,
            bottom: -18,
            child: Icon(
              Icons.agriculture_rounded,
              size: 118,
              color: Color(0x24FFFFFF),
            ),
          ),
          const Positioned(
            right: 94,
            top: 14,
            child: Icon(
              Icons.wb_sunny_outlined,
              size: 24,
              color: Color(0x66FFFFFF),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Row(
                  children: [
                    const Icon(
                      Icons.eco_rounded,
                      color: Colors.white,
                      size: 22,
                    ),
                    const SizedBox(width: 8),
                    Flexible(
                      child: Text(
                        'Trabalho no pomar',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: textTheme.titleLarge?.copyWith(
                          color: Colors.white,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  'Escolha uma atividade para começar.',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: textTheme.bodyMedium?.copyWith(
                    color: Colors.white.withValues(alpha: 0.88),
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
