import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';

import '../../domain/spraying_models.dart';
import '../spraying_view_model.dart';
import 'spraying_review_modal.dart';

class SprayingInputsModal extends StatefulWidget {
  const SprayingInputsModal({required this.viewModel, super.key});

  final SprayingViewModel viewModel;

  static Future<void> show(BuildContext context, SprayingViewModel vm) {
    final maxHeight = MediaQuery.sizeOf(context).height * 0.75;
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      constraints: BoxConstraints(maxHeight: maxHeight),
      builder: (_) => SprayingInputsModal(viewModel: vm),
    );
  }

  @override
  State<SprayingInputsModal> createState() => _SprayingInputsModalState();
}

class _SprayingInputsModalState extends State<SprayingInputsModal> {
  final _inputs = <SprayingInput>[];
  final _generalFormKey = GlobalKey<FormState>();
  final _inputFormKey = GlobalKey<FormState>();
  String? _saveError;

  late final TextEditingController _operatorCtrl;
  late final TextEditingController _machineCtrl;
  late final TextEditingController _tractorCtrl;
  late final TextEditingController _titleCtrl;
  late final TextEditingController _notesCtrl;

  // Controllers para adicionar insumo
  final _productNameCtrl = TextEditingController();
  final _activeIngCtrl = TextEditingController();
  final _doseCtrl = TextEditingController();
  final _doseUnitCtrl = TextEditingController(text: 'L/ha');
  final _totalQtyCtrl = TextEditingController();
  final _totalQtyUnitCtrl = TextEditingController(text: 'L');
  final _inputNotesCtrl = TextEditingController();
  String _selectedInputType = 'fungicide';

  static const _inputTypes = [
    {'value': 'fungicide', 'label': 'Fungicida'},
    {'value': 'insecticide', 'label': 'Inseticida'},
    {'value': 'acaricide', 'label': 'Acaricida'},
    {'value': 'herbicide', 'label': 'Herbicida'},
    {'value': 'foliar_fertilizer', 'label': 'Adubo Foliar'},
    {'value': 'growth_regulator', 'label': 'Regulador de Crescimento'},
    {'value': 'other', 'label': 'Outro Insumo'},
  ];

  @override
  void initState() {
    super.initState();
    final vm = widget.viewModel;
    final op = vm.currentOperation;

    _operatorCtrl = TextEditingController(
      text:
          vm.draftOperatorName ??
          (op?.operatorName != 'Operador' ? op?.operatorName ?? '' : ''),
    );
    _machineCtrl = TextEditingController(
      text: vm.draftMachineName ?? (op?.machineName ?? ''),
    );
    _tractorCtrl = TextEditingController(
      text: vm.draftTractorIdentifier ?? (op?.tractorIdentifier ?? ''),
    );
    _titleCtrl = TextEditingController(
      text: vm.draftTitle ?? (op?.title ?? ''),
    );
    _notesCtrl = TextEditingController(
      text: vm.draftNotes ?? (op?.notes ?? ''),
    );

    if (vm.draftInputs.isNotEmpty) {
      _inputs.addAll(vm.draftInputs);
    } else if (op?.inputs != null) {
      _inputs.addAll(op!.inputs);
    }

    _selectedInputType = vm.draftInputType;
    _productNameCtrl.text = vm.draftProductName;
    _activeIngCtrl.text = vm.draftActiveIngredient;
    _doseCtrl.text = vm.draftDose;
    _doseUnitCtrl.text = vm.draftDoseUnit.isNotEmpty
        ? vm.draftDoseUnit
        : 'L/ha';
    _totalQtyCtrl.text = vm.draftTotalQuantity;
    _totalQtyUnitCtrl.text = vm.draftTotalQuantityUnit.isNotEmpty
        ? vm.draftTotalQuantityUnit
        : 'L';
    _inputNotesCtrl.text = vm.draftInputNotes;

    _operatorCtrl.addListener(_persistDraft);
    _machineCtrl.addListener(_persistDraft);
    _tractorCtrl.addListener(_persistDraft);
    _titleCtrl.addListener(_persistDraft);
    _notesCtrl.addListener(_persistDraft);
    _productNameCtrl.addListener(_persistDraft);
    _activeIngCtrl.addListener(_persistDraft);
    _doseCtrl.addListener(_persistDraft);
    _doseUnitCtrl.addListener(_persistDraft);
    _totalQtyCtrl.addListener(_persistDraft);
    _totalQtyUnitCtrl.addListener(_persistDraft);
    _inputNotesCtrl.addListener(_persistDraft);
  }

  void _persistDraft() {
    final vm = widget.viewModel;
    vm.draftOperatorName = _operatorCtrl.text;
    vm.draftMachineName = _machineCtrl.text;
    vm.draftTractorIdentifier = _tractorCtrl.text;
    vm.draftTitle = _titleCtrl.text;
    vm.draftNotes = _notesCtrl.text;
    vm.draftInputs = List.from(_inputs);
    vm.draftInputType = _selectedInputType;
    vm.draftProductName = _productNameCtrl.text;
    vm.draftActiveIngredient = _activeIngCtrl.text;
    vm.draftDose = _doseCtrl.text;
    vm.draftDoseUnit = _doseUnitCtrl.text;
    vm.draftTotalQuantity = _totalQtyCtrl.text;
    vm.draftTotalQuantityUnit = _totalQtyUnitCtrl.text;
    vm.draftInputNotes = _inputNotesCtrl.text;
  }

  @override
  void dispose() {
    _persistDraft();
    _operatorCtrl.removeListener(_persistDraft);
    _machineCtrl.removeListener(_persistDraft);
    _tractorCtrl.removeListener(_persistDraft);
    _titleCtrl.removeListener(_persistDraft);
    _notesCtrl.removeListener(_persistDraft);
    _productNameCtrl.removeListener(_persistDraft);
    _activeIngCtrl.removeListener(_persistDraft);
    _doseCtrl.removeListener(_persistDraft);
    _doseUnitCtrl.removeListener(_persistDraft);
    _totalQtyCtrl.removeListener(_persistDraft);
    _totalQtyUnitCtrl.removeListener(_persistDraft);
    _inputNotesCtrl.removeListener(_persistDraft);

    _operatorCtrl.dispose();
    _machineCtrl.dispose();
    _tractorCtrl.dispose();
    _titleCtrl.dispose();
    _notesCtrl.dispose();
    _productNameCtrl.dispose();
    _activeIngCtrl.dispose();
    _doseCtrl.dispose();
    _doseUnitCtrl.dispose();
    _totalQtyCtrl.dispose();
    _totalQtyUnitCtrl.dispose();
    _inputNotesCtrl.dispose();
    super.dispose();
  }

  void _addInput() {
    if (!_inputFormKey.currentState!.validate()) return;

    final input = SprayingInput(
      localId: const Uuid().v4(),
      inputType: _selectedInputType,
      productName: _productNameCtrl.text.trim(),
      activeIngredient: _activeIngCtrl.text.trim().isNotEmpty
          ? _activeIngCtrl.text.trim()
          : null,
      dose: double.tryParse(_doseCtrl.text.trim().replaceAll(',', '.')),
      doseUnit: _doseUnitCtrl.text.trim().isNotEmpty
          ? _doseUnitCtrl.text.trim()
          : null,
      totalQuantity: double.tryParse(
        _totalQtyCtrl.text.trim().replaceAll(',', '.'),
      ),
      totalQuantityUnit: _totalQtyUnitCtrl.text.trim().isNotEmpty
          ? _totalQtyUnitCtrl.text.trim()
          : null,
      notes: _inputNotesCtrl.text.trim().isNotEmpty
          ? _inputNotesCtrl.text.trim()
          : null,
    );

    setState(() {
      _inputs.add(input);
      _productNameCtrl.clear();
      _activeIngCtrl.clear();
      _doseCtrl.clear();
      _totalQtyCtrl.clear();
      _inputNotesCtrl.clear();
    });
    _persistDraft();
  }

  Future<void> _onSave() async {
    if (!_generalFormKey.currentState!.validate()) return;

    if (_inputs.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Adicione pelo menos um insumo agrícola para salvar a pulverização.',
          ),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    final saved = await widget.viewModel.saveInputsAndComplete(
      inputs: _inputs,
      operatorName: _operatorCtrl.text.trim(),
      title: _titleCtrl.text.trim().isNotEmpty ? _titleCtrl.text.trim() : null,
      machineName: _machineCtrl.text.trim().isNotEmpty
          ? _machineCtrl.text.trim()
          : null,
      tractorIdentifier: _tractorCtrl.text.trim().isNotEmpty
          ? _tractorCtrl.text.trim()
          : null,
      notes: _notesCtrl.text.trim().isNotEmpty ? _notesCtrl.text.trim() : null,
    );

    if (!mounted) return;
    if (saved) {
      Navigator.pop(context);
    } else {
      setState(() {
        _saveError =
            widget.viewModel.errorMessage ??
            'Não foi possível salvar. Revise as plantas selecionadas.';
      });
    }
  }

  InputDecoration _inputDecoration(
    BuildContext context, {
    Widget? prefixIcon,
    String? hintText,
    EdgeInsetsGeometry? contentPadding,
  }) {
    final colorScheme = Theme.of(context).colorScheme;
    return InputDecoration(
      prefixIcon: prefixIcon,
      hintText: hintText,
      filled: true,
      fillColor: colorScheme.surfaceContainerHighest.withValues(alpha: 0.35),
      contentPadding:
          contentPadding ??
          const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(color: colorScheme.outlineVariant),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(color: colorScheme.outlineVariant),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(color: colorScheme.primary, width: 2),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(color: colorScheme.error),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(color: colorScheme.error, width: 2),
      ),
    );
  }

  Widget _buildFieldLabel(BuildContext context, String label) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Text(
        label,
        style: theme.textTheme.labelLarge?.copyWith(
          fontWeight: FontWeight.bold,
          color: theme.colorScheme.onSurface,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Material(
      color: colorScheme.surface,
      borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      clipBehavior: Clip.antiAlias,
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.sizeOf(context).height * 0.75,
        ),
        child: SafeArea(
          top: false,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Drag handle
              Center(
                child: Container(
                  margin: const EdgeInsets.only(top: 10, bottom: 4),
                  width: 36,
                  height: 4,
                  decoration: BoxDecoration(
                    color: colorScheme.outlineVariant.withValues(alpha: 0.6),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),

              // Header
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 8, 12, 12),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: colorScheme.primaryContainer.withValues(
                          alpha: 0.5,
                        ),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Icon(
                        Icons.science_outlined,
                        color: colorScheme.primary,
                        size: 22,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Registro de Pulverização',
                            style: theme.textTheme.titleLarge?.copyWith(
                              fontWeight: FontWeight.bold,
                              fontSize: 20,
                            ),
                          ),
                          Text(
                            'Informe o operador, máquinas e insumos aplicados',
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: colorScheme.outline,
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close),
                      tooltip: 'Fechar',
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                  ],
                ),
              ),
              const Divider(height: 1),

              // Conteúdo rolável
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // Seção Plantas Afetadas
                      ListenableBuilder(
                        listenable: widget.viewModel,
                        builder: (context, _) {
                          final count = widget.viewModel.reviewedPlants.length;
                          return Material(
                            color: colorScheme.surfaceContainerHighest
                                .withValues(alpha: 0.35),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14),
                              side: BorderSide(
                                color: colorScheme.outlineVariant,
                              ),
                            ),
                            child: Padding(
                              padding: const EdgeInsets.all(14),
                              child: Row(
                                children: [
                                  Icon(
                                    Icons.eco_rounded,
                                    color: colorScheme.primary,
                                    size: 24,
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          '$count plantas atingidas',
                                          style: theme.textTheme.bodyMedium
                                              ?.copyWith(
                                                fontWeight: FontWeight.bold,
                                              ),
                                        ),
                                        Text(
                                          'Calculadas pelo raio de 9m da rota',
                                          style: theme.textTheme.bodySmall
                                              ?.copyWith(
                                                color: colorScheme.outline,
                                              ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  TextButton.icon(
                                    onPressed: () {
                                      Navigator.of(context).pop();
                                      SprayingReviewModal.show(
                                        context,
                                        widget.viewModel,
                                      );
                                    },
                                    icon: const Icon(
                                      Icons.tune_rounded,
                                      size: 18,
                                    ),
                                    label: const Text('Revisar'),
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
                      const SizedBox(height: 20),

                      // Dados do Operador e Máquina
                      Form(
                        key: _generalFormKey,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            _buildFieldLabel(context, 'Operador *'),
                            TextFormField(
                              key: const ValueKey('spraying-operator-input'),
                              controller: _operatorCtrl,
                              decoration: _inputDecoration(
                                context,
                                prefixIcon: const Icon(Icons.person_outline),
                                hintText: 'Nome do operador',
                              ),
                              validator: (v) => v == null || v.trim().isEmpty
                                  ? 'Informe o operador'
                                  : null,
                            ),
                            const SizedBox(height: 14),

                            Row(
                              children: [
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.stretch,
                                    children: [
                                      _buildFieldLabel(context, 'Máquina'),
                                      TextFormField(
                                        controller: _machineCtrl,
                                        decoration: _inputDecoration(
                                          context,
                                          prefixIcon: const Icon(
                                            Icons
                                                .precision_manufacturing_outlined,
                                          ),
                                          hintText: 'Ex: Jacto Advance',
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.stretch,
                                    children: [
                                      _buildFieldLabel(context, 'Id máquina'),
                                      TextFormField(
                                        controller: _tractorCtrl,
                                        decoration: _inputDecoration(
                                          context,
                                          prefixIcon: const Icon(
                                            Icons.agriculture_outlined,
                                          ),
                                          hintText: 'Ex: JD 6110',
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 14),
                            _buildFieldLabel(context, 'Título da operação'),
                            TextFormField(
                              controller: _titleCtrl,
                              decoration: _inputDecoration(
                                context,
                                prefixIcon: const Icon(Icons.title),
                                hintText: 'Ex: Aplicação Fungicida',
                              ),
                            ),
                            const SizedBox(height: 14),

                            _buildFieldLabel(context, 'Observações'),
                            TextFormField(
                              controller: _notesCtrl,
                              maxLines: 2,
                              decoration: _inputDecoration(
                                context,
                                prefixIcon: const Icon(Icons.note_alt_outlined),
                                hintText: 'Condições do tempo',
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 24),

                      // Insumos Adicionados
                      Row(
                        children: [
                          Icon(
                            Icons.format_list_bulleted_rounded,
                            size: 20,
                            color: colorScheme.primary,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            'Insumos Aplicados (${_inputs.length}) *',
                            style: theme.textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),

                      if (_inputs.isEmpty)
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: colorScheme.errorContainer.withValues(
                              alpha: 0.2,
                            ),
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(
                              color: colorScheme.error.withValues(alpha: 0.4),
                            ),
                          ),
                          child: Row(
                            children: [
                              Icon(
                                Icons.warning_amber_rounded,
                                color: colorScheme.error,
                                size: 22,
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Text(
                                  'Nenhum insumo adicionado. É obrigatório registrar ao menos 1 produto.',
                                  style: theme.textTheme.bodySmall?.copyWith(
                                    color: colorScheme.error,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        )
                      else
                        ListView.separated(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          itemCount: _inputs.length,
                          separatorBuilder: (_, _) => const SizedBox(height: 8),
                          itemBuilder: (ctx, idx) {
                            final input = _inputs[idx];
                            return Material(
                              color: colorScheme.surface,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(14),
                                side: BorderSide(
                                  color: colorScheme.outlineVariant,
                                ),
                              ),
                              child: ListTile(
                                leading: Container(
                                  padding: const EdgeInsets.all(8),
                                  decoration: BoxDecoration(
                                    color: colorScheme.primaryContainer
                                        .withValues(alpha: 0.5),
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: Icon(
                                    Icons.science_outlined,
                                    color: colorScheme.primary,
                                    size: 20,
                                  ),
                                ),
                                title: Text(
                                  input.productName,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                subtitle: Text(
                                  'Dose: ${input.dose ?? "-"} ${input.doseUnit ?? ""} • Total: ${input.totalQuantity ?? "-"} ${input.totalQuantityUnit ?? ""}',
                                ),
                                trailing: IconButton(
                                  icon: Icon(
                                    Icons.delete_outline,
                                    color: colorScheme.error,
                                    size: 20,
                                  ),
                                  onPressed: () {
                                    setState(() {
                                      _inputs.removeAt(idx);
                                    });
                                    _persistDraft();
                                  },
                                ),
                              ),
                            );
                          },
                        ),
                      const SizedBox(height: 20),

                      // Formulário para Adicionar Insumo
                      Material(
                        color: colorScheme.surfaceContainerHighest.withValues(
                          alpha: 0.25,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                          side: BorderSide(color: colorScheme.outlineVariant),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Form(
                            key: _inputFormKey,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                Text(
                                  'Adicionar Produto / Insumo',
                                  style: theme.textTheme.titleSmall?.copyWith(
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                const SizedBox(height: 12),

                                _buildFieldLabel(context, 'Tipo de Insumo *'),
                                InputDecorator(
                                  decoration: _inputDecoration(
                                    context,
                                    prefixIcon: const Icon(
                                      Icons.category_outlined,
                                    ),
                                    contentPadding: const EdgeInsets.symmetric(
                                      horizontal: 14,
                                      vertical: 4,
                                    ),
                                  ),
                                  child: DropdownButtonHideUnderline(
                                    child: DropdownButton<String>(
                                      key: const ValueKey(
                                        'spraying-input-type-dropdown',
                                      ),
                                      value: _selectedInputType,
                                      isExpanded: true,
                                      isDense: true,
                                      items: _inputTypes.map((t) {
                                        return DropdownMenuItem(
                                          value: t['value'],
                                          child: Text(t['label']!),
                                        );
                                      }).toList(),
                                      onChanged: (val) {
                                        if (val != null) {
                                          setState(
                                            () => _selectedInputType = val,
                                          );
                                          _persistDraft();
                                        }
                                      },
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 12),

                                _buildFieldLabel(context, 'Nome do Produto *'),
                                TextFormField(
                                  key: const ValueKey(
                                    'spraying-product-name-input',
                                  ),
                                  controller: _productNameCtrl,
                                  decoration: _inputDecoration(
                                    context,
                                    prefixIcon: const Icon(
                                      Icons.medication_outlined,
                                    ),
                                    hintText: 'Ex: Score Flexi',
                                  ),
                                  validator: (v) =>
                                      v == null || v.trim().isEmpty
                                      ? 'Informe o nome do produto'
                                      : null,
                                ),
                                const SizedBox(height: 12),

                                _buildFieldLabel(context, 'Ingrediente Ativo'),
                                TextFormField(
                                  controller: _activeIngCtrl,
                                  decoration: _inputDecoration(
                                    context,
                                    prefixIcon: const Icon(
                                      Icons.biotech_outlined,
                                    ),
                                    hintText: 'Ex: Difenoconazol',
                                  ),
                                ),
                                const SizedBox(height: 12),

                                Row(
                                  children: [
                                    Expanded(
                                      flex: 3,
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.stretch,
                                        children: [
                                          _buildFieldLabel(context, 'Dose'),
                                          TextFormField(
                                            controller: _doseCtrl,
                                            keyboardType:
                                                const TextInputType.numberWithOptions(
                                                  decimal: true,
                                                ),
                                            decoration: _inputDecoration(
                                              context,
                                              hintText: '0.0',
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      flex: 2,
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.stretch,
                                        children: [
                                          _buildFieldLabel(context, 'Unidade'),
                                          TextFormField(
                                            controller: _doseUnitCtrl,
                                            decoration: _inputDecoration(
                                              context,
                                              hintText: 'L/ha',
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 12),

                                Row(
                                  children: [
                                    Expanded(
                                      flex: 3,
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.stretch,
                                        children: [
                                          _buildFieldLabel(
                                            context,
                                            'Quantidade Total',
                                          ),
                                          TextFormField(
                                            controller: _totalQtyCtrl,
                                            keyboardType:
                                                const TextInputType.numberWithOptions(
                                                  decimal: true,
                                                ),
                                            decoration: _inputDecoration(
                                              context,
                                              hintText: '0.0',
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      flex: 2,
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.stretch,
                                        children: [
                                          _buildFieldLabel(context, 'Unidade'),
                                          TextFormField(
                                            controller: _totalQtyUnitCtrl,
                                            decoration: _inputDecoration(
                                              context,
                                              hintText: 'L',
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 16),

                                OutlinedButton.icon(
                                  key: const ValueKey('btn-add-spraying-input'),
                                  style: OutlinedButton.styleFrom(
                                    padding: const EdgeInsets.symmetric(
                                      vertical: 12,
                                    ),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(14),
                                    ),
                                  ),
                                  icon: const Icon(Icons.add_rounded),
                                  label: const Text('Adicionar este Insumo'),
                                  onPressed: _addInput,
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              // FOOTER: Salvar e Confirmar
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (_saveError case final message?) ...[
                      Text(message, style: TextStyle(color: colorScheme.error)),
                      const SizedBox(height: 8),
                    ],
                    FilledButton.icon(
                      key: const ValueKey('btn-confirm-save-spraying'),
                      style: FilledButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                      icon: const Icon(Icons.check_rounded),
                      label: const Text(
                        'Confirmar e Salvar Pulverização',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      onPressed: _onSave,
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
