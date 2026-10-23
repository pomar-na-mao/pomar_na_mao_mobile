import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

/// Tokens e fábrica de marcadores compartilhados pelos mapas de operações.
abstract final class OperationMapStyle {
  static const mapType = MapType.satellite;
  static const initialZoom = 17.0;
  static const boundsPadding = 64.0;

  static const plantColor = Color(0xFF2E7D32);
  static const plantHighlightColor = Color(0xFF66BB6A);
  static const nonExistentPlantColor = Color(0xFFF9A825);
  static const nonExistentPlantHighlightColor = Color(0xFFFFD54F);
  static const addedPlantColor = Color(0xFF0F766E);
  static const addedPlantHighlightColor = Color(0xFF5EEAD4);

  static const markerAnchor = Offset(0.5, 0.5);
  static const userMarkerZIndex = 1000;

  static Future<BitmapDescriptor> createPlantMarkerIcon({
    required Color color,
    required Color highlightColor,
  }) async {
    const size = 64;
    const center = Offset(size / 2, size / 2);
    const radius = 22.0;
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);

    canvas.drawCircle(center, radius + 5, Paint()..color = Colors.white);
    canvas.drawCircle(center, radius, Paint()..color = color);
    canvas.drawCircle(
      center.translate(-7, -7),
      6,
      Paint()..color = highlightColor,
    );

    final picture = recorder.endRecording();
    final image = await picture.toImage(size, size);
    picture.dispose();
    final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
    image.dispose();
    return BitmapDescriptor.bytes(
      bytes!.buffer.asUint8List(),
      width: 28,
      height: 28,
    );
  }
}
