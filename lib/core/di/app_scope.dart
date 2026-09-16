import 'package:flutter/widgets.dart';

import 'app_dependencies.dart';

/// [InheritedWidget] que provê [AppDependencies] para a árvore de widgets.
class AppScope extends InheritedWidget {
  const AppScope({
    required this.dependencies,
    required super.child,
    super.key,
  });

  final AppDependencies dependencies;

  /// Retorna as dependências do escopo mais próximo. Lança exceção se não encontrado.
  static AppDependencies of(BuildContext context) {
    final scope = context.dependOnInheritedWidgetOfExactType<AppScope>();
    assert(scope != null, 'Nenhum AppScope encontrado no BuildContext');
    return scope!.dependencies;
  }

  /// Retorna as dependências do escopo mais próximo, ou `null` se ausente.
  static AppDependencies? maybeOf(BuildContext context) {
    return context.dependOnInheritedWidgetOfExactType<AppScope>()?.dependencies;
  }

  @override
  bool updateShouldNotify(AppScope oldWidget) =>
      dependencies != oldWidget.dependencies;
}
