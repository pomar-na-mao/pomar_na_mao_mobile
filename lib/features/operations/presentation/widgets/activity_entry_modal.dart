import 'package:flutter/material.dart';

import '../../../../core/ui/app_form_field.dart';
import '../../../../core/ui/full_height_form_modal.dart';
import '../../domain/activity_models.dart';
import '../activity_view_model.dart';
import 'activity_catalog_components.dart';

class ActivityEntryModal extends StatefulWidget {
  const ActivityEntryModal({required this.viewModel, super.key});

  final ActivityViewModel viewModel;

  static Future<bool?> show(BuildContext context, ActivityViewModel viewModel) {
    return showFullHeightFormModal<bool>(
      context: context,
      builder: (_) => ActivityEntryModal(viewModel: viewModel),
    );
  }

  @override
  State<ActivityEntryModal> createState() => _ActivityEntryModalState();
}

class _ActivityEntryModalState extends State<ActivityEntryModal> {
  final _formKey = GlobalKey<FormState>();
  final _activityController = TextEditingController();
  final _responsibleController = TextEditingController();
  late DateTime _date;
  late TimeOfDay _time;
  MixtureCatalogItem? _mixture;
  MachineCatalogItem? _machine;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _date = DateTime(now.year, now.month, now.day);
    _time = TimeOfDay.fromDateTime(now);
  }

  @override
  void dispose() {
    _activityController.dispose();
    _responsibleController.dispose();
    super.dispose();
  }

  Future<void> _selectDate() async {
    final selected = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (selected != null && mounted) setState(() => _date = selected);
  }

  Future<void> _selectTime() async {
    final selected = await showTimePicker(context: context, initialTime: _time);
    if (selected != null && mounted) setState(() => _time = selected);
  }

  Future<void> _selectMixture() async {
    final item = await showFullHeightFormModal<MixtureCatalogItem>(
      context: context,
      builder: (_) => _MixtureCatalogPicker(catalog: widget.viewModel.mixtures),
    );
    if (item == null || !mounted) return;
    setState(() => _mixture = item);
  }

  Future<void> _selectMachine() async {
    final item = await showFullHeightFormModal<MachineCatalogItem>(
      context: context,
      builder: (_) => _MachineCatalogPicker(catalog: widget.viewModel.machines),
    );
    if (item == null || !mounted) return;
    setState(() => _machine = item);
  }

  Future<void> _save() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    final saved = await widget.viewModel.save(
      activity: _activityController.text,
      performedAt: composeActivityDateTime(_date, _time.hour, _time.minute),
      responsible: _responsibleController.text,
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
        child: SizedBox.expand(
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
                        const AppFormFieldLabel('Atividade realizada *'),
                        TextFormField(
                          key: const ValueKey('activity-activity'),
                          controller: _activityController,
                          textCapitalization: TextCapitalization.sentences,
                          decoration: appFormInputDecoration(
                            context,
                            prefixIcon: const Icon(Icons.task_alt_rounded),
                            hintText: 'Ex.: roçagem',
                          ),
                          validator: _required,
                        ),
                        const SizedBox(height: 14),
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  const AppFormFieldLabel('Data *'),
                                  OutlinedButton.icon(
                                    key: const ValueKey('activity-date'),
                                    onPressed: _selectDate,
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
                                  const AppFormFieldLabel('Hora *'),
                                  OutlinedButton.icon(
                                    key: const ValueKey('activity-time'),
                                    onPressed: _selectTime,
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
                        const AppFormFieldLabel('Responsável *'),
                        TextFormField(
                          key: const ValueKey('activity-responsible'),
                          controller: _responsibleController,
                          textCapitalization: TextCapitalization.words,
                          decoration: appFormInputDecoration(
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
                              key: const ValueKey('activity-select-machine'),
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
                          _SelectedMachineCard(
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
                              key: const ValueKey('activity-select-mixture'),
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
                          _SelectedMixtureCard(
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
                        key: const ValueKey('activity-save'),
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

typedef _SelectedMachineCard = SelectedMachineCard;
typedef _SelectedMixtureCard = SelectedMixtureCard;
typedef _MixtureCatalogPicker = MixtureCatalogPicker;
typedef _MachineCatalogPicker = MachineCatalogPicker;
