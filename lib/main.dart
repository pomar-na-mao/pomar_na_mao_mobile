import 'dart:async';

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

import 'app/pomar_na_mao_app.dart';
import 'core/config/app_config.dart';
import 'core/di/app_dependencies.dart';
import 'core/diagnostics/runtime_diagnostics.dart';
import 'core/diagnostics/runtime_error_hooks.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  RuntimeErrorHooks(RuntimeDiagnostics.instance).install();
  _AppWakeLock().start();

  final supabaseClient = SupabaseClient(
    AppConfig.supabaseUrl,
    AppConfig.supabasePublishableKey,
  );

  final dependencies = AppDependencies.fromSupabaseClient(supabaseClient);

  runApp(PomarNaMaoApp(dependencies: dependencies));
}

class _AppWakeLock with WidgetsBindingObserver {
  void start() {
    WidgetsBinding.instance.addObserver(this);
    unawaited(_enable());
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      unawaited(_enable());
    }
  }

  Future<void> _enable() async {
    try {
      await WakelockPlus.enable();
    } catch (error, stackTrace) {
      FlutterError.reportError(
        FlutterErrorDetails(
          exception: error,
          stack: stackTrace,
          library: 'app wake lock',
          context: ErrorDescription('while keeping the screen awake'),
        ),
      );
    }
  }
}
