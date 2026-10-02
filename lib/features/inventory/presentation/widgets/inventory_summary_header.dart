import 'package:flutter/material.dart';

import '../../domain/inventory_property_profile.dart';
import 'inventory_dashboard_card.dart';

class InventorySummaryHeader extends StatelessWidget {
  const InventorySummaryHeader({
    required this.profile,
    required this.fruitAssetPath,
    this.onRefreshCache,
    this.isRefreshing = false,
    super.key,
  });

  final InventoryPropertyProfile profile;
  final String fruitAssetPath;
  final VoidCallback? onRefreshCache;
  final bool isRefreshing;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isCompact = constraints.maxWidth < 360;
        final isWide = constraints.maxWidth >= 600;
        final illustrationSize = isWide ? 92.0 : (isCompact ? 64.0 : 76.0);

        return InventoryDashboardCard(
          padding: EdgeInsets.symmetric(
            horizontal: isCompact ? 14 : 18,
            vertical: isCompact ? 12 : 14,
          ),
          gradient: const LinearGradient(
            colors: [Color(0xFFE8F2E6), Color(0xFFF7FAF5)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(
                child: _HeroContent(
                  profile: profile,
                  isCompact: isCompact,
                ),
              ),
              SizedBox(width: isCompact ? 10 : 16),
              _FruitIllustration(
                assetPath: fruitAssetPath,
                size: illustrationSize,
              ),
            ],
          ),
        );
      },
    );
  }
}

class _HeroContent extends StatelessWidget {
  const _HeroContent({
    required this.profile,
    required this.isCompact,
  });

  final InventoryPropertyProfile profile;
  final bool isCompact;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 7,
              height: 7,
              decoration: const BoxDecoration(
                color: Color(0xFF2E7D32),
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: 6),
            Flexible(
              child: Text(
                'VISÃO DA PROPRIEDADE',
                style: theme.textTheme.labelSmall?.copyWith(
                  color: const Color(0xFF2E6B3E),
                  fontWeight: FontWeight.w800,
                  letterSpacing: 1.1,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        Text(
          profile.farmName,
          style: theme.textTheme.titleMedium?.copyWith(
            color: const Color(0xFF132A1C),
            fontWeight: FontWeight.w900,
            letterSpacing: -0.2,
            height: 1.2,
            fontSize: isCompact ? 18 : 20,
          ),
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 6,
          runSpacing: 6,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            _HeroBadge(
              icon: Icons.landscape_outlined,
              label: profile.totalArea,
            ),
            _HeroBadge(
              icon: Icons.eco_outlined,
              label: profile.crop,
            ),
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
        color: Colors.white.withValues(alpha: 0.90),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFD2E3D0)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x08173820),
            blurRadius: 4,
            offset: Offset(0, 1.5),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 14, color: const Color(0xFF2E6B3E)),
            const SizedBox(width: 5),
            Text(
              label,
              style: Theme.of(context).textTheme.labelMedium?.copyWith(
                color: const Color(0xFF1E3F29),
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
        padding: const EdgeInsets.all(7),
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: Colors.white,
          border: Border.all(color: const Color(0xFFD4E6D2), width: 1.5),
          boxShadow: const [
            BoxShadow(
              color: Color(0x10173820),
              blurRadius: 10,
              offset: Offset(0, 3),
            ),
          ],
          gradient: const RadialGradient(
            colors: [Color(0xFFFFFFFF), Color(0xFFE4F0E2)],
            center: Alignment(-0.2, -0.2),
            radius: 0.9,
          ),
        ),
        child: ExcludeSemantics(
          child: Image.asset(
            assetPath,
            fit: BoxFit.contain,
            errorBuilder: (context, error, stackTrace) => const Icon(
              Icons.image_not_supported_outlined,
              size: 34,
              color: Color(0xFF5F6F64),
            ),
          ),
        ),
      ),
    );
  }
}
