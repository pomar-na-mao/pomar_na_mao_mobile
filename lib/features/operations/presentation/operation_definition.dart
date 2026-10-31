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

@immutable
class OperationModuleDefinition {
  const OperationModuleDefinition({
    required this.id,
    required this.title,
    required this.subtitle,
    required this.operations,
  });

  final String id;
  final String title;
  final String subtitle;
  final List<OperationDefinition> operations;
}

const operationModules = <OperationModuleDefinition>[
  OperationModuleDefinition(
    id: 'orchard-routine',
    title: 'Rotina do pomar',
    subtitle: 'Registros e controles para o trabalho diário no campo.',
    operations: [
      OperationDefinition(
        id: 'inspection',
        title: 'Inspeção',
        description: 'Registre ocorrências e acompanhe cada planta no mapa.',
        icon: Icons.fact_check_outlined,
        accent: Color(0xFF2F6B45),
        isEnabled: true,
      ),
      OperationDefinition(
        id: 'mipd',
        title: 'MIPD',
        description: 'Manejo integrado de pragas e doenças no pomar.',
        icon: Icons.bug_report_outlined,
        accent: Color(0xFF0F766E),
        isEnabled: true,
      ),
      OperationDefinition(
        id: 'activity',
        title: 'Atividade',
        description: 'Registre atividades em rotas e áreas desenhadas no mapa.',
        icon: Icons.edit_location_alt_outlined,
        accent: Color(0xFF5B6F32),
        isEnabled: true,
      ),
      OperationDefinition(
        id: 'stock',
        title: 'Estoque',
        description: 'Controle entradas, saídas e saldos dos produtos.',
        icon: Icons.inventory_2_outlined,
        accent: Color(0xFF7A5A24),
        isEnabled: false,
      ),
      OperationDefinition(
        id: 'agronomic-sampling',
        title: 'Coletas agronômicas',
        description: 'Organize amostras e registros coletados no campo.',
        icon: Icons.biotech_outlined,
        accent: Color(0xFF6A4C93),
        isEnabled: false,
      ),
    ],
  ),
  OperationModuleDefinition(
    id: 'production-management',
    title: 'Gestão da produção',
    subtitle:
        'Acompanhe aplicações, recursos, colheita e planejamento técnico.',
    operations: [
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
        title: 'Análise de solo',
        description: 'Leituras e recomendações por talhão.',
        icon: Icons.science_outlined,
        accent: Color(0xFF6B4A35),
        isEnabled: false,
      ),
      OperationDefinition(
        id: 'activity-planning',
        title: 'Planejamento de atividades',
        description: 'Programe tarefas, responsáveis e prazos do pomar.',
        icon: Icons.event_note_outlined,
        accent: Color(0xFF3F5E8C),
        isEnabled: false,
      ),
    ],
  ),
];
