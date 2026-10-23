import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';

import '../../domain/inspection_models.dart';
import '../../domain/mipd_models.dart';
import '../mipd_view_model.dart';

class MipdPlantModal extends StatefulWidget {
  const MipdPlantModal({
    required this.plant,
    required this.viewModel,
    super.key,
  });

  final InspectionPlant plant;
  final MipdViewModel viewModel;

  static Future<void> show(
    BuildContext context,
    InspectionPlant plant,
    MipdViewModel viewModel,
  ) => showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => MipdPlantModal(plant: plant, viewModel: viewModel),
  );

  @override
  State<MipdPlantModal> createState() => _MipdPlantModalState();
}

class _MipdPlantModalState extends State<MipdPlantModal> {
  late final String _localId = widget.viewModel.createLocalId();
  OccurrenceType? _type;
  final _parts = <MipdPlantPart>{};
  String? _photo;
  bool _busy = false;
  bool _saved = false;

  Future<void> _capture() async {
    try {
      final photo = await widget.viewModel.capturePhoto(_localId);
      if (photo != null && mounted) {
        await widget.viewModel.removePhoto(_photo);
        setState(() => _photo = photo);
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Não foi possível abrir a câmera: $error')),
        );
      }
    }
  }

  Future<void> _save() async {
    if (_type == null || _parts.isEmpty || _busy) return;
    setState(() => _busy = true);
    try {
      await widget.viewModel.save(
        localId: _localId,
        plant: widget.plant,
        occurrenceType: _type!,
        plantParts: _parts,
        localPhotoPath: _photo,
      );
      _saved = true;
      if (mounted) Navigator.pop(context);
    } catch (error) {
      if (mounted) {
        setState(() => _busy = false);
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Erro ao salvar: $error')));
      }
    }
  }

  @override
  void dispose() {
    if (!_saved) unawaited(widget.viewModel.removePhoto(_photo));
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final canSave = _type != null && _parts.isNotEmpty && !_busy;
    final modalHeight = MediaQuery.sizeOf(context).height * 0.80;

    return Material(
      color: colorScheme.surface,
      borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
      clipBehavior: Clip.antiAlias,
      child: SizedBox(
        height: modalHeight,
        child: SafeArea(
          top: false,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                child: Container(
                  width: 36,
                  height: 4,
                  margin: const EdgeInsets.only(top: 12, bottom: 8),
                  decoration: BoxDecoration(
                    color: colorScheme.outlineVariant,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 8, 12, 12),
                child: Row(
                  children: [
                    Icon(
                      Icons.eco_rounded,
                      color: colorScheme.primary,
                      size: 26,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        widget.plant.label,
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                          fontSize: 18,
                        ),
                      ),
                    ),
                    IconButton(
                      key: const ValueKey('mipd-plant-close'),
                      icon: const Icon(Icons.close_rounded),
                      tooltip: 'Fechar',
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                  ],
                ),
              ),
              const Divider(height: 1),
              Expanded(
                child: SingleChildScrollView(
                  key: const ValueKey('mipd-plant-form'),
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(
                        'Praga ou doença',
                        style: theme.textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 8),
                      DropdownButtonFormField<OccurrenceType>(
                        key: const ValueKey('mipd-occurrence-selector'),
                        initialValue: _type,
                        isExpanded: true,
                        hint: const Text(
                          'Selecione uma praga ou doença',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        decoration: InputDecoration(
                          prefixIcon: const Icon(Icons.pest_control_outlined),
                          filled: true,
                          fillColor: colorScheme.surfaceContainerHighest
                              .withValues(alpha: 0.35),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(14),
                            borderSide: BorderSide(
                              color: colorScheme.outlineVariant.withValues(
                                alpha: 0.6,
                              ),
                            ),
                          ),
                        ),
                        items: [
                          for (final type in widget.viewModel.catalog.where(
                            (item) => item.isPestDisease,
                          ))
                            DropdownMenuItem(
                              value: type,
                              child: Text(
                                type.name,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                        ],
                        onChanged: _busy
                            ? null
                            : (value) => setState(() => _type = value),
                      ),
                      if (widget.viewModel.catalog.isEmpty)
                        Padding(
                          padding: const EdgeInsets.only(top: 8),
                          child: Text(
                            'Nenhuma praga ou doença disponível.',
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: colorScheme.error,
                            ),
                          ),
                        ),
                      const SizedBox(height: 20),
                      Text(
                        'Parte da planta',
                        style: theme.textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Selecione uma ou mais opções',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: colorScheme.onSurfaceVariant,
                        ),
                      ),
                      const SizedBox(height: 10),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          for (final part in MipdPlantPart.values)
                            FilterChip(
                              label: Text(part.label),
                              selected: _parts.contains(part),
                              showCheckmark: true,
                              onSelected: _busy
                                  ? null
                                  : (selected) => setState(
                                      () => selected
                                          ? _parts.add(part)
                                          : _parts.remove(part),
                                    ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 20),
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              'Foto da planta',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: theme.textTheme.titleSmall?.copyWith(
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            '(opcional)',
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      CustomPaint(
                        painter: _DashedBorderPainter(
                          color: colorScheme.outline,
                        ),
                        child: SizedBox(
                          height: 180,
                          child: _photo == null
                              ? Center(
                                  child: OutlinedButton.icon(
                                    onPressed: _busy ? null : _capture,
                                    icon: const Icon(Icons.camera_alt_outlined),
                                    label: const Text('Tirar foto'),
                                  ),
                                )
                              : Stack(
                                  fit: StackFit.expand,
                                  children: [
                                    ClipRRect(
                                      borderRadius: BorderRadius.circular(12),
                                      child: Image.file(
                                        File(_photo!),
                                        fit: BoxFit.cover,
                                      ),
                                    ),
                                    Positioned(
                                      right: 6,
                                      top: 6,
                                      child: Row(
                                        children: [
                                          IconButton.filled(
                                            tooltip: 'Tirar outra foto',
                                            onPressed: _busy ? null : _capture,
                                            icon: const Icon(
                                              Icons.camera_alt_outlined,
                                            ),
                                          ),
                                          const SizedBox(width: 4),
                                          IconButton.filled(
                                            tooltip: 'Remover foto',
                                            onPressed: _busy
                                                ? null
                                                : () async {
                                                    await widget.viewModel
                                                        .removePhoto(_photo);
                                                    if (mounted) {
                                                      setState(
                                                        () => _photo = null,
                                                      );
                                                    }
                                                  },
                                            icon: const Icon(
                                              Icons.delete_outline,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const Divider(height: 1),
              Container(
                color: colorScheme.surface,
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
                child: Row(
                  children: [
                    Expanded(
                      child: Row(
                        children: [
                          Icon(
                            Icons.edit_note_rounded,
                            size: 20,
                            color: colorScheme.onSurfaceVariant,
                          ),
                          const SizedBox(width: 6),
                          Flexible(
                            child: Text(
                              _parts.isEmpty
                                  ? 'Nenhuma parte selecionada'
                                  : '${_parts.length} ${_parts.length == 1 ? 'parte selecionada' : 'partes selecionadas'}',
                              style: theme.textTheme.bodyMedium?.copyWith(
                                color: colorScheme.onSurfaceVariant,
                                fontWeight: FontWeight.w600,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),
                    FilledButton.icon(
                      key: const ValueKey('mipd-save'),
                      style: FilledButton.styleFrom(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 20,
                          vertical: 12,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                      onPressed: canSave ? _save : null,
                      icon: _busy
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : const Icon(Icons.check_rounded, size: 18),
                      label: Text(_busy ? 'Salvando...' : 'Salvar'),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _DashedBorderPainter extends CustomPainter {
  const _DashedBorderPainter({required this.color});

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final path = Path()
      ..addRRect(
        RRect.fromRectAndRadius(Offset.zero & size, const Radius.circular(12)),
      );
    final metric = path.computeMetrics().first;
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;
    for (double distance = 0; distance < metric.length; distance += 12) {
      canvas.drawPath(
        metric.extractPath(distance, (distance + 6).clamp(0, metric.length)),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _DashedBorderPainter oldDelegate) =>
      oldDelegate.color != color;
}
