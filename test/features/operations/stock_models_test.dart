import 'package:flutter_test/flutter_test.dart';
import 'package:pomar_na_mao_mobile/features/operations/domain/stock_models.dart';

void main() {
  test('requires a valid quantity and unit', () {
    const invalidUnit = StockDraft(
      name: 'Produto',
      type: 'FUNGICIDE',
      registeredForCrop: true,
      quantity: 3,
      unit: '',
    );
    const negative = StockDraft(
      name: 'Produto',
      type: 'FUNGICIDE',
      registeredForCrop: true,
      quantity: -1,
      unit: 'Kg',
    );
    const valid = StockDraft(
      name: 'Produto',
      type: 'FUNGICIDE',
      registeredForCrop: true,
      quantity: 3.5,
      unit: 'Kg',
    );

    expect(invalidUnit.validate(), 'Selecione uma unidade válida.');
    expect(negative.validate(), 'A quantidade não pode ser negativa.');
    expect(valid.validate(), isNull);
  });

  test('translates default stock types and preserves custom labels', () {
    expect(stockTypeLabel('FUNGICIDE'), 'Fungicida');
    expect(stockTypeLabel('CUSTOM_TYPE'), 'CUSTOM_TYPE');
  });
}
