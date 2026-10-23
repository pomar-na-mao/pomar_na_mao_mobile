import 'dart:async';

import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

import '../../../core/ui/map_activity.dart';
import '../../farm/domain/user_location.dart';
import '../../farm/presentation/bounded_plant_markers.dart';
import '../../farm/presentation/farm_map_geometry.dart';
import '../../farm/presentation/plant_spatial_index.dart';
import '../../farm/presentation/user_map_navigation.dart';
import '../domain/inspection_models.dart';
import 'mipd_view_model.dart';
import 'operation_map_style.dart';
import 'widgets/mipd_plant_modal.dart';
import 'widgets/mipd_saved_markings.dart';
import 'widgets/operation_action_button.dart';
import 'widgets/spraying_signal_overlay.dart';

class MipdMapConfig {
  const MipdMapConfig({
    required this.plants,
    required this.onSelectPlant,
    this.userLocation,
  });
  final List<InspectionPlant> plants;
  final ValueChanged<InspectionPlant> onSelectPlant;
  final UserLocation? userLocation;
}

typedef MipdMapBuilder = Widget Function(
  BuildContext context,
  MipdMapConfig config,
);

class MipdView extends StatefulWidget {
  const MipdView({required this.viewModel, this.mapBuilder, super.key});
  final MipdViewModel viewModel;
  final MipdMapBuilder? mapBuilder;

  @override
  State<MipdView> createState() => _MipdViewState();
}

class _MipdViewState extends State<MipdView> {
  final _plantLayer = BoundedPlantMarkers();
  Set<Marker> _markers = const {};
  BitmapDescriptor? _plantIcon;
  BitmapDescriptor? _userIcon;
  GoogleMapController? _controller;

  @override
  void initState() {
    super.initState();
    _plantLayer.addListener(_markersChanged);
    unawaited(_loadIcons());
    WidgetsBinding.instance.addPostFrameCallback(
      (_) => widget.viewModel.initialize(),
    );
  }

  Future<void> _loadIcons() async {
    final icons = await Future.wait([
      OperationMapStyle.createPlantMarkerIcon(
        color: OperationMapStyle.plantColor,
        highlightColor: OperationMapStyle.plantHighlightColor,
      ),
      createUserLocationMarkerIcon(),
    ]);
    if (mounted) {
      setState(() {
        _plantIcon = icons[0];
        _userIcon = icons[1];
      });
    }
  }

  void _markersChanged() {
    if (mounted) setState(() => _markers = _plantLayer.markers);
  }

  void _updateMarkers() {
    final vm = widget.viewModel;
    final plantsById = {for (final plant in vm.plants) plant.id: plant};
    _plantLayer.update(
      revision: (vm.plants, _plantIcon),
      plants: () => [
        for (final plant in vm.plants)
          SpatialPlant(plant.id, plant.latitude!, plant.longitude!),
      ],
      markerFor: (node) {
        final plant = plantsById[node.plantId]!;
        return Marker(
          markerId: MarkerId('mipd_${plant.id}'),
          position: LatLng(plant.latitude!, plant.longitude!),
          icon:
              _plantIcon ??
              BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueGreen),
          anchor: OperationMapStyle.markerAnchor,
          onTap: () => MipdPlantModal.show(context, plant, vm),
        );
      },
      onClusterTap: (node) => showPlantClusterMembers(
        context,
        layer: _plantLayer,
        node: node,
        labelFor: (id) => plantsById[id]!.label,
        onSelect: (id) {
          Navigator.pop(context);
          MipdPlantModal.show(context, plantsById[id]!, vm);
        },
      ),
    );
  }

  @override
  void dispose() {
    widget.viewModel.pauseLocation();
    _plantLayer.dispose();
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: widget.viewModel,
    builder: (context, _) {
      final vm = widget.viewModel;
      final colorScheme = Theme.of(context).colorScheme;
      if (widget.mapBuilder == null) _updateMarkers();
      final config = MipdMapConfig(
        plants: vm.plants,
        userLocation: vm.userLocation,
        onSelectPlant: (plant) => MipdPlantModal.show(context, plant, vm),
      );
      return Scaffold(
        backgroundColor: const Color(0xFFF4F7F2),
        appBar: AppBar(
          title: const Text('MIPD'),
          backgroundColor: const Color(0xFFF4F7F2),
          surfaceTintColor: Colors.transparent,
        ),
        body: Stack(
          children: [
            Column(
              children: [
                Expanded(
                  child: Stack(
                    children: [
                      Positioned.fill(
                        child: ActiveMapSurface(
                          onActivityChanged: (active) => active
                              ? widget.viewModel.resumeLocation()
                              : widget.viewModel.pauseLocation(),
                          builder: (_) => widget.mapBuilder != null
                              ? widget.mapBuilder!(context, config)
                              : GoogleMap(
                                  key: const ValueKey('mipd-google-map'),
                                  mapType: OperationMapStyle.mapType,
                                  initialCameraPosition: const CameraPosition(
                                    target: defaultFarmMapPosition,
                                    zoom: OperationMapStyle.initialZoom,
                                  ),
                                  markers: {
                                    ..._markers,
                                    if (vm.userLocation case final location?)
                                      Marker(
                                        markerId: const MarkerId('mipd_user'),
                                        position: LatLng(
                                          location.latitude,
                                          location.longitude,
                                        ),
                                        icon:
                                            _userIcon ??
                                            BitmapDescriptor.defaultMarkerWithHue(
                                              BitmapDescriptor.hueAzure,
                                            ),
                                        anchor: OperationMapStyle.markerAnchor,
                                        zIndexInt:
                                            OperationMapStyle.userMarkerZIndex,
                                      ),
                                  },
                                  myLocationEnabled: false,
                                  myLocationButtonEnabled: false,
                                  onCameraIdle: _plantLayer.cameraIdle,
                                  onMapCreated: (controller) {
                                    _controller = controller;
                                    _plantLayer.controller = controller;
                                    _plantLayer.cameraIdle();
                                  },
                                ),
                        ),
                      ),
                      if (vm.status == MipdLoadStatus.loading)
                        const Positioned(
                          top: 0,
                          left: 0,
                          right: 0,
                          child: LinearProgressIndicator(),
                        ),
                      if (vm.status == MipdLoadStatus.error)
                        Positioned(
                          top: 12,
                          left: 12,
                          right: 12,
                          child: Material(
                            color: Colors.red.shade50,
                            borderRadius: BorderRadius.circular(12),
                            child: ListTile(
                              title: Text(
                                vm.errorMessage ?? 'Erro ao carregar dados',
                              ),
                              trailing: IconButton(
                                icon: const Icon(Icons.refresh),
                                onPressed: vm.loadPlants,
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
                SafeArea(
                  top: false,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 8,
                    ),
                    child: Center(
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 480),
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            color: colorScheme.surface,
                            borderRadius: BorderRadius.circular(24),
                            border: Border.all(
                              color: colorScheme.outlineVariant.withValues(
                                alpha: 0.6,
                              ),
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.06),
                                blurRadius: 14,
                                offset: const Offset(0, 4),
                              ),
                            ],
                          ),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 10,
                            ),
                            child: Row(
                              children: [
                                Expanded(
                                  child: OperationActionButton(
                                    key: const ValueKey('mipd-load-plants'),
                                    tooltip: 'Carregar plantas',
                                    backgroundColor: const Color(0xFFE0F2FE),
                                    borderColor: const Color(0xFFBAE6FD),
                                    iconColor: const Color(0xFF0284C7),
                                    icon: vm.status == MipdLoadStatus.loading
                                        ? const SizedBox(
                                            width: 22,
                                            height: 22,
                                            child: CircularProgressIndicator(
                                              strokeWidth: 2.5,
                                              color: Color(0xFF0284C7),
                                            ),
                                          )
                                        : const Icon(
                                            Icons.cloud_download_outlined,
                                            size: 24,
                                          ),
                                    onPressed:
                                        vm.status == MipdLoadStatus.loading
                                        ? null
                                        : vm.loadPlants,
                                  ),
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: OperationActionButton(
                                    key: const ValueKey('mipd-saved-markings'),
                                    tooltip: 'Marcações salvas',
                                    backgroundColor: const Color(0xFFEDE9FE),
                                    borderColor: const Color(0xFFDDD6FE),
                                    iconColor: const Color(0xFF7C3AED),
                                    icon: const Icon(
                                      Icons.folder_outlined,
                                      size: 24,
                                    ),
                                    onPressed: () =>
                                        MipdSavedMarkings.show(context, vm),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
            if (vm.isWaitingForStableLocation)
              Positioned.fill(
                child: SprayingSignalOverlay(
                  onCancel: vm.cancelStableLocationWait,
                ),
              ),
          ],
        ),
      );
    },
  );
}
