import 'package:flutter/material.dart';

import '../../domain/activity_models.dart';
import '../spraying_view_model.dart';
import 'activity_catalog_components.dart';

class SprayingRegistrationModal extends StatefulWidget {
  const SprayingRegistrationModal({required this.viewModel, super.key});

  final SprayingViewModel viewModel;

  static Future<bool?> show(BuildContext context, SprayingViewModel viewModel) {
    final maxHeight = MediaQuery.sizeOf(context).height * 0.75;
    return showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      constraints: BoxConstraints(maxHeight: maxHeight),
      builder: (modalContext) => Padding(
        key: const ValueKey('spraying-registration-modal-top-margin'),
        padding: EdgeInsets.only(
          top: MediaQuery.paddingOf(modalContext).top + 24,
        ),
        child: SprayingRegistrationModal(viewModel: viewModel),
      ),
    );
  }

  @override
  State<SprayingRegistrationModal> createState() =>
      _SprayingRegistrationModalState();
}

class _SprayingRegistrationModalState extends State<SprayingRegistrationModal> {
  final _formKey = GlobalKey<FormState>();
  final _activityController = TextEditingController(text: 'Pulverização');
  final _responsibleController = TextEditingController();
  late final DateTime _date;
  late final TimeOfDay _time;
  MixtureCatalogItem? _mixture;
  MachineCatalogItem? _machine;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _date = DateTime(now.year, now.month, now.day);
    _time = TimeOfDay.fromDateTime(now);

    final op = widget.viewModel.reviewingOperation;
    if (op != null) {
      if (op.responsible.isNotEmpty && op.responsible != 'Operador') {
        _responsibleController.text = op.responsible;
      }
      _machine = op.machineId == null
          ? null
          : widget.viewModel.machines
              .where((m) => m.id == op.machineId)
              .firstOrNull;
      _mixture = op.mixtureId == null
          ? null
          : widget.viewModel.mixtures
              .where((m) => m.id == op.mixtureId)
              .firstOrNull;
    }
  }

  @override
  void dispose() {
    _activityController.dispose();
    _responsibleController.dispose();
    super.dispose();
  }

  Future<void> _selectMixture() async {
    final item = await showModalBottomSheet<MixtureCatalogItem>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      constraints: BoxConstraints(
        maxHeight: MediaQuery.sizeOf(context).height * 0.75,
      ),
      builder: (_) => MixtureCatalogPicker(catalog: widget.viewModel.mixtures),
    );
    if (item == null || !mounted) return;
    setState(() => _mixture = item);
  }

  Future<void> _selectMachine() async {
    final item = await showModalBottomSheet<MachineCatalogItem>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      constraints: BoxConstraints(
        maxHeight: MediaQuery.sizeOf(context).height * 0.75,
      ),
      builder: (_) => MachineCatalogPicker(catalog: widget.viewModel.machines),
    );
    if (item == null || !mounted) return;
    setState(() => _machine = item);
  }

  InputDecoration _inputDecoration(
    BuildContext context, {
    Widget? prefixIcon,
    String? hintText,
  }) {
    final colorScheme = Theme.of(context).colorScheme;
    return InputDecoration(
      prefixIcon: prefixIcon,
      hintText: hintText,
      filled: true,
      fillColor: colorScheme.surfaceContainerHighest.withValues(alpha: 0.35),
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
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

  Widget _fieldLabel(BuildContext context, String label) => Padding(
    padding: const EdgeInsets.only(bottom: 6),
    child: Text(
      label,
      style: Theme.of(context).textTheme.labelLarge?.copyWith(
        fontWeight: FontWeight.bold,
      ),
    ),
  );

  Future<void> _save() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    final performedAt = composeActivityDateTime(
      _date,
      _time.hour,
      _time.minute,
    );
    final saved = await widget.viewModel.saveReview(
      responsible: _responsibleController.text,
      performedAt: performedAt,
      mixture: _mixture,
      machine: _machine,
    );
    if (!mounted) return;
    if (saved) {
      Navigator.of(context).pop(true);
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          widget.viewModel.errorMessage ?? 'Não foi possível salvar.',
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final viewInsets = MediaQuery.viewInsetsOf(context);
    return Material(
      color: colorScheme.surface,
      borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      clipBehavior: Clip.antiAlias,
      child: AnimatedPadding(
        duration: const Duration(milliseconds: 180),
        padding: EdgeInsets.only(bottom: viewInsets.bottom),
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.sizeOf(context).height * 0.75,
          ),
          child: SafeArea(
            top: false,
            child: Form(
              key: _formKey,
              child: Column(
                children: [
                  Center(
                    child: Container(
                      margin: const EdgeInsets.only(top: 10, bottom: 4),
                      width: 36,
                      height: 4,
                      decoration: BoxDecoration(
                        color: colorScheme.outlineVariant.withValues(
                          alpha: 0.6,
                        ),
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
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
                            Icons.edit_note_rounded,
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
                                'Registrar operação',
                                style: theme.textTheme.titleLarge?.copyWith(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 20,
                                ),
                              ),
                              Text(
                                'Informe os dados e recursos utilizados',
                                style: theme.textTheme.bodySmall?.copyWith(
                                  color: colorScheme.outline,
                                ),
                              ),
                            ],
                          ),
                        ),
                        IconButton(
                          tooltip: 'Fechar',
                          onPressed: () => Navigator.of(context).pop(false),
                          icon: const Icon(Icons.close),
                        ),
                      ],
                    ),
                  ),
                  const Divider(height: 1),
                  Expanded(
                    child: ListView(
                      padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
                      children: [
                        _fieldLabel(context, 'Atividade realizada *'),
                        TextFormField(
                          key: const ValueKey('spraying-activity'),
                          controller: _activityController,
                          readOnly: true,
                          decoration: _inputDecoration(
                            context,
                            prefixIcon: const Icon(Icons.task_alt_rounded),
                          ),
                        ),
                        const SizedBox(height: 14),
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  _fieldLabel(context, 'Data *'),
                                  OutlinedButton.icon(
                                    key: const ValueKey('spraying-date'),
                                    onPressed: null,
                                    icon: const Icon(
                                      Icons.calendar_today_outlined,
                                    ),
                                    label: Text(_dateLabel(_date)),
                                    style: OutlinedButton.styleFrom(
                                      minimumSize: const Size.fromHeight(48),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(14),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  _fieldLabel(context, 'Hora *'),
                                  OutlinedButton.icon(
                                    key: const ValueKey('spraying-time'),
                                    onPressed: null,
                                    icon: const Icon(Icons.schedule),
                                    label: Text(_time.format(context)),
                                    style: OutlinedButton.styleFrom(
                                      minimumSize: const Size.fromHeight(48),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(14),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 14),
                        _fieldLabel(context, 'Responsável *'),
                        TextFormField(
                          key: const ValueKey('spraying-responsible'),
                          controller: _responsibleController,
                          textCapitalization: TextCapitalization.words,
                          decoration: _inputDecoration(
                            context,
                            prefixIcon: const Icon(
                              Icons.person_outline_rounded,
                            ),
                            hintText: 'Ex.: João',
                          ),
                          validator: _required,
                        ),
                        const SizedBox(height: 22),
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                'Máquina/Trator',
                                style: theme.textTheme.titleMedium?.copyWith(
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                            FilledButton.tonalIcon(
                              key: const ValueKey('spraying-select-machine'),
                              onPressed: _selectMachine,
                              icon: Icon(
                                _machine == null ? Icons.add : Icons.swap_horiz,
                              ),
                              label: Text(
                                _machine == null ? 'Selecionar' : 'Trocar',
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Opcional. Selecione uma opção cadastrada; os dados '
                          'da máquina são somente leitura.',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: colorScheme.onSurfaceVariant,
                          ),
                        ),
                        const SizedBox(height: 10),
                        if (_machine == null)
                          const Card(
                            child: Padding(
                              padding: EdgeInsets.all(16),
                              child: Text('Nenhuma máquina selecionada.'),
                            ),
                          )
                        else
                          SelectedMachineCard(
                            machine: _machine!,
                            onRemove: () => setState(() => _machine = null),
                          ),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                'Calda utilizada',
                                style: theme.textTheme.titleMedium?.copyWith(
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                            FilledButton.tonalIcon(
                              key: const ValueKey('spraying-select-mixture'),
                              onPressed: _selectMixture,
                              icon: Icon(
                                _mixture == null ? Icons.add : Icons.swap_horiz,
                              ),
                              label: Text(
                                _mixture == null ? 'Selecionar' : 'Trocar',
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Somente leitura. Nome, observações, insumos, doses e '
                          'unidades da calda não podem ser alterados.',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: colorScheme.onSurfaceVariant,
                          ),
                        ),
                        const SizedBox(height: 10),
                        if (_mixture == null)
                          const Card(
                            child: Padding(
                              padding: EdgeInsets.all(16),
                              child: Text('Nenhuma calda selecionada.'),
                            ),
                          )
                        else
                          SelectedMixtureCard(
                            mixture: _mixture!,
                            onRemove: () => setState(() => _mixture = null),
                          ),
                      ],
                    ),
                  ),
                  const Divider(height: 1),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 10, 16, 16),
                    child: ListenableBuilder(
                      listenable: widget.viewModel,
                      builder: (context, _) => FilledButton.icon(
                        key: const ValueKey('spraying-save'),
                        style: FilledButton.styleFrom(
                          minimumSize: const Size.fromHeight(50),
                        ),
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
                          widget.viewModel.saving ? 'Salvando...' : 'Salvar',
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  String? _required(String? value) =>
      value?.trim().isEmpty ?? true ? 'Campo obrigatório' : null;

  String _dateLabel(DateTime date) =>
      '${date.day.toString().padLeft(2, '0')}/'
      '${date.month.toString().padLeft(2, '0')}/${date.year}';
}
