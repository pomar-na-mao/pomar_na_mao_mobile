import 'package:flutter/material.dart';

@immutable
class OperationDefinition {
  const OperationDefinition({
    required this.id,
    required this.title,
    required this.icon,
    required this.accent,
    required this.isEnabled,
  });

  final String id;
  final String title;
  final IconData icon;
  final Color accent;
  final bool isEnabled;
}

const operationDefinitions = <OperationDefinition>[
  OperationDefinition(
    id: 'inspection',
    title: 'Inspeção',
    icon: Icons.fact_check_outlined,
    accent: Color(0xFF2F6B45),
    isEnabled: true,
  ),
  OperationDefinition(
    id: 'spraying',
    title: 'Pulverização',
    icon: Icons.pest_control_outlined,
    accent: Color(0xFF7A5C12),
    isEnabled: false,
  ),
  OperationDefinition(
    id: 'irrigation',
    title: 'Irrigação',
    icon: Icons.water_drop_outlined,
    accent: Color(0xFF176B87),
    isEnabled: false,
  ),
  OperationDefinition(
    id: 'harvest',
    title: 'Colheita',
    icon: Icons.agriculture_outlined,
    accent: Color(0xFF9A4F18),
    isEnabled: false,
  ),
  OperationDefinition(
    id: 'soil-analysis',
    title: 'Análise de Solo',
    icon: Icons.science_outlined,
    accent: Color(0xFF6B4A35),
    isEnabled: false,
  ),
];
