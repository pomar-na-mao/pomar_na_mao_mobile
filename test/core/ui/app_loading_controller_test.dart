import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:pomar_na_mao_mobile/core/ui/app_loading_controller.dart';

void main() {
  test('keeps loading active until every tracked operation finishes', () async {
    final controller = AppLoadingController();
    final first = Completer<void>();
    final second = Completer<void>();
    final states = <bool>[];

    controller.addListener(() {
      states.add(controller.isLoading);
    });

    final firstOperation = controller.track(() => first.future);
    final secondOperation = controller.track(() => second.future);

    expect(controller.isLoading, isTrue);

    first.complete();
    await firstOperation;
    expect(controller.isLoading, isTrue);

    second.complete();
    await secondOperation;
    expect(controller.isLoading, isFalse);
    expect(states, [true, true, true, false]);
  });

  test('clears loading when a tracked operation fails', () async {
    final controller = AppLoadingController();

    await expectLater(
      controller.track<void>(() => Future<void>.error(Exception('boom'))),
      throwsException,
    );

    expect(controller.isLoading, isFalse);
  });
}
