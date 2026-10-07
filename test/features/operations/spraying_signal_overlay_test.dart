import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pomar_na_mao_mobile/features/operations/presentation/widgets/spraying_signal_overlay.dart';

void main() {
  testWidgets('shows a translucent blocking overlay with cancellation', (
    tester,
  ) async {
    var cancelled = false;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Stack(
            fit: StackFit.expand,
            children: [
              const ColoredBox(color: Colors.green),
              Positioned.fill(
                child: SprayingSignalOverlay(onCancel: () => cancelled = true),
              ),
            ],
          ),
        ),
      ),
    );

    expect(find.text('Aguardando sinal estabilizar'), findsOneWidget);
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    final barrier = tester.widget<ModalBarrier>(find.byType(ModalBarrier).last);
    expect(barrier.color, const Color(0x99000000));
    await tester.tap(find.text('Cancelar'));
    await tester.pump();
    expect(cancelled, isTrue);
  });
}
