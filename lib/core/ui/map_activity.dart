import 'package:flutter/material.dart';

import '../diagnostics/runtime_diagnostics.dart';

class MapActivity extends InheritedWidget {
  const MapActivity({required this.active, required super.child, super.key});
  final bool active;
  static bool of(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<MapActivity>()?.active ?? true;
  @override
  bool updateShouldNotify(MapActivity oldWidget) => active != oldWidget.active;
}

/// Keeps the containing screen's state while releasing the native platform view.
class ActiveMapSurface extends StatefulWidget {
  const ActiveMapSurface({
    required this.builder,
    this.onActivityChanged,
    super.key,
  });
  final WidgetBuilder builder;
  final ValueChanged<bool>? onActivityChanged;
  @override
  State<ActiveMapSurface> createState() => _ActiveMapSurfaceState();
}

class _ActiveMapSurfaceState extends State<ActiveMapSurface>
    with WidgetsBindingObserver {
  bool _visible = true;
  bool _foreground = true;
  bool? _lastActive;
  static int _activeSurfaces = 0;
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _foreground =
        WidgetsBinding.instance.lifecycleState == null ||
        WidgetsBinding.instance.lifecycleState == AppLifecycleState.resumed;
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _visible =
        MapActivity.of(context) && (ModalRoute.of(context)?.isCurrent ?? true);
    _updateActivity();
  }

  void _updateActivity() {
    final active = _visible && _foreground;
    if (_lastActive == active) return;
    if (_lastActive == true) _activeSurfaces--;
    if (active) _activeSurfaces++;
    _lastActive = active;
    RuntimeDiagnostics.instance.record(
      RuntimeStage.lifecycle,
      outcome: active ? RuntimeOutcome.started : RuntimeOutcome.stopped,
      activeMaps: _activeSurfaces,
    );
    widget.onActivityChanged?.call(active);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    setState(() {
      _foreground = state == AppLifecycleState.resumed;
      _updateActivity();
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _visible = false;
    _updateActivity();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => _visible && _foreground
      ? widget.builder(context)
      : const SizedBox.expand();
}
