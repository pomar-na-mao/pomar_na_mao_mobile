import 'package:flutter/material.dart';

@immutable
class OperationDefinition {
  const OperationDefinition({
    required this.id,
    required this.title,
    required this.description,
    required this.icon,
    required this.accent,
    required this.isEnabled,
  });

  final String id;
  final String title;
  final String description;
  final IconData icon;
  final Color accent;
  final bool isEnabled;
}

const operationDefinitions = <OperationDefinition>[
  OperationDefinition(
    id: 'inspection',
    title: 'Inspeção',
    description: 'Registre ocorrências e acompanhe cada planta no mapa.',
    icon: Icons.fact_check_outlined,
    accent: Color(0xFF2F6B45),
    isEnabled: true,
  ),
  OperationDefinition(
    id: 'spraying',
    title: 'Pulverização',
    description: 'Acompanhe a aplicação, insumos e rota no mapa.',
    icon: Icons.pest_control_outlined,
    accent: Color(0xFFB77900),
    isEnabled: true,
  ),
  OperationDefinition(
    id: 'irrigation',
    title: 'Irrigação',
    description: 'Rotina de acompanhamento hídrico por área.',
    icon: Icons.water_drop_outlined,
    accent: Color(0xFF176B87),
    isEnabled: false,
  ),
  OperationDefinition(
    id: 'harvest',
    title: 'Colheita',
    description: 'Controle de etapas e registros de produção.',
    icon: Icons.shopping_basket_outlined,
    accent: Color(0xFFB83A3A),
    isEnabled: false,
  ),
  OperationDefinition(
    id: 'soil-analysis',
    title: 'Análise de Solo',
    description: 'Leituras e recomendações por talhão.',
    icon: Icons.science_outlined,
    accent: Color(0xFF6B4A35),
    isEnabled: false,
  ),
];
