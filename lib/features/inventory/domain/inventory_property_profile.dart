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

  static const ricardoLichia = InventoryPropertyProfile(
    farmName: 'Fazenda Coatiara',
    totalArea: '117 ha',
    crop: 'Lichia',
    spacing: '8 × 5 m',
    classification: 'Semi-adensado',
    density: '187 plantas/ha',
    variety: 'Múltiplas',
  );

  static const hassAvocado = InventoryPropertyProfile(
    farmName: 'Fazenda Santa Maria',
    totalArea: '85 ha',
    crop: 'Abacate Hass',
    spacing: '6 × 4 m',
    classification: 'Adensado',
    density: '416 plantas/ha',
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
