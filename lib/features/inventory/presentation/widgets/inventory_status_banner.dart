import 'dart:async';

import 'package:flutter/material.dart';

import 'inventory_dashboard_card.dart';

class InventoryInlineError extends StatelessWidget {
  const InventoryInlineError({
    required this.message,
    required this.onRetry,
    super.key,
  });

  final String message;
  final Future<void> Function() onRetry;

  @override
  Widget build(BuildContext context) {
    return InventoryDashboardCard(
      child: Row(
        children: [
          const Icon(Icons.cloud_off_outlined, color: Color(0xFF9A6111)),
          const SizedBox(width: 12),
          Expanded(child: Text(message)),
          TextButton(
            onPressed: () => unawaited(onRetry()),
            child: const Text('Tentar novamente'),
          ),
        ],
      ),
    );
  }
}

class InventoryMapNotice extends StatelessWidget {
  const InventoryMapNotice({
    required this.message,
    required this.onRetry,
    super.key,
  });

  final String message;
  final Future<void> Function() onRetry;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: const Color(0xFFFFF6E7),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFF0D8AC)),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 8, 8, 8),
        child: Row(
          children: [
            const Icon(Icons.info_outline, color: Color(0xFF8A5A12), size: 21),
            const SizedBox(width: 9),
            Expanded(child: Text(message)),
            TextButton(
              onPressed: () => unawaited(onRetry()),
              child: const Text('Tentar novamente'),
            ),
          ],
        ),
      ),
    );
  }
}

class InventoryMapError extends StatelessWidget {
  const InventoryMapError({
    required this.onRetry,
    super.key,
  });

  final Future<void> Function() onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.map_outlined, size: 38, color: Color(0xFF5F6F64)),
            const SizedBox(height: 8),
            const Text(
              'Não foi possível carregar o mapa.',
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 6),
            FilledButton.tonal(
              onPressed: () => unawaited(onRetry()),
              child: const Text('Tentar novamente'),
            ),
          ],
        ),
      ),
    );
  }
}
