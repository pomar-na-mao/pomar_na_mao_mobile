import 'inventory_summary.dart';

abstract interface class InventoryRepository {
  Future<InventorySummary> fetchSummary();
}
