import 'package:flutter/material.dart';

import '../../domain/inventory_property_profile.dart';
import 'inventory_dashboard_card.dart';

class InventorySummaryHeader extends StatelessWidget {
  const InventorySummaryHeader({
    required this.profile,
    required this.fruitAssetPath,
    super.key,
  });

  final InventoryPropertyProfile profile;
  final String fruitAssetPath;

  @override
  Widget build(BuildContext context) {
    return InventoryDashboardCard(
      padding: const EdgeInsets.fromLTRB(22, 20, 18, 18),
      gradient: const LinearGradient(
        colors: [Color(0xFFE7F1E5), Color(0xFFF8FBF6)],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final wide = constraints.maxWidth >= 560;
          final content = _HeroText(profile: profile);
          final illustration = _FruitIllustration(
            assetPath: fruitAssetPath,
            size: wide ? 168 : 132,
          );

          if (wide) {
            return Row(
              children: [
                Expanded(child: content),
                const SizedBox(width: 16),
                illustration,
              ],
            );
          }

          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              content,
              const SizedBox(height: 12),
              Align(alignment: Alignment.centerRight, child: illustration),
            ],
          );
        },
      ),
    );
  }
}

class _HeroText extends StatelessWidget {
  const _HeroText({required this.profile});

  final InventoryPropertyProfile profile;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'VISÃO DA PROPRIEDADE',
          style: theme.textTheme.labelMedium?.copyWith(
            color: const Color(0xFF3C6E47),
            fontWeight: FontWeight.w800,
            letterSpacing: 1.1,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          profile.farmName,
          style: theme.textTheme.headlineSmall?.copyWith(
            color: const Color(0xFF173326),
            fontWeight: FontWeight.w900,
            height: 1.1,
          ),
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            _HeroBadge(
              icon: Icons.landscape_outlined,
              label: profile.totalArea,
            ),
            _HeroBadge(icon: Icons.eco_outlined, label: profile.crop),
          ],
        ),
      ],
    );
  }
}

class _HeroBadge extends StatelessWidget {
  const _HeroBadge({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.82),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: const Color(0xFFD6E4D5)),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 18, color: const Color(0xFF3C6E47)),
            const SizedBox(width: 7),
            Text(
              label,
              style: Theme.of(context).textTheme.labelLarge?.copyWith(
                color: const Color(0xFF294C35),
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _FruitIllustration extends StatelessWidget {
  const _FruitIllustration({required this.assetPath, required this.size});

  final String assetPath;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      image: true,
      label: 'Ilustração de lichia',
      child: Container(
        width: size,
        height: size,
        padding: const EdgeInsets.all(8),
        decoration: const BoxDecoration(
          shape: BoxShape.circle,
          gradient: RadialGradient(
            colors: [Color(0xFFFFFFFF), Color(0xFFDDEED8)],
          ),
        ),
        child: ExcludeSemantics(
          child: Image.asset(
            assetPath,
            fit: BoxFit.contain,
            errorBuilder: (context, error, stackTrace) => const Icon(
              Icons.image_not_supported_outlined,
              size: 46,
              color: Color(0xFF5F6F64),
            ),
          ),
        ),
      ),
    );
  }
}
