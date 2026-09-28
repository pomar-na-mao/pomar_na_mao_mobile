import 'package:flutter/services.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

import '../diagnostics/runtime_diagnostics.dart';

/// The platform can dispose a map while its last camera command is in flight.
Future<void> animateMapCamera(
  GoogleMapController controller,
  CameraUpdate update,
) async {
  try {
    await controller.animateCamera(update);
  } on PlatformException {
    RuntimeDiagnostics.instance.record(
      RuntimeStage.projection,
      outcome: RuntimeOutcome.failure,
    );
  } on StateError {
    RuntimeDiagnostics.instance.record(
      RuntimeStage.projection,
      outcome: RuntimeOutcome.failure,
    );
  } on MissingPluginException {
    RuntimeDiagnostics.instance.record(
      RuntimeStage.projection,
      outcome: RuntimeOutcome.failure,
    );
  }
}
