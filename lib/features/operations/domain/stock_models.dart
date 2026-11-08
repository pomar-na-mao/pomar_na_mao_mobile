import 'package:flutter/foundation.dart';

const stockUnits = <String>['Kg', 'L', 'm³'];

const defaultStockTypes = <String>[
  'INSECTICIDE',
  'ACARICIDE',
  'FUNGICIDE',
  'BACTERICIDE',
  'CUPRIC',
  'BIOLOGICAL',
  'FOLIAR_FERTILIZER',
  'MICRONUTRIENT',
  'NUTRITION',
  'ADJUVANT',
  'OIL',
  'HERBICIDE',
  'GROWTH_REGULATOR',
];

const _stockTypeLabels = <String, String>{
  'INSECTICIDE': 'Inseticida',
  'ACARICIDE': 'Acaricida',
  'FUNGICIDE': 'Fungicida',
  'BACTERICIDE': 'Bactericida',
  'CUPRIC': 'Cúprico / Cobre',
  'BIOLOGICAL': 'Biológico',
  'FOLIAR_FERTILIZER': 'Adubo foliar',
  'MICRONUTRIENT': 'Micronutriente',
  'NUTRITION': 'Nutrição',
  'ADJUVANT': 'Adjuvante',
  'OIL': 'Óleo mineral / vegetal',
  'HERBICIDE': 'Herbicida',
  'GROWTH_REGULATOR': 'Regulador de crescimento',
};

String stockTypeLabel(String type) =>
    _stockTypeLabels[type.trim().toUpperCase()] ?? type;

@immutable
class StockItem {
  const StockItem({
    required this.id,
    required this.name,
    required this.type,
    required this.registeredForCrop,
    required this.createdAt,
    required this.updatedAt,
    this.activeIngredient,
    this.formulation,
    this.concentration,
    this.chemicalGroup,
    this.manufacturer,
    this.mapaRegistration,
    this.expirationDate,
    this.target1,
    this.target2,
    this.safetyIntervalDays,
    this.labelDose,
    this.doseUnit,
    this.quantity,
    this.unit,
    this.photoObjectPath,
    this.observations,
  });

  final String id;
  final String name;
  final String type;
  final String? activeIngredient;
  final String? formulation;
  final String? concentration;
  final String? chemicalGroup;
  final String? manufacturer;
  final String? mapaRegistration;
  final DateTime? expirationDate;
  final bool registeredForCrop;
  final String? target1;
  final String? target2;
  final int? safetyIntervalDays;
  final String? labelDose;
  final String? doseUnit;
  final double? quantity;
  final String? unit;
  final String? photoObjectPath;
  final String? observations;
  final DateTime createdAt;
  final DateTime updatedAt;
}

@immutable
class StockDraft {
  const StockDraft({
    required this.name,
    required this.type,
    required this.quantity,
    required this.unit,
    this.registeredForCrop = true,
    this.activeIngredient,
    this.formulation,
    this.concentration,
    this.chemicalGroup,
    this.manufacturer,
    this.mapaRegistration,
    this.expirationDate,
    this.target1,
    this.target2,
    this.safetyIntervalDays,
    this.labelDose,
    this.doseUnit,
    this.photoObjectPath,
    this.observations,
  });

  final String name;
  final String type;
  final String? activeIngredient;
  final String? formulation;
  final String? concentration;
  final String? chemicalGroup;
  final String? manufacturer;
  final String? mapaRegistration;
  final DateTime? expirationDate;
  final bool registeredForCrop;
  final String? target1;
  final String? target2;
  final int? safetyIntervalDays;
  final String? labelDose;
  final String? doseUnit;
  final double quantity;
  final String unit;
  final String? photoObjectPath;
  final String? observations;

  String? validate() {
    if (name.trim().isEmpty) return 'Informe o nome do item do estoque.';
    if (name.trim().length > 150) {
      return 'O nome deve ter no máximo 150 caracteres.';
    }
    if (type.trim().isEmpty) return 'Selecione o tipo do item do estoque.';
    if (quantity < 0) {
      return 'A quantidade não pode ser negativa.';
    }
    if (!stockUnits.contains(unit)) {
      return 'Selecione uma unidade válida.';
    }
    if (safetyIntervalDays != null && safetyIntervalDays! < 0) {
      return 'O intervalo de segurança não pode ser negativo.';
    }
    return null;
  }
}

@immutable
class StockPhoto {
  const StockPhoto({required this.path, required this.contentType});

  final String path;
  final String contentType;
}
