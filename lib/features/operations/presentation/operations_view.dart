import 'package:flutter/material.dart';

import 'inspection_view.dart';
import 'activity_view.dart';
import 'activity_view_model.dart';
import 'inspection_view_model.dart';
import 'mipd_view.dart';
import 'mipd_view_model.dart';
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
    this.mipdViewModel,
    this.mipdMapBuilder,
    this.activityViewModel,
    this.activityMapBuilder,
    super.key,
  });

  final InspectionViewModel? inspectionViewModel;
  final InspectionMapBuilder? inspectionMapBuilder;
  final SprayingViewModel? sprayingViewModel;
  final SprayingMapBuilder? sprayingMapBuilder;
  final MipdViewModel? mipdViewModel;
  final MipdMapBuilder? mipdMapBuilder;
  final ActivityViewModel? activityViewModel;
  final ActivityMapBuilder? activityMapBuilder;

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
    } else if (operation.id == 'mipd' && mipdViewModel != null) {
      Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (_) =>
              MipdView(viewModel: mipdViewModel!, mapBuilder: mipdMapBuilder),
        ),
      );
    } else if (operation.id == 'activity' && activityViewModel != null) {
      Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (_) => ActivityView(
            viewModel: activityViewModel!,
            mapBuilder: activityMapBuilder,
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
                    child: ListView.separated(
                      key: const ValueKey('operations-scroll-view'),
                      padding: EdgeInsets.fromLTRB(
                        horizontalPadding,
                        0,
                        horizontalPadding,
                        24,
                      ),
                      itemCount: operationModules.length,
                      separatorBuilder: (_, _) => const SizedBox(height: 22),
                      itemBuilder: (context, index) => _OperationModuleSection(
                        module: operationModules[index],
                        onOperationTap: (operation) =>
                            _openOperation(context, operation),
                      ),
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

class _OperationModuleSection extends StatelessWidget {
  const _OperationModuleSection({
    required this.module,
    required this.onOperationTap,
  });

  final OperationModuleDefinition module;
  final ValueChanged<OperationDefinition> onOperationTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Semantics(
      container: true,
      label: module.title,
      child: Column(
        key: ValueKey('operations-module-${module.id}'),
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      module.title,
                      style: theme.textTheme.titleLarge?.copyWith(
                        color: colorScheme.onSurface,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      module.subtitle,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                        height: 1.3,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Icon(
                Icons.swipe_left_alt_rounded,
                size: 24,
                color: colorScheme.primary.withValues(alpha: 0.72),
                semanticLabel: 'Arraste para navegar',
              ),
            ],
          ),
          const SizedBox(height: 12),
          LayoutBuilder(
            builder: (context, constraints) {
              final cardWidth = switch (constraints.maxWidth) {
                >= 900 => (constraints.maxWidth - 24) / 3,
                >= 560 => (constraints.maxWidth - 12) / 2,
                _ => constraints.maxWidth * 0.88,
              };
              return SizedBox(
                height: 142,
                child: ListView.separated(
                  key: ValueKey('operations-module-${module.id}-list'),
                  scrollDirection: Axis.horizontal,
                  physics: const BouncingScrollPhysics(
                    parent: AlwaysScrollableScrollPhysics(),
                  ),
                  itemCount: module.operations.length,
                  separatorBuilder: (_, _) => const SizedBox(width: 12),
                  itemBuilder: (context, index) {
                    final operation = module.operations[index];
                    return SizedBox(
                      width: cardWidth,
                      child: OperationCard(
                        key: ValueKey('operation-card-${operation.id}'),
                        operation: operation,
                        onTap: operation.isEnabled
                            ? () => onOperationTap(operation)
                            : null,
                      ),
                    );
                  },
                ),
              );
            },
          ),
        ],
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
