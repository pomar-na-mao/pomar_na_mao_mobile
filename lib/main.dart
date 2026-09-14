import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'app/pomar_na_mao_app.dart';
import 'core/config/app_config.dart';
import 'core/di/app_dependencies.dart';

void main() {
  // Garante que os bindings do Flutter estejam iniciados antes do runApp
  WidgetsFlutterBinding.ensureInitialized();

  final supabaseClient = SupabaseClient(
    AppConfig.supabaseUrl,
    AppConfig.supabasePublishableKey,
  );

  final dependencies = AppDependencies.fromSupabaseClient(supabaseClient);

  runApp(PomarNaMaoApp(dependencies: dependencies));
}
