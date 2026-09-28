import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pomar_na_mao_mobile/core/ui/map_activity.dart';

void main() {
  testWidgets('unmounts inactive surfaces and suspends on background', (
    tester,
  ) async {
    final activity = <bool>[];
    Widget app(bool active) => MaterialApp(
      home: MapActivity(
        active: active,
        child: ActiveMapSurface(
          onActivityChanged: activity.add,
          builder: (_) => const Text('native-surface'),
        ),
      ),
    );
    await tester.pumpWidget(app(true));
    expect(find.text('native-surface'), findsOneWidget);
    await tester.pumpWidget(app(false));
    expect(find.text('native-surface'), findsNothing);
    await tester.pumpWidget(app(true));
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    await tester.pump();
    expect(find.text('native-surface'), findsNothing);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pump();
    expect(find.text('native-surface'), findsOneWidget);
    expect(activity, [true, false, true, false, true]);
    await tester.pumpWidget(const SizedBox.shrink());
    expect(activity.last, isFalse);
  });
}
