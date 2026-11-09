import 'dart:io';

import 'package:flutter/material.dart';

import '../../data/stock_photo_picker.dart';
import '../../domain/stock_models.dart';
import '../stock_view_model.dart';

class StockFormSheet extends StatefulWidget {
  const StockFormSheet({
    required this.viewModel,
    required this.item,
    super.key,
  });

  final StockViewModel viewModel;
  final StockItem? item;

  @override
  State<StockFormSheet> createState() => _StockFormSheetState();
}

class _StockFormSheetState extends State<StockFormSheet> {
  static const _fieldSpacing = 22.0;

  final _formKey = GlobalKey<FormState>();
  late final Map<String, TextEditingController> _controllers;
  late String? _type;
  late String? _unit;
  late bool _registeredForCrop;
  late DateTime? _expirationDate;
  StockPhoto? _photo;
  Future<String?>? _existingPhotoUrl;

  StockItem? get _item => widget.item;

  @override
  void initState() {
    super.initState();
    final item = _item;
    _type = item?.type;
    _unit = item?.unit;
    _registeredForCrop = item?.registeredForCrop ?? true;
    _expirationDate = item?.expirationDate;
    if (item?.photoObjectPath != null) {
      _existingPhotoUrl = widget.viewModel.photoUrl(item!);
    }
    _controllers = {
      'name': TextEditingController(text: item?.name),
      'activeIngredient': TextEditingController(text: item?.activeIngredient),
      'formulation': TextEditingController(text: item?.formulation),
      'concentration': TextEditingController(text: item?.concentration),
      'chemicalGroup': TextEditingController(text: item?.chemicalGroup),
      'manufacturer': TextEditingController(text: item?.manufacturer),
      'mapaRegistration': TextEditingController(text: item?.mapaRegistration),
      'expirationDate': TextEditingController(
        text: _formatDateLabel(_expirationDate),
      ),
      'target1': TextEditingController(text: item?.target1),
      'target2': TextEditingController(text: item?.target2),
      'safetyInterval': TextEditingController(
        text: item?.safetyIntervalDays?.toString(),
      ),
      'labelDose': TextEditingController(text: item?.labelDose),
      'doseUnit': TextEditingController(text: item?.doseUnit),
      'quantity': TextEditingController(text: item?.quantity?.toString()),
      'observations': TextEditingController(text: item?.observations),
    };
  }

  @override
  void dispose() {
    for (final controller in _controllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);
    final theme = Theme.of(context);
    return AnimatedPadding(
      duration: const Duration(milliseconds: 180),
      padding: EdgeInsets.only(bottom: media.viewInsets.bottom),
      child: Material(
        key: const ValueKey('stock-form-sheet'),
        color: theme.colorScheme.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        clipBehavior: Clip.antiAlias,
        child: Column(
          children: [
            const SizedBox(height: 10),
            Container(
              width: 44,
              height: 4,
              decoration: BoxDecoration(
                color: theme.colorScheme.outlineVariant,
                borderRadius: BorderRadius.circular(4),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 12, 12),
              child: Row(
                children: [
                  Container(
                    width: 38,
                    height: 38,
                    decoration: BoxDecoration(
                      color: const Color(0xFF7A5A24).withValues(alpha: 0.14),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(
                      Icons.inventory_2_outlined,
                      color: Color(0xFF7A5A24),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      _item == null ? 'Adicionar ao estoque' : 'Editar item',
                      style: theme.textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  IconButton(
                    tooltip: 'Fechar',
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close),
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            Expanded(
              child: Form(
                key: _formKey,
                child: SingleChildScrollView(
                  key: const ValueKey('stock-form-scroll'),
                  padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _PhotoSelector(
                        photo: _photo,
                        existingPhotoUrl: _existingPhotoUrl,
                        onPick: _pickPhoto,
                      ),
                      const SizedBox(height: 24),
                      _field(
                        'name',
                        'Nome *',
                        Icons.inventory_2_outlined,
                        validator: (value) =>
                            value == null || value.trim().isEmpty
                            ? 'Informe o nome do item.'
                            : value.trim().length > 150
                            ? 'Use no máximo 150 caracteres.'
                            : null,
                      ),
                      const SizedBox(height: _fieldSpacing),
                      _typeField(),
                      const SizedBox(height: _fieldSpacing),
                      LayoutBuilder(
                        builder: (context, constraints) {
                          final quantity = _field(
                            'quantity',
                            'Quantidade *',
                            Icons.scale_outlined,
                            keyboardType: const TextInputType.numberWithOptions(
                              decimal: true,
                            ),
                            validator: _quantityValidator,
                          );
                          final unit = _unitField();
                          if (constraints.maxWidth < 360) {
                            return Column(
                              children: [
                                quantity,
                                const SizedBox(height: _fieldSpacing),
                                unit,
                              ],
                            );
                          }
                          return Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(flex: 2, child: quantity),
                              const SizedBox(width: 12),
                              Expanded(child: unit),
                            ],
                          );
                        },
                      ),
                      const SizedBox(height: _fieldSpacing),
                      _field(
                        'activeIngredient',
                        'Ingrediente ativo',
                        Icons.science_outlined,
                      ),
                      const SizedBox(height: _fieldSpacing),
                      _field(
                        'manufacturer',
                        'Fabricante',
                        Icons.factory_outlined,
                      ),
                      const SizedBox(height: 16),
                      ExpansionTile(
                        tilePadding: EdgeInsets.zero,
                        title: const Text('Detalhes técnicos'),
                        children: [
                          const SizedBox(
                            key: ValueKey(
                              'stock-technical-details-top-spacing',
                            ),
                            height: 18,
                          ),
                          _field(
                            'formulation',
                            'Formulação',
                            Icons.biotech_outlined,
                          ),
                          const SizedBox(height: _fieldSpacing),
                          _field(
                            'concentration',
                            'Concentração',
                            Icons.percent,
                          ),
                          const SizedBox(height: _fieldSpacing),
                          _field(
                            'chemicalGroup',
                            'Grupo químico',
                            Icons.category_outlined,
                          ),
                          const SizedBox(height: _fieldSpacing),
                          _field(
                            'mapaRegistration',
                            'Registro MAPA',
                            Icons.badge_outlined,
                          ),
                          const SizedBox(height: _fieldSpacing),
                          _expirationDateField(),
                          const SizedBox(height: _fieldSpacing),
                          _field('target1', 'Alvo 1', Icons.gps_fixed),
                          const SizedBox(height: _fieldSpacing),
                          _field('target2', 'Alvo 2', Icons.gps_fixed),
                          const SizedBox(height: _fieldSpacing),
                          _field(
                            'safetyInterval',
                            'Intervalo de segurança (dias)',
                            Icons.timelapse_outlined,
                            keyboardType: TextInputType.number,
                            validator: (value) {
                              if (value == null || value.trim().isEmpty) {
                                return null;
                              }
                              final parsed = int.tryParse(value.trim());
                              return parsed == null || parsed < 0
                                  ? 'Informe zero ou um número positivo.'
                                  : null;
                            },
                          ),
                          const SizedBox(height: _fieldSpacing),
                          _field(
                            'labelDose',
                            'Dose de bula',
                            Icons.medication_outlined,
                          ),
                          const SizedBox(height: _fieldSpacing),
                          _field(
                            'doseUnit',
                            'Unidade da dose',
                            Icons.straighten_outlined,
                          ),
                          const SizedBox(
                            key: ValueKey(
                              'stock-technical-details-bottom-spacing',
                            ),
                            height: 18,
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      SwitchListTile.adaptive(
                        contentPadding: EdgeInsets.zero,
                        title: const Text('Registrado para a cultura'),
                        value: _registeredForCrop,
                        onChanged: (value) =>
                            setState(() => _registeredForCrop = value),
                      ),
                      const SizedBox(height: 12),
                      _field(
                        'observations',
                        'Observações',
                        Icons.notes_outlined,
                        maxLines: 3,
                      ),
                    ],
                  ),
                ),
              ),
            ),
            SafeArea(
              top: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 10, 20, 14),
                child: SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: ListenableBuilder(
                    listenable: widget.viewModel,
                    builder: (context, _) => FilledButton.icon(
                      key: const ValueKey('save-stock-item'),
                      onPressed: widget.viewModel.saving ? null : _save,
                      icon: widget.viewModel.saving
                          ? const SizedBox.square(
                              dimension: 18,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : const Icon(Icons.save_outlined),
                      label: Text(
                        _item == null ? 'Adicionar item' : 'Salvar alterações',
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _field(
    String key,
    String label,
    IconData icon, {
    TextInputType? keyboardType,
    String? Function(String?)? validator,
    int maxLines = 1,
  }) => TextFormField(
    key: ValueKey('stock-$key-field'),
    controller: _controllers[key],
    keyboardType: keyboardType,
    validator: validator,
    maxLines: maxLines,
    decoration: _decoration(label, icon),
  );

  Widget _typeField() => DropdownButtonFormField<String>(
    key: const ValueKey('stock-type-field'),
    initialValue: _type,
    isExpanded: true,
    decoration: _decoration('Tipo *', Icons.category_outlined),
    items: widget.viewModel.types
        .map(
          (type) => DropdownMenuItem(
            value: type,
            child: Text(stockTypeLabel(type), overflow: TextOverflow.ellipsis),
          ),
        )
        .toList(),
    validator: (value) => value == null ? 'Selecione o tipo.' : null,
    onChanged: (value) => setState(() => _type = value),
  );

  Widget _unitField() => DropdownButtonFormField<String>(
    key: const ValueKey('stock-unit-field'),
    initialValue: _unit,
    isExpanded: true,
    decoration: _decoration('Unidade *', Icons.straighten_outlined),
    items: stockUnits
        .map((unit) => DropdownMenuItem(value: unit, child: Text(unit)))
        .toList(),
    validator: (value) => value == null ? 'Selecione a unidade.' : null,
    onChanged: (value) => setState(() => _unit = value),
  );

  Widget _expirationDateField() => TextFormField(
    key: const ValueKey('stock-expirationDate-field'),
    controller: _controllers['expirationDate'],
    readOnly: true,
    showCursor: false,
    onTap: _selectExpirationDate,
    decoration: _decoration(
      'Validade',
      Icons.calendar_today_outlined,
      suffixIcon: _expirationDate == null
          ? null
          : IconButton(
              key: const ValueKey('clear-stock-expiration-date'),
              tooltip: 'Limpar validade',
              onPressed: _clearExpirationDate,
              icon: const Icon(Icons.close),
            ),
    ),
  );

  InputDecoration _decoration(
    String label,
    IconData icon, {
    Widget? suffixIcon,
  }) => InputDecoration(
    labelText: label,
    prefixIcon: Icon(icon),
    suffixIcon: suffixIcon,
    filled: true,
    fillColor: Theme.of(context).colorScheme.surfaceContainerHighest
        .withValues(alpha: 0.35),
    border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
    enabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(14),
      borderSide: BorderSide(
        color: Theme.of(context).colorScheme.outlineVariant,
      ),
    ),
  );

  String? _quantityValidator(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'Informe a quantidade.';
    }
    final parsed = double.tryParse(value.trim().replaceAll(',', '.'));
    if (parsed == null || parsed < 0) {
      return 'Informe zero ou um valor positivo.';
    }
    if (_unit == null) {
      return 'Selecione a unidade.';
    }
    return null;
  }

  Future<void> _selectExpirationDate() async {
    final now = DateTime.now();
    final selected = await showDatePicker(
      context: context,
      initialDate: _expirationDate ?? DateTime(now.year, now.month, now.day),
      firstDate: DateTime(1900),
      lastDate: DateTime(2200, 12, 31),
    );
    if (selected == null || !mounted) return;
    setState(() {
      _expirationDate = DateTime(selected.year, selected.month, selected.day);
      _controllers['expirationDate']!.text = _formatDateLabel(_expirationDate);
    });
  }

  void _clearExpirationDate() {
    setState(() {
      _expirationDate = null;
      _controllers['expirationDate']!.clear();
    });
  }

  Future<void> _pickPhoto(StockPhotoSource source) async {
    final photo = await widget.viewModel.pickPhoto(source);
    if (!mounted || photo == null) return;
    final size = await File(photo.path).length();
    if (!mounted) return;
    if (size > 5 * 1024 * 1024) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('A imagem deve ter no máximo 5 MB.')),
      );
      return;
    }
    setState(() => _photo = photo);
  }

  Future<void> _save() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    final quantityText = _controllers['quantity']!.text.trim();
    final safetyText = _controllers['safetyInterval']!.text.trim();
    final draft = StockDraft(
      name: _controllers['name']!.text,
      type: _type ?? '',
      registeredForCrop: _registeredForCrop,
      activeIngredient: _controllers['activeIngredient']!.text,
      formulation: _controllers['formulation']!.text,
      concentration: _controllers['concentration']!.text,
      chemicalGroup: _controllers['chemicalGroup']!.text,
      manufacturer: _controllers['manufacturer']!.text,
      mapaRegistration: _controllers['mapaRegistration']!.text,
      expirationDate: _expirationDate,
      target1: _controllers['target1']!.text,
      target2: _controllers['target2']!.text,
      safetyIntervalDays: safetyText.isEmpty ? null : int.parse(safetyText),
      labelDose: _controllers['labelDose']!.text,
      doseUnit: _controllers['doseUnit']!.text,
      quantity: quantityText.isEmpty
          ? 0
          : double.parse(quantityText.replaceAll(',', '.')),
      unit: _unit ?? '',
      photoObjectPath: _item?.photoObjectPath,
      observations: _controllers['observations']!.text,
    );
    final saved = await widget.viewModel.save(
      draft: draft,
      current: _item,
      photo: _photo,
    );
    if (!mounted) return;
    if (saved) {
      Navigator.pop(context, true);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(widget.viewModel.error ?? 'Erro ao salvar.')),
      );
    }
  }
}

String _formatDateLabel(DateTime? date) {
  if (date == null) return '';
  final day = date.day.toString().padLeft(2, '0');
  final month = date.month.toString().padLeft(2, '0');
  return '$day/$month/${date.year}';
}

class _PhotoSelector extends StatelessWidget {
  const _PhotoSelector({
    required this.photo,
    required this.existingPhotoUrl,
    required this.onPick,
  });

  final StockPhoto? photo;
  final Future<String?>? existingPhotoUrl;
  final ValueChanged<StockPhotoSource> onPick;

  @override
  Widget build(BuildContext context) {
    final Widget preview;
    if (photo != null) {
      preview = Image.file(File(photo!.path), fit: BoxFit.cover);
    } else if (existingPhotoUrl != null) {
      preview = FutureBuilder<String?>(
        future: existingPhotoUrl,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(
              child: SizedBox.square(
                dimension: 24,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            );
          }
          final url = snapshot.data;
          if (snapshot.hasError || url == null || url.isEmpty) {
            return const Center(
              child: Icon(Icons.broken_image_outlined, size: 40),
            );
          }
          return Image.network(
            url,
            key: const ValueKey('stock-existing-photo'),
            semanticLabel: 'Foto atual do item do estoque',
            fit: BoxFit.cover,
            errorBuilder: (_, _, _) => const Center(
              child: Icon(Icons.broken_image_outlined, size: 40),
            ),
          );
        },
      );
    } else {
      preview = const Icon(Icons.photo_outlined, size: 40);
    }
    final buttonStyle = OutlinedButton.styleFrom(
      minimumSize: const Size(0, 44),
      padding: const EdgeInsets.symmetric(horizontal: 4),
      textStyle: Theme.of(context).textTheme.labelSmall
          ?.copyWith(fontSize: 10.5),
      visualDensity: VisualDensity.compact,
    );
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        ClipRRect(
          key: const ValueKey('stock-photo-preview'),
          borderRadius: BorderRadius.circular(14),
          child: SizedBox(
            width: 104,
            height: 104,
            child: ColoredBox(
              color: Theme.of(context).colorScheme.surfaceContainerHighest,
              child: preview,
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  key: const ValueKey('stock-photo-camera'),
                  style: buttonStyle,
                  onPressed: () => onPick(StockPhotoSource.camera),
                  icon: const Icon(Icons.photo_camera_outlined, size: 16),
                  label: const Text(
                    'Câmera',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: OutlinedButton.icon(
                  key: const ValueKey('stock-photo-gallery'),
                  style: buttonStyle,
                  onPressed: () => onPick(StockPhotoSource.gallery),
                  icon: const Icon(Icons.photo_library_outlined, size: 16),
                  label: const Text(
                    'Galeria',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
