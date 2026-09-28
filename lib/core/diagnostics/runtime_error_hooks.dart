import 'package:flutter/foundation.dart';

import 'runtime_diagnostics.dart';

/// Installs once without replacing the existing crash reporting chain.
class RuntimeErrorHooks {
  RuntimeErrorHooks(this.diagnostics);

  final RuntimeDiagnostics diagnostics;
  FlutterExceptionHandler? _previousFlutter;
  bool Function(Object, StackTrace)? _previousPlatform;
  FlutterExceptionHandler? _flutterHandler;
  bool Function(Object, StackTrace)? _platformHandler;

  void install() {
    if (_flutterHandler != null) return;
    _previousFlutter = FlutterError.onError;
    _previousPlatform = PlatformDispatcher.instance.onError;
    _flutterHandler = (details) {
      diagnostics.record(
        RuntimeStage.flutterError,
        outcome: RuntimeOutcome.failure,
      );
      (_previousFlutter ?? FlutterError.presentError)(details);
    };
    _platformHandler = (error, stack) {
      diagnostics.record(
        RuntimeStage.asynchronousError,
        outcome: RuntimeOutcome.failure,
      );
      return _previousPlatform?.call(error, stack) ?? false;
    };
    FlutterError.onError = _flutterHandler;
    PlatformDispatcher.instance.onError = _platformHandler;
  }

  void uninstall() {
    if (_flutterHandler == null) return;
    if (identical(FlutterError.onError, _flutterHandler)) {
      FlutterError.onError = _previousFlutter;
    }
    if (identical(PlatformDispatcher.instance.onError, _platformHandler)) {
      PlatformDispatcher.instance.onError = _previousPlatform;
    }
    _flutterHandler = null;
    _platformHandler = null;
  }
}
