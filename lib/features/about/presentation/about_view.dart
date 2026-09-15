import 'package:flutter/material.dart';

class AboutView extends StatelessWidget {
  const AboutView({super.key});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(title: const Text('Quem somos')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _HeroHeader(colorScheme: colorScheme),
            const SizedBox(height: 20),
            _InstitutionCard(
              logoPath: 'assets/images/logo.png',
              title: 'Pomar na mão',
              subtitle: 'Agricultura de precisão e IA',
              description:
                  'Somos uma empresa dedicada em mudar a gestão de pomares '
                  'através de controle fino com agricultura de precisão e '
                  'inteligência artificial, possibilitando melhor uso de '
                  'recursos e economia.',
              color: colorScheme.primary,
            ),
            const SizedBox(height: 14),
            _InstitutionCard(
              logoPath: 'assets/images/primora.png',
              title: 'Prímora',
              subtitle: 'Consultoria',
              description:
                  'Consultoria agrícola com especialidade em gerenciamento e '
                  'inteligência de dados.',
              color: colorScheme.tertiary,
            ),
          ],
        ),
      ),
    );
  }
}

class _HeroHeader extends StatelessWidget {
  const _HeroHeader({required this.colorScheme});

  final ColorScheme colorScheme;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: colorScheme.primaryContainer,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Pomar na mão',
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                color: colorScheme.onPrimaryContainer,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Tecnologia aplicada para manejo inteligente de pomares.',
              style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                color: colorScheme.onPrimaryContainer,
                height: 1.35,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _InstitutionCard extends StatelessWidget {
  const _InstitutionCard({
    required this.logoPath,
    required this.title,
    required this.subtitle,
    required this.description,
    required this.color,
  });

  final String logoPath;
  final String title;
  final String subtitle;
  final String description;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
        side: BorderSide(color: colorScheme.outlineVariant),
      ),
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 52,
                  height: 52,
                  padding: const EdgeInsets.all(7),
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.12, green: 0.84),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Image.asset(logoPath, fit: BoxFit.contain),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: Theme.of(context).textTheme.titleLarge
                            ?.copyWith(fontWeight: FontWeight.w800),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        subtitle,
                        style: Theme.of(context).textTheme.bodyMedium
                            ?.copyWith(color: color, height: 1.25),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Text(
              description,
              style: Theme.of(context).textTheme.bodyLarge
                  ?.copyWith(color: colorScheme.onSurfaceVariant, height: 1.45),
            ),
          ],
        ),
      ),
    );
  }
}
