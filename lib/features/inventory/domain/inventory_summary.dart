class InventorySummary {
  const InventorySummary({
    required this.existingPlants,
    required this.availablePlantingSpots,
    this.zones = 0,
    this.regionPoints = 0,
    this.farmBoundaryPoints = 0,
  });

  final int existingPlants;
  final int availablePlantingSpots;
  final int zones;
  final int regionPoints;
  final int farmBoundaryPoints;
}
