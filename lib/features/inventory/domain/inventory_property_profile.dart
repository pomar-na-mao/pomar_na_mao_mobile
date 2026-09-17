class InventoryPropertyProfile {
  const InventoryPropertyProfile({
    required this.farmName,
    required this.totalArea,
    required this.crop,
    required this.spacing,
    required this.classification,
    required this.density,
    required this.variety,
  });

  static const sitioSaoFrancisco = InventoryPropertyProfile(
    farmName: 'Sítio São Francisco',
    totalArea: '54 ha',
    crop: 'Avocado',
    spacing: '8 × 5 m',
    classification: 'Semi-adensado',
    density: '250 plantas/ha',
    variety: 'Hass',
  );

  final String farmName;
  final String totalArea;
  final String crop;
  final String spacing;
  final String classification;
  final String density;
  final String variety;
}
