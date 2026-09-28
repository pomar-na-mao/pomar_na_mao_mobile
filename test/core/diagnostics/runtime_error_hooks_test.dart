import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pomar_na_mao_mobile/core/diagnostics/runtime_diagnostics.dart';
import 'package:pomar_na_mao_mobile/core/diagnostics/runtime_error_hooks.dart';

void main() {
  test('chains existing handlers exactly once and restores them', () {
    final originalFlutter = FlutterError.onError;
    final originalPlatform = PlatformDispatcher.instance.onError;
    addTearDown(() {
      FlutterError.onError = originalFlutter;
      PlatformDispatcher.instance.onError = originalPlatform;
    });
    var flutterCalls = 0;
    var platformCalls = 0;
    void previousFlutter(FlutterErrorDetails details) => flutterCalls++;
    bool previousPlatform(Object error, StackTrace stack) {
      platformCalls++;
      return true;
    }

    FlutterError.onError = previousFlutter;
    PlatformDispatcher.instance.onError = previousPlatform;
    final diagnostics = RuntimeDiagnostics();
    final hooks = RuntimeErrorHooks(diagnostics)..install();
    hooks.install();
    FlutterError.onError!(
      FlutterErrorDetails(exception: StateError('private')),
    );
    expect(
      PlatformDispatcher.instance.onError!(
        StateError('private'),
        StackTrace.current,
      ),
      isTrue,
    );
    expect(flutterCalls, 1);
    expect(platformCalls, 1);
    expect(diagnostics.exportJson(), isNot(contains('private')));
    hooks.uninstall();
    expect(FlutterError.onError, same(previousFlutter));
    expect(PlatformDispatcher.instance.onError, same(previousPlatform));
  });
}
