import 'package:flutter/material.dart';

import '../inspection_view_model.dart';
import 'inspection_filters_modal.dart';

/// Modal para filtragem de plantas por zona e catálogo de ocorrências.
/// Redireciona para [InspectionFiltersModal] preservando compatibilidade retroativa.
class OccurrenceCatalogModal extends StatelessWidget {
  const OccurrenceCatalogModal({
    required this.viewModel,
    super.key,
  });

  final InspectionViewModel viewModel;

  static Future<void> show(BuildContext context, InspectionViewModel viewModel) {
    return InspectionFiltersModal.show(context, viewModel);
  }

  @override
  Widget build(BuildContext context) {
    return InspectionFiltersModal(viewModel: viewModel);
  }
}
