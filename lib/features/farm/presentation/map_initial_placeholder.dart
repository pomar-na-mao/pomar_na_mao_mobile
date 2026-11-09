import 'package:flutter/material.dart';

class MapInitialPlaceholder extends StatelessWidget {
  const MapInitialPlaceholder({required this.resolved, super.key});

  final bool resolved;

  @override
  Widget build(BuildContext context) => ColoredBox(
    color: const Color(0xFFE7ECE6),
    child: Center(
      child: resolved
          ? const Padding(
              padding: EdgeInsets.all(24),
              child: Text(
                'Não foi possível obter a localização nem o ponto inicial da fazenda.',
                textAlign: TextAlign.center,
              ),
            )
          : const CircularProgressIndicator(),
    ),
  );
}
