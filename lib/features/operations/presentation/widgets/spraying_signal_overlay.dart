import 'package:flutter/material.dart';

class SprayingSignalOverlay extends StatelessWidget {
  const SprayingSignalOverlay({required this.onCancel, super.key});

  final VoidCallback? onCancel;

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        const ModalBarrier(color: Color(0x99000000), dismissible: false),
        Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const CircularProgressIndicator(color: Colors.white),
                const SizedBox(height: 24),
                Text(
                  'Aguardando sinal estabilizar',
                  key: const ValueKey('spraying-signal-message'),
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 16),
                TextButton(
                  onPressed: onCancel,
                  style: TextButton.styleFrom(foregroundColor: Colors.white),
                  child: const Text('Cancelar'),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
