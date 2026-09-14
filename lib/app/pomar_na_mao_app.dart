import 'package:flutter/material.dart';
import 'package:pomar_na_mao_mobile/core/di/app_dependencies.dart';
import 'package:pomar_na_mao_mobile/core/di/app_scope.dart';

class PomarNaMaoApp extends StatefulWidget {
  const PomarNaMaoApp({this.dependencies, super.key});

  final AppDependencies? dependencies;

  @override
  State<PomarNaMaoApp> createState() => _PomarNaMaoAppState();
}

class _PomarNaMaoAppState extends State<PomarNaMaoApp> {
  @override
  Widget build(BuildContext context) {
    Widget app = MaterialApp(
      title: 'Pomar na mão',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF3C6E47)),
        useMaterial3: true,
      ),
      home: Scaffold(body: Center(child: Text('Pomar na mão'))),
    );

    if (widget.dependencies case final deps?) {
      return AppScope(dependencies: deps, child: app);
    }

    return app;
  }
}
