import 'dart:async';

import 'package:flutter/material.dart';

import '../../../core/config/app_config.dart';
import 'inventory_view_model.dart';
import 'widgets/inventory_cultivation_card.dart';
import 'widgets/inventory_map_section.dart';
import 'widgets/inventory_metrics_grid.dart';
import 'widgets/inventory_summary_header.dart';

export 'widgets/inventory_dashboard_card.dart' show formatInventoryCount;
export 'widgets/inventory_map_section.dart' show InventoryMapBuilder;

class InventoryView extends StatefulWidget {
  InventoryView({
    required this.viewModel,
    this.mapBuilder,
    String? fruitAssetPath,
    super.key,
  }) : fruitAssetPath = fruitAssetPath ?? AppConfig.activeTenant.fruitAssetPath;

  final InventoryViewModel viewModel;
  final InventoryMapBuilder? mapBuilder;
  final String fruitAssetPath;

  @override
  State<InventoryView> createState() => _InventoryViewState();
}

class _InventoryViewState extends State<InventoryView> {
  static const _backgroundColor = Color(0xFFF4F7F2);
  final ScrollController _scrollController = ScrollController();
  bool _isScrolled = false;

  @override
  void initState() {
    super.initState();
    unawaited(widget.viewModel.initialize());
    _scrollController.addListener(_onScroll);
  }

  void _onScroll() {
    final scrolled = _scrollController.hasClients && _scrollController.offset > 4;
    if (scrolled != _isScrolled) {
      setState(() {
        _isScrolled = scrolled;
      });
    }
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(covariant InventoryView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.viewModel != widget.viewModel) {
      unawaited(widget.viewModel.initialize());
    }
  }

  Future<void> _handleRefreshCache(BuildContext context) async {
    try {
      await widget.viewModel.refreshCache();
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Dados e cache atualizados com sucesso!'),
          duration: Duration(seconds: 3),
        ),
      );
    } catch (_) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Não foi possível atualizar o cache. Verifique sua conexão.',
          ),
          duration: Duration(seconds: 4),
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
            Icon(Icons.inventory_2_outlined),
            SizedBox(width: 8),
            Flexible(
              child: Text('Inventário', overflow: TextOverflow.ellipsis),
            ),
          ],
        ),
        actions: [
          ListenableBuilder(
            listenable: widget.viewModel,
            builder: (context, _) {
              final isRefreshing = widget.viewModel.isRefreshingCache;
              return Padding(
                padding: const EdgeInsets.only(right: 8),
                child: IconButton(
                  key: const ValueKey('inventory-refresh-cache-button'),
                  tooltip: 'Carregar dados e atualizar',
                  onPressed: isRefreshing
                      ? null
                      : () => _handleRefreshCache(context),
                  icon: isRefreshing
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Color(0xFF294C35),
                          ),
                        )
                      : const Icon(
                          Icons.cloud_download_outlined,
                          color: Color(0xFF294C35),
                        ),
                ),
              );
            },
          ),
        ],
      ),
      body: LayoutBuilder(
        builder: (context, constraints) {
          final horizontalPadding = constraints.maxWidth >= 720 ? 28.0 : 16.0;
          return ListenableBuilder(
            listenable: widget.viewModel,
            builder: (context, _) {
              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    decoration: BoxDecoration(
                      color: _backgroundColor,
                      boxShadow: _isScrolled
                          ? [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.06),
                                blurRadius: 8,
                                offset: const Offset(0, 4),
                              ),
                            ]
                          : null,
                    ),
                    padding: EdgeInsets.fromLTRB(
                      horizontalPadding,
                      8,
                      horizontalPadding,
                      12,
                    ),
                    child: Align(
                      alignment: Alignment.topCenter,
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 960),
                        child: InventorySummaryHeader(
                          key: const ValueKey('inventory-property-hero'),
                          profile: widget.viewModel.profile,
                          fruitAssetPath: widget.fruitAssetPath,
                          onRefreshCache: () => _handleRefreshCache(context),
                          isRefreshing: widget.viewModel.isRefreshingCache,
                        ),
                      ),
                    ),
                  ),
                  Expanded(
                    child: RefreshIndicator(
                      onRefresh: () => _handleRefreshCache(context),
                      child: SingleChildScrollView(
                        controller: _scrollController,
                        physics: const AlwaysScrollableScrollPhysics(),
                        padding: EdgeInsets.fromLTRB(
                          horizontalPadding,
                          4,
                          horizontalPadding,
                          32,
                        ),
                        child: Align(
                          alignment: Alignment.topCenter,
                          child: ConstrainedBox(
                            constraints: const BoxConstraints(maxWidth: 960),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                InventoryMetricsGrid(viewModel: widget.viewModel),
                                const SizedBox(height: 18),
                                InventoryCultivationCard(
                                  key: const ValueKey('inventory-cultivation-card'),
                                  profile: widget.viewModel.profile,
                                ),
                                const SizedBox(height: 18),
                                InventoryMapSection(
                                  key: const ValueKey('inventory-map-card'),
                                  viewModel: widget.viewModel,
                                  mapBuilder: widget.mapBuilder,
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              );
            },
          );
        },
      ),
    );
  }
}
