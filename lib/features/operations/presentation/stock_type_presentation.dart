import 'package:flutter/material.dart';

import '../domain/stock_models.dart';

@immutable
class StockTypeGroup {
  const StockTypeGroup({required this.type, required this.items});

  final String type;
  final List<StockItem> items;

  String get label => stockTypeLabel(type);
  Color get color => stockTypeColor(type);
}

List<StockTypeGroup> groupStockItemsByType(Iterable<StockItem> items) {
  final itemsByType = <String, List<StockItem>>{};
  for (final item in items) {
    final type = item.type.trim().toUpperCase();
    itemsByType.putIfAbsent(type, () => <StockItem>[]).add(item);
  }

  final groups = itemsByType.entries.map((entry) {
    final sortedItems = List<StockItem>.of(entry.value)
      ..sort((left, right) {
        final byName = left.name.toLowerCase().compareTo(
          right.name.toLowerCase(),
        );
        return byName != 0 ? byName : left.id.compareTo(right.id);
      });
    return StockTypeGroup(type: entry.key, items: sortedItems);
  }).toList();

  groups.sort(
    (left, right) =>
        left.label.toLowerCase().compareTo(right.label.toLowerCase()),
  );
  return groups;
}

Color stockTypeColor(String type) => switch (type.trim().toUpperCase()) {
  'INSECTICIDE' => const Color(0xFFB42318),
  'ACARICIDE' => const Color(0xFFC2410C),
  'FUNGICIDE' => const Color(0xFFB45309),
  'BACTERICIDE' => const Color(0xFFA16207),
  'CUPRIC' => const Color(0xFF92400E),
  'BIOLOGICAL' => const Color(0xFF15803D),
  'FOLIAR_FERTILIZER' => const Color(0xFF4D7C0F),
  'MICRONUTRIENT' => const Color(0xFF1D4ED8),
  'NUTRITION' => const Color(0xFF0E7490),
  'ADJUVANT' => const Color(0xFF6D28D9),
  'OIL' => const Color(0xFF475569),
  'HERBICIDE' => const Color(0xFFBE185D),
  'GROWTH_REGULATOR' => const Color(0xFF0F766E),
  _ => const Color(0xFF7A5A24),
};
