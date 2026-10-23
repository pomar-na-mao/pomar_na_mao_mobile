import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:pomar_na_mao_mobile/features/operations/presentation/operation_map_style.dart';

void main() {
  group('OperationMapStyle', () {
    test('preserva os tokens visuais e de câmera da Inspeção', () {
      expect(OperationMapStyle.mapType, MapType.satellite);
      expect(OperationMapStyle.initialZoom, 17);
      expect(OperationMapStyle.boundsPadding, 64);
      expect(OperationMapStyle.plantColor, const Color(0xFF2E7D32));
      expect(OperationMapStyle.nonExistentPlantColor, const Color(0xFFF9A825));
      expect(OperationMapStyle.markerAnchor, const Offset(0.5, 0.5));
      expect(OperationMapStyle.userMarkerZIndex, 1000);
    });
  });
}
